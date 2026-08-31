package Router_Architecture.common

import DataStruct._
import chisel3._
import tool.{ACG, AsyncClock, AsyncDelay, DelayElement}

/** One asynchronous pipeline stage for a request/acknowledge packet channel. */
class AsyncStage(
    dfireDelayRole: String = AsyncDelay.DefaultRole
) extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet // sink side of the stage
    val out = Flipped(new HS_Packet) // source side of the stage
  })

  private val acg = Module(new ACG(Map(
    "InNum" -> 1,
    "OutNum" -> 1,
    "DfireDelayRole" -> dfireDelayRole
  )))

  // Handshake wires are handled by the ACG; only data is registered on fire.
  acg.In(0) <> io.in.HS

  acg.Out(0).Ack := io.out.HS.Ack

  // SDF: last-stage Out.Req Q leads Data Q by ~36 ps while D[26] is already
  // known. Delay Req so the sink does not sample X on Tail/data.
  private val outReqDelay = Module(new DelayElement(
    AsyncDelay.steps(1, AsyncDelay.FifoOutReq),
    AsyncDelay.unitPs(AsyncDelay.FifoOutReq)
  ))
  outReqDelay.io.I := acg.Out(0).Req
  io.out.HS.Req := outReqDelay.io.Z

  AsyncClock(acg.fire_o, reset) {
    io.out.Data := RegNext(io.in.Data)
  }
}
