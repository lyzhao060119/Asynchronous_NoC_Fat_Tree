package Router_Architecture.ultra

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Ultra Fig. 5(a) input-side composition. */
class IPM(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int
) extends Module {
  private val legalOutputPorts = UltraTopology.legalOutputPorts(config, ingressPort)
  private val nBranches = legalOutputPorts.length
  val io = IO(new Bundle {
    val ReqIn = Input(Bool())
    val DataIn = Input(new Packet)
    val Done = Input(Vec(nBranches, Bool()))
    // Router-internal completion barrier for the current Tail only.
    val tailReleaseReady = Input(Bool())
    val AckIn = Output(Bool())
    val ReqX = Output(Bool())
    val DataX = Output(new Packet)
    val RS = Output(Vec(nBranches, Bool()))
  })
  val mousetrap = Module(new MousetrapV1(PacketLayout.FlitWidth))
  val prs = Module(new PacketRouteSelector(config, xCoordinate, yCoordinate, routerLevel, ingressPort))
  val ackGenerator = Module(new AckGenerator(nBranches))

  mousetrap.io.reset := reset.asBool
  mousetrap.io.ReqIn := io.ReqIn
  mousetrap.io.DataIn := io.DataIn.flit
  mousetrap.io.AckX := ackGenerator.io.AckX
  mousetrap.io.PRSReady := prs.io.PRSReady
  ackGenerator.io.ReqX := mousetrap.io.ReqX
  ackGenerator.io.Done := io.Done.asUInt
  ackGenerator.io.currentFlitIsTail := mousetrap.io.DataOut(PacketLayout.IsTailIndex)
  ackGenerator.io.tailReleaseReady := io.tailReleaseReady
  prs.io.RoutingInfo.flit := mousetrap.io.DataOut
  prs.io.ReqX := mousetrap.io.ReqX
  prs.io.AckX := ackGenerator.io.AckX
  for (i <- 0 until nBranches) {
    io.RS(i) := prs.io.RS(i)
  }
  io.AckIn := mousetrap.io.ReqX
  io.ReqX := mousetrap.io.ReqX
  io.DataX.flit := mousetrap.io.DataOut
}

object IPMMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  emitVerilog(
    new IPM(
      config = config,
      xCoordinate = 0,
      yCoordinate = 0,
      routerLevel = 1,
      ingressPort = 4
    ),
    Array("--target-dir", "generated_ultra", "IPMAdmissionStage")
  )
}
