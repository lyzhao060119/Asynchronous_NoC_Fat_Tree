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
  require(Set(4, 5, 7, 8, 10, 16, 20, 28, 64).contains(SourceCount))

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
  val Ackout = Wire(Vec(SourceCount, Bool()))
  val ReqMerged = ReqSelection.asUInt.xorR
  val AckMerged = Ackout.asUInt.xorR
  val DataSelected = Mux1H(MG, io.Datain.map(_.flit))

  val Reqout = Wire(Bool())
  val RegEnable = Wire(Bool())
  // Close the internal fire from the raw request phase.  The externally
  // delayed Reqout is only the bundled-data output; feeding it back here would
  // extend the click window by the output protection delay.
  RegEnable := (AckMerged ^ ReqMerged) & ~(io.Ackin ^ Reqout)

  Ackout := withClockAndReset((~RegEnable).asClock, reset.asAsyncReset) {
    val FF0_FF3 = RegInit(VecInit(Seq.fill(SourceCount)(false.B)))
    FF0_FF3 := ReqSelection
    FF0_FF3
  }
  val DataReg = Wire(UInt(PacketLayout.FlitWidth.W))
  DataReg := withClockAndReset(RegEnable.asClock, reset.asAsyncReset){
    val ff = RegInit(0.U(PacketLayout.FlitWidth.W))
    ff := DataSelected
    ff
  }
  Reqout := withClockAndReset(RegEnable.asClock, reset.asAsyncReset){
    val ff = RegInit(0.B)
    ff := ~ff
    ff
  }
  // Intentional output timing protection. Keep this after the Reqout state and
  // outside RegEnable feedback; paired STA measures the mapped path to io.Reqout.
  val OPMDelay = Module(new DelayElement(
    CMRParameters.OpmReqoutDelaySteps,
    DelayUnitPs = CMRParameters.OpmReqoutDelayUnitPs))
  OPMDelay.io.I := Reqout
  // Output-only fine delay; internal RegEnable feedback remains on raw Reqout.
  private val OPMReqoutBuffers = Seq.tabulate(CMRParameters.OpmReqoutBufferStages) { stage =>
    val buffer = Module(new DontTouchBuf)
    buffer.suggestName(s"OPMReqoutBuffer_$stage")
    buffer
  }
  private val ProtectedReqout = OPMReqoutBuffers.foldLeft(OPMDelay.io.Z) { (previous, buffer) =>
    buffer.io.I := previous
    buffer.io.Z
  }

  val tailFlag = DataReg(PacketLayout.IsTailIndex)
  // Timing-only protection for Grant-release -> TailPassed capture recovery.
  // Ackout retains the raw close event; only TailPassed sees this delayed copy.
  for (input <- 0 until SourceCount) {
    // Keep one physical protection branch per state.  A shared high-fanout
    // delay has a different mapped delay/load and cannot use the same hold
    // window established for a single TailPassed CP sink.
    val TailCaptureDelay = Module(new DelayElement(
      CMRParameters.OpmTailCaptureDelaySteps,
      DelayUnitPs = CMRParameters.OpmTailCaptureDelayUnitPs))
    TailCaptureDelay.suggestName(s"TailCaptureDelay_$input")
    TailCaptureDelay.io.I := ~RegEnable
    val TailDetectorReset = (reset.asBool || !Grant(input)).asAsyncReset
    TailPassed(input) := withClockAndReset(TailCaptureDelay.io.Z.asClock, TailDetectorReset) {
      val FF = RegInit(false.B)
      FF := tailFlag
      FF
    }
  }

  io.Ackout := Ackout
  io.Grant := Grant
  io.Dataout.flit := DataReg
  io.TailPassed := TailPassed
  io.Reqout := ProtectedReqout
}

object OPMMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1, parentLanes = 1, fifoDepth = 5, vcCount = 1,
    allowSameDirChild = false, allowSameDirParent = false
  )
  emitVerilog(new OPM(config, egressPort = 0), Array("--target-dir", "generated_cmr/opm"))
}
