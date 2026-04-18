package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.AsyncFork
import chisel3._

/** Paper-aligned request-generator block for one input port.
  *
  * In this design the low-level branch request launch and completion-ack merge
  * are both implemented by the asynchronous fork primitive, so this module
  * becomes the place where packet replication requests are issued toward the
  * sparse internal edge set.
  */
class InputRequestGeneratorModule(forkWidth: Int) extends Module {
  require(forkWidth >= 1)

  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(forkWidth, Bool()))
    val forkOutputs = Vec(forkWidth, Flipped(new HS_Packet))

    val packetLaunch = Output(Bool())
    val packetLaunchClock = Output(Clock())
    val packetComplete = Output(Bool())
    val packetCompleteClock = Output(Clock())
  })

  private val fork = Module(new AsyncFork(forkWidth))

  fork.io.in <> io.in
  fork.io.destMask := io.destMask
  io.forkOutputs <> fork.io.out

  io.packetLaunch := fork.io.launch
  io.packetLaunchClock := fork.io.launch_clock
  io.packetComplete := fork.io.fire
  io.packetCompleteClock := fork.io.fire_clock
}
