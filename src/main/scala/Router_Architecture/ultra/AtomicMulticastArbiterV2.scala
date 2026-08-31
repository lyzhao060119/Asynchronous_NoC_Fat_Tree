package Router_Architecture.ultra

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.HasBlackBoxResource
import tool.{ACG, AsyncClock, AsyncDelay, AsyncPrimitiveProfile, DelayElement}

/** Structural Head capture cell used by AtomicMulticastArbiterV2. */
private class UltraHeadCaptureCell(delaySteps: Int, delayPs: Int)
    extends BlackBox(Map("DelayValue" -> delaySteps, "DelayUnitPs" -> delayPs))
    with HasBlackBoxResource {
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val local_head = Input(Bool())
    val local_mask = Input(UInt(5.W))
    val release_commit = Input(Bool())
    val packet_present = Output(Bool())
    val packet_mask = Output(UInt(5.W))
  })
  addResource("/ASYNC/UltraHeadCaptureCell.v")
  addResource("/ASYNC/DLatchBank.v")
  addResource(AsyncPrimitiveProfile.delayElementResource)
}

/** Frozen asynchronous round front end.  One occupancy latch plus decoded
  * SELECT/BUILD/ARMED/RETURN phases close four candidate membership windows
  * in parallel during BUILD, then export only immutable transaction fields
  * to the ACG fire domain.
  */
private class AsyncArbiterTransactionController(
    anchorSteps: Int, anchorPs: Int,
    roundCloseSteps: Int, roundClosePs: Int,
    membershipSteps: Int, membershipPs: Int,
    finalBuilderSteps: Int, finalBuilderPs: Int,
    returnSteps: Int, returnPs: Int
) extends BlackBox(Map(
      "AnchorDelayValue" -> anchorSteps, "AnchorDelayUnitPs" -> anchorPs,
      "RoundCloseDelayValue" -> roundCloseSteps, "RoundCloseDelayUnitPs" -> roundClosePs,
      "MembershipDelayValue" -> membershipSteps, "MembershipDelayUnitPs" -> membershipPs,
      "FinalBuilderDelayValue" -> finalBuilderSteps, "FinalBuilderDelayUnitPs" -> finalBuilderPs,
      "ReturnDelayValue" -> returnSteps, "ReturnDelayUnitPs" -> returnPs
    ))
    with HasBlackBoxResource {
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val fire = Input(Bool())
    val packet_present = Input(UInt(5.W))
    val packet_active = Input(UInt(5.W))
    val all_tail_passed = Input(UInt(5.W))
    val output_tail_busy = Input(UInt(5.W))
    val owner0 = Input(UInt(3.W)); val owner1 = Input(UInt(3.W)); val owner2 = Input(UInt(3.W))
    val owner3 = Input(UInt(3.W)); val owner4 = Input(UInt(3.W))
    val mask0 = Input(UInt(5.W)); val mask1 = Input(UInt(5.W)); val mask2 = Input(UInt(5.W))
    val mask3 = Input(UInt(5.W)); val mask4 = Input(UInt(5.W))
    val tx_valid = Output(Bool())
    val tx_release = Output(Bool())
    val tx_winner = Output(UInt(5.W))
    val tx_mask0 = Output(UInt(5.W)); val tx_mask1 = Output(UInt(5.W)); val tx_mask2 = Output(UInt(5.W))
    val tx_mask3 = Output(UInt(5.W)); val tx_mask4 = Output(UInt(5.W))
  })
  addResource("/ASYNC/AsyncArbiterTransactionController.v")
  addResource("/ASYNC/AsyncRoundMembershipCell.v")
  addResource("/ASYNC/Mutex5Anchor.v")
  addResource("/ASYNC/Mutex3Grant.v")
  addResource("/ASYNC/TAC2.v")
  addResource("/ASYNC/Mutex2.v")
  addResource("/ASYNC/MullerC2.v")
  addResource("/ASYNC/DLatchBank.v")
  addResource(AsyncPrimitiveProfile.delayElementResource)
}

/**
  * Transactional successor to AtomicMulticastAdmission.
  *
  * It deliberately has the same public interface as the legacy Atomic block,
  * but captures Heads with latches, freezes a complete transaction through an
  * asynchronous four-stage builder, and lets ACG fire update only frozen
  * owner/active state.
  */
class AtomicMulticastArbiterV2(config: RouterModuleConfig) extends Module {
  require(config.totalPorts == 5, "AtomicMulticastArbiterV2 targets five ports.")
  require(config.childLanes == 1 && config.parentLanes == 1,
    "AtomicMulticastArbiterV2 targets one lane per direction.")

  private val nPorts = config.totalPorts
  private val ownerW = 3
  private val noneOwner = nPorts.U(ownerW.W)
  private val captureSteps = AsyncDelay.steps(1, AsyncDelay.UltraArbiterHeadCapture)
  private val capturePs = AsyncDelay.unitPs(AsyncDelay.UltraArbiterHeadCapture)
  private def delaySteps(role: String) = AsyncDelay.steps(1, role)
  private def delayPs(role: String) = AsyncDelay.unitPs(role)

  val io = IO(new Bundle {
    val RS = Input(Vec(nPorts, Vec(nPorts - 1, Bool())))
    val allTailPassed = Input(Vec(nPorts, Bool()))
    val outputTailBusy = Input(Vec(nPorts, Bool()))
    val admittedRS = Output(Vec(nPorts, Vec(nPorts - 1, Bool())))
    val admissionPending = Output(Vec(nPorts, Bool()))
    val outputOwner = Output(Vec(nPorts, UInt(ownerW.W)))
    val packetMask = Output(Vec(nPorts, UInt(nPorts.W)))
    val packetActive = Output(Vec(nPorts, Bool()))
    /** Stable level used only to release the input-side Tail Ack barrier. */
    val tailReleaseReady = Output(Vec(nPorts, Bool()))
  })

  private val localHead = Wire(Vec(nPorts, Bool()))
  private val localMask = Wire(Vec(nPorts, UInt(nPorts.W)))
  for (input <- 0 until nPorts) {
    val legalOutputs = UltraTopology.legalOutputPorts(config, input)
    localHead(input) := io.RS(input).asUInt.orR
    localMask(input) := VecInit((0 until nPorts).map { output =>
      legalOutputs.indexOf(output) match {
        case branch if branch >= 0 => io.RS(input)(branch)
        case _ => false.B
      }
    }).asUInt
  }

  // The only fire-clocked persistent state: it is updated from frozen tx Q.
  private val commitController = Module(new ACG(Map(
    "InNum" -> 0, "OutNum" -> 1, "OutEnFF" -> 0, "MrGoEn" -> 0,
    "DfireDelayRole" -> AsyncDelay.UltraArbiterCommit
  )))
  private val commitAckDelay = Module(new DelayElement(
    AsyncDelay.steps(1, AsyncDelay.UltraArbiterCommitAck),
    AsyncDelay.unitPs(AsyncDelay.UltraArbiterCommitAck)
  ))
  commitAckDelay.io.I := commitController.Out(0).Req
  commitController.Out(0).Ack := commitAckDelay.io.Z
  private val fire = commitController.fire_o

  private val active = Wire(Vec(nPorts, Bool()))
  private val owner = Wire(Vec(nPorts, UInt(ownerW.W)))
  private val tx = Module(new AsyncArbiterTransactionController(
    delaySteps(AsyncDelay.UltraArbiterAnchor), delayPs(AsyncDelay.UltraArbiterAnchor),
    delaySteps(AsyncDelay.UltraArbiterRoundClose), delayPs(AsyncDelay.UltraArbiterRoundClose),
    delaySteps(AsyncDelay.UltraArbiterMembershipClose), delayPs(AsyncDelay.UltraArbiterMembershipClose),
    delaySteps(AsyncDelay.UltraArbiterFinalBuilder), delayPs(AsyncDelay.UltraArbiterFinalBuilder),
    delaySteps(AsyncDelay.UltraArbiterReturn), delayPs(AsyncDelay.UltraArbiterReturn)
  ))
  tx.io.reset := reset.asBool
  tx.io.fire := fire.asBool
  tx.io.packet_active := active.asUInt
  tx.io.all_tail_passed := io.allTailPassed.asUInt
  tx.io.output_tail_busy := io.outputTailBusy.asUInt
  tx.io.owner0 := owner(0); tx.io.owner1 := owner(1); tx.io.owner2 := owner(2)
  tx.io.owner3 := owner(3); tx.io.owner4 := owner(4)

  private val releaseCommit = Wire(Vec(nPorts, Bool()))
  private val present = Wire(Vec(nPorts, Bool()))
  private val masks = Wire(Vec(nPorts, UInt(nPorts.W)))
  for (input <- 0 until nPorts) {
    releaseCommit(input) := fire.asBool && tx.io.tx_release && tx.io.tx_winner(input)
    val capture = Module(new UltraHeadCaptureCell(captureSteps, capturePs))
    capture.io.reset := reset.asBool
    capture.io.local_head := localHead(input)
    capture.io.local_mask := localMask(input)
    capture.io.release_commit := releaseCommit(input)
    present(input) := capture.io.packet_present
    masks(input) := capture.io.packet_mask
  }
  tx.io.packet_present := present.asUInt
  tx.io.mask0 := masks(0); tx.io.mask1 := masks(1); tx.io.mask2 := masks(2)
  tx.io.mask3 := masks(3); tx.io.mask4 := masks(4)
  commitController.Start := tx.io.tx_valid

  private val committed = AsyncClock(fire, reset) {
    val ownerRegs = RegInit(VecInit(Seq.fill(nPorts)(noneOwner)))
    val activeRegs = RegInit(VecInit(Seq.fill(nPorts)(false.B)))
    val txMasks = Seq(tx.io.tx_mask0, tx.io.tx_mask1, tx.io.tx_mask2, tx.io.tx_mask3, tx.io.tx_mask4)
    when(tx.io.tx_release) {
      for (input <- 0 until nPorts) when(tx.io.tx_winner(input)) {
        activeRegs(input) := false.B
        for (output <- 0 until nPorts) when(txMasks(input)(output)) {
          ownerRegs(output) := noneOwner
        }
      }
    }.otherwise {
      for (input <- 0 until nPorts) when(tx.io.tx_winner(input)) {
        activeRegs(input) := true.B
        for (output <- 0 until nPorts) when(txMasks(input)(output)) {
          ownerRegs(output) := input.U
        }
      }
    }
    (ownerRegs, activeRegs)
  }
  owner := committed._1
  active := committed._2

  for (input <- 0 until nPorts) {
    io.admissionPending(input) := present(input) && !active(input)
    io.packetActive(input) := active(input)
    io.packetMask(input) := Mux(active(input), masks(input), 0.U)
    // This is deliberately a level, rather than the release fire pulse: V1
    // remains closed while a Tail waits, so it cannot lose this indication.
    io.tailReleaseReady(input) := !present(input) && !active(input)
    for (branch <- 0 until nPorts - 1) {
      val output = UltraTopology.legalOutputPorts(config, input)(branch)
      // A Head must be tied to a live captured descriptor.  In particular a
      // stale active bit may never lend admission to a later Head.
      io.admittedRS(input)(branch) := io.RS(input)(branch) && present(input) &&
        active(input) && masks(input)(output)
    }
  }
  io.outputOwner := owner
}

object AtomicMulticastArbiterV2Main extends App {
  private val config = RouterModuleConfig(
    childLanes = 1, parentLanes = 1, fifoDepth = 1, vcCount = 1,
    allowSameDirChild = false, allowSameDirParent = false
  )
  emitVerilog(
    new AtomicMulticastArbiterV2(config),
    Array("--target-dir", "generated_ultra", "AtomicMulticastArbiterV2")
  )
}
