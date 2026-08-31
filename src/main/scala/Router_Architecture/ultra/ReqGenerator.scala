package Router_Architecture.ultra

import chisel3._

/** One multi-flit Request Generator for one IPM-to-OPM edge. */
class ReqGenerator extends Module {
  val io = IO(new Bundle {
    val RS = Input(Bool())
    val ReqX = Input(Bool()); val Ack = Input(Bool())
    val Grant = Input(Bool()); val MG = Input(Bool())
    val Req = Output(Bool()); val Done = Output(Bool()); val PPE = Output(Bool())
  })
  val asymC = Module(new ReqGenAsymC3)
  asymC.io.reset := reset.asBool
  asymC.io.Grant := io.Grant
  asymC.io.Done := io.Done
  asymC.io.MG := io.MG
  val phaseReg = withClockAndReset(io.RS.asClock, reset.asAsyncReset) {
    val reg = RegInit(false.B)
    reg := io.ReqX ^ !io.Ack
    reg
  }
  // Ultra Fig. 5(a): RS is the RouteSelected signal delivered to this branch.
  // In this router AtomicMulticastAdmission is its sole producer: a losing
  // Head sees RS=0, while a winning Head receives its original route bit.
  // PPE then retains the selected Body/Tail path after RS returns low.
  val branchActive = io.RS || io.PPE
  val selectedRequest = Mux(branchActive, io.ReqX ^ phaseReg, io.Ack)

  io.Req := Mux(branchActive, selectedRequest, io.Ack)
  io.Done := io.Req ^ io.Ack
  io.PPE := asymC.io.PPE
}
