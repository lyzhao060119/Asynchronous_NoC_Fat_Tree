package Router_Architecture.common

import DataStruct._
import chisel3._

/**
 * Asynchronous arbiter for multiple packet channels.
 *
 * This shell preserves the existing interface while internally splitting the
 * selector and output buffer into separate modules.
 */
class AsyncArbiter(val nIn: Int) extends Module {
  require(nIn >= 1)
  val idxW = math.max(1, chisel3.util.log2Ceil(nIn))
  private val selector = Module(new AsyncArbiterRequestSelector(nIn))
  private val outBuffer = Module(new AsyncOutputBuffer)

  val io = IO(new Bundle {
    val in = Vec(nIn, new HS_Packet) // candidate inputs, usually from forks
    val out = Flipped(new HS_Packet) // selected output link

    val fire = Output(Bool())
    val fire_clock = Output(Clock())

    val chosen = Output(UInt(idxW.W))
    val chosenData = Output(new Packet)
    val anyPending = Output(Bool())
  })

  for (i <- 0 until nIn) {
    selector.io.in(i) <> io.in(i)
  }

  selector.io.outAck := io.out.HS.Ack
  io.out.HS.Req := selector.io.outReq

  outBuffer.io.fireClock := selector.io.fire_clock
  outBuffer.io.inData := selector.io.chosenData
  io.out.Data := outBuffer.io.outData

  io.chosen := selector.io.chosen
  io.chosenData := selector.io.chosenData
  io.anyPending := selector.io.anyPending
  io.fire := selector.io.fire
  io.fire_clock := selector.io.fire_clock
}
