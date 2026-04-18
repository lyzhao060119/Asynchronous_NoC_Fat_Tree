package Router_Architecture.common

import chisel3._
import tool.{AsyncClock, DelayElement}

/**
 * Completion-side acknowledge join for a sparse asynchronous fork.
 *
 * Once all launched branches finish, it toggles the input acknowledge and emits
 * a packet-complete pulse.
 */
class AsyncForkAckJoinBlock extends Module {
  val io = IO(new Bundle {
    val inReq = Input(Bool())
    val forkBusy = Input(Bool())
    val pendingAny = Input(Bool())

    val inAck = Output(Bool())
    val fire = Output(Bool())
    val fire_clock = Output(Clock())
  })

  private val completePulse = Module(new DelayElement(1))
  private val completeCond = WireDefault(false.B)

  completePulse.io.I := completeCond

  private val finishClock = completePulse.io.Z.asClock

  private val inAckReg = AsyncClock(finishClock, reset) {
    val reg = RegInit(false.B)
    reg := io.inReq
    reg
  }

  private val inputFull = io.inReq ^ inAckReg
  completeCond := inputFull && io.forkBusy && !io.pendingAny

  io.inAck := inAckReg
  io.fire := completePulse.io.Z
  io.fire_clock := finishClock
}
