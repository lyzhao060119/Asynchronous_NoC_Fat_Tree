package Router_Architecture.ultra

import chisel3._
import chisel3.util.HasBlackBoxResource

/** Parent-biased 2+2+1 asynchronous anchor selector.
  *
  * It is intentionally a primitive-only boundary: Atomic admission does not
  * consume its grants until the follow-up arbiter integration change.
  */
class Mutex5Anchor extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val req = Input(UInt(5.W))
    val grant = Output(UInt(5.W))
  })
  addResource("/ASYNC/Mutex5Anchor.v")
  addResource("/ASYNC/Mutex3Grant.v")
  addResource("/ASYNC/TAC2.v")
  addResource("/ASYNC/Mutex2.v")
  addResource("/ASYNC/MullerC2.v")
}

private class Mutex5AnchorHarness extends Module {
  val io = IO(new Bundle {
    val req = Input(UInt(5.W))
    val grant = Output(UInt(5.W))
  })
  private val anchor = Module(new Mutex5Anchor)
  anchor.io.reset := reset.asBool
  anchor.io.req := io.req
  io.grant := anchor.io.grant
}

object Mutex5AnchorMain extends App {
  emitVerilog(
    new Mutex5AnchorHarness,
    Array("--target-dir", "generated_ultra", "Mutex5AnchorHarness")
  )
}
