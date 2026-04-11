package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.{AsyncArbiter, RouterModuleConfig}
import chisel3._
import chisel3.util.log2Ceil

class RouterOutputArbiterModule(config: RouterModuleConfig) extends Module {
  private val inputIdxW = math.max(1, log2Ceil(config.totalPorts))

  val io = IO(new Bundle {
    val inputs = Vec(config.totalPorts, new HS_Packet)
    val out = Flipped(new HS_Packet)

    val anyPending = Output(Bool())
    val chosen = Output(UInt(inputIdxW.W))
    val chosenData = Output(new Packet)
    val fireClock = Output(Clock())
  })

  private val arbiter = Module(new AsyncArbiter(config.totalPorts))

  arbiter.io.in <> io.inputs
  arbiter.io.out <> io.out

  io.anyPending := arbiter.io.anyPending
  io.chosen := arbiter.io.chosen
  io.chosenData := arbiter.io.chosenData
  io.fireClock := arbiter.io.fire_clock
}
