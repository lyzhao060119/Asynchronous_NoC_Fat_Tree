package tool

import chisel3._
import chisel3.util.HasBlackBoxResource

object AsyncPrimitiveProfile {
  private val profile = sys.props
    .get("async.primitives")
    .orElse(sys.env.get("ASYNC_PRIMITIVES"))
    .getOrElse("sim")
    .toLowerCase

  require(
    Set("sim", "structural", "fpga", "synth", "asic").contains(profile),
    s"Unsupported async primitive profile '$profile'; expected sim, structural, fpga, synth, or asic"
  )

  val name: String = profile

  val delayElementResource: String = profile match {
    case "fpga" | "synth" => "/ASYNC/DelayElement_FPGA.v"
    case "sim" | "structural" => "/ASYNC/DelayElement_sim.v"
    case _                => "/ASYNC/DelayElement_ASIC.v"
  }

  val dontTouchBufResource: String = profile match {
    case "fpga" | "synth" => "/ASYNC/DontTouchBuf_FPGA.v"
    case "sim" | "structural" => "/ASYNC/DontTouchBuf_sim.v"
    case _                => "/ASYNC/DontTouchBuf_ASIC.v"
  }

  val mutex2Resource: String = profile match {
    case "fpga" | "synth" => "/ASYNC/Mutex2_fpga.v"
    case "asic"           => "/ASYNC/Mutex2_ASIC.v"
    case "structural"     => "/ASYNC/Mutex2.v"
    case _                => "/ASYNC/Mutex2_sim.v"
  }
}

/** Per-domain intentional delay selection.
  *
  * ASIC uses ASYNC_DELAY_PROFILE / -Dasync.delay.profile to sweep conservative
  * role-specific DEL cells. Simulation and FPGA profiles keep the caller's
  * requested DelayValue and use the profile resource's default mapping.
  */
object AsyncDelay {
  private case class DelaySpec(unitPs: Int, steps: Int)

  val DefaultRole = "default"
  val FifoDfire = "fifo_dfire"
  // Output Req must not lead Data Q.  One DEL150 covers the observed
  // ~36 ps last-stage clk-to-q skew without changing fire_o.
  val FifoOutReq = "fifo_out_req"
  val VcArbiterDfire = "vc_arbiter_dfire"
  val OpmArbiterDfire = "opm_arbiter_dfire"
  val DemuxLaunch = "demux_launch"
  val ReqGenLaunch = "reqgen_launch"
  val ForkComplete = "fork_complete"
  val ContextState = "context_state"
  val PriorityPulse = "priority_pulse"
  val Stage1InputCapture = "stage1_input_capture"
  val Stage1CommitReady = "stage1_commit_ready"
  val Stage1CommitGlobal = "stage1_commit_global"
  val Stage1OutputReqMargin = "stage1_output_req_margin"
  val UltraPrsMatched = "ultra_prs_matched"
  val UltraAdmissionAcg = "ultra_admission_acg"
  /** AtomicMulticastArbiterV2: routed Head mask must precede packetPresent. */
  val UltraArbiterHeadCapture = "ultra_arbiter_head_capture"
  /** AtomicMulticastArbiterV2 decision-cell bundled-data close margin. */
  val UltraArbiterDecision = "ultra_arbiter_decision"
  /** AtomicMulticastArbiterV2: anchor grant/mask must precede round start. */
  val UltraArbiterAnchor = "ultra_arbiter_anchor"
  /** AtomicMulticastArbiterV2: anchor snapshot must precede common close. */
  val UltraArbiterRoundClose = "ultra_arbiter_round_close"
  /** AtomicMulticastArbiterV2: one candidate close window. */
  val UltraArbiterMembershipClose = "ultra_arbiter_membership_close"
  /** AtomicMulticastArbiterV2: frozen membership precedes greedy payload. */
  val UltraArbiterFinalBuilder = "ultra_arbiter_final_builder"
  /** AtomicMulticastArbiterV2: fire-to-return state-settling boundary. */
  val UltraArbiterReturn = "ultra_arbiter_return"
  /** AtomicMulticastArbiterV2 frozen transaction to ACG fire margin. */
  val UltraArbiterCommit = "ultra_arbiter_commit"
  /** AtomicMulticastArbiterV2 dummy output Ack return margin. */
  val UltraArbiterCommitAck = "ultra_arbiter_commit_ack"
  /** OPM V2 XOR4-to-L5 bundled-data control margin. */
  val UltraOpmV2ReqMargin = "ultra_opm_v2_req_margin"

  val profile: String = sys.props
    .get("async.delay.profile")
    .orElse(sys.env.get("ASYNC_DELAY_PROFILE"))
    .getOrElse("P150_BASELINE")
    .toUpperCase

  private val baseline = DelaySpec(unitPs = 150, steps = 1)
  private val safe = DelaySpec(unitPs = 250, steps = 1)
  private val short = DelaySpec(unitPs = 100, steps = 1)
  private val tiny = DelaySpec(unitPs = 75, steps = 1)
  private val Stage1CustomProfile =
    "STAGE1_A(0|50|75|100|150|250)_BR(0|50|75|100|150|250)_BG(75|100|150|250)".r
  private val Stage1MarginProfile =
    "STAGE1M_A(50|75|100|150|250)_BR(50|75|100|150|250)_BG(75|100|150|250)_OM(75|100|150|250)".r
  private val UltraRtmProfile =
    "ULTRA_P250_PRS_ACG_OPM(0|50|75|100|150|250)".r
  // Phase-4 candidate: retain the membership close-margin hierarchy, but
  // make it an intentional physical bypass.  All other Ultra roles remain
  // bit-for-bit equivalent to the OPM75 timing baseline.
  private val UltraMembershipBypassProfile = "ULTRA_P250_PRS_ACG_OPM75_MEM0"
  // Phase-5 candidate: retain both capture and membership margin hierarchy,
  // but bypass their explicit DEL cells.  The PRS matched delay remains the
  // upstream route-decode guard; this profile tests only the downstream
  // RS-vector-to-mask capture window.
  private val UltraMembershipHeadCaptureBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0"
  // OPM V2 timing-optimization candidate.  The named RTL margin hierarchy is
  // deliberately retained, but its explicit DEL chain is bypassed so that
  // DC must satisfy the paired V2 control window with ordinary buffering and
  // drive sizing on the XOR4-to-L5 segment.
  private val UltraOpmSynthProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0"
  // Phase-6 candidate: keep the accepted OPM_SYNTH / MEM0 / HC0 bypasses,
  // and additionally bypass only the Mutex5-OR-to-round-start Anchor DEL.
  // RoundClose, FinalBuilder, Return, Commit and PRS remain DEL250.
  private val UltraOpmSynthAnchorBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_ANC0"
  // Phase-6 candidate after ANC0 SDF FAIL: keep Anchor DEL250 and bypass
  // only the post-membership greedy-fold FinalBuilder DEL.
  // RoundClose, Return, Commit and PRS remain DEL250.
  private val UltraOpmSynthFinalBuilderBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0"
  // Phase-7 candidate: keep the accepted FB0 bypasses and the
  // I=round_busy RoundClose qualification, then bypass only the
  // remaining RoundClose DEL.  Anchor, Return, Commit and PRS stay DEL250.
  private val UltraOpmSynthRoundCloseBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0"
  // Phase-8 candidate: keep the accepted RC0 bypasses, then bypass only
  // the dummy output Ack return DEL.  Dfire stays DEL250.
  private val UltraOpmSynthCommitAckBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0"
  // R1 candidate: sticky dual-rail Anchor capture, then bypass only the
  // remaining Anchor DEL.  Return, Dfire and PRS stay DEL250.
  private val UltraOpmSynthAnchorStickyBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0"
  // Head candidate after R4a Dfire measurement: keep the accepted ANCST0
  // bypasses, then bypass only the ACG Commit Dfire DEL.  DC must satisfy
  // Start→fire with ordinary buffering under set_min_delay.  Return and
  // PRS stay DEL250.
  private val UltraOpmSynthDfireBypassProfile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE0"
  // Head candidate after the DFIRE0 zero-buffer rejection: keep ANCST0 and
  // derate only the ACG Commit Dfire from DEL250 to DEL150.  The explicit
  // cell stays a real T28 DEL150; Return and PRS stay DEL250.
  private val UltraOpmSynthDfire150Profile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE150"
  // Single-role retry after DFIRE150 on R3f: keep ANCST0 and derate only
  // the ACG Commit Dfire from DEL150 to DEL100.  The explicit cell stays a
  // real T28 DEL100; Return and PRS stay DEL250.
  private val UltraOpmSynthDfire100Profile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE100"
  // Single-role probe of the library DEL050 cell.  Nominal sizing is 75 ps
  // (below the 80 ps floor) but mapped T28 DEL050 is expected >50 ps; the
  // SDF measurement decides.  Return and PRS stay DEL250.
  private val UltraOpmSynthDfire50Profile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50"
  // Single-role PRS prune after the DFIRE50 paired RTC: keep Commit DEL050
  // and Return DEL250, and derate only UltraPrsMatched from DEL250 to
  // DEL150.  DelayValue stays 1; do not start with PRS0.
  private val UltraOpmSynthDfire50Prs150Profile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS150"
  // Single-role skip from the accepted PRS150: keep Commit DEL050 and
  // Return DEL250, and derate only UltraPrsMatched from DEL150 to DEL050.
  // DelayValue stays 1; do not DelayValue=0.
  private val UltraOpmSynthDfire50Prs50Profile =
    "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS50"

  private def delaySpec(unitPs: String): DelaySpec =
    if (unitPs == "0") DelaySpec(unitPs = 150, steps = 0)
    else DelaySpec(unitPs = unitPs.toInt, steps = 1)

  private def asicSpec(role: String): DelaySpec = profile match {
    case Stage1MarginProfile(a, br, bg, om) =>
      role match {
        case Stage1InputCapture    => delaySpec(a)
        case Stage1CommitReady     => delaySpec(br)
        case Stage1CommitGlobal    => delaySpec(bg)
        case Stage1OutputReqMargin => delaySpec(om)
        case _                     => baseline
      }
    case Stage1CustomProfile(a, br, bg) =>
      role match {
        case Stage1InputCapture => delaySpec(a)
        case Stage1CommitReady  => delaySpec(br)
        case Stage1CommitGlobal => delaySpec(bg)
        case _                  => baseline
      }
    case "P150_BASELINE" =>
      role match {
        // V2's three new bundled-data control paths start conservatively.
        // They are intentionally independent of legacy P150 callers.
        case UltraArbiterHeadCapture | UltraArbiterDecision | UltraArbiterAnchor |
            UltraArbiterRoundClose | UltraArbiterMembershipClose |
            UltraArbiterFinalBuilder | UltraArbiterReturn | UltraArbiterCommit => safe
        case _ => baseline
      }
    case "P250_SAFE" => safe
    case "ULTRA_P250_PRS_ACG" =>
      role match {
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterHeadCapture |
            UltraArbiterDecision | UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterMembershipClose | UltraArbiterFinalBuilder |
            UltraArbiterReturn | UltraArbiterCommit => safe
        case _                                   => baseline
      }
    case UltraMembershipBypassProfile =>
      role match {
        case UltraArbiterMembershipClose => DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterHeadCapture |
            UltraArbiterDecision | UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterFinalBuilder | UltraArbiterReturn | UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => tiny
        case _                    => baseline
      }
    case UltraMembershipHeadCaptureBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterFinalBuilder | UltraArbiterReturn |
            UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => tiny
        case _                    => baseline
      }
    case UltraOpmSynthProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterFinalBuilder | UltraArbiterReturn |
            UltraArbiterCommit => safe
        // Keep the hierarchy, eliminate only the explicit physical DEL075.
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthAnchorBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterRoundClose | UltraArbiterFinalBuilder |
            UltraArbiterReturn | UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthFinalBuilderBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterReturn | UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthRoundCloseBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterAnchor | UltraArbiterReturn |
            UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthCommitAckBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterAnchor | UltraArbiterReturn |
            UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfireBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor |
            UltraArbiterCommit =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfire150Profile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraArbiterCommit => DelaySpec(unitPs = 150, steps = 1)
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfire100Profile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraArbiterCommit => DelaySpec(unitPs = 100, steps = 1)
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfire50Profile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraArbiterCommit => DelaySpec(unitPs = 50, steps = 1)
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfire50Prs150Profile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraPrsMatched => DelaySpec(unitPs = 150, steps = 1)
        case UltraArbiterCommit => DelaySpec(unitPs = 50, steps = 1)
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthDfire50Prs50Profile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn => safe
        case UltraPrsMatched => DelaySpec(unitPs = 50, steps = 1)
        case UltraArbiterCommit => DelaySpec(unitPs = 50, steps = 1)
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraOpmSynthAnchorStickyBypassProfile =>
      role match {
        case UltraArbiterMembershipClose | UltraArbiterHeadCapture |
            UltraArbiterFinalBuilder | UltraArbiterRoundClose |
            UltraArbiterCommitAck | UltraArbiterAnchor =>
          DelaySpec(unitPs = 250, steps = 0)
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterDecision |
            UltraArbiterReturn | UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin => DelaySpec(unitPs = 75, steps = 0)
        case _                    => baseline
      }
    case UltraRtmProfile(opm) =>
      role match {
        case UltraPrsMatched | UltraAdmissionAcg | UltraArbiterHeadCapture |
            UltraArbiterDecision | UltraArbiterAnchor | UltraArbiterRoundClose |
            UltraArbiterMembershipClose | UltraArbiterFinalBuilder |
            UltraArbiterReturn | UltraArbiterCommit => safe
        case UltraOpmV2ReqMargin                 => delaySpec(opm)
        case _                                    => baseline
      }
    case "P100_FIFO_ONLY" =>
      role match {
        case FifoDfire => short
        case _         => baseline
      }
    case "P100_FORWARD_SHORT" =>
      role match {
        case FifoDfire | OpmArbiterDfire => short
        case _                           => baseline
      }
    case "P100_SHORT_ONLY" =>
      role match {
        case FifoDfire | OpmArbiterDfire | ContextState | PriorityPulse =>
          short
        case _ => baseline
      }
    case "P100_DEMUX" =>
      role match {
        case DemuxLaunch | FifoDfire | OpmArbiterDfire | ContextState |
            PriorityPulse =>
          short
        case _ => baseline
      }
    case "P100_VC" | "REQGEN_OPT" =>
      role match {
        case DemuxLaunch | VcArbiterDfire | FifoDfire | OpmArbiterDfire |
            ContextState | PriorityPulse =>
          short
        case _ => baseline
      }
    case "STAGE1_SAFE" =>
      role match {
        case Stage1InputCapture | Stage1CommitReady | Stage1CommitGlobal |
            Stage1OutputReqMargin =>
          safe
        case _ => baseline
      }
    case "STAGE1_ALL150" =>
      role match {
        case Stage1InputCapture | Stage1CommitReady | Stage1CommitGlobal |
            Stage1OutputReqMargin =>
          baseline
        case _ => baseline
      }
    case "STAGE1_A_C_150_B250" =>
      role match {
        case Stage1InputCapture | Stage1OutputReqMargin => baseline
        case Stage1CommitReady | Stage1CommitGlobal => safe
        case _ => baseline
      }
    case "STAGE1_A_C_100_B250" =>
      role match {
        case Stage1InputCapture | Stage1OutputReqMargin => short
        case Stage1CommitReady | Stage1CommitGlobal => safe
        case _ => baseline
      }
    case "STAGE1_B_READY_150" =>
      role match {
        case Stage1InputCapture => short
        case Stage1CommitReady => baseline
        case Stage1CommitGlobal => safe
        case _ => baseline
      }
    case "STAGE1_B_GLOBAL_150" =>
      role match {
        case Stage1InputCapture => short
        case Stage1CommitReady | Stage1CommitGlobal => baseline
        case _ => baseline
      }
    case "STAGE1_A_C_075_B250" =>
      role match {
        case Stage1InputCapture | Stage1OutputReqMargin => tiny
        case Stage1CommitReady | Stage1CommitGlobal => safe
        case _ => baseline
      }
    case other =>
      require(
        false,
        s"Unsupported ASYNC_DELAY_PROFILE '$other'; expected P150_BASELINE, ULTRA_P250_PRS_ACG[_OPM0|50|75|100|150|250], ULTRA_P250_PRS_ACG_OPM75_MEM0[_HC0], ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0[_ANC0|_FB0|_FB0_RC0|_FB0_RC0_CACK0|_FB0_RC0_CACK0_ANCST0|_FB0_RC0_CACK0_ANCST0_DFIRE0|_FB0_RC0_CACK0_ANCST0_DFIRE150|_FB0_RC0_CACK0_ANCST0_DFIRE100|_FB0_RC0_CACK0_ANCST0_DFIRE50|_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS150|_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS50], P100_FIFO_ONLY, P100_FORWARD_SHORT, P100_DEMUX/P100_VC/REQGEN_OPT, STAGE1_Axxx_BRxxx_BGxxx, or STAGE1M_Axxx_BRxxx_BGxxx_OMxxx."
      )
      baseline
  }

  def steps(n: Int, role: String = DefaultRole): Int = {
    require(n >= 0)
    // Ultra OPM RTM sweeps must elaborate the same explicit DEL topology in
    // structural simulation and ASIC synthesis.  Other simulation profiles
    // retain their historical caller-selected delay behavior.
    val v2ArbiterRole = Set(UltraArbiterHeadCapture, UltraArbiterDecision,
      UltraArbiterAnchor, UltraArbiterRoundClose, UltraArbiterMembershipClose,
      UltraArbiterFinalBuilder, UltraArbiterReturn, UltraArbiterCommit,
      UltraArbiterCommitAck).contains(role)
    if (AsyncPrimitiveProfile.name == "asic" || profile.startsWith("ULTRA_P250_PRS_ACG_OPM") || v2ArbiterRole) {
      if (n == 0) 0 else asicSpec(role).steps
    } else n
  }

  def unitPs(role: String = DefaultRole): Int = {
    val v2ArbiterRole = Set(UltraArbiterHeadCapture, UltraArbiterDecision,
      UltraArbiterAnchor, UltraArbiterRoundClose, UltraArbiterMembershipClose,
      UltraArbiterFinalBuilder, UltraArbiterReturn, UltraArbiterCommit,
      UltraArbiterCommitAck).contains(role)
    if (AsyncPrimitiveProfile.name == "asic" || profile.startsWith("ULTRA_P250_PRS_ACG_OPM") || v2ArbiterRole)
      asicSpec(role).unitPs
    else 150
  }
}

// ***************************************
// Asynchronous Handshake Channel
// ***************************************
class HS_IO extends Bundle {
  val Req: Bool = Input(Bool())
  val Ack: Bool = Output(Bool())
}

// ***************************************
// Asynchronous Handshake Channel with Data
// ***************************************
class HS_Data(val WIDTH: Int) extends Bundle {
  val HS = new HS_IO
  val Data: UInt = Input(UInt(WIDTH.W))
}

// ***************************************
// Delay Element blackbox. Select the resource with ASYNC_PRIMITIVES=sim|fpga|asic.
// ***************************************
class DelayElement(
    val DelayValue: Int,
    val DelayUnitPs: Int = AsyncDelay.unitPs()
) extends BlackBox(
      Map("DelayValue" -> DelayValue, "DelayUnitPs" -> DelayUnitPs)
    )
    with HasBlackBoxResource {
  require(DelayValue >= 0)
  require(Set(50, 75, 100, 150, 250).contains(DelayUnitPs))
  val io = IO(new Bundle {
    val I: Bool = Input(Bool())
    val Z: Bool = Output(Bool())
  })
  addResource(AsyncPrimitiveProfile.delayElementResource)
}

/** Single keep/dont_touch buffer. ASIC maps to BUFFD0; not a DEL cell. */
class DontTouchBuf extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val I: Bool = Input(Bool())
    val Z: Bool = Output(Bool())
  })
  addResource(AsyncPrimitiveProfile.dontTouchBufResource)
}

// ***************************************
// MrGo unit. For more information about MrGo please refers to
// M. Roncken et al., "How to think about self-timed systems,"
// ***************************************
class MrGo extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val fire: Bool = Input(Bool())
    val En: Bool = Input(Bool())
    val Out: Bool = Output(Bool())
  })
  addResource("/ASYNC/MrGo.v")
}

class Mutex2 extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val req0 = Input(Bool())
    val req1 = Input(Bool())
    val gnt0 = Output(Bool())
    val gnt1 = Output(Bool())
  })
  addResource(AsyncPrimitiveProfile.mutex2Resource)
}

// ***************************************
// Asynchronous Controller Generator
// ***************************************
class ACG(val Para: Map[String, Any]) extends Module {

  // Get Parameters
  private val InNum: Int = Para.getOrElse("InNum", 0).asInstanceOf[Int]
  private val OutNum: Int = Para.getOrElse("OutNum", 0).asInstanceOf[Int]
  private val InEnFF: Int = Para.getOrElse("InEnFF", 0).asInstanceOf[Int]
  private val OutEnFF: Int = Para.getOrElse("OutEnFF", 0).asInstanceOf[Int]
  private val InitFull: Seq[Int] =
    Para.getOrElse("InitFull", Seq.fill(OutNum)(0)).asInstanceOf[Seq[Int]]
  private val MrGoEn: Int = Para.getOrElse("MrGoEn", 0).asInstanceOf[Int]
  private val InPLB: Seq[Int] =
    Para.getOrElse("InPLB", Seq.fill(InNum - 1)(0)).asInstanceOf[Seq[Int]]
  private val OutPLB: Seq[Int] =
    Para.getOrElse("OutPLB", Seq.fill(OutNum - 1)(0)).asInstanceOf[Seq[Int]]
  private val DreqDelayRole: String =
    Para.getOrElse("DreqDelayRole", AsyncDelay.DefaultRole).asInstanceOf[String]
  private val DfireDelayRole: String =
    Para.getOrElse("DfireDelayRole", AsyncDelay.DefaultRole).asInstanceOf[String]

  // Check Parameters
  require(InNum >= 0, s"[UAC] InNum must be >= 0")
  require(OutNum >= 0, s"[UAC] OutNum must be >= 0")
  require(InNum + OutNum > 0, s"[UAC] InNum+OutNum must be > 0")
  require(InEnFF == 0 || InEnFF == 1, s"[UAC] InEnFF must be 0 or 1")
  require(OutEnFF == 0 || OutEnFF == 1, s"[UAC] OutEnFF must be 0 or 1")
  require(MrGoEn == 0 || MrGoEn == 1, s"[UAC] OutEnFF must be 0 or 1")
  require(InPLB.forall(x => x == 0 || x == 1), "InPLB must contain only 0 or 1")
  require(OutPLB.forall(x => x == 0 || x == 1), "OutPLB must contain only 0 or 1")

  // Create ports
  val In: Vec[HS_IO] =
    if (InNum != 0) IO(Vec(InNum, new HS_IO())) else Vec(InNum, new HS_IO())
  val Out: Vec[HS_IO] =
    if (OutNum != 0) IO(Vec(OutNum, Flipped(new HS_IO())))
    else Vec(OutNum, Flipped(new HS_IO()))
  val InEn: Vec[Bool] =
    if (InEnFF != 0) IO(Input(Vec(InNum, Bool()))) else Vec(InNum, Bool())
  val OutEn: Vec[Bool] =
    if (OutEnFF != 0) IO(Input(Vec(OutNum, Bool()))) else Vec(OutNum, Bool())
  val fire_o: Clock = IO(Output(Clock()))
  val Start: Bool = if (InNum == 0) IO(Input(Bool())) else false.B
  val go: Bool = if (MrGoEn != 0) IO(Input(Bool())) else Bool()

  // Implementing input links.
  // Dreq is currently bypassed in ASIC profiles unless a caller requests steps.
  private def input_links(HS: HS_IO, InEn: Bool, fire: Bool): Bool = {
    val req_tmp = Wire(Bool())
    val dreqSteps = AsyncDelay.steps(0, DreqDelayRole)
    if (dreqSteps == 0) {
      req_tmp := HS.Req
    } else {
      val Dreq =
        Module(new DelayElement(dreqSteps, AsyncDelay.unitPs(DreqDelayRole)))
      Dreq.io.I := HS.Req
      req_tmp := Dreq.io.Z
    }
    AsyncClock(fire.asClock, reset) {
      val ff = RegInit(false.B)
      if (InEnFF == 1) {
        ff := Mux(InEn, HS.Req, HS.Ack)
      } else {
        ff := HS.Req
      }
      HS.Ack := ff
    }
    HS.Ack ^ req_tmp
  }

  // Implementing output links
  private def output_links(HS: HS_IO, OutEn: Bool, init: Int, fire: Bool): Bool = {
    AsyncClock(fire.asClock, reset) {
      val ff = RegInit(init.asUInt)
      if (OutEnFF == 1) {
        ff := Mux(OutEn, !HS.Ack, HS.Req)
      } else {
        ff := !HS.Ack
      }
      HS.Req := ff
    }
    !(HS.Ack ^ HS.Req)
  }

  // Implementing joint
  private def joint(full: Bool, empty: Bool, go: Bool): Bool = {
    val fire_and = full && empty
    val Dfire = Module(
      new DelayElement(
        AsyncDelay.steps(1, DfireDelayRole),
        AsyncDelay.unitPs(DfireDelayRole)
      )
    )
    if (MrGoEn == 1) {
      val MrGo = Module(new MrGo()).io
      MrGo.fire := fire_and
      MrGo.En := !go
      Dfire.io.I := MrGo.Out
    } else {
      Dfire.io.I := fire_and
    }
    Dfire.io.Z
  }

  // Implementing Input Parameterized logic block
  private val full: Bool = (0 until InNum).foldLeft(Start)((ResFull, idx) => {
    val wire_PRO = Wire(Bool())
    if (idx == 0) {
      if (InNum == 0) {
        wire_PRO := ResFull
      } else {
        wire_PRO := ResFull || input_links(In(idx), InEn(idx), fire_o.asBool)
      }

    } else if (InPLB(idx - 1) == 1) {
      wire_PRO := ResFull || input_links(In(idx), InEn(idx), fire_o.asBool)
    } else {
      wire_PRO := ResFull && input_links(In(idx), InEn(idx), fire_o.asBool)
    }
    wire_PRO
  })

  // Implementing Output Parameterized logic block
  private val empty: Bool = (0 until OutNum).foldLeft(true.B)((ResEmpty, idx) => {
    val wire_PRO = Wire(Bool())
    if (idx == 0) {
      if (OutNum == 0) {
        wire_PRO := ResEmpty
      } else {
        wire_PRO := ResEmpty && output_links(Out(idx), OutEn(idx), InitFull(idx), fire_o.asBool)
      }
    } else if (OutPLB(idx - 1) == 1) {
      wire_PRO := ResEmpty || output_links(Out(idx), OutEn(idx), InitFull(idx), fire_o.asBool)
    } else {
      wire_PRO := ResEmpty && output_links(Out(idx), OutEn(idx), InitFull(idx), fire_o.asBool)
    }
    wire_PRO
  })

  // Create asynchronous clock
  fire_o := joint(full, empty, go).asClock
}

object AsyncClock {
  /** Creates a new asynchronous clock and reset scope.
    *
    * @param Aclock the new asynchronous Clock
    * @param reset the new asynchronous Reset
    * @param block the block of code to run with new implicit asynchronous Clock and Reset
    */
  def apply[T](Aclock: Clock, reset: Reset)(block: => T): T = {
    withClockAndReset(Aclock, reset.asAsyncReset) {
      block
    }
  }
}
