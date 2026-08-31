package NoC.CMR

import DataStruct.HS_Packet
import Router_Architecture.CMR.CMRRouter
import Router_Architecture.common.{AsyncFifo, AsyncFifoLike, CircularFifo}
import chisel3._
import tool.AsyncDelay

/**
  * Wrapper-compatible 16-core CMR fat-tree NoC using allocated lanes.
  *
  * Geometry is L1 1->2 and L2 2->4 (default) or L2 2->2 when
  * `CMR_NOC16_L2_PARENT_LANES=2` / `CMR_FAT_LANE_PROFILE=122`.  One depth-3
  * AsyncFifo sits on every physical inter-level lane unless bypassed.  The
  * core, quadrant and top-port map is the same as NoC.CMR.NoC_16nodes so the
  * remote TAB/VCTM AXI harness can be reused without translation.  The
  * emitted module name stays NoC_16nodes.
  *
  * Set CMR_USE_CIRCULAR_FIFO=1 to replace the inter-level AsyncFifo chain with
  * the Transition-paper circular FIFO. Circular mode is selected only on the
  * existing depth-three links; the unmodified four-slot paper FIFO can retain
  * four flits internally.
  *
  * Set CMR_BYPASS_INTERLEVEL_FIFO=1 to omit those sixteen links and wire each
  * L1 parent lane directly to the matching L2 child lane. Bypass takes
  * priority over CircularFIFO and is a diagnostic topology: storage is only
  * the in-router CMR Buffer. It is not a product configuration.
  */
class CMRFatTreeNoC16(
    interLevelFifoDepth: Int = 3,
    l2ParentLanes: Int = CMRFatTreeNoC16.defaultL2ParentLanes
) extends Module {
  override def desiredName: String = "NoC_16nodes"

  require(interLevelFifoDepth >= 1)
  require(l2ParentLanes == 2 || l2ParentLanes == 4,
    s"NoC16 L2 parent lanes must be 2 (1-2-2) or 4 (1-2-4), got $l2ParentLanes")
  private val l1ChildLanes = 1
  private val l1ParentLanes = 2
  private val l2ChildLanes = 2
  private val bypassInterLevelFifo = sys.env.get("CMR_BYPASS_INTERLEVEL_FIFO").contains("1")
  private val circularFifoRequested =
    !bypassInterLevelFifo && sys.env.get("CMR_USE_CIRCULAR_FIFO").contains("1")
  require(!circularFifoRequested || interLevelFifoDepth == 3,
    s"Transition CircularFIFO is enabled only for existing depth-3 links, got $interLevelFifoDepth")

  val io = IO(new Bundle {
    val core_inputs = Vec(16, new HS_Packet)
    val core_outputs = Flipped(Vec(16, new HS_Packet))
    val top_input = Vec(l2ParentLanes, new HS_Packet)
    val top_output = Flipped(Vec(l2ParentLanes, new HS_Packet))
  })

  private val routerL1 = Seq.tabulate(2, 2) { (x, y) =>
    Module(new CMRRouter(
      xCoordinate = x,
      yCoordinate = y,
      routerLevel = 1,
      childLanes = l1ChildLanes,
      parentLanes = l1ParentLanes
    ))
  }
  private val routerL2 = Module(new CMRRouter(
    xCoordinate = 0,
    yCoordinate = 0,
    routerLevel = 2,
    childLanes = l2ChildLanes,
    parentLanes = l2ParentLanes
  ))

  for (x <- 0 until 2) {
    for (y <- 0 until 2) {
      for (dir <- 0 until 4) {
        val selector = (~dir) & 0x3
        val localX = (selector >> 1) & 0x1
        val localY = selector & 0x1
        val core = 2 * x + localX + 4 * (2 * y + localY)
        routerL1(x)(y).io.inputs.child(dir)(0) <> io.core_inputs(core)
        routerL1(x)(y).io.outputs.child(dir)(0) <> io.core_outputs(core)
      }
    }
  }

  private def interLevelFifo(depth: Int): AsyncFifoLike =
    if (circularFifoRequested) Module(new CircularFifo(compatibilityDepth = depth))
    else Module(new AsyncFifo(depth, AsyncDelay.FifoDfire))

  for (dir <- 0 until 4) {
    val selector = (~dir) & 0x3
    val l1X = (selector >> 1) & 0x1
    val l1Y = selector & 0x1
    for (lane <- 0 until l1ParentLanes) {
      if (bypassInterLevelFifo) {
        routerL1(l1X)(l1Y).io.outputs.parent(lane) <> routerL2.io.inputs.child(dir)(lane)
        routerL2.io.outputs.child(dir)(lane) <> routerL1(l1X)(l1Y).io.inputs.parent(lane)
      } else {
        val upward = interLevelFifo(interLevelFifoDepth)
        val downward = interLevelFifo(interLevelFifoDepth)
        upward.io.enq <> routerL1(l1X)(l1Y).io.outputs.parent(lane)
        upward.io.deq <> routerL2.io.inputs.child(dir)(lane)
        downward.io.enq <> routerL2.io.outputs.child(dir)(lane)
        downward.io.deq <> routerL1(l1X)(l1Y).io.inputs.parent(lane)
      }
    }
  }

  for (lane <- 0 until l2ParentLanes) {
    routerL2.io.inputs.parent(lane) <> io.top_input(lane)
    routerL2.io.outputs.parent(lane) <> io.top_output(lane)
  }
}

object CMRFatTreeNoC16 {
  def defaultL2ParentLanes: Int = {
    sys.env.get("CMR_NOC16_L2_PARENT_LANES").map(_.trim) match {
      case Some("2") => 2
      case Some("4") => 4
      case Some(other) =>
        throw new IllegalArgumentException(
          s"CMR_NOC16_L2_PARENT_LANES='$other'. Supported: 2, 4."
        )
      case None =>
        sys.env.getOrElse("CMR_FAT_LANE_PROFILE", "124").trim.toLowerCase
          .replace("-", "").replace("_", "") match {
          case "122" | "1222" | "fatlane1222" => 2
          case _ => 4
        }
    }
  }
}

object CMRFatTreeNoC16Main extends App {
  private val l2Parent = CMRFatTreeNoC16.defaultL2ParentLanes
  private val targetDir =
    if (l2Parent == 2) "generated_cmr/fat_tree_noc16_122"
    else "generated_cmr/fat_tree_noc16"
  emitVerilog(
    new CMRFatTreeNoC16(l2ParentLanes = l2Parent),
    Array("--target-dir", targetDir)
  )
}
