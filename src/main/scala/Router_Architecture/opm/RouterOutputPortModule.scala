package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

class RouterOutputPortModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val inputs = Vec(config.totalPorts, new HS_Packet)
    val out = Flipped(new HS_Packet)

    val anyPending = Output(Bool())
    val holder = Output(UInt(config.holderW.W))
  })

  private val arbiter = Module(new RouterOutputArbiterModule(config))
  private val holder = Module(new RouterOutputHolderModule(config))

  arbiter.io.inputs <> io.inputs
  arbiter.io.out <> io.out

  io.anyPending := arbiter.io.anyPending
  holder.io.fireClock := arbiter.io.fireClock
  holder.io.chosen := arbiter.io.chosen
  holder.io.chosenData := arbiter.io.chosenData
  io.holder := holder.io.holder
}
