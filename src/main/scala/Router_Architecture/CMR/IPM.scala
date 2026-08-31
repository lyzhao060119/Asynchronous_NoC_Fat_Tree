package Router_Architecture.CMR

import DataStruct.Packet
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/**
  * Continuous paper Fig. 5 Input Port Module.
  *
  * The Mesh-specific Address Modifier Units are intentionally omitted: both
  * the repository quadtree `RoutingLogic` and constructor-selected
  * `RoutingLogic_mesh` already compute the complete multicast output set.
  * Ingress is suppressed through UltraTopology.
  */
class IPM(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int,
    useMeshRouting: Boolean = false,
    meshGridSize: Int = 8
) extends Module {
  override def desiredName: String = "IPM"

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
    val Reqin = Input(Bool())
    val Datain = Input(new Packet)
    val Ackout = Output(Bool())

    val Ackin = Input(Vec(CMRParameters.BranchCount, Bool()))
    val TailPassed = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Reqout = Output(Vec(CMRParameters.BranchCount, Bool()))
    val Dataout = Output(Vec(CMRParameters.BranchCount, new Packet))
    val PathEnabled = Output(Vec(CMRParameters.BranchCount, Bool()))
  })

  private val RouteComputationUnit = Module(new RCU(
    config, xCoordinate, yCoordinate, routerLevel, ingressPort,
    useMeshRouting, meshGridSize
  ))
  private val Buffer = Module(new CMRBuffer)

  RouteComputationUnit.io.Reqin := io.Reqin
  RouteComputationUnit.io.Ackout := Buffer.io.Ackout
  RouteComputationUnit.io.Datain := io.Datain
  RouteComputationUnit.io.TailPassed := io.TailPassed

  Buffer.io.Reqin := io.Reqin
  Buffer.io.Datain := io.Datain
  Buffer.io.PathEnabled := RouteComputationUnit.io.PathEnabled
  Buffer.io.Ackin := io.Ackin

  // Keep Fig. 6's decode (Mat) and bundled RouteSel pulse available to
  // integration-level asynchronous verification without adding them to
  // the IPM's external API.
  dontTouch(RouteComputationUnit.io.Mat)
  dontTouch(RouteComputationUnit.io.RouteSel)

  io.Ackout := Buffer.io.Ackout
  io.Reqout := Buffer.io.Reqout
  io.Dataout := Buffer.io.Dataout
  io.PathEnabled := RouteComputationUnit.io.PathEnabled
}

object IPMMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val ingressPort = args.drop(1).headOption.map(_.toInt).getOrElse(4)
  require(routerLevel >= 1 && routerLevel <= 3)
  require(ingressPort >= 0 && ingressPort < CMRParameters.RouterPortCount)

  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = CMRParameters.CellCount,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  emitVerilog(
    new IPM(config, 0, 0, routerLevel, ingressPort),
    Array("--target-dir", s"generated_cmr/ipm_l${routerLevel}_p$ingressPort")
  )
}
