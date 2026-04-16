package Router_Architecture.common

import DataStruct._
import chisel3._
import tool._

/** One asynchronous pipeline stage for a request/acknowledge packet channel. */
class AsyncStage extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet // sink side of the stage
    val out = Flipped(new HS_Packet) // source side of the stage
  })

  private val acg = Module(new ACG(Map(
    "InNum" -> 1,
    "OutNum" -> 1,
  )))

  // Handshake wires are handled by the ACG; only data is registered on fire.
  acg.In(0) <> io.in.HS
  acg.Out(0) <> io.out.HS

  AsyncClock(acg.fire_o, reset) {
    io.out.Data := RegNext(io.in.Data)
  }
}
