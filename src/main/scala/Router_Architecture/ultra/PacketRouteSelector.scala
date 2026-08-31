package Router_Architecture.ultra

import DataStruct.Packet
import Router_Architecture.algorithm.RoutingLogic
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import tool.{AsyncDelay, DelayElement}

/** Ultra Fig. 5(a) / Transition Fig. 2 head-only packet route selector. */
class PacketRouteSelector(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int
) extends RawModule {
  require(ingressPort >= 0 && ingressPort < config.totalPorts)
  private val legalOutputPorts = UltraTopology.legalOutputPorts(config, ingressPort)
  private val nBranches = legalOutputPorts.length
  private val routing = new RoutingLogic(xCoordinate, yCoordinate)
  private val ingressDir = config.dirOfPhys(ingressPort).U(3.W)
  val io = IO(new Bundle {
    val RoutingInfo = Input(new Packet)
    val ReqX = Input(Bool())
    val AckX = Input(Bool())
    val RS = Output(Vec(nBranches, Bool()))
    val PRSReady = Output(Bool())
  })
  val matchedDelay = Module(new DelayElement(
    AsyncDelay.steps(1, AsyncDelay.UltraPrsMatched),
    AsyncDelay.unitPs(AsyncDelay.UltraPrsMatched)
  ))
  matchedDelay.io.I := io.ReqX
  val requestActive = matchedDelay.io.Z ^ io.AckX
  io.PRSReady := requestActive
  val headActive = requestActive && io.RoutingInfo.flit(config.isHeadIndex)
  val decision = routing.computeRouting(io.RoutingInfo, headActive, routerLevel, ingressDir)
  for ((physicalOutputPort, branch) <- legalOutputPorts.zipWithIndex)
    io.RS(branch) := decision.output_valid(config.dirOfPhys(physicalOutputPort)) && io.PRSReady
}

object PacketRouteSelectorMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  emitVerilog(
    new PacketRouteSelector(
      config = config,
      xCoordinate = 0,
      yCoordinate = 0,
      routerLevel = 1,
      ingressPort = 4
    ),
    Array("--target-dir", "generated_ultra", "PacketRouteSelector")
  )
}
