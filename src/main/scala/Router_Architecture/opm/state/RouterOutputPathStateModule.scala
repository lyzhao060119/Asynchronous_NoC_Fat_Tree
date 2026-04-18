package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.log2Ceil
import tool.AsyncClock

/**
 * Project-specific multi-flit path state at one physical output.
 *
 * This is the multi-flit counterpart to the paper's path-hold behavior: once a
 * head flit claims an output, the owner stays active until the tail leaves.
 */
class RouterOutputPathStateModule(config: RouterModuleConfig) extends Module {
  private val inputIdxW = math.max(1, log2Ceil(config.totalPorts))
  private val noneLiteral = config.noneValue.U(config.holderW.W)

  val io = IO(new Bundle {
    val fireClock = Input(Clock())
    val chosen = Input(UInt(inputIdxW.W))
    val chosenData = Input(new Packet)
    val holder = Output(UInt(config.holderW.W))
  })

  private val holderReg = AsyncClock(io.fireClock, reset) {
    RegInit(noneLiteral)
  }
  io.holder := holderReg

  AsyncClock(io.fireClock, reset) {
    when(io.chosenData.flit(config.isTailIndex)) {
      holderReg := noneLiteral
    }.elsewhen(io.chosenData.flit(config.isHeadIndex)) {
      holderReg := io.chosen.pad(config.holderW)
    }
  }
}
