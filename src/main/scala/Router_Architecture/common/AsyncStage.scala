package Router_Architecture.common

import DataStruct._
import chisel3._
import tool._

class AsyncStage extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet // sink
    val out = Flipped(new HS_Packet) // source
  })

  private val acg = Module(new ACG(Map(
    "InNum" -> 1,
    "OutNum" -> 1,
  )))

  // HS connect
  acg.In(0) <> io.in.HS
  acg.Out(0) <> io.out.HS

  AsyncClock(acg.fire_o, reset) {
    io.out.Data := RegNext(io.in.Data)
  }
}
