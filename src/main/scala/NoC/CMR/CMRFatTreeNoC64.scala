package NoC.CMR

import DataStruct.HS_Packet
import NoC.NoCScaleConfig
import chisel3._

/**
  * Wrapper-compatible 64-core CMR fat-tree NoC.
  *
  * Geometry is selected by `CMR_Q64_PROFILE` (`thin`, `1222` default, or
  * `1248`) with fallback to `CMR_FAT_LANE_PROFILE`.  IO is 64 cores plus
  * the profile's top parent lanes (1, 2 or 8).  The emitted module name
  * stays `NoC_64nodes` so the 64-core TB can bind without translation.
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
  require(Set(1, 2, 8).contains(topLanes),
    s"NoC64 top lanes must be 1 (thin), 2 (1222) or 8 (1248), got $topLanes")

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
  private val scale = NoCScaleConfig.q64TreeFromEnv
  private val profile =
    if (scale.channels == NoCScaleConfig.ThinLane111) "thin"
    else if (scale.channels == NoCScaleConfig.FatLane1222) "1222"
    else "1248"
  emitVerilog(
    new CMRFatTreeNoC64(scale),
    Array("--target-dir", s"generated_cmr/fat_tree_noc64_$profile")
  )
}

object CMRFatTreeNoC64ThinMain extends App {
  emitVerilog(
    new CMRFatTreeNoC64(NoCScaleConfig.thinTree64),
    Array("--target-dir", "generated_cmr/fat_tree_noc64_thin")
  )
}
