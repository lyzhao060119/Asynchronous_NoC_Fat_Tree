package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncFifo, AsyncFork, RouterModuleConfig}
import chisel3._

class RouterInputDatapathModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(config.totalPorts, Bool()))
    val forkOutputs = Vec(config.totalPorts, Flipped(new HS_Packet))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())
    val launchClock = Output(Clock())
  })

  private val fifo = Module(new AsyncFifo(config.fifoDepth))
  private val fork = Module(new AsyncFork(config.totalPorts))

  fifo.io.enq <> io.in
  fork.io.in <> fifo.io.deq
  fork.io.destMask := io.destMask
  io.forkOutputs <> fork.io.out

  io.inValid := fifo.io.deq.HS.Req ^ fifo.io.deq.HS.Ack
  io.inBits := fifo.io.deq.Data
  io.isHead := io.inValid && io.inBits.flit(config.isHeadIndex)
  io.isTail := io.inValid && io.inBits.flit(config.isTailIndex)
  io.launchClock := fork.io.launch_clock
}
