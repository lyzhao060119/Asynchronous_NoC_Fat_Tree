package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncMaskedArbiter, RouterModuleConfig}
import chisel3._
import chisel3.util.log2Ceil
import tool.{AsyncClock, AsyncDelay}

/** Input datapath shell for one physical port.
  *
  * The datapath is intentionally split into a input buffer and a dedicated
  * request-generator block.
  */
class InputDatapathModule(config: RouterModuleConfig, forkWidth: Int)
    extends Module {
  require(forkWidth >= 1)
  private val vcW = math.max(1, log2Ceil(config.vcCount))

  val io = IO(new Bundle {
    val in = new HS_Packet
    val vcAllow = Input(Vec(config.vcCount, Bool()))
    val vcActive = Input(Vec(config.vcCount, Bool()))
    val destMask = Input(Vec(forkWidth, Bool()))
    val canLaunch = Input(Bool())
    val forkOutputs = Vec(forkWidth, Flipped(new HS_Packet))

    val vcInValid = Output(Vec(config.vcCount, Bool()))
    val vcInBits = Output(Vec(config.vcCount, new Packet))
    val vcIsHead = Output(Vec(config.vcCount, Bool()))
    val vcIsTail = Output(Vec(config.vcCount, Bool()))
    val vcReceiveActive = Output(Vec(config.vcCount, Bool()))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())
    val activeVc = Output(UInt(vcW.W))
    val launch = Output(Bool())
    val launchClock = Output(Clock())
    val complete = Output(Bool())
    val completeClock = Output(Clock())
  })

  private val buffer = Module(new InputVcBuffer(config))
  private val selector =
    Module(new AsyncMaskedArbiter(config.vcCount, AsyncDelay.VcArbiterDfire))
  private val requestGen = Module(
    new InputRequestGeneratorModule(forkWidth)
  )

  buffer.io.in <> io.in
  buffer.io.vcActive := io.vcActive
  for (v <- 0 until config.vcCount) {
    selector.io.in(v) <> buffer.io.out(v)
    selector.io.allow(v) := io.vcAllow(v)
    io.vcInValid(v) := buffer.io.inValid(v)
    io.vcInBits(v) := buffer.io.inBits(v)
    io.vcIsHead(v) := buffer.io.isHead(v)
    io.vcIsTail(v) := buffer.io.isTail(v)
    io.vcReceiveActive(v) := buffer.io.receiveActive(v)
  }

  requestGen.io.in <> selector.io.out
  requestGen.io.destMask := io.destMask
  requestGen.io.canLaunch := io.canLaunch
  io.forkOutputs <> requestGen.io.forkOutputs

  private val activeVcReg = AsyncClock(selector.io.fire_clock, reset) {
    val reg = RegInit(0.U(vcW.W))
    reg := selector.io.chosen
    reg
  }

  io.inBits := requestGen.io.in.Data
  io.inValid := requestGen.io.in.HS.Req ^ requestGen.io.in.HS.Ack
  io.isHead := io.inBits.flit(config.isHeadIndex)
  io.isTail := io.inBits.flit(config.isTailIndex)
  io.activeVc := activeVcReg
  io.launch := requestGen.io.packetLaunch
  io.launchClock := requestGen.io.packetLaunchClock
  io.complete := requestGen.io.packetComplete
  io.completeClock := requestGen.io.packetCompleteClock
}
