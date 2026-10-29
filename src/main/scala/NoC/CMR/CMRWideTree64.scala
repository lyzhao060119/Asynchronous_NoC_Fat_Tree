package NoC.CMR

import NoC.{NoCScaleConfig, NoCRouterChannelConfig}
import Router_Architecture.CMR.{CMRParameters, CMRRouter}
import chisel3._

/** Single-router-per-group control experiment; not an alias for PROP M16.
  * 16 L1 c1p4 + 4 L2 c4p16 + 1 L3 c16p16, 64 cores, 16 top lanes.
  * Inter-level lanes are direct, as in the paper's network experiment.
  */
object CMRWideTree64Config {
  val channels: NoCRouterChannelConfig = NoCRouterChannelConfig(
    l1ChildLanes = 1, l1ParentLanes = 4,
    l2ParentLanes = 16, l3ParentLanes = 16, topChildLanes = 16)
  val scale: NoCScaleConfig = NoCScaleConfig(1, 1, channels)
}

class CMRWideTree64 extends CMRFatTree(
  scale = CMRWideTree64Config.scale, bypassInterLevelFifo = true
) {
  override def desiredName: String = "CMRWideTree64"
}

/** One explicitly selected emit per process to bound large FIRRTL heaps. */
object CMRWideGeometryMain extends App {
  private val kind = args.headOption.getOrElse("l1")
  private val target = args.drop(1).headOption.getOrElse(s"generated_cmr/wide_$kind")
  private val geometry = Map("l1" -> (1, 1, 4, false),
    "l2" -> (2, 4, 16, false), "l3" -> (3, 16, 16, false),
    "mesh" -> (1, 16, 16, true))
  if (kind == "tree64") {
    emitVerilog(new CMRWideTree64, Array("--target-dir", target))
    println("CMR_WIDE_EMIT_PASS tree64 routers=21 ipm=336 opm=336 cores=64 top=16")
  } else {
    require(geometry.contains(kind), s"Unknown wide emit: $kind")
    val (level, child, parent, mesh) = geometry(kind)
    emitVerilog(new CMRRouter(0, 0, level, child, parent, mesh, 8),
      Array("--target-dir", target))
    println(s"CMR_WIDE_EMIT_PASS $kind ports=${CMRParameters.portCount(child,parent)} " +
      s"adapters=${CMRParameters.expectedLaneAdapters(child,parent)} " +
      s"mutex=${CMRParameters.mutexWidths(child,parent).toSeq.sorted.mkString(",")}")
  }
}
