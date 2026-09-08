package Router_Architecture.CMR

import chisel3._
import chisel3.util.HasBlackBoxResource
import tool.AsyncPrimitiveProfile

/** Exact-width CMR mutex, implemented as a state-holding TAC tree. */
class CMRMutexN(val width: Int)
    extends BlackBox(Map("WIDTH" -> width))
    with HasBlackBoxResource {
  override def desiredName: String = "CMRMutexN"
  private val Supported = Set(1, 2, 4, 5, 8, 10, 16, 20)
  require(Supported.contains(width), s"unsupported CMR mutex width $width")
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val req = Input(UInt(width.W))
    val grant = Output(UInt(width.W))
  })
  addResource("/ASYNC/CMR/CMRMutexN.v")
  addResource("/ASYNC/CMR/CMRFlattenedTAC.v")
  addResource("/ASYNC/MullerC2.v")
  addResource("/ASYNC/Mutex4.v")
  addResource(AsyncPrimitiveProfile.mutex2Resource)
}

/** First-level continuous lane selector for one input/direction pair. */
class ContinuousLaneSelector(val laneCount: Int) extends Module {
  require(Set(1, 2, 4, 8).contains(laneCount))
  val io = IO(new Bundle {
    val PathEnabled = Input(Bool())
    val OtherGrant = Input(Vec(laneCount, Bool()))
    val LaneSelect = Output(Vec(laneCount, Bool()))
  })
  private val mutex = Module(new CMRMutexN(laneCount))
  private val requests = Wire(Vec(laneCount, Bool()))
  for (lane <- 0 until laneCount) {
    requests(lane) := io.PathEnabled && !io.OtherGrant(lane)
  }
  mutex.io.reset := reset.asBool
  mutex.io.req := requests.asUInt
  io.LaneSelect := VecInit(mutex.io.grant.asBools)
}

/** C-element packet-lifetime selector. A lost OPM contest waits on the
  * selected lane until packet completion; it intentionally does not retry. */
class LaneSelecterCelement(val laneCount: Int)
    extends BlackBox(Map("LANES" -> laneCount)) with HasBlackBoxResource {
  require(Set(2, 4, 8).contains(laneCount))
  override def desiredName: String = "LaneSelecterCelement"
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val LaneIsEmpty = Input(UInt(laneCount.W))
    val PacketActive = Input(Bool())
    val LaneSelect = Output(UInt(laneCount.W))
  })
  addResource("/ASYNC/CMR/LaneSelecterCelement.v")
  addResource("/ASYNC/CMR/CMRMutexN.v")
  addResource("/ASYNC/CMR/CMRFlattenedTAC.v")
  addResource("/ASYNC/MullerC2.v")
  addResource("/ASYNC/Mutex4.v")
  addResource(AsyncPrimitiveProfile.mutex2Resource)
}

class LanePhaseAdapter(val laneCount: Int)
    extends BlackBox(Map("LANES" -> laneCount))
    with HasBlackBoxResource {
  override def desiredName: String = "LanePhaseAdapter"
  require(Set(1, 2, 4, 8).contains(laneCount))
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val Reqin = Input(Bool())
    val LaneSelect = Input(UInt(laneCount.W))
    val Commit = Input(UInt(laneCount.W))
    val Ackin = Input(UInt(laneCount.W))
    val Ackout = Output(Bool())
    val Reqout = Output(UInt(laneCount.W))
  })
  addResource("/ASYNC/CMR/LanePhaseAdapter.v")
  addResource("/ASYNC/CMR/PhaseResetDLatch.v")
}

/** Per-lane two-phase adapter built from the request and acknowledgement
  * Toggle Q states.  LaneSelect must be held through the physical OPM
  * acknowledgement; LaneSelecterCelement provides that packet-lifetime hold.
  */
class LanePhaseAdapterDFF(val laneCount: Int)
    extends BlackBox(Map("LANES" -> laneCount))
    with HasBlackBoxResource {
  override def desiredName: String = "LanePhaseAdapterDFF"
  require(Set(2, 4, 8).contains(laneCount))
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val LaneSelect = Input(UInt(laneCount.W))
    val IPMReqOut = Input(UInt(laneCount.W))
    val OPMAckOut = Input(UInt(laneCount.W))
    val IPMAckIn = Output(UInt(laneCount.W))
    val OPMReqIn = Output(UInt(laneCount.W))
  })
  addResource("/ASYNC/CMR/LanePhaseAdapterDFF.v")
  addResource("/ASYNC/CMR/Toggle.v")
}

/** Capture the first LaneSelect while PathEnabled and hold it until Tail. */
class WormholeLaneLock(val laneCount: Int)
    extends BlackBox(Map("LANES" -> laneCount))
    with HasBlackBoxResource {
  override def desiredName: String = "WormholeLaneLock"
  require(Set(1, 2, 4, 8).contains(laneCount))
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val PathEnabled = Input(Bool())
    val LaneSelect = Input(UInt(laneCount.W))
    val HeldSelect = Output(UInt(laneCount.W))
  })
  addResource("/ASYNC/CMR/LanePhaseAdapter.v")
  addResource("/ASYNC/CMR/PhaseResetDLatch.v")
}
