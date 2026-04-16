package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncFifo, AsyncFork, RouterModuleConfig}
import chisel3._

/**
 * Input datapath for one physical port.
 *
 * Incoming traffic is buffered in an asynchronous FIFO and then replicated
 * through a per-port sparse fork according to the destination mask.
 */
class RouterInputDatapathModule(config: RouterModuleConfig, forkWidth: Int) extends Module {
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
  })

  private val fifo = Module(new AsyncFifo(config.fifoDepth))
  private val fork = Module(new AsyncFork(forkWidth))

  fifo.io.enq <> io.in
  fork.io.in <> fifo.io.deq
  fork.io.destMask := io.destMask
  io.forkOutputs <> fork.io.out

  io.inValid := fifo.io.deq.HS.Req ^ fifo.io.deq.HS.Ack
  io.inBits := fifo.io.deq.Data
  io.isHead := io.inValid && io.inBits.flit(config.isHeadIndex)
  io.isTail := io.inValid && io.inBits.flit(config.isTailIndex)
  // The fork launch pulse is used to update per-packet route state.
  io.launchClock := fork.io.launch_clock
}
