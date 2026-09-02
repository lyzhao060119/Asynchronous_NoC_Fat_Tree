package Router_Architecture.CMR

import DataStruct.{Packet, PacketLayout}
import chisel3._

/** Paper constants around the repository's native Packet. */
object CMRParameters {
  val CellCount = 5
  val BranchCount = 4
  val RouterPortCount = 5
  val AddressWidth = PacketLayout.Y1Hi - PacketLayout.X0Lo + 1

  require(AddressWidth == 24)

  // Locked Fat vs Thin hop recipe: 1xDEL050 and no rcu_matched_buf chain.
  // RouteComputation's combinational Mat bits must settle before Req_rc opens
  // RouteSel and its self-acknowledging Toggle feedback loop.  Steps 0
  // omits the DelayElement (diagnostic hop netlists only).
  val RcuMatchedDelaySteps: Int =
    sys.env.get("CMR_RCU_MATCHED_DELAY_STEPS").map(_.toInt).getOrElse(1)
  val RcuMatchedDelayUnitPs: Int =
    sys.env.get("CMR_RCU_MATCHED_DELAY_UNIT_PS").map(_.toInt).getOrElse(50)
  require(RcuMatchedDelaySteps >= 0)
  require(Set(50, 75, 100, 150, 250).contains(RcuMatchedDelayUnitPs))

  // V2 close-event clocks Ackout/TailPassed on RegEnable falling. A
  // combinational downstream Ack can keep XNOR(Reqout, Ackin) high, so L5
  // never closes and the Ack DFF never samples. Locked default is 1xDEL050
  // for Fat and Thin.  CMR_OPM_ACKIN_USE_BUF=1 replaces that cell with a
  // single dont_touch buffer (BUFFD0 / LUT1 / #10ps sim) and is not locked.
  val OpmAckinUseBuf: Boolean =
    sys.env.get("CMR_OPM_ACKIN_USE_BUF").contains("1")
  val OpmAckinDelaySteps: Int =
    sys.env.get("CMR_OPM_ACKIN_DELAY_STEPS").map(_.toInt).getOrElse(1)
  val OpmAckinDelayUnitPs: Int =
    sys.env.get("CMR_OPM_ACKIN_DELAY_UNIT_PS").map(_.toInt).getOrElse(50)
  require(OpmAckinDelaySteps >= 0)
  require(Set(50, 75, 100, 150, 250).contains(OpmAckinDelayUnitPs))

  def Address_field(Datain: Packet): UInt =
    Datain.flit(PacketLayout.Y1Hi, PacketLayout.X0Lo)

  val SupportedLaneGeometries: Set[(Int, Int)] =
    Set((1, 1), (1, 2), (2, 2), (2, 4), (4, 8))

  /** LanePhaseAdapter count for one CMRRouter: one adapter per ingress
    * port and legal output direction whose destination width is greater
    * than one.  Matches scripts/asic_dc/cmr/run_remote_cmr_flow.py.
    */
  def expectedLaneAdapters(childLanes: Int, parentLanes: Int): Int = {
    val parentDirAdapters = if (parentLanes > 1) 4 * childLanes else 0
    val childDirAdapters =
      if (childLanes > 1) 4 * childLanes * 3 + parentLanes * 4 else 0
    parentDirAdapters + childDirAdapters
  }

  def portCount(childLanes: Int, parentLanes: Int): Int = 4 * childLanes + parentLanes

  def childOpmFanIn(childLanes: Int, parentLanes: Int): Int =
    3 * childLanes + parentLanes

  def parentOpmFanIn(childLanes: Int): Int = 4 * childLanes

  def maxOpmFanIn(childLanes: Int, parentLanes: Int): Int =
    math.max(childOpmFanIn(childLanes, parentLanes), parentOpmFanIn(childLanes))

  def mutexWidths(childLanes: Int, parentLanes: Int): Set[Int] = {
    val lanes = Set(childLanes, parentLanes).filter(_ > 1)
    Set(childOpmFanIn(childLanes, parentLanes), parentOpmFanIn(childLanes)) ++ lanes
  }

  def legalOutputDirections(
      config: Router_Architecture.common.RouterModuleConfig,
      ingressPort: Int
  ): IndexedSeq[Int] = {
    val ingressDirection = config.dirOfPhys(ingressPort)
    (0 until config.nDirs).filter(_ != ingressDirection).toIndexedSeq
  }
}
