package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncFifo, RouterModuleConfig}
import chisel3._

/** Paper-aligned input buffer stage.
  *
  * This module only stores and exposes the next flit at one physical input
  * port. It deliberately excludes route computation and request generation so
  * those responsibilities stay in dedicated control blocks.
  */
class InputBuffer(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet
    val out = Flipped(new HS_Packet)

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())
  })

  private val fifo = Module(new AsyncFifo(config.fifoDepth))

  fifo.io.enq <> io.in
  io.out <> fifo.io.deq

  io.inValid := fifo.io.deq.HS.Req ^ fifo.io.deq.HS.Ack
  io.inBits := fifo.io.deq.Data
  io.isHead := io.inValid && io.inBits.flit(config.isHeadIndex)
  io.isTail := io.inValid && io.inBits.flit(config.isTailIndex)
}
