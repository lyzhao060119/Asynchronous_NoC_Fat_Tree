package Router_Architecture.CMR

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.common.RouterModuleConfig
import Router_Architecture.ultra.{UltraDLatchBank, UltraTopology, V2CloseEvent}
import chisel3._
import chisel3.util.{HasBlackBoxResource, Mux1H}
import tool.{AsyncPrimitiveProfile, DelayElement, DontTouchBuf}

/** Fig. 2 four-way continuous-time arbiter. */
class Mutex4 extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "Mutex4"
  val io = IO(new Bundle {
    val req0 = Input(Bool()); val req1 = Input(Bool())
    val req2 = Input(Bool()); val req3 = Input(Bool())
    val gnt0 = Output(Bool()); val gnt1 = Output(Bool())
    val gnt2 = Output(Bool()); val gnt3 = Output(Bool())
  })

  addResource("/ASYNC/Mutex4.v")
  addResource(AsyncPrimitiveProfile.mutex2Resource)
}

/** Continuous paper Fig. 2 OPM using the repository's native Packet. */
class OPM(config: RouterModuleConfig, egressPort: Int) extends Module {
  override def desiredName: String = "OPM"

  require(CMRParameters.SupportedLaneGeometries.contains(
    (config.childLanes, config.parentLanes)
  ))
  require(egressPort >= 0 && egressPort < config.totalPorts)
  private val SourceCount = UltraTopology.legalInputPorts(config, egressPort).length
  require(Set(4, 5, 8, 10, 16, 20).contains(SourceCount))

  val io = IO(new Bundle {
    val Reqin = Input(Vec(SourceCount, Bool()))
    val PktPathEnable = Input(Vec(SourceCount, Bool()))
    val Datain = Input(Vec(SourceCount, new Packet))
    val Ackin = Input(Bool())
    val Ackout = Output(Vec(SourceCount, Bool()))
    val Grant = Output(Vec(SourceCount, Bool()))
    val Reqout = Output(Bool())
    val Dataout = Output(new Packet)
    val TailPassed = Output(Vec(SourceCount, Bool()))
  })

  private val Arbiter = Module(new CMRMutexN(SourceCount))
  Arbiter.io.reset := reset.asBool
  Arbiter.io.req := io.PktPathEnable.asUInt
  val Grant = VecInit(Arbiter.io.grant.asBools)

  val TailPassed = Wire(Vec(SourceCount, Bool()))
  val MG = Wire(Vec(SourceCount, Bool()))
  for (input <- 0 until SourceCount) {
    MG(input) := Grant(input) && !TailPassed(input)
  }

  private val L1_L4 = Seq.fill(SourceCount)(Module(new UltraDLatchBank(1)))
  val ReqSelection = Wire(Vec(SourceCount, Bool()))
  for (input <- 0 until SourceCount) {
    L1_L4(input).io.reset := reset.asBool
    L1_L4(input).io.en := MG(input)
    L1_L4(input).io.d := io.Reqin(input).asUInt
    ReqSelection(input) := L1_L4(input).io.q(0)
  }

  val ReqMerged = ReqSelection.asUInt.xorR

  val DataSelected = Mux1H(MG, io.Datain.map(_.flit))
  private val L5 = Module(new UltraDLatchBank(1))
  private val DataReg = Module(new UltraDLatchBank(PacketLayout.FlitWidth))
  val Reqout = L5.io.q(0)
  val delayedAckin = Wire(Bool())
  if (CMRParameters.OpmAckinUseBuf) {
    val AckinDelay = Module(new DontTouchBuf)
    AckinDelay.io.I := io.Ackin
    delayedAckin := AckinDelay.io.Z
  } else if (CMRParameters.OpmAckinDelaySteps > 0) {
    val AckinDelay = Module(new DelayElement(
      CMRParameters.OpmAckinDelaySteps, DelayUnitPs = CMRParameters.OpmAckinDelayUnitPs
    ))
    AckinDelay.io.I := io.Ackin
    delayedAckin := AckinDelay.io.Z
  } else {
    delayedAckin := io.Ackin
  }
  val RegEnable = !(Reqout ^ delayedAckin)
  private val RegClose = Module(new V2CloseEvent)
  RegClose.io.latch_enable := RegEnable

  L5.io.reset := reset.asBool
  L5.io.en := RegEnable
  // Data mux settling before the V2 request latch is a physical bundled-data
  // obligation, constrained during DC/P&R rather than by an RTL delay line.
  L5.io.d := ReqMerged.asUInt
  DataReg.io.reset := reset.asBool
  DataReg.io.en := RegEnable
  DataReg.io.d := DataSelected

  private val Ackout = withClockAndReset(RegClose.io.close_clock.asClock, reset.asAsyncReset) {
    val FF0_FF3 = RegInit(VecInit(Seq.fill(SourceCount)(false.B)))
    FF0_FF3 := ReqSelection
    FF0_FF3
  }

  val tailFlag = DataReg.io.q(PacketLayout.IsTailIndex)
  for (input <- 0 until SourceCount) {
    val TailDetectorReset = (reset.asBool || !Grant(input)).asAsyncReset
    TailPassed(input) := withClockAndReset(RegClose.io.close_clock.asClock, TailDetectorReset) {
      val FF = RegInit(false.B)
      FF := tailFlag
      FF
    }
  }

  io.Ackout := Ackout
  io.Grant := Grant
  io.Reqout := Reqout
  io.Dataout.flit := DataReg.io.q
  io.TailPassed := TailPassed
}

object OPMMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1, parentLanes = 1, fifoDepth = 5, vcCount = 1,
    allowSameDirChild = false, allowSameDirParent = false
  )
  emitVerilog(new OPM(config, egressPort = 0), Array("--target-dir", "generated_cmr/opm"))
}
