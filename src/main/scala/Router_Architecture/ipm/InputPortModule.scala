package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Combines the paper-aligned input datapath with project-specific packet
  * state.
  */
class InputPortModule(config: RouterModuleConfig, forkWidth: Int)
    extends Module {
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

  private val datapath = Module(
    new InputDatapathModule(config, forkWidth)
  )
  private val context = Module(new PacketContextModule(config))

  datapath.io.in <> io.in
  datapath.io.destMask := io.destMask
  io.forkOutputs <> datapath.io.forkOutputs

  io.inValid := datapath.io.inValid
  io.inBits := datapath.io.inBits
  io.isHead := datapath.io.isHead
  io.isTail := datapath.io.isTail

  context.io.launchClock := datapath.io.launchClock
  context.io.isHead := datapath.io.isHead
  context.io.isTail := datapath.io.isTail
  context.io.nextDir := io.nextDir
  context.io.nextLane := io.nextLane

  io.storedDir := context.io.storedDir
  io.storedLane := context.io.storedLane
}
