package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.{AsyncArbiter, RouterModuleConfig}
import chisel3._
import chisel3.util.log2Ceil

/**
 * Paper-aligned output request selector / arbitration front end.
 *
 * Each physical output only sees the legal sparse input set that can reach it.
 */
class RouterOutputRequestSelectorModule(
  config: RouterModuleConfig,
  legalInputs: Seq[Int]
) extends Module {
  require(legalInputs.nonEmpty)

  private val inputIdxW = math.max(1, log2Ceil(config.totalPorts))
  private val localIdxW = math.max(1, log2Ceil(legalInputs.length))

  val io = IO(new Bundle {
    val inputs = Vec(legalInputs.length, new HS_Packet)
    val out = Flipped(new HS_Packet)

    val anyPending = Output(Bool())
    val chosen = Output(UInt(inputIdxW.W))
    val chosenData = Output(new Packet)
    val fireClock = Output(Clock())
  })

  private val arbiter = Module(new AsyncArbiter(legalInputs.length))

  arbiter.io.in <> io.inputs
  arbiter.io.out <> io.out

  private val chosenGlobal = Wire(UInt(inputIdxW.W))
  chosenGlobal := legalInputs.head.U(inputIdxW.W)
  for ((globalIdx, localIdx) <- legalInputs.zipWithIndex) {
    when(arbiter.io.chosen === localIdx.U(localIdxW.W)) {
      chosenGlobal := globalIdx.U(inputIdxW.W)
    }
  }

  io.anyPending := arbiter.io.anyPending
  io.chosen := chosenGlobal
  io.chosenData := arbiter.io.chosenData
  io.fireClock := arbiter.io.fire_clock
}
