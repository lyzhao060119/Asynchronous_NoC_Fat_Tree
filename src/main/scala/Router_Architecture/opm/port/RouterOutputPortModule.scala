package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Wraps one physical output lane with a request selector and packet path state. */
class RouterOutputPortModule(config: RouterModuleConfig, legalInputs: Seq[Int]) extends Module {
  val io = IO(new Bundle {
    val inputs = Vec(legalInputs.length, new HS_Packet)
    val out = Flipped(new HS_Packet)

    val anyPending = Output(Bool())
    val holder = Output(UInt(config.holderW.W))
  })

  private val requestSelector =
    Module(new RouterOutputRequestSelectorModule(config, legalInputs))
  private val pathState = Module(new RouterOutputPathStateModule(config))

  requestSelector.io.inputs <> io.inputs
  requestSelector.io.out <> io.out

  io.anyPending := requestSelector.io.anyPending
  pathState.io.fireClock := requestSelector.io.fireClock
  pathState.io.chosen := requestSelector.io.chosen
  pathState.io.chosenData := requestSelector.io.chosenData
  io.holder := pathState.io.holder
}
