package Router_Architecture.ultra

import chisel3._

/** Ack generator for one IPM. */
class AckGenerator(nBranches: Int) extends Module {
  require(nBranches >= 1)
  val io = IO(new Bundle {
    val ReqX = Input(Bool())
    val Done = Input(UInt(nBranches.W))
    /** V1 holds this bit stable until AckX returns for the current flit. */
    val currentFlitIsTail = Input(Bool())
    /** Atomic V2 has released the current packet's complete reservation. */
    val tailReleaseReady = Input(Bool())
    val AckX = Output(Bool())
  })

  // Ultra Fig. 5(a): the reduction-NOR of all branch Done levels is an event
  // clock, not a level-sensitive enable. Its initial high level does not
  // sample ReqX. Branch activity first lowers complete; only the final
  // Done 1->0 transition raises it and clocks the Ack-following DFF.
  private val allDone = io.Done === 0.U
  // Only the final flit waits for the packet-set release transaction.  Head
  // and Body retain the Ultra Fig. 5(a) completion event unchanged.
  private val complete = allDone && (!io.currentFlitIsTail || io.tailReleaseReady)
  private val ackReg = withClockAndReset(complete.asClock, reset.asAsyncReset) {
    val reg = RegInit(false.B)
    reg := io.ReqX
    reg
  }
  io.AckX := ackReg
}
