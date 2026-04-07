package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncFifo, AsyncFork, RouterModuleConfig}
import chisel3._
import tool.AsyncClock

class RouterInputPortModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(config.totalPorts, Bool()))
    val forkOutputs = Vec(config.totalPorts, Flipped(new HS_Packet))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())

    val storedDir = Output(Vec(config.nDirs, Bool()))
    val storedLane = Output(Vec(config.nDirs, UInt(config.laneW.W)))
    val nextDir = Input(Vec(config.nDirs, Bool()))
    val nextLane = Input(Vec(config.nDirs, UInt(config.laneW.W)))
  })

  private val fifo = Module(new AsyncFifo(config.fifoDepth))
  private val fork = Module(new AsyncFork(config.totalPorts))

  fifo.io.enq <> io.in
  fork.io.in <> fifo.io.deq
  fork.io.destMask := io.destMask
  io.forkOutputs <> fork.io.out

  private val dirReg = AsyncClock(fork.io.launch_clock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(false.B)))
  }
  private val laneReg = AsyncClock(fork.io.launch_clock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(0.U(config.laneW.W))))
  }

  io.storedDir := dirReg
  io.storedLane := laneReg

  io.inValid := fifo.io.deq.HS.Req ^ fifo.io.deq.HS.Ack
  io.inBits := fifo.io.deq.Data
  io.isHead := io.inValid && io.inBits.flit(config.isHeadIndex)
  io.isTail := io.inValid && io.inBits.flit(config.isTailIndex)

  AsyncClock(fork.io.launch_clock, reset) {
    when(io.isHead) {
      dirReg := io.nextDir
      for (d <- 0 until config.nDirs) {
        when(io.nextDir(d)) {
          laneReg(d) := io.nextLane(d)
        }.otherwise {
          laneReg(d) := 0.U
        }
      }
    }

    when(io.isTail) {
      dirReg := VecInit(Seq.fill(config.nDirs)(false.B))
      laneReg := VecInit(Seq.fill(config.nDirs)(0.U(config.laneW.W)))
    }
  }
}
