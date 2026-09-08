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
    meshGridSize: Int = 8,
    meshCoordShift: Int = 0
) extends Module {
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  if (useMeshRouting) {
    require(routerLevel == 1, "mesh / TopMesh routers are elaborated as level-1")
    require(meshGridSize >= 2 && meshGridSize <= 64)
    require(meshCoordShift >= 0 && meshCoordShift <= 5)
    require(xCoordinate >= 0 && xCoordinate < meshGridSize)
    require(yCoordinate >= 0 && yCoordinate < meshGridSize)
  } else {
    require(meshCoordShift == 0, "quadtree routers do not shift mesh coordinates")
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
      useMeshRouting, meshGridSize, meshCoordShift
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
        val selector = Module(new LaneSelecterCelement(laneCount))
        selector.io.reset := reset.asBool
        selector.io.PacketActive := ipm.io.PathEnabled(branch)
        val held = VecInit(selector.io.LaneSelect.asBools)
        val laneIsEmpty = outputs.zipWithIndex.map { case (output, lane) =>
          val source = sourceIndices(lane)
          val otherGrants = OutputPortModules(output).io.Grant.zipWithIndex.collect {
            case (grant, index) if index != source => grant
          }
          !(if (otherGrants.isEmpty) false.B else otherGrants.reduce(_ || _))
        }
        selector.io.LaneIsEmpty := VecInit(laneIsEmpty).asUInt
        for ((output, lane) <- outputs.zipWithIndex) {
          val source = sourceIndices(lane)
          OutputPortModules(output).io.PktPathEnable(source) :=
            ipm.io.PathEnabled(branch) && held(lane)
          OutputPortModules(output).io.Datain(source) := ipm.io.Dataout(branch)
        }

        val adapter = Module(new LanePhaseAdapterDFF(laneCount))
        val laneAcks = Wire(Vec(laneCount, Bool()))
        val laneTails = Wire(Vec(laneCount, Bool()))

        adapter.io.reset := reset.asBool
        adapter.io.LaneSelect := selector.io.LaneSelect
        for ((output, lane) <- outputs.zipWithIndex) {
          val source = sourceIndices(lane)
          laneAcks(lane) := OutputPortModules(output).io.Ackout(source)
          laneTails(lane) := held(lane) &&
            OutputPortModules(output).io.TailPassed(source)
          OutputPortModules(output).io.Reqin(source) := adapter.io.OPMReqIn(lane)
        }
        adapter.io.IPMReqOut :=
          VecInit(Seq.fill(laneCount)(ipm.io.Reqout(branch))).asUInt
        adapter.io.OPMAckOut := laneAcks.asUInt
        ipm.io.Ackin(branch) :=
          (adapter.io.IPMAckIn & selector.io.LaneSelect).orR
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
      useMeshRouting: Boolean,
      xCoordinate: Int = 0,
      yCoordinate: Int = 0
  ): String = {
    val base =
      if (useMeshRouting)
        s"generated_cmr/router_l${routerLevel}_c${childLanes}_p${parentLanes}_mesh"
      else if (childLanes == 1 && parentLanes == 1)
        s"generated_cmr/router_l$routerLevel"
      else
        s"generated_cmr/router_l${routerLevel}_c${childLanes}_p${parentLanes}"
    if (xCoordinate == 0 && yCoordinate == 0) base
    else s"${base}_x${xCoordinate}_y${yCoordinate}"
  }
}

object CMRRouterMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val childLanes = args.drop(1).headOption.map(_.toInt).getOrElse(1)
  private val parentLanes = args.drop(2).headOption.map(_.toInt).getOrElse(1)
  private val meshFlag = args.drop(3).headOption.getOrElse("0")
  private val useMesh = meshFlag == "1" || meshFlag.equalsIgnoreCase("mesh")
  private val meshGrid = args.drop(4).headOption.map(_.toInt).getOrElse(8)
  private val xCoordinate = args.drop(5).headOption.map(_.toInt).getOrElse(0)
  private val yCoordinate = args.drop(6).headOption.map(_.toInt).getOrElse(0)
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  private val targetDir = CMRRouterEmit.targetDir(
    routerLevel, childLanes, parentLanes, useMesh, xCoordinate, yCoordinate
  )
  emitVerilog(
    new CMRRouter(
      xCoordinate, yCoordinate, routerLevel, childLanes, parentLanes, useMesh, meshGrid
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
