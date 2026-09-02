package Router_Architecture.sync_cmr

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.common.RouterModuleConfig
import Router_Architecture.ultra.UltraTopology
import chisel3._
import chisel3.util.{Mux1H, PriorityEncoder, UIntToOH}

  /**
    * First-level clocked lane pick for one input/direction pair.  LaneSelect
    * is combinational nextSel so isolated Head is one clock; selected holds
    * the choice until TailPassed.  OtherGrant is the registered OPM grant
    * (not liveGrant) to avoid a combinational loop.
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
  private val tailPassedQ = RegNext(io.TailPassed.asUInt, 0.U(laneCount.W))
  private val candidate = VecInit.tabulate(laneCount) { lane =>
    io.PathEnabled && !io.OtherGrant(lane) && !holding
  }.asUInt

  val nextSel = WireDefault(UInt(laneCount.W), selected)
  when (!io.PathEnabled) {
    nextSel := 0.U
  }.elsewhen (holding) {
    when ((selected & tailPassedQ).orR) {
      nextSel := 0.U
    }.elsewhen ((selected & io.OtherGrant.asUInt).orR) {
      nextSel := 0.U
    }
  }.elsewhen (candidate.orR) {
    nextSel := UIntToOH(PriorityEncoder(candidate), laneCount)
  }
  selected := nextSel
  io.LaneSelect := VecInit(nextSel.asBools)
}

  /**
    * Clocked Fig. 2 OPM.  A reset-initialized rotating priority pick replaces
    * Mutex.  While idle, liveGrant is combinational so isolated Head is one
    * clock; the grant register holds the winner until Tail so Body/Tail cannot
    * change winner.  io.Grant is the register (for OtherGrant), not liveGrant,
    * to avoid a combinational loop through LaneSelect.
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
  private val nextGrant = WireDefault(0.U(SourceCount.W))
  when (idle && reqs.orR) {
    val above = reqs & ~(lastOH | (lastOH - 1.U))
    val pick = Mux(above.orR, above, reqs)
    nextGrant := UIntToOH(PriorityEncoder(pick), SourceCount)
  }
  private val liveGrant = Mux(idle && reqs.orR, nextGrant, grant)
  when (idle && reqs.orR) {
    grant := nextGrant
    lastOH := nextGrant
  }

  private val grantedValid = (liveGrant & io.validIn.asUInt).orR
  private val fire = grantedValid && io.readyOut
  private val tailFlag = Mux(
    liveGrant.orR,
    Mux1H(liveGrant, io.Datain.map(_.flit(PacketLayout.IsTailIndex))),
    false.B
  )
  when (fire && tailFlag) {
    grant := 0.U
  }

  val TailPassed = Wire(Vec(SourceCount, Bool()))
  for (src <- 0 until SourceCount) {
    TailPassed(src) := liveGrant(src) && fire && tailFlag
    io.readyIn(src) := liveGrant(src) && io.readyOut
  }

  dontTouch(grant)
  io.Grant := VecInit(grant.asBools)
  io.validOut := grantedValid
  io.Dataout.flit := Mux(liveGrant.orR, Mux1H(liveGrant, io.Datain.map(_.flit)), 0.U)
  io.TailPassed := TailPassed
}

object SyncOPMMain extends App {
  private val config = SyncCmrConfig(1, 1)
  emitVerilog(
    new SyncOPM(config, egressPort = 0),
    Array("--target-dir", "generated_sync_cmr/opm")
  )
}
