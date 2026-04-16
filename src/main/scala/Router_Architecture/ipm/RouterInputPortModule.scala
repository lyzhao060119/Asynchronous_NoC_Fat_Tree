package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

class RouterInputPortModule(config: RouterModuleConfig, forkWidth: Int) extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(forkWidth, Bool()))
    val forkOutputs = Vec(forkWidth, Flipped(new HS_Packet))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())

    val storedDir = Output(Vec(config.nDirs, Bool()))
    val storedLane = Output(Vec(config.nDirs, UInt(config.laneW.W)))
    val nextDir = Input(Vec(config.nDirs, Bool()))
    val nextLane = Input(Vec(config.nDirs, UInt(config.laneW.W)))
  })

  private val datapath = Module(new RouterInputDatapathModule(config, forkWidth))
  private val state = Module(new RouterInputStateModule(config))

  datapath.io.in <> io.in
  datapath.io.destMask := io.destMask
  io.forkOutputs <> datapath.io.forkOutputs

  io.inValid := datapath.io.inValid
  io.inBits := datapath.io.inBits
  io.isHead := datapath.io.isHead
  io.isTail := datapath.io.isTail

  state.io.launchClock := datapath.io.launchClock
  state.io.isHead := datapath.io.isHead
  state.io.isTail := datapath.io.isTail
  state.io.nextDir := io.nextDir
  state.io.nextLane := io.nextLane

  io.storedDir := state.io.storedDir
  io.storedLane := state.io.storedLane
}
