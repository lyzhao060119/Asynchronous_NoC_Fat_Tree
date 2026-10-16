package NoC.CMR

import DataStruct.HS_Packet
import NoC.NoCScaleConfig
import chisel3._

/**
  * Wrapper-compatible 64-core CMR fat-tree NoC.
  *
  * This wrapper is the PFAT 1-2-4-8 tree only.  PROP selects the separate
  * M16 tree in `PROPtemp64M16`; the removed Thin/1-2-2-2 profiles are not
  * silently aliased to this topology.
  *
  * Inter-level FIFOs default to bypass (paper DUT).  Set
  * `CMR_BYPASS_INTERLEVEL_FIFO=0` to restore the depth-1 AsyncFifo chain
  * (or CircularFIFO when `CMR_USE_CIRCULAR_FIFO=1` and the depth is 3).
  */
class CMRFatTreeNoC64(
    scale: NoCScaleConfig = NoCScaleConfig.fatTree64,
    bypassInterLevelFifo: Boolean = CMRFatTreeNoC64.defaultBypass
) extends Module {
  override def desiredName: String = "NoC_64nodes"

  require(scale.coresPerQuad == 64)
  private val topLanes = scale.channels.l3.parentLanes
  require(topLanes == 8,
    s"PFAT64 top lanes must be 8, got $topLanes")

  val io = IO(new Bundle {
    val core_inputs = Vec(64, new HS_Packet)
    val core_outputs = Flipped(Vec(64, new HS_Packet))
    val top_input = Vec(topLanes, new HS_Packet)
    val top_output = Flipped(Vec(topLanes, new HS_Packet))
  })

  private val tree = Module(new CMRFatTree(
    coordinateX = 0,
    coordinateY = 0,
    scale = scale,
    bypassInterLevelFifo = bypassInterLevelFifo
  ))

  io <> tree.io
}

object CMRFatTreeNoC64 {
  def defaultBypass: Boolean =
    !sys.env.get("CMR_BYPASS_INTERLEVEL_FIFO").contains("0")
}

object CMRFatTreeNoC64Main extends App {
  private val profile = sys.env.getOrElse("CMR_Q64_PROFILE", "1248")
    .trim.toLowerCase.replace("-", "").replace("_", "")
  profile match {
    case "prop" | "m16" | "propm16" =>
      emitVerilog(
        new PROPtemp64M16,
        Array("--target-dir", "generated_cmr/prop_temp64_m16")
      )
    case "1248" | "pfat" | "fatlane1248" =>
      emitVerilog(
        new CMRFatTreeNoC64(NoCScaleConfig.fatTree64),
        Array("--target-dir", "generated_cmr/fat_tree_noc64_1248")
      )
    case other =>
      throw new IllegalArgumentException(
        s"Unsupported CMR_Q64_PROFILE='$other'. Use prop (M16) or 1248."
      )
  }
}
