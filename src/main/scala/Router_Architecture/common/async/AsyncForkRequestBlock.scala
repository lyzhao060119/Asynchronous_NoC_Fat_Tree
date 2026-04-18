package Router_Architecture.common

import chisel3._
import tool.{AsyncClock, DelayElement}

/**
 * Launch-side request block for a sparse asynchronous fork.
 *
 * It decides when a new packet can start, toggles the selected branch requests,
 * and exposes the branch-pending status used by the completion join logic.
 */
class AsyncForkRequestBlock(val outN: Int) extends Module {
  require(outN >= 1)

  val io = IO(new Bundle {
    val inReq = Input(Bool())
    val inAck = Input(Bool())
    val destMask = Input(Vec(outN, Bool()))
    val outAck = Input(Vec(outN, Bool()))

    val outReq = Output(Vec(outN, Bool()))
    val pendingAny = Output(Bool())
    val forkBusy = Output(Bool())

    val launch = Output(Bool())
    val launch_clock = Output(Clock())
  })

  private val launchPulse = Module(new DelayElement(1))
  private val launchCond = WireDefault(false.B)

  launchPulse.io.I := launchCond

  private val launchClock = launchPulse.io.Z.asClock

  private val launchPhase = AsyncClock(launchClock, reset) {
    val reg = RegInit(false.B)
    reg := !reg
    reg
  }

  private val outReqReg = Seq.tabulate(outN) { j =>
    AsyncClock(launchClock, reset) {
      val reg = RegInit(false.B)
      when(io.destMask(j)) {
        reg := !reg
      }
      reg
    }
  }

  private val outPending = Wire(Vec(outN, Bool()))
  for (j <- 0 until outN) {
    io.outReq(j) := outReqReg(j)
    outPending(j) := outReqReg(j) ^ io.outAck(j)
  }

  private val inputFull = io.inReq ^ io.inAck
  private val hasDest = io.destMask.asUInt.orR
  private val forkBusy = launchPhase ^ io.inAck

  launchCond := inputFull && hasDest && !forkBusy

  io.pendingAny := outPending.asUInt.orR
  io.forkBusy := forkBusy
  io.launch := launchPulse.io.Z
  io.launch_clock := launchClock
}
