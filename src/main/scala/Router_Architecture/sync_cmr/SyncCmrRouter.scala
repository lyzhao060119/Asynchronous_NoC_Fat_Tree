package Router_Architecture.sync_cmr

import Router_Architecture.CMR.CMRParameters
import Router_Architecture.ultra.UltraTopology
import chisel3._
import chisel3.util.Mux1H

/**
  * Clocked Continuous-Time Replication router.  Port geometry matches
  * `CMRRouter` (Thin 1-1 and Fat lane profiles).  Handshake is valid/ready.
  * Elaboration only: closed-loop check is clocked DC + MAXIMUM SDF GLS.
  */
class SyncCmrRouter(
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    childLanes: Int = 1,
    parentLanes: Int = 1
) extends Module {
  override def desiredName: String = "SyncCmrRouter"
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))

  private val config = SyncCmrConfig(childLanes, parentLanes)
  private val PortCount = config.totalPorts
  private val BranchCount = CMRParameters.BranchCount

  require((0 until PortCount).forall { input =>
    CMRParameters.legalOutputDirections(config, input).length == BranchCount
  })
  require(config.legalEdges.forall { case (input, output) =>
    config.dirOfPhys(input) != config.dirOfPhys(output)
  })

  val io = IO(new Bundle {
    val inputs = new SyncDirGroupedIO(childLanes, parentLanes)
    val outputs = Flipped(new SyncDirGroupedIO(childLanes, parentLanes))
  })

  private def inputPort(index: Int): SyncVrPacket = {
    val direction = config.dirOfPhys(index)
    val lane = config.laneOfPhys(index)
    if (direction < 4) io.inputs.child(direction)(lane)
    else io.inputs.parent(lane)
  }

  private def outputPort(index: Int): SyncVrPacket = {
    val direction = config.dirOfPhys(index)
    val lane = config.laneOfPhys(index)
    if (direction < 4) io.outputs.child(direction)(lane)
    else io.outputs.parent(lane)
  }

  private val InputPortModules = Seq.tabulate(PortCount) { input =>
    Module(new SyncCmrIPM(config, xCoordinate, yCoordinate, routerLevel, input))
  }
  private val OutputPortModules = Seq.tabulate(PortCount) { output =>
    Module(new SyncOPM(config, output))
  }

  for (input <- 0 until PortCount) {
    val port = inputPort(input)
    val ipm = InputPortModules(input)
    ipm.io.validIn := port.hs.valid
    ipm.io.Datain := port.data
    port.hs.ready := ipm.io.readyOut
  }

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
        OutputPortModules(output).io.validIn(source) := ipm.io.validOut(branch)
        ipm.io.readyIn(branch) := OutputPortModules(output).io.readyIn(source)
        ipm.io.TailPassed(branch) := OutputPortModules(output).io.TailPassed(source)
      } else {
        val selector = Module(new SyncLaneSelector(laneCount))
        selector.io.PathEnabled := ipm.io.PathEnabled(branch)
        val laneReadys = Wire(Vec(laneCount, Bool()))
        val laneTails = Wire(Vec(laneCount, Bool()))
        for ((output, lane) <- outputs.zipWithIndex) {
          val source = sourceIndices(lane)
          val otherGrants = OutputPortModules(output).io.Grant.zipWithIndex.collect {
            case (g, index) if index != source => g
          }
          selector.io.OtherGrant(lane) :=
            (if (otherGrants.isEmpty) false.B else otherGrants.reduce(_ || _))
          selector.io.TailPassed(lane) := OutputPortModules(output).io.TailPassed(source)

          OutputPortModules(output).io.PktPathEnable(source) :=
            ipm.io.PathEnabled(branch) && selector.io.LaneSelect(lane)
          OutputPortModules(output).io.Datain(source) := ipm.io.Dataout(branch)
          OutputPortModules(output).io.validIn(source) :=
            ipm.io.validOut(branch) && selector.io.LaneSelect(lane)
          laneReadys(lane) := OutputPortModules(output).io.readyIn(source)
          laneTails(lane) := OutputPortModules(output).io.TailPassed(source)
        }
        ipm.io.readyIn(branch) := Mux1H(selector.io.LaneSelect, laneReadys)
        ipm.io.TailPassed(branch) := Mux1H(selector.io.LaneSelect, laneTails)
      }
    }
  }

  for (output <- 0 until PortCount) {
    val port = outputPort(output)
    val opm = OutputPortModules(output)
    dontTouch(opm.io.Grant)
    port.hs.valid := opm.io.validOut
    port.data := opm.io.Dataout
    opm.io.readyOut := port.hs.ready
  }
}

object SyncCmrRouterMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val childLanes = args.drop(1).headOption.map(_.toInt).getOrElse(1)
  private val parentLanes = args.drop(2).headOption.map(_.toInt).getOrElse(1)
  require(routerLevel >= 1 && routerLevel <= 3)
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  private val targetDir =
    if (childLanes == 1 && parentLanes == 1) s"generated_sync_cmr/router_l$routerLevel"
    else s"generated_sync_cmr/router_l${routerLevel}_c${childLanes}_p${parentLanes}"

  emitVerilog(
    new SyncCmrRouter(0, 0, routerLevel, childLanes, parentLanes),
    Array("--target-dir", targetDir)
  )
  println("CMR_SYNC_EMIT " + targetDir)
}

object SyncCmrPrimitiveMatrixEmitMain extends App {
  private val jobs = Seq((1, 1, 1), (2, 2, 2))
  for ((level, child, parent) <- jobs) {
    require(CMRParameters.SupportedLaneGeometries.contains((child, parent)))
    val dir =
      if (child == 1 && parent == 1) s"generated_sync_cmr/router_l$level"
      else s"generated_sync_cmr/router_l${level}_c${child}_p${parent}"
    emitVerilog(
      new SyncCmrRouter(0, 0, level, child, parent),
      Array("--target-dir", dir)
    )
    val selectors = CMRParameters.expectedLaneAdapters(child, parent)
    println(
      s"CMR_SYNC_PRIMITIVE_EMIT L$level c${child}p$parent " +
        s"SELECTOR=$selectors dir=$dir"
    )
  }
}
