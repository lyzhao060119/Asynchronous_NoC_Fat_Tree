package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{AsyncFork, RouterModuleConfig}
import chisel3._
import chisel3.util._
import tool.{AsyncClock, AsyncDelay}

/** Two-VC ingress buffer for one physical input port.
  *
  * Flits from the same packet are mapped back to the VC that accepted the head
  * by using the packet id bits. A new head is accepted only into a VC that has no
  * receive-active packet, no in-flight context, and no visible FIFO token.
  */
class InputVcBuffer(config: RouterModuleConfig) extends Module {
  private val idW = PacketLayout.IdHi - PacketLayout.IdLo + 1
  private val vcW = math.max(1, log2Ceil(config.vcCount))

  val io = IO(new Bundle {
    val in = new HS_Packet
    val vcActive = Input(Vec(config.vcCount, Bool()))
    val out = Vec(config.vcCount, Flipped(new HS_Packet))

    val inValid = Output(Vec(config.vcCount, Bool()))
    val inBits = Output(Vec(config.vcCount, new Packet))
    val isHead = Output(Vec(config.vcCount, Bool()))
    val isTail = Output(Vec(config.vcCount, Bool()))
    val receiveActive = Output(Vec(config.vcCount, Bool()))
  })

  private val demux = Module(
    new AsyncFork(config.vcCount, launchDelayRole = AsyncDelay.DemuxLaunch)
  )
  private val buffers = Seq.fill(config.vcCount)(Module(new InputBuffer(config)))

  demux.io.in <> io.in
  for (v <- 0 until config.vcCount) {
    buffers(v).io.in <> demux.io.out(v)
    io.out(v) <> buffers(v).io.out
    io.inValid(v) := buffers(v).io.inValid
    io.inBits(v) := buffers(v).io.inBits
    io.isHead(v) := buffers(v).io.isHead
    io.isTail(v) := buffers(v).io.isTail
  }

  private val rxActive = AsyncClock(demux.io.launch_clock, reset) {
    RegInit(VecInit(Seq.fill(config.vcCount)(false.B)))
  }
  private val rxId = AsyncClock(demux.io.launch_clock, reset) {
    RegInit(VecInit(Seq.fill(config.vcCount)(0.U(idW.W))))
  }

  private val incomingId =
    io.in.Data.flit(PacketLayout.IdHi, PacketLayout.IdLo)
  private val incomingHead = io.in.Data.flit(config.isHeadIndex)
  private val incomingTail = io.in.Data.flit(config.isTailIndex)

  private val idMatches = Wire(Vec(config.vcCount, Bool()))
  private val vcFree = Wire(Vec(config.vcCount, Bool()))
  for (v <- 0 until config.vcCount) {
    idMatches(v) := rxActive(v) && (rxId(v) === incomingId)
    vcFree(v) := !rxActive(v) && !io.vcActive(v) && !io.inValid(v)
    io.receiveActive(v) := rxActive(v)
  }

  private val hasMatch = idMatches.asUInt.orR
  private val hasFree = vcFree.asUInt.orR
  private val matchVc = PriorityEncoder(idMatches)
  private val freeVc = PriorityEncoder(vcFree)
  private val routeValid = Mux(incomingHead, hasFree, hasMatch)
  private val routeVc = Mux(incomingHead, freeVc, matchVc)

  for (v <- 0 until config.vcCount) {
    demux.io.destMask(v) := routeValid && (routeVc === v.U(vcW.W))
  }
  demux.io.canLaunch := routeValid

  AsyncClock(demux.io.launch_clock, reset) {
    when(routeValid) {
      when(incomingHead) {
        rxActive(routeVc) := !incomingTail
        rxId(routeVc) := incomingId
      }.elsewhen(incomingTail) {
        rxActive(routeVc) := false.B
      }
    }
  }
}
