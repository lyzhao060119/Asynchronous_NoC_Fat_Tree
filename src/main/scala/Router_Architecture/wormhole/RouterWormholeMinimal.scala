package Router_Architecture.wormhole

import DataStruct._
import Router_Architecture.algorithm.RoutingLogic
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._
import chisel3.util._
import tool.{ACG, AsyncClock, AsyncDelay, DelayElement}

/** Stage1 high-performance wormhole router.
  *
  * One physical lane per direction, no VC, depth-1 input/output slots, and
  * all-or-nothing multicast commit. InputSlot and OutputSlot are explicit
  * two-phase ACG boundaries; the old AsyncFork / AsyncMaskedArbiter path is not
  * used.
  */
class RouterWormholeMinimal(
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    inputCaptureDelayRole: String = AsyncDelay.Stage1InputCapture,
    commitReadyDelayRole: String = AsyncDelay.Stage1CommitReady,
    commitGlobalDelayRole: String = AsyncDelay.Stage1CommitGlobal,
    outputReqMarginDelayRole: String = AsyncDelay.Stage1OutputReqMargin
) extends Module {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = (routerLevel == 1),
    allowSameDirParent = false
  )
  private val nPorts = config.totalPorts
  private val idWidth = PacketLayout.IdHi - PacketLayout.IdLo + 1
  private val noneOwner = nPorts.U(config.holderW.W)
  private val routing = new RoutingLogic(xCoordinate, yCoordinate)

  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(1, 1)
    val outputs = Flipped(new RouterDirGroupedHSIO(1, 1))

    val probe = Output(new Bundle {
      val inputValid = Vec(nPorts, Bool())
      val outputValid = Vec(nPorts, Bool())
      val inputData = Vec(nPorts, new Packet)
      val outputData = Vec(nPorts, new Packet)
      val routeMask = Vec(nPorts, UInt(nPorts.W))
      val requestMask = Vec(nPorts, UInt(nPorts.W))
      val outputWinner = Vec(nPorts, UInt(nPorts.W))
      val grantedAll = Vec(nPorts, Bool())
      val canCommit = Vec(nPorts, Bool())
      val winner = Vec(nPorts, Bool())
      val commitConflict = Vec(nPorts, Bool())
      val commitRaw = Bool()
      val commit = Vec(nPorts, Bool())
      val inputCaptureFire = Vec(nPorts, Bool())
      val commitReady = Vec(nPorts, Bool())
      val globalCommitEvent = Bool()
      val outputReqPending = Vec(nPorts, Bool())
      val outputReqLaunchEvent = Vec(nPorts, Bool())
      val inputSlotReq = Vec(nPorts, Bool())
      val inputSlotAck = Vec(nPorts, Bool())
      val outputSlotReq = Vec(nPorts, Bool())
      val outputSlotAck = Vec(nPorts, Bool())
      val outputHolder = Vec(nPorts, UInt(config.holderW.W))
      val contextActive = Vec(nPorts, Bool())
      val contextMask = Vec(nPorts, UInt(nPorts.W))
    })
  })

  private def inPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    if (d < 4) io.inputs.child(d)(0) else io.inputs.parent(0)
  }

  private def outPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    if (d < 4) io.outputs.child(d)(0) else io.outputs.parent(0)
  }

  private def isHead(p: Packet): Bool = p.flit(config.isHeadIndex)
  private def isTail(p: Packet): Bool = p.flit(config.isTailIndex)
  private def packetId(p: Packet): UInt =
    p.flit(PacketLayout.IdHi, PacketLayout.IdLo)
  private def zeroPacket: Packet = 0.U.asTypeOf(new Packet)

  private def maskFromDirs(dirs: Vec[Bool], inIdx: Int): UInt = {
    VecInit((0 until nPorts).map { o =>
      dirs(config.dirOfPhys(o)) && config.canConnect(inIdx, o).B
    }).asUInt
  }

  private val inputData = Wire(Vec(nPorts, new Packet))
  private val outputData = Wire(Vec(nPorts, new Packet))
  private val contextMask = Wire(Vec(nPorts, UInt(nPorts.W)))
  private val contextActive = Wire(Vec(nPorts, Bool()))
  private val contextId = Wire(Vec(nPorts, UInt(idWidth.W)))
  private val outputHolder = Wire(Vec(nPorts, UInt(config.holderW.W)))

  private val inputSlotReq = Wire(Vec(nPorts, Bool()))
  private val inputSlotAck = Wire(Vec(nPorts, Bool()))
  private val outputSlotReq = Wire(Vec(nPorts, Bool()))
  private val outputSlotAck = Wire(Vec(nPorts, Bool()))
  private val outputReqPending = Wire(Vec(nPorts, Bool()))
  private val outputReqLaunchEvent = Wire(Vec(nPorts, Bool()))

  private val inputValid = Wire(Vec(nPorts, Bool()))
  private val outputValid = Wire(Vec(nPorts, Bool())) //no pending flits in ouput slot 
  private val routeMask = Wire(Vec(nPorts, UInt(nPorts.W)))
  private val requestMask = Wire(Vec(nPorts, UInt(nPorts.W)))
  private val outputWinnerProbe = Wire(Vec(nPorts, UInt(nPorts.W)))
  private val grantedAll = Wire(Vec(nPorts, Bool()))
  private val canCommit = Wire(Vec(nPorts, Bool()))
  private val winner = Wire(Vec(nPorts, Bool()))
  private val commitConflict = Wire(Vec(nPorts, Bool()))
  private val commitRaw = Wire(Bool())
  private val commitLevel = Wire(Vec(nPorts, Bool()))
  private val commit = Wire(Vec(nPorts, Bool()))
  private val commitReady = Wire(Vec(nPorts, Bool()))
  private val globalCommitEvent = Wire(Bool())
  private val inputCaptureFire = Wire(Vec(nPorts, Bool()))

  // Domain A: external input -> InputSlot.
  for (i <- 0 until nPorts) {
    val port = inPort(i)
    val cap = Module(new ACG(Map(
      "InNum" -> 1,
      "OutNum" -> 1,
      "DfireDelayRole" -> inputCaptureDelayRole
    )))
    cap.In(0) <> port.HS
    inputSlotReq(i) := cap.Out(0).Req
    cap.Out(0).Ack := inputSlotAck(i)
    inputValid(i) := inputSlotReq(i) ^ inputSlotAck(i)
    inputCaptureFire(i) := cap.fire_o.asBool
    val dataReg = AsyncClock(cap.fire_o, reset) {
      RegNext(port.Data, zeroPacket)
    }
    inputData(i) := dataReg
  }

  // OutputSlot hold/release boundary. The registered output slot is the
  // external two-phase source; there is no extra Domain C fire delay.
  for (o <- 0 until nPorts) {
    val port = outPort(o)
    port.HS.Req := outputSlotReq(o)
    outputSlotAck(o) := port.HS.Ack
    outputValid(o) := outputSlotReq(o) ^ outputSlotAck(o)
    port.Data := outputData(o)
  }

  // Route and request masks.
  for (i <- 0 until nPorts) {
    val ingressDir = config.dirOfPhys(i).U(3.W)
    val headDirs =
      routing
        .computeRouting(inputData(i), inputValid(i), routerLevel, ingressDir)
        .output_valid
    val headMask = maskFromDirs(headDirs, i)
    val contextMatches =
      contextActive(i) && (packetId(inputData(i)) === contextId(i))
    val headCanStart = isHead(inputData(i)) && !contextActive(i)
    val bodyCanContinue = !isHead(inputData(i)) && contextMatches

    routeMask(i) := headMask
    requestMask(i) := Mux(
      headCanStart,
      headMask,
      Mux(bodyCanContinue, contextMask(i), 0.U(nPorts.W))
    )
  }

  // Input-atomic mask arbitration. Stage1 allows multiple inputs to commit in
  // the same event only when their complete requested masks are disjoint.
  val slotWritable = Wire(Vec(nPorts, Bool()))
  for (o <- 0 until nPorts) {
    slotWritable(o) := !outputValid(o) && !outputReqPending(o)
  }

  val ownerOk = Seq.tabulate(nPorts, nPorts) { (i, o) =>
    Mux(
      isHead(inputData(i)),
      outputHolder(o) === noneOwner,
      outputHolder(o) === i.U(config.holderW.W)
    )
  }

  val requestableAll = Wire(Vec(nPorts, Bool()))
  val acceptedMasks = Wire(Vec(nPorts + 1, UInt(nPorts.W)))
  acceptedMasks(0) := 0.U
  for (i <- 0 until nPorts) {
    val requestedAny =
      (0 until nPorts).map(o => requestMask(i)(o)).foldLeft(false.B)(_ || _)
    requestableAll(i) := inputValid(i) && requestedAny && (0 until nPorts).map { o =>
      !requestMask(i)(o) || (slotWritable(o) && ownerOk(i)(o))
    }.foldLeft(true.B)(_ && _)
    val conflictFree = (requestMask(i) & acceptedMasks(i)) === 0.U
    winner(i) := requestableAll(i) && conflictFree
    grantedAll(i) := winner(i)
    canCommit(i) := winner(i)
    acceptedMasks(i + 1) := acceptedMasks(i) | Mux(winner(i), requestMask(i), 0.U(nPorts.W))
  }

  for (o <- 0 until nPorts) {
    outputWinnerProbe(o) := VecInit((0 until nPorts).map { i =>
      winner(i) && requestMask(i)(o)
    }).asUInt
  }

  // Domain B commit stage:
  //   fire chain:    inputValid -> DelayElement -> commitReady
  //   control chain: route/mask/free/holder/arbitration -> winner
  //   commitRaw is delayed once more before clocking state to preserve a
  //   bundled-data margin from commit/data/mask to globalCommitEvent. The
  //   commitLevel remains stable at the global commit clock edge and is the
  //   state-update enable. commit is only the pulse-shaped raw-event source;
  //   using it as sampled data would race globalCommitEvent.
  for (i <- 0 until nPorts) {
    val commitDelay = Module(
      new DelayElement(
        AsyncDelay.steps(1, commitReadyDelayRole),
        AsyncDelay.unitPs(commitReadyDelayRole)
      )
    )
    commitDelay.io.I := inputValid(i)
    commitReady(i) := commitDelay.io.Z
    commitLevel(i) := inputValid(i) && commitReady(i) && winner(i)
    commit(i) := commitLevel(i) && !globalCommitEvent
  }
  commitRaw := commit.asUInt.orR
  for (o <- 0 until nPorts) {
    val committedWriters =
      VecInit((0 until nPorts).map(i => commitLevel(i) && requestMask(i)(o)))
    commitConflict(o) := PopCount(committedWriters) > 1.U
  }
  val globalCommitDelay = Module(
    new DelayElement(
      AsyncDelay.steps(1, commitGlobalDelayRole),
      AsyncDelay.unitPs(commitGlobalDelayRole)
    )
  )
  globalCommitDelay.io.I := commitRaw
  globalCommitEvent := globalCommitDelay.io.Z

  val commitState = AsyncClock(globalCommitEvent.asClock, reset) {
    val ackRegs = RegInit(VecInit(Seq.fill(nPorts)(false.B)))
    val contextActiveRegs = RegInit(VecInit(Seq.fill(nPorts)(false.B)))
    val contextMaskRegs = RegInit(VecInit(Seq.fill(nPorts)(0.U(nPorts.W))))
    val contextIdRegs = RegInit(VecInit(Seq.fill(nPorts)(0.U(idWidth.W))))
    val outputReqRegs = RegInit(VecInit(Seq.fill(nPorts)(false.B)))
    val outputDataRegs = RegInit(VecInit(Seq.fill(nPorts)(zeroPacket)))
    val outputHolderRegs = RegInit(VecInit(Seq.fill(nPorts)(noneOwner)))

    for (i <- 0 until nPorts) {
      val stateCommit = commitLevel(i)
      val stateData = inputData(i)
      val stateMask = requestMask(i)
      when(stateCommit) {
        ackRegs(i) := !ackRegs(i)
        when(isHead(stateData) && !isTail(stateData)) {
          contextActiveRegs(i) := true.B
          contextMaskRegs(i) := stateMask
          contextIdRegs(i) := packetId(stateData)
        }.elsewhen(isTail(stateData)) {
          contextActiveRegs(i) := false.B
          contextMaskRegs(i) := 0.U
        }
      }
    }

    for (o <- 0 until nPorts) {
      val outputWrite =
        (0 until nPorts).map(i => commitLevel(i) && requestMask(i)(o))
          .foldLeft(false.B)(_ || _)
      val chosenData = Wire(new Packet)
      val chosenOwner = Wire(UInt(config.holderW.W))
      chosenData := zeroPacket
      chosenOwner := noneOwner
      for (i <- 0 until nPorts) {
        val writer = commitLevel(i) && requestMask(i)(o)
        val writerData = inputData(i)
        when(writer) {
          chosenData := writerData
          chosenOwner := i.U(config.holderW.W)
        }
      }
      when(outputWrite) {
        outputReqRegs(o) := !outputReqRegs(o)
        outputDataRegs(o) := chosenData
        when(isTail(chosenData)) {
          outputHolderRegs(o) := noneOwner
        }.otherwise {
          outputHolderRegs(o) := chosenOwner
        }
      }
    }

    (ackRegs, contextActiveRegs, contextMaskRegs, contextIdRegs,
      outputReqRegs, outputDataRegs, outputHolderRegs)
  }

  val outputLaunchState = Seq.tabulate(nPorts) { o =>
    val reqLaunchDelay = Module(
      new DelayElement(
        AsyncDelay.steps(1, outputReqMarginDelayRole),
        AsyncDelay.unitPs(outputReqMarginDelayRole)
      )
    )
    reqLaunchDelay.io.I := outputReqPending(o)
    outputReqLaunchEvent(o) := reqLaunchDelay.io.Z

    AsyncClock(outputReqLaunchEvent(o).asClock, reset) {
      val outputReqReg = RegInit(false.B)
      val outputPendingAckReg = RegInit(false.B)
      when(outputReqPending(o)) {
        outputReqReg := !outputReqReg
        outputPendingAckReg := !outputPendingAckReg
      }
      (outputReqReg, outputPendingAckReg)
    }
  }

  for (i <- 0 until nPorts) {
    inputSlotAck(i) := commitState._1(i)
    contextActive(i) := commitState._2(i)
    contextMask(i) := commitState._3(i)
    contextId(i) := commitState._4(i)
  }
  for (o <- 0 until nPorts) {
    outputReqPending(o) := commitState._5(o) ^ outputLaunchState(o)._2
    outputSlotReq(o) := outputLaunchState(o)._1
    outputData(o) := commitState._6(o)
    outputHolder(o) := commitState._7(o)
  }

  // Probes.
  io.probe.inputValid := inputValid
  io.probe.outputValid := outputValid
  io.probe.inputData := inputData
  io.probe.outputData := outputData
  io.probe.routeMask := routeMask
  io.probe.requestMask := requestMask
  io.probe.outputWinner := outputWinnerProbe
  io.probe.grantedAll := grantedAll
  io.probe.canCommit := canCommit
  io.probe.winner := winner
  io.probe.commitConflict := commitConflict
  io.probe.commitRaw := commitRaw
  io.probe.commit := commit
  io.probe.inputCaptureFire := inputCaptureFire
  io.probe.commitReady := commitReady
  io.probe.globalCommitEvent := globalCommitEvent
  io.probe.outputReqPending := outputReqPending
  io.probe.outputReqLaunchEvent := outputReqLaunchEvent
  io.probe.inputSlotReq := inputSlotReq
  io.probe.inputSlotAck := inputSlotAck
  io.probe.outputSlotReq := outputSlotReq
  io.probe.outputSlotAck := outputSlotAck
  io.probe.outputHolder := outputHolder
  io.probe.contextActive := contextActive
  io.probe.contextMask := contextMask
}
