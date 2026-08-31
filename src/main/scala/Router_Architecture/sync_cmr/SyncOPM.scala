package Router_Architecture.sync_cmr

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.common.RouterModuleConfig
import Router_Architecture.ultra.UltraTopology
import chisel3._
import chisel3.util.{Mux1H, PriorityEncoder, UIntToOH}

/**
  * First-level clocked lane pick for one input/direction pair.  Holds the
  * chosen lane until TailPassed; drops it if another source takes the OPM.
  */
class SyncLaneSelector(val laneCount: Int) extends Module {
  require(Set(1, 2, 4, 8).contains(laneCount))
  override def desiredName: String = "SyncLaneSelector"

  val io = IO(new Bundle {
    val PathEnabled = Input(Bool())
    val OtherGrant = Input(Vec(laneCount, Bool()))
    val TailPassed = Input(Vec(laneCount, Bool()))
    val LaneSelect = Output(Vec(laneCount, Bool()))
  })

  private val selected = RegInit(0.U(laneCount.W))
  private val holding = selected.orR
  private val candidate = VecInit.tabulate(laneCount) { lane =>
    io.PathEnabled && !io.OtherGrant(lane) && !holding
  }.asUInt

  val nextSel = WireDefault(selected)
  when (!io.PathEnabled) {
    nextSel := 0.U
  }.elsewhen (holding) {
    when ((selected & io.TailPassed.asUInt).orR) {
      nextSel := 0.U
    }.elsewhen ((selected & io.OtherGrant.asUInt).orR) {
      nextSel := 0.U
    }
  }.elsewhen (candidate.orR) {
    nextSel := UIntToOH(PriorityEncoder(candidate), laneCount)
  }
  selected := nextSel
  io.LaneSelect := VecInit(selected.asBools)
}

/**
  * Clocked Fig. 2 OPM.  A reset-initialized rotating priority pick replaces
  * Mutex; the chosen index is captured in Grant and held until Tail.
  * The picker runs only while idle so Body/Tail cannot change winner.
  */
class SyncOPM(config: RouterModuleConfig, egressPort: Int) extends Module {
  override def desiredName: String = "SyncOPM"

  require(CMRParameters.SupportedLaneGeometries.contains(
    (config.childLanes, config.parentLanes)
  ))
  require(egressPort >= 0 && egressPort < config.totalPorts)
  private val SourceCount = UltraTopology.legalInputPorts(config, egressPort).length
  require(Set(4, 5, 8, 10, 16, 20).contains(SourceCount))

  val io = IO(new Bundle {
    val validIn = Input(Vec(SourceCount, Bool()))
    val PktPathEnable = Input(Vec(SourceCount, Bool()))
    val Datain = Input(Vec(SourceCount, new Packet))
    val readyOut = Input(Bool())
    val readyIn = Output(Vec(SourceCount, Bool()))
    val Grant = Output(Vec(SourceCount, Bool()))
    val validOut = Output(Bool())
    val Dataout = Output(new Packet)
    val TailPassed = Output(Vec(SourceCount, Bool()))
  })

  private val grant = RegInit(0.U(SourceCount.W))
  private val lastOH = RegInit(1.U(SourceCount.W))
  private val idle = !grant.orR
  private val reqs = io.PktPathEnable.asUInt & io.validIn.asUInt
  when (idle && reqs.orR) {
    val above = reqs & ~(lastOH | (lastOH - 1.U))
    val pick = Mux(above.orR, above, reqs)
    val nextGrant = UIntToOH(PriorityEncoder(pick), SourceCount)
    grant := nextGrant
    lastOH := nextGrant
  }

  private val grantedValid = (grant & io.validIn.asUInt).orR
  private val fire = grantedValid && io.readyOut
  private val tailFlag = Mux(grant.orR, Mux1H(grant, io.Datain.map(_.flit(PacketLayout.IsTailIndex))), false.B)
  when (fire && tailFlag) {
    grant := 0.U
  }

  val TailPassed = Wire(Vec(SourceCount, Bool()))
  for (src <- 0 until SourceCount) {
    TailPassed(src) := grant(src) && fire && tailFlag
    io.readyIn(src) := grant(src) && io.readyOut
  }

  dontTouch(grant)
  io.Grant := VecInit(grant.asBools)
  io.validOut := grantedValid
  io.Dataout.flit := Mux(grant.orR, Mux1H(grant, io.Datain.map(_.flit)), 0.U)
  io.TailPassed := TailPassed
}

object SyncOPMMain extends App {
  private val config = SyncCmrConfig(1, 1)
  emitVerilog(
    new SyncOPM(config, egressPort = 0),
    Array("--target-dir", "generated_sync_cmr/opm")
  )
}
