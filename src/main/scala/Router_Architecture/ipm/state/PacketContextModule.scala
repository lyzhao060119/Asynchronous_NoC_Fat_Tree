package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import tool.{AsyncClock, AsyncDelay, DelayElement}

/** Extra multi-flit packet context for this project.
  *
  * Remembers selected directions, reserved lanes, and destination mask so
  * body/tail flits can bypass route recomputation and lane reallocation.
  * State is saved on head launch and cleared on tail completion.
  */
class PacketContextModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val launchClock = Input(Clock())
    val launch = Input(Bool())
    val completeClock = Input(Clock())
    val complete = Input(Bool())
    val isHead = Input(Bool())
    val isTail = Input(Bool())

    val nextDir = Input(Vec(config.nDirs, Bool()))
    val nextLane = Input(Vec(config.nDirs, UInt(config.laneW.W)))
    val nextMask = Input(Vec(config.totalPorts, Bool()))

    val storedDir = Output(Vec(config.nDirs, Bool()))
    val storedLane = Output(Vec(config.nDirs, UInt(config.laneW.W)))
    val storedMask = Output(Vec(config.totalPorts, Bool()))
  })

  private val stateEvent = Module(
    new DelayElement(
      AsyncDelay.steps(1, AsyncDelay.ContextState),
      AsyncDelay.unitPs(AsyncDelay.ContextState)
    )
  )
  stateEvent.io.I := io.launch || io.complete
  private val stateClock = stateEvent.io.Z.asClock

  private val dirReg = AsyncClock(stateClock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(false.B)))
  }
  private val laneReg = AsyncClock(stateClock, reset) {
    RegInit(VecInit(Seq.fill(config.nDirs)(0.U(config.laneW.W))))
  }
  private val maskReg = AsyncClock(stateClock, reset) {
    RegInit(VecInit(Seq.fill(config.totalPorts)(false.B)))
  }

  io.storedDir := dirReg
  io.storedLane := laneReg
  io.storedMask := maskReg

  AsyncClock(stateClock, reset) {
    when(io.complete && io.isTail) {
      dirReg := VecInit(Seq.fill(config.nDirs)(false.B))
      laneReg := VecInit(Seq.fill(config.nDirs)(0.U(config.laneW.W)))
      maskReg := VecInit(Seq.fill(config.totalPorts)(false.B))
    }.elsewhen(io.launch && io.isHead && !io.isTail) {
      dirReg := io.nextDir
      maskReg := io.nextMask
      for (d <- 0 until config.nDirs) {
        when(io.nextDir(d)) {
          laneReg(d) := io.nextLane(d)
        }.otherwise {
          laneReg(d) := 0.U
        }
      }
    }
  }
}
