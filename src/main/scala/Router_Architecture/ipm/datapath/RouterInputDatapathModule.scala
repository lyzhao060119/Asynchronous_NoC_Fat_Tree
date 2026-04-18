package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Input datapath shell for one physical port.
  *
  * The datapath is intentionally split into a paper-aligned input buffer and a
  * dedicated request-generator block. Project-specific packet context is kept
  * in a separate module and is not mixed into this shell.
  */
class RouterInputDatapathModule(config: RouterModuleConfig, forkWidth: Int)
    extends Module {
  require(forkWidth >= 1)

  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(forkWidth, Bool()))
    val forkOutputs = Vec(forkWidth, Flipped(new HS_Packet))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())
    val launchClock = Output(Clock())
    val completeClock = Output(Clock())
  })

  private val buffer = Module(new InputBuffer(config))
  private val requestGen = Module(
    new RouterInputRequestGeneratorModule(forkWidth)
  )

  buffer.io.in <> io.in
  requestGen.io.in <> buffer.io.out
  requestGen.io.destMask := io.destMask
  io.forkOutputs <> requestGen.io.forkOutputs

  io.inValid := buffer.io.inValid
  io.inBits := buffer.io.inBits
  io.isHead := buffer.io.isHead
  io.isTail := buffer.io.isTail
  io.launchClock := requestGen.io.packetLaunchClock
  io.completeClock := requestGen.io.packetCompleteClock
}
