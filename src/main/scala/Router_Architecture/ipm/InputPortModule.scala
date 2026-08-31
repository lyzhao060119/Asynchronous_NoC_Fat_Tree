package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.Mux1H

/** Combines the paper-aligned input datapath with project-specific packet
  * state.
  */
class InputPortModule(config: RouterModuleConfig, forkWidth: Int)
    extends Module {
  val io = IO(new Bundle {
    val in = new HS_Packet
    val destMask = Input(Vec(forkWidth, Bool()))
    val canLaunch = Input(Bool())
    val forkOutputs = Vec(forkWidth, Flipped(new HS_Packet))

    val inValid = Output(Bool())
    val inBits = Output(new Packet)
    val isHead = Output(Bool())
    val isTail = Output(Bool())

    val storedDir = Output(Vec(config.nDirs, Bool()))
    val storedLane = Output(Vec(config.nDirs, UInt(config.laneW.W)))
    val storedMask = Output(Vec(config.totalPorts, Bool()))
    val nextDir = Input(Vec(config.nDirs, Bool()))
    val nextLane = Input(Vec(config.nDirs, UInt(config.laneW.W)))
    val nextMask = Input(Vec(config.totalPorts, Bool()))

    /** Head launch pulse for RR priority advancement in InputControlModule. */
    val headLaunch = Output(Bool())
  })

  private val datapath = Module(
    new InputDatapathModule(config, forkWidth)
  )
  private val contexts =
    Seq.fill(config.vcCount)(Module(new PacketContextModule(config)))

  datapath.io.in <> io.in
  datapath.io.destMask := io.destMask
  datapath.io.canLaunch := io.canLaunch
  io.forkOutputs <> datapath.io.forkOutputs

  private val vcContextActive = Wire(Vec(config.vcCount, Bool()))
  private val vcBodyReady = Wire(Vec(config.vcCount, Bool()))
  private val vcHeadReady = Wire(Vec(config.vcCount, Bool()))
  for (v <- 0 until config.vcCount) {
    vcContextActive(v) := contexts(v).io.storedMask.asUInt.orR
    vcBodyReady(v) :=
      datapath.io.vcInValid(v) && !datapath.io.vcIsHead(v)
    vcHeadReady(v) :=
      datapath.io.vcInValid(v) && datapath.io.vcIsHead(v)
    datapath.io.vcActive(v) := vcContextActive(v)
  }

  private val anyBodyReady = vcBodyReady.asUInt.orR
  private val anyContextActive = vcContextActive.asUInt.orR
  for (v <- 0 until config.vcCount) {
    val lowerBodyReady =
      if (v == 0) false.B else VecInit(vcBodyReady.take(v)).asUInt.orR
    val lowerHeadReady =
      if (v == 0) false.B else VecInit(vcHeadReady.take(v)).asUInt.orR
    val bodyGrant = vcBodyReady(v) && !lowerBodyReady
    val headGrant =
      !anyBodyReady && !anyContextActive && vcHeadReady(v) && !lowerHeadReady
    datapath.io.vcAllow(v) := bodyGrant || headGrant
  }

  io.inValid := datapath.io.inValid
  io.inBits := datapath.io.inBits
  io.isHead := datapath.io.isHead
  io.isTail := datapath.io.isTail

  for (v <- 0 until config.vcCount) {
    contexts(v).io.launchClock := datapath.io.launchClock
    contexts(v).io.launch := datapath.io.launch && (datapath.io.activeVc === v.U)
    contexts(v).io.completeClock := datapath.io.completeClock
    contexts(v).io.complete :=
      datapath.io.complete && (datapath.io.activeVc === v.U)
    contexts(v).io.isHead := datapath.io.isHead
    contexts(v).io.isTail := datapath.io.isTail
    contexts(v).io.nextDir := io.nextDir
    contexts(v).io.nextLane := io.nextLane
    contexts(v).io.nextMask := io.nextMask
  }

  private val activeVcOH =
    VecInit((0 until config.vcCount).map(v => datapath.io.activeVc === v.U))
  for (d <- 0 until config.nDirs) {
    io.storedDir(d) :=
      Mux1H(activeVcOH, contexts.map(_.io.storedDir(d)))
    io.storedLane(d) :=
      Mux1H(activeVcOH, contexts.map(_.io.storedLane(d)))
  }
  for (o <- 0 until config.totalPorts) {
    io.storedMask(o) :=
      Mux1H(activeVcOH, contexts.map(_.io.storedMask(o)))
  }

  io.headLaunch := datapath.io.launch && datapath.io.isHead
}
