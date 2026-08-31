package Router_Architecture.CMR

import DataStruct.HS_Packet
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import Router_Architecture.ultra.UltraTopology
import chisel3._

/** Continuous-Time Replication router with exact per-direction lane geometry. */
class CMRRouter(
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    childLanes: Int = 1,
    parentLanes: Int = 1,
    useMeshRouting: Boolean = false,
    meshGridSize: Int = 8
) extends Module {
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  if (useMeshRouting) {
    require(routerLevel == 1, "mesh / TopMesh routers are elaborated as level-1")
    require(meshGridSize >= 2 && meshGridSize <= 64)
    require(xCoordinate >= 0 && xCoordinate < meshGridSize)
    require(yCoordinate >= 0 && yCoordinate < meshGridSize)
  }

  private val config = RouterModuleConfig(
    childLanes = childLanes,
    parentLanes = parentLanes,
    fifoDepth = CMRParameters.CellCount,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )
  private val PortCount = config.totalPorts
  private val BranchCount = CMRParameters.BranchCount

  require((0 until PortCount).forall { input =>
    CMRParameters.legalOutputDirections(config, input).length == BranchCount
  })
  require(config.legalEdges.forall { case (input, output) =>
    config.dirOfPhys(input) != config.dirOfPhys(output)
  })

  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(childLanes, parentLanes)
    val outputs = Flipped(new RouterDirGroupedHSIO(childLanes, parentLanes))
  })

  private def inputPort(index: Int): HS_Packet = {
    val direction = config.dirOfPhys(index)
    val lane = config.laneOfPhys(index)
    if (direction < 4) io.inputs.child(direction)(lane)
    else io.inputs.parent(lane)
  }

  private def outputPort(index: Int): HS_Packet = {
    val direction = config.dirOfPhys(index)
    val lane = config.laneOfPhys(index)
    if (direction < 4) io.outputs.child(direction)(lane)
    else io.outputs.parent(lane)
  }

  private val InputPortModules = Seq.tabulate(PortCount) { input =>
    Module(new IPM(
      config, xCoordinate, yCoordinate, routerLevel, input,
      useMeshRouting, meshGridSize
    ))
  }
  private val OutputPortModules = Seq.tabulate(PortCount) { output =>
    Module(new OPM(config, output))
  }

  for (input <- 0 until PortCount) {
    val port = inputPort(input)
    val ipm = InputPortModules(input)
    ipm.io.Reqin := port.HS.Req
    ipm.io.Datain := port.Data
    port.HS.Ack := ipm.io.Ackout
  }

  // Four direction-level CMR reads are expanded into the exact physical
  // lanes of their destination direction.  Each sparse edge is connected
  // once; an ingress direction is removed in its entirety.
  for (input <- 0 until PortCount) {
    val ipm = InputPortModules(input)
    val legalDirections = CMRParameters.legalOutputDirections(config, input)

    for ((outputDirection, branch) <- legalDirections.zipWithIndex) {
      val laneCount = config.lanesPerDir(outputDirection)
      val outputs = (0 until laneCount).map(config.physIndex(outputDirection, _))
      val sourceIndices = outputs.map { output =>
        val source = UltraTopology.legalInputPorts(config, output).indexOf(input)
        require(source >= 0)
        source
      }

      if (laneCount == 1) {
        val output = outputs.head
        val source = sourceIndices.head
        OutputPortModules(output).io.PktPathEnable(source) := ipm.io.PathEnabled(branch)
        OutputPortModules(output).io.Datain(source) := ipm.io.Dataout(branch)
        OutputPortModules(output).io.Reqin(source) := ipm.io.Reqout(branch)
        ipm.io.Ackin(branch) := OutputPortModules(output).io.Ackout(source)
        ipm.io.TailPassed(branch) := OutputPortModules(output).io.TailPassed(source)
      } else {
        val selector = Module(new ContinuousLaneSelector(laneCount))
        selector.io.PathEnabled := ipm.io.PathEnabled(branch)
        for ((output, lane) <- outputs.zipWithIndex) {
          val source = sourceIndices(lane)
          val otherGrants = OutputPortModules(output).io.Grant.zipWithIndex.collect {
            case (grant, index) if index != source => grant
          }
          selector.io.OtherGrant(lane) := (if (otherGrants.isEmpty) false.B
            else otherGrants.reduce(_ || _))

          OutputPortModules(output).io.PktPathEnable(source) :=
            ipm.io.PathEnabled(branch) && selector.io.LaneSelect(lane)
          OutputPortModules(output).io.Datain(source) := ipm.io.Dataout(branch)
        }

        val adapter = Module(new LanePhaseAdapter(laneCount))
        val commits = Wire(Vec(laneCount, Bool()))
        val laneAcks = Wire(Vec(laneCount, Bool()))
        val laneTails = Wire(Vec(laneCount, Bool()))

        adapter.io.reset := reset.asBool
        adapter.io.Reqin := ipm.io.Reqout(branch)
        adapter.io.LaneSelect := selector.io.LaneSelect.asUInt
        for ((output, lane) <- outputs.zipWithIndex) {
          val source = sourceIndices(lane)
          commits(lane) := selector.io.LaneSelect(lane) &&
            OutputPortModules(output).io.Grant(source)
          laneAcks(lane) := OutputPortModules(output).io.Ackout(source)
          laneTails(lane) := commits(lane) &&
            OutputPortModules(output).io.TailPassed(source)
          OutputPortModules(output).io.Reqin(source) := adapter.io.Reqout(lane)
        }
        adapter.io.Commit := commits.asUInt
        adapter.io.Ackin := laneAcks.asUInt
        ipm.io.Ackin(branch) := adapter.io.Ackout
        ipm.io.TailPassed(branch) := laneTails.asUInt.orR
      }
    }
  }

  for (output <- 0 until PortCount) {
    val port = outputPort(output)
    val opm = OutputPortModules(output)
    dontTouch(opm.io.Grant)
    port.HS.Req := opm.io.Reqout
    port.Data := opm.io.Dataout
    opm.io.Ackin := port.HS.Ack
  }
}

object CMRRouterEmit {
  def targetDir(
      routerLevel: Int,
      childLanes: Int,
      parentLanes: Int,
      useMeshRouting: Boolean
  ): String = {
    if (useMeshRouting)
      s"generated_cmr/router_l${routerLevel}_c${childLanes}_p${parentLanes}_mesh"
    else if (childLanes == 1 && parentLanes == 1)
      s"generated_cmr/router_l$routerLevel"
    else
      s"generated_cmr/router_l${routerLevel}_c${childLanes}_p${parentLanes}"
  }
}

object CMRRouterMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val childLanes = args.drop(1).headOption.map(_.toInt).getOrElse(1)
  private val parentLanes = args.drop(2).headOption.map(_.toInt).getOrElse(1)
  private val meshFlag = args.drop(3).headOption.getOrElse("0")
  private val useMesh = meshFlag == "1" || meshFlag.equalsIgnoreCase("mesh")
  private val meshGrid = args.drop(4).headOption.map(_.toInt).getOrElse(8)
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  private val targetDir = CMRRouterEmit.targetDir(
    routerLevel, childLanes, parentLanes, useMesh
  )
  emitVerilog(
    new CMRRouter(
      0, 0, routerLevel, childLanes, parentLanes, useMesh, meshGrid
    ),
    Array("--target-dir", targetDir)
  )
  println("CMR_EMIT " + targetDir)
}

/** Emit every DATE V3 async Router primitive used for DC / hop PPA. */
object CMRPrimitiveMatrixEmitMain extends App {
  private val jobs = Seq(
    (1, 1, 1, false, 8),
    (2, 1, 1, false, 8),
    (3, 1, 1, false, 8),
    (1, 1, 2, false, 8),
    (2, 2, 2, false, 8),
    (3, 2, 2, false, 8),
    (2, 2, 4, false, 8),
    (3, 4, 8, false, 8),
    (1, 2, 2, true, 8),
    (1, 1, 1, true, 8)
  )
  for ((level, child, parent, mesh, grid) <- jobs) {
    require(CMRParameters.SupportedLaneGeometries.contains((child, parent)))
    val dir = CMRRouterEmit.targetDir(level, child, parent, mesh)
    emitVerilog(
      new CMRRouter(0, 0, level, child, parent, mesh, grid),
      Array("--target-dir", dir)
    )
    val adapters = CMRParameters.expectedLaneAdapters(child, parent)
    println(
      s"CMR_PRIMITIVE_EMIT L$level c${child}p$parent mesh=$mesh " +
        s"ADAPTER=$adapters dir=$dir"
    )
  }
}
