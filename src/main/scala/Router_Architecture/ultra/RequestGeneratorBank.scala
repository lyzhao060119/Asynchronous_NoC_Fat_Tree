package Router_Architecture.ultra

import chisel3._

/**
  * Four Ultra Fig. 5(a) Request Generators belonging to one input port.
  *
  * AtomicMulticastAdmission supplies the sole RS input only after the complete
  * multicast output set has been reserved. OPM Ack/Grant/MG return on the same
  * statically ordered no-U-turn branches.
  */
class RequestGeneratorBank(nBranches: Int = 4) extends Module {
  require(nBranches >= 1)

  val io = IO(new Bundle {
    val RS = Input(Vec(nBranches, Bool()))
    val ReqX = Input(Bool())
    val Ack = Input(Vec(nBranches, Bool()))
    val Grant = Input(Vec(nBranches, Bool()))
    val MG = Input(Vec(nBranches, Bool()))
    val Req = Output(Vec(nBranches, Bool()))
    val PPE = Output(Vec(nBranches, Bool()))
    val Done = Output(Vec(nBranches, Bool()))
  })

  private val generators = Seq.fill(nBranches)(Module(new ReqGenerator))
  for (branch <- 0 until nBranches) {
    val generator = generators(branch)
    generator.io.RS := io.RS(branch)
    generator.io.ReqX := io.ReqX
    generator.io.Ack := io.Ack(branch)
    generator.io.Grant := io.Grant(branch)
    generator.io.MG := io.MG(branch)

    io.Req(branch) := generator.io.Req
    io.PPE(branch) := generator.io.PPE
    io.Done(branch) := generator.io.Done
  }
}

object RequestGeneratorBankMain extends App {
  emitVerilog(
    new RequestGeneratorBank(4),
    Array("--target-dir", "generated_ultra", "RequestGeneratorBank")
  )
}
