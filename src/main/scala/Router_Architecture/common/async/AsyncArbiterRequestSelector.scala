package Router_Architecture.common

import DataStruct._
import chisel3._
import chisel3.util._
import tool.{ACG, AsyncClock, Mutex2}

/**
 * Request-selection front end of the asynchronous arbiter.
 *
 * This block performs mutex arbitration, drives the output request handshake,
 * and updates per-input acknowledge state. Output data buffering is kept in a
 * dedicated module so the architecture matches the paper's selector/buffer
 * split more closely.
 */
class AsyncArbiterRequestSelector(val nIn: Int) extends Module {
  require(nIn >= 1)
  private val idxW = math.max(1, log2Ceil(nIn))

  val io = IO(new Bundle {
    val in = Vec(nIn, new HS_Packet)
    val outAck = Input(Bool())

    val outReq = Output(Bool())

    val fire = Output(Bool())
    val fire_clock = Output(Clock())

    val chosen = Output(UInt(idxW.W))
    val chosenData = Output(new Packet)
    val anyPending = Output(Bool())
  })

  private val acg = Module(new ACG(Map(
    "InNum" -> 0,
    "OutNum" -> 1,
    "OutEnFF" -> 0,
    "MrGoEn" -> 0
  )))

  private case class Candidate(valid: Bool, ready: Bool, idx: UInt, data: Packet)

  private def zeroPacket: Packet = 0.U.asTypeOf(new Packet)

  private def emptyCandidate: Candidate =
    Candidate(false.B, true.B, 0.U(idxW.W), zeroPacket)

  private def mergeCandidates(left: Candidate, right: Candidate): Candidate = {
    val mutex = Module(new Mutex2)
    val bothValid = left.valid && right.valid
    val onlyLeft = left.valid && !right.valid
    val onlyRight = !left.valid && right.valid
    val mutexResolved = mutex.io.gnt0 ^ mutex.io.gnt1

    val outValid = Wire(Bool())
    val outReady = Wire(Bool())
    val outIdx = Wire(UInt(idxW.W))
    val outData = Wire(new Packet)

    mutex.io.req0 := left.valid
    mutex.io.req1 := right.valid

    outValid := left.valid || right.valid
    outReady := true.B
    outIdx := 0.U
    outData := zeroPacket

    when(onlyLeft) {
      outReady := left.ready
      outIdx := left.idx
      outData := left.data
    }.elsewhen(onlyRight) {
      outReady := right.ready
      outIdx := right.idx
      outData := right.data
    }.elsewhen(bothValid) {
      outReady := mutexResolved && ((mutex.io.gnt0 && left.ready) || (mutex.io.gnt1 && right.ready))
      when(mutex.io.gnt0) {
        outIdx := left.idx
        outData := left.data
      }.elsewhen(mutex.io.gnt1) {
        outIdx := right.idx
        outData := right.data
      }.otherwise {
        outIdx := left.idx
        outData := left.data
      }
    }

    Candidate(outValid, outReady, outIdx, outData)
  }

  private def reduceCandidates(nodes: Seq[Candidate]): Candidate = {
    if (nodes.length == 1) {
      nodes.head
    } else {
      val padded = if (nodes.length % 2 == 0) nodes else nodes :+ emptyCandidate
      val nextLevel = padded.grouped(2).map {
        case Seq(left, right) => mergeCandidates(left, right)
      }.toSeq
      reduceCandidates(nextLevel)
    }
  }

  private val ackReg = AsyncClock(acg.fire_o, reset) {
    RegInit(VecInit(Seq.fill(nIn)(false.B)))
  }

  for (i <- 0 until nIn) {
    io.in(i).HS.Ack := ackReg(i)
  }

  private val fullVec = Wire(Vec(nIn, Bool()))
  for (i <- 0 until nIn) {
    fullVec(i) := io.in(i).HS.Req ^ ackReg(i)
  }

  private val leaves = Seq.tabulate(nIn) { i =>
    Candidate(fullVec(i), true.B, i.U(idxW.W), io.in(i).Data)
  }
  private val winner = reduceCandidates(leaves)
  private val hasAny = fullVec.asUInt.orR
  private val canFire = winner.valid && winner.ready

  acg.Start := canFire

  io.outReq := acg.Out(0).Req
  acg.Out(0).Ack := io.outAck

  io.chosen := winner.idx
  io.chosenData := winner.data
  io.anyPending := hasAny

  AsyncClock(acg.fire_o, reset) {
    when(canFire) {
      ackReg(winner.idx) := io.in(winner.idx).HS.Req
    }
  }

  io.fire := acg.fire_o.asBool
  io.fire_clock := acg.fire_o
}
