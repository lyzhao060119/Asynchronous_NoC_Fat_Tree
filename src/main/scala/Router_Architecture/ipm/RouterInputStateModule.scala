package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import tool.AsyncClock

class RouterInputStateModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val launchClock = Input(Clock())
    val isHead = Input(Bool())
    val isTail = Input(Bool())

    val nextDir = Input(Vec(config.nDirs, Bool()))
    val nextLane = Input(Vec(config.nDirs, UInt(config.laneW.W)))

    val storedDir = Output(Vec(config.nDirs, Bool()))
    val storedLane = Output(Vec(config.nDirs, UInt(config.laneW.W)))
  })

  private val dirReg = AsyncClock(io.launchClock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(false.B)))
  }
  private val laneReg = AsyncClock(io.launchClock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(0.U(config.laneW.W))))
  }

  io.storedDir := dirReg
  io.storedLane := laneReg

  AsyncClock(io.launchClock, reset) {
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
