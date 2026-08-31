package Router_Architecture.common

import DataStruct._
import chisel3._
import chisel3.util._
import tool.{ACG, AsyncClock, AsyncDelay}

/** Asynchronous arbiter with an explicit per-input allow mask.
  *
  * Inputs whose allow bit is low remain pending and are not acknowledged. This
  * is used by the input VC selector to keep a blocked head from consuming its
  * FIFO slot while another VC drains a body/tail flit.
  */
class AsyncMaskedArbiter(
    val nIn: Int,
    dfireDelayRole: String = AsyncDelay.DefaultRole
) extends Module {
  require(nIn >= 1)
  private val idxW = math.max(1, log2Ceil(nIn))

  val io = IO(new Bundle {
    val in = Vec(nIn, new HS_Packet)
    val allow = Input(Vec(nIn, Bool()))
    val out = Flipped(new HS_Packet)

    val fire = Output(Bool())
    val fire_clock = Output(Clock())
    val chosen = Output(UInt(idxW.W))
    val chosenData = Output(new Packet)
    val anyPending = Output(Bool())
  })

  private val acg = Module(new ACG(Map(
    "InNum" -> 0,
    "OutNum" -> 1,
    "OutEnFF" -> 0,
    "MrGoEn" -> 0,
    "DfireDelayRole" -> dfireDelayRole
  )))
  private val outBuffer = Module(new AsyncOutputBuffer)

  private def zeroPacket: Packet = 0.U.asTypeOf(new Packet)

  private val ackReg = AsyncClock(acg.fire_o, reset) {
    RegInit(VecInit(Seq.fill(nIn)(false.B)))
  }

  private val fullVec = Wire(Vec(nIn, Bool()))
  private val allowedFull = Wire(Vec(nIn, Bool()))
  for (i <- 0 until nIn) {
    io.in(i).HS.Ack := ackReg(i)
    fullVec(i) := io.in(i).HS.Req ^ ackReg(i)
    allowedFull(i) := fullVec(i) && io.allow(i)
  }

  private val hasAllowed = allowedFull.asUInt.orR
  private val chosenIdx = PriorityEncoder(allowedFull)
  private val chosenData = Mux1H(
    (0 until nIn).map(i => (chosenIdx === i.U) -> io.in(i).Data)
  )

  acg.Start := hasAllowed
  io.out.HS.Req := acg.Out(0).Req
  acg.Out(0).Ack := io.out.HS.Ack

  outBuffer.io.fireClock := acg.fire_o
  outBuffer.io.inData := Mux(hasAllowed, chosenData, zeroPacket)
  io.out.Data := outBuffer.io.outData

  AsyncClock(acg.fire_o, reset) {
    when(hasAllowed) {
      ackReg(chosenIdx) := io.in(chosenIdx).HS.Req
    }
  }

  io.fire := acg.fire_o.asBool
  io.fire_clock := acg.fire_o
  io.chosen := chosenIdx
  io.chosenData := Mux(hasAllowed, chosenData, zeroPacket)
  io.anyPending := fullVec.asUInt.orR
}
