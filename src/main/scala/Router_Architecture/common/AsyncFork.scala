package Router_Architecture.common

import DataStruct._
import chisel3._
import tool.{AsyncClock, DelayElement}

class AsyncFork(val outN: Int) extends Module {
  require(outN >= 1)

  val io = IO(new Bundle {
    val in         = new HS_Packet
    val destMask   = Input(Vec(outN, Bool()))
    val out        = Vec(outN, Flipped(new HS_Packet))
    val launch     = Output(Bool())
    val launch_clock = Output(Clock())
    val fire       = Output(Bool())
    val fire_clock = Output(Clock())
  })

  val launchCond   = WireDefault(false.B)
  val completeCond = WireDefault(false.B)
  val launchPulse  = Module(new DelayElement(1))
  val finishPulse  = Module(new DelayElement(1))

  launchPulse.io.I := launchCond
  finishPulse.io.I := completeCond

  val launchClock = launchPulse.io.Z.asClock
  val finishClock = finishPulse.io.Z.asClock

  val inAckReg = AsyncClock(finishClock, reset) {
    val reg = RegInit(false.B)
    reg := io.in.HS.Req
    reg
  }
  io.in.HS.Ack := inAckReg

  val launchPhase = AsyncClock(launchClock, reset) {
    val reg = RegInit(false.B)
    reg := !reg
    reg
  }

  val outReqReg = Seq.tabulate(outN) { j =>
    AsyncClock(launchClock, reset) {
      val reg = RegInit(false.B)
      when(io.destMask(j)) {
        reg := !reg
      }
      reg
    }
  }

  val outPending = Wire(Vec(outN, Bool()))
  for (j <- 0 until outN) {
    io.out(j).HS.Req := outReqReg(j)
    io.out(j).Data   := io.in.Data
    outPending(j)    := outReqReg(j) ^ io.out(j).HS.Ack
  }

  val hasDest    = io.destMask.asUInt.orR
  val inputFull  = io.in.HS.Req ^ inAckReg
  val forkBusy   = launchPhase ^ inAckReg
  val pendingAny = outPending.asUInt.orR

  launchCond   := inputFull && hasDest && !forkBusy
  completeCond := inputFull && forkBusy && !pendingAny

  io.launch      := launchPulse.io.Z
  io.launch_clock:= launchClock
  io.fire       := finishPulse.io.Z
  io.fire_clock := finishClock
}
