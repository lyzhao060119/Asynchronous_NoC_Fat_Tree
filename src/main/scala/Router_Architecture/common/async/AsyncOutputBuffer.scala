package Router_Architecture.common

import DataStruct._
import chisel3._
import tool.AsyncClock

/**
 * Dedicated output data buffer used after asynchronous request selection.
 */
class AsyncOutputBuffer extends Module {
  val io = IO(new Bundle {
    val fireClock = Input(Clock())
    val inData = Input(new Packet)
    val outData = Output(new Packet)
  })

  private def zeroPacket: Packet = 0.U.asTypeOf(new Packet)

  private val outReg = AsyncClock(io.fireClock, reset) {
    RegNext(io.inData, zeroPacket)
  }

  io.outData := outReg
}
