package Router_Architecture.sync_cmr

import DataStruct.Packet
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/**
  * Clocked Fig. 5 IPM: SyncCmrRCU plus SyncCmrBuffer.  Quadtree routing
  * is unchanged; Mesh AMU is omitted, matching the async IPM.
  */
class SyncCmrIPM(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int
) extends Module {
  override def desiredName: String = "SyncCmrIPM"

  require(CMRParameters.SupportedLaneGeometries.contains(
    (config.childLanes, config.parentLanes)
  ))
  require(routerLevel >= 1 && routerLevel <= 3)
  require(ingressPort >= 0 && ingressPort < config.totalPorts)
  require(
    CMRParameters.legalOutputDirections(config, ingressPort).length ==
      CMRParameters.BranchCount
  )

  val io = IO(new Bundle {
    val validIn = Input(Bool())
    val Datain = Input(new Packet)
    val readyOut = Output(Bool())

    val readyIn = Input(Vec(CMRParameters.BranchCount, Bool()))
    val TailPassed = Input(Vec(CMRParameters.BranchCount, Bool()))
    val validOut = Output(Vec(CMRParameters.BranchCount, Bool()))
    val Dataout = Output(Vec(CMRParameters.BranchCount, new Packet))
    val PathEnabled = Output(Vec(CMRParameters.BranchCount, Bool()))
  })

  private val RouteComputationUnit = Module(new SyncCmrRCU(
    config, xCoordinate, yCoordinate, routerLevel, ingressPort
  ))
  private val Buffer = Module(new SyncCmrBuffer)

  RouteComputationUnit.io.validIn := io.validIn
  RouteComputationUnit.io.readyIn := Buffer.io.readyOut
  RouteComputationUnit.io.Datain := io.Datain
  RouteComputationUnit.io.TailPassed := io.TailPassed

  Buffer.io.validIn := io.validIn
  Buffer.io.Datain := io.Datain
  Buffer.io.PathEnabled := RouteComputationUnit.io.PathEnabled
  Buffer.io.readyIn := io.readyIn

  dontTouch(RouteComputationUnit.io.Mat)
  dontTouch(RouteComputationUnit.io.RouteSel)

  io.readyOut := Buffer.io.readyOut
  io.validOut := Buffer.io.validOut
  io.Dataout := Buffer.io.Dataout
  io.PathEnabled := RouteComputationUnit.io.PathEnabled
}

object SyncCmrIPMMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val ingressPort = args.drop(1).headOption.map(_.toInt).getOrElse(4)
  require(routerLevel >= 1 && routerLevel <= 3)
  private val config = SyncCmrConfig(1, 1)
  require(ingressPort >= 0 && ingressPort < config.totalPorts)
  emitVerilog(
    new SyncCmrIPM(config, 0, 0, routerLevel, ingressPort),
    Array("--target-dir", s"generated_sync_cmr/ipm_l${routerLevel}_p$ingressPort")
  )
}
