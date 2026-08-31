package Router_Architecture.ultra

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.common.RouterModuleConfig
import tool.{AsyncDelay, DelayElement}
import chisel3._
import chisel3.util.{HasBlackBoxResource, Mux1H}

/** Paper-level transparent latch backed by src/main/resources/ASYNC/DLatchBank.v. */
class UltraDLatchBank(width: Int)
    extends BlackBox(Map("WIDTH" -> width))
    with HasBlackBoxResource {
  override def desiredName: String = "DLatchBank"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val en = Input(Bool())
    val d = Input(UInt(width.W))
    val q = Output(UInt(width.W))
  })

  addResource("/ASYNC/DLatchBank.v")
}

/** Explicit post-enable close event for the V2 Ack/TP DFFs. */
class V2CloseEvent extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "V2CloseEvent"
  val io = IO(new Bundle {
    val latch_enable = Input(Bool())
    val close_clock = Output(Bool())
  })
  addResource("/ASYNC/V2CloseEvent.v")
}

/**
  * Ultra Fig. 5(b) output-side datapath with the Transition Fig. 4 multi-flit
  * tail extension.
  *
  * AtomicMulticastAdmission performs packet-set arbitration before requests
  * reach this block. Consequently PPE is one-hot-or-zero and is also the raw
  * Grant monitoring signal returned to the Request Generators.
  *
  * The paper's L1-L4 request latches, L5 request latch, and output data
  * register are level-sensitive DLatchBank instances. Only the Ack and TP
  * state points are edge-triggered DFFs, as drawn in Ultra Fig. 5(b).
  */
class OPM(config: RouterModuleConfig, egressPort: Int) extends Module {
  override def desiredName: String = "OutputPortModule"

  require(config.totalPorts == 5, "OutputPortModule currently targets 5 ports.")
  require(
    config.childLanes == 1 && config.parentLanes == 1,
    "OutputPortModule currently targets one lane per direction."
  )
  require(egressPort >= 0 && egressPort < config.totalPorts)
  private val legalInputPorts = UltraTopology.legalInputPorts(config, egressPort)
  require(legalInputPorts.length == 4, "The current OPM requires four legal source IPMs.")

  val io = IO(new Bundle {
    val Req = Input(Vec(4, Bool()))
    val PPE = Input(Vec(4, Bool()))
    val DataX = Input(Vec(4, new Packet))
    val AckOut = Input(Bool())
    val Ack = Output(Vec(4, Bool()))
    val Grant = Output(Vec(4, Bool()))
    val MG = Output(Vec(4, Bool()))
    val ReqOut = Output(Bool())
    val DataOut = Output(new Packet)
    val TailPassed = Output(Vec(4, Bool()))
  })

  // Atomic packet-set admission guarantees PPE one-hot-or-zero. Ultra
  // Fig. 5(b)'s Grant monitor is therefore the admitted PPE itself.
  val grant = Wire(Vec(4, Bool()))
  grant := io.PPE
  io.Grant := io.PPE

  val tp = Wire(Vec(4, Bool()))
  val mg = Wire(Vec(4, Bool()))
  for (source <- 0 until 4) {
    // Ultra Fig. 5(b) Grant Masking: each raw grant is transparent until its
    // TP DFF records completion of the selected packet.
    mg(source) := grant(source) && !tp(source)
  }
  io.MG := mg

  // Ultra Fig. 5(b) Request Selection: L1-L4 are transparent only for the
  // admitted source. Global reset uses the DLatchBank asynchronous clear.
  val requestLatches = Seq.fill(4)(Module(new UltraDLatchBank(1)))
  val selectedReq = Wire(Vec(4, Bool()))
  for (source <- 0 until 4) {
    requestLatches(source).io.reset := reset.asBool
    requestLatches(source).io.en := mg(source)
    requestLatches(source).io.d := io.Req(source).asUInt
    selectedReq(source) := requestLatches(source).io.q(0)
  }

  // The four mutually-exclusive two-phase requests are merged exactly as in
  // Ultra Fig. 5(b) and Transition Fig. 4.
  val mergedReq = selectedReq.asUInt.xorR

  // Part VII bundled-data relative-timing margin.  This is intentionally one
  // common control delay after XOR4, not four branch delays: it postpones L5
  // closure/ReqOut without changing L1->Ack, MG, TP, or the data path.  The
  // Global reset clears L5 directly and never traverses the request delay.
  val v2RequestMargin = Module(
    new DelayElement(
      AsyncDelay.steps(1, AsyncDelay.UltraOpmV2ReqMargin),
      AsyncDelay.unitPs(AsyncDelay.UltraOpmV2ReqMargin)
    )
  )
  v2RequestMargin.io.I := mergedReq

  // MG is the one-hot Xbar select in Fig. 5(b). Mux1H expresses one physical
  // one-hot multiplexer rather than a priority-style repeated assignment.
  val selectedData = Mux1H(mg, io.DataX.map(_.flit))

  // Modified Mousetrap V2: L5 and the data register are normally transparent.
  // A ReqOut/AckOut phase mismatch makes RegEnable low and protects the flit.
  val requestOutLatch = Module(new UltraDLatchBank(1))
  val dataOutLatch = Module(new UltraDLatchBank(PacketLayout.FlitWidth))
  val reqOutState = requestOutLatch.io.q(0)
  val regEnable = !(reqOutState ^ io.AckOut)
  val v2LatchEnable = regEnable
  val closeEvent = Module(new V2CloseEvent)
  closeEvent.io.latch_enable := v2LatchEnable

  requestOutLatch.io.reset := reset.asBool
  requestOutLatch.io.en := v2LatchEnable
  requestOutLatch.io.d := v2RequestMargin.io.Z.asUInt
  dataOutLatch.io.reset := reset.asBool
  dataOutLatch.io.en := v2LatchEnable
  dataOutLatch.io.d := selectedData

  // The explicit close event is physically after the actual E pin shared by
  // L5/data latch, so Ack/TP cannot launch feedback before V2 closes.
  val regDisableClock = closeEvent.io.close_clock.asClock
  val ackState = withClockAndReset(regDisableClock, reset.asAsyncReset) {
    val regs = RegInit(VecInit(Seq.fill(4)(false.B)))
    regs := selectedReq
    regs
  }

  // Ultra uses D=1 because every packet is one flit. For the documented
  // multi-flit extension, the winning TP DFF samples the Tail bit from the
  // V2 data latch's committed output, not from the pre-V2 Xbar input. At the
  // RegEnable falling edge that latch has just safely captured this flit. A
  // low Grant asynchronously clears TP after the Request Generator releases
  // PPE.
  val committedIsTail = dataOutLatch.io.q(PacketLayout.IsTailIndex)
  for (source <- 0 until 4) {
    val tpReset = (reset.asBool || !grant(source)).asAsyncReset
    tp(source) := withClockAndReset(regDisableClock, tpReset) {
      val reg = RegInit(false.B)
      reg := committedIsTail
      reg
    }
  }

  io.Ack := ackState
  io.ReqOut := reqOutState
  io.DataOut.flit := dataOutLatch.io.q
  io.TailPassed := tp

}

object OutputPortModuleMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  emitVerilog(
    new OPM(config, egressPort = 0),
    Array("--target-dir", "generated_ultra", "OutputPortModule")
  )
}
