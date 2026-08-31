package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.{PriorityEncoder, log2Ceil}
import tool.{AsyncClock, AsyncDelay, DelayElement}

/** Input-side control shell.
  *
  * Handshake Domain III (RouteLaunch): route/lane/eligibility from the
  * registered VC-select flit. No Scheme C sampling; no canLaunch export (A+B
  * reverted — Fork uses hasDest = destMask.orR).
  */
class InputControlModule(
    config: RouterModuleConfig,
    computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  private val nInputs = config.totalPorts
  private val inputIdxW = math.max(1, log2Ceil(nInputs))

  val io = IO(new Bundle {
    val inBits = Input(Vec(nInputs, new Packet))
    val inValid = Input(Vec(nInputs, Bool()))
    val isHead = Input(Vec(nInputs, Bool()))
    val storedDir = Input(Vec(nInputs, Vec(config.nDirs, Bool())))
    val storedLane =
      Input(Vec(nInputs, Vec(config.nDirs, UInt(config.laneW.W))))
    val storedMask =
      Input(Vec(nInputs, Vec(nInputs, Bool())))

    val opmHolder = Input(Vec(nInputs, UInt(config.holderW.W)))
    val opmOutEmpty = Input(Vec(nInputs, Bool()))

    val headLaunch = Input(Vec(nInputs, Bool()))

    val nextDir = Output(Vec(nInputs, Vec(config.nDirs, Bool())))
    val nextLane =
      Output(Vec(nInputs, Vec(config.nDirs, UInt(config.laneW.W))))
    val destMask =
      Output(Vec(nInputs, Vec(nInputs, Bool())))
    val canLaunch = Output(Vec(nInputs, Bool()))
  })

  private val routeSelector =
    Module(new PacketRouteSelector(config, computeHeadRouting))
  private val laneReservation = Module(new LaneReservation(config))
  private val requestMask = Module(new MulticastRequestMaskModule(config))
  private val eligibility = Module(new InputEligibilityModule(config))

  private val anyHeadLaunch = io.headLaunch.asUInt.orR
  private val priPulse = Module(
    new DelayElement(
      AsyncDelay.steps(1, AsyncDelay.PriorityPulse),
      AsyncDelay.unitPs(AsyncDelay.PriorityPulse)
    )
  )
  priPulse.io.I := anyHeadLaunch
  private val priClock = priPulse.io.Z.asClock
  private val priorityBase = AsyncClock(priClock, reset) {
    val reg = RegInit(0.U(inputIdxW.W))
    when(anyHeadLaunch) {
      val granted = PriorityEncoder(io.headLaunch.asUInt)
      val next = granted +& 1.U
      reg := Mux(next >= nInputs.U, 0.U, next)(inputIdxW - 1, 0)
    }
    reg
  }

  routeSelector.io.inBits := io.inBits
  routeSelector.io.inValid := io.inValid
  routeSelector.io.isHead := io.isHead
  routeSelector.io.storedDir := io.storedDir

  laneReservation.io.inValid := io.inValid
  laneReservation.io.isHead := io.isHead
  laneReservation.io.currentDestVec := routeSelector.io.currentDestVec
  laneReservation.io.holder := io.opmHolder
  laneReservation.io.priorityBase := priorityBase

  requestMask.io.inValid := io.inValid
  requestMask.io.isHead := io.isHead
  requestMask.io.currentDestVec := routeSelector.io.currentDestVec
  requestMask.io.headSelLane := laneReservation.io.headSelLane
  requestMask.io.storedMask := io.storedMask
  requestMask.io.headAllocOk := laneReservation.io.headAllocOk

  eligibility.io.inValid := io.inValid
  eligibility.io.isHead := io.isHead
  eligibility.io.requestMask := requestMask.io.destMask
  eligibility.io.headWantedMask := requestMask.io.destMask
  eligibility.io.storedMask := io.storedMask
  eligibility.io.holder := io.opmHolder
  eligibility.io.outEmpty := io.opmOutEmpty

  io.nextDir := routeSelector.io.currentDestVec
  io.nextLane := laneReservation.io.headSelLane
  io.destMask := eligibility.io.destMask
  io.canLaunch := eligibility.io.canLaunch
}
