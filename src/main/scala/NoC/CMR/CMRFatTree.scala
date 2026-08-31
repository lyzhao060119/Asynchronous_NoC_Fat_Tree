package NoC.CMR

import DataStruct.HS_Packet
import NoC.NoCScaleConfig
import Router_Architecture.CMR.CMRRouter
import Router_Architecture.common.{AsyncFifo, AsyncFifoLike, CircularFifo}
import chisel3._
import tool.AsyncDelay

/** One complete 64-core CMR quadtree.
  *
  * Lane geometry comes from `scale.channels`.  FatLane1248 is L1 1→2, L2 2→4,
  * L3 4→8 (eight top lanes).  FatLane1222 keeps L1 1→2 and uses 2→2 at L2
  * and L3 (two top lanes).  L1 stays one child lane so the tile is 64 cores.
  *
  * Set CMR_USE_CIRCULAR_FIFO=1 to replace the inter-level AsyncFifo chain with
  * the Transition-paper circular FIFO on existing depth-three lanes. The
  * unmodified four-slot paper FIFO can retain four flits internally.
  *
  * `bypassInterLevelFifo` wires each physical inter-level lane directly.
  * Bypass takes priority over CircularFIFO.  Storage is then only the
  * in-router CMR Buffer.  The 64-core paper DUT (`CMRFatTreeNoC64`) defaults
  * to bypass; this tile generator keeps FIFOs unless the caller requests it.
  */
class CMRFatTree(
    coordinateX: Int = 0,
    coordinateY: Int = 0,
    scale: NoCScaleConfig = NoCScaleConfig.Verification256,
    bypassInterLevelFifo: Boolean = false
) extends Module {
  private val l1 = scale.channels.l1
  private val l2 = scale.channels.l2
  private val l3 = scale.channels.l3
  require((l1.childLanes, l1.parentLanes) == (1, 2),
    s"64-core Fat L1 must be (1,2), got (${l1.childLanes},${l1.parentLanes})")
  require(l2.childLanes == l1.parentLanes)
  require(l3.childLanes == l2.parentLanes)
  require(Router_Architecture.CMR.CMRParameters.SupportedLaneGeometries.contains(
    (l2.childLanes, l2.parentLanes)
  ), s"unsupported L2 geometry (${l2.childLanes},${l2.parentLanes})")
  require(Router_Architecture.CMR.CMRParameters.SupportedLaneGeometries.contains(
    (l3.childLanes, l3.parentLanes)
  ), s"unsupported L3 geometry (${l3.childLanes},${l3.parentLanes})")
  require(scale.coresPerQuad == 64)

  private val circularFifoRequested =
    !bypassInterLevelFifo && sys.env.get("CMR_USE_CIRCULAR_FIFO").contains("1")

  private def useCircularFifo(depth: Int): Boolean = {
    require(!circularFifoRequested || depth == 3,
      s"Transition CircularFIFO is enabled only for existing depth-3 links, got $depth")
    circularFifoRequested
  }

  private def interLevelFifo(depth: Int): AsyncFifoLike =
    if (useCircularFifo(depth)) Module(new CircularFifo(compatibilityDepth = depth))
    else Module(new AsyncFifo(depth, AsyncDelay.FifoDfire))

  val io = IO(new Bundle {
    val core_inputs = Vec(scale.coresPerQuad, new HS_Packet)
    val core_outputs = Flipped(Vec(scale.coresPerQuad, new HS_Packet))
    val top_input = Vec(l3.parentLanes, new HS_Packet)
    val top_output = Flipped(Vec(l3.parentLanes, new HS_Packet))
  })

  private val routersL1 = Seq.tabulate(
    scale.leafRouterGridX,
    scale.leafRouterGridY
  ) { (x, y) =>
    Module(new CMRRouter(
      x + coordinateX * scale.leafRouterGridX,
      y + coordinateY * scale.leafRouterGridY,
      routerLevel = 1,
      childLanes = l1.childLanes,
      parentLanes = l1.parentLanes
    ))
  }
  private val routersL2 = Seq.tabulate(
    scale.midRouterGridX,
    scale.midRouterGridY
  ) { (x, y) =>
    Module(new CMRRouter(
      x + coordinateX * scale.midRouterGridX,
      y + coordinateY * scale.midRouterGridY,
      routerLevel = 2,
      childLanes = l2.childLanes,
      parentLanes = l2.parentLanes
    ))
  }
  private val routerL3 = Module(new CMRRouter(
    coordinateX,
    coordinateY,
    routerLevel = 3,
    childLanes = l3.childLanes,
    parentLanes = l3.parentLanes
  ))

  for (y <- 0 until scale.leafRouterGridY; x <- 0 until scale.leafRouterGridX) {
    val localX0 = 2 * x
    val localY0 = 2 * y
    val cores = Seq(
      scale.localCoreIndex(localX0 + 1, localY0 + 1, 0),
      scale.localCoreIndex(localX0 + 1, localY0, 0),
      scale.localCoreIndex(localX0, localY0 + 1, 0),
      scale.localCoreIndex(localX0, localY0, 0)
    )
    for (direction <- 0 until 4) {
      routersL1(x)(y).io.inputs.child(direction)(0) <>
        io.core_inputs(cores(direction))
      routersL1(x)(y).io.outputs.child(direction)(0) <>
        io.core_outputs(cores(direction))
    }
  }

  private def connectInterLevel(
      childOut: HS_Packet,
      parentIn: HS_Packet,
      childIn: HS_Packet,
      parentOut: HS_Packet,
      depth: Int
  ): Unit = {
    if (bypassInterLevelFifo) {
      childOut <> parentIn
      parentOut <> childIn
    } else {
      val upward = interLevelFifo(depth)
      val downward = interLevelFifo(depth)
      upward.io.enq <> childOut
      upward.io.deq <> parentIn
      downward.io.enq <> parentOut
      downward.io.deq <> childIn
    }
  }

  // Every physical inter-level lane receives its own FIFO, or a bypass wire.
  for (y <- 0 until scale.midRouterGridY; x <- 0 until scale.midRouterGridX) {
    for (direction <- 0 until 4) {
      val selector = (~direction) & 0x3
      val childX = 2 * x + ((selector >> 1) & 1)
      val childY = 2 * y + (selector & 1)
      for (lane <- 0 until l2.childLanes) {
        connectInterLevel(
          routersL1(childX)(childY).io.outputs.parent(lane),
          routersL2(x)(y).io.inputs.child(direction)(lane),
          routersL1(childX)(childY).io.inputs.parent(lane),
          routersL2(x)(y).io.outputs.child(direction)(lane),
          l1.fifoDepth
        )
      }
    }
  }

  for (direction <- 0 until 4) {
    val selector = (~direction) & 0x3
    val childX = (selector >> 1) & 1
    val childY = selector & 1
    for (lane <- 0 until l3.childLanes) {
      connectInterLevel(
        routersL2(childX)(childY).io.outputs.parent(lane),
        routerL3.io.inputs.child(direction)(lane),
        routersL2(childX)(childY).io.inputs.parent(lane),
        routerL3.io.outputs.child(direction)(lane),
        l2.fifoDepth
      )
    }
  }

  for (lane <- 0 until l3.parentLanes) {
    routerL3.io.inputs.parent(lane) <> io.top_input(lane)
    routerL3.io.outputs.parent(lane) <> io.top_output(lane)
  }
}

object CMRFatTreeMain extends App {
  private val scale = NoCScaleConfig.fatTree64
  private val targetDir =
    if (NoCScaleConfig.fatLaneProfileName == "1222") "generated_cmr/fat_tree_1_2_2_2"
    else "generated_cmr/fat_tree_1_2_4_8"
  emitVerilog(
    new CMRFatTree(scale = scale),
    Array("--target-dir", targetDir)
  )
}

/** Simulation boundary harness for a two-packet, three-level upward path. */
class CMRFatTreeSmokeHarness extends Module {
  private val scale = NoCScaleConfig.Verification256
  val io = IO(new Bundle {
    val Reqin = Input(Vec(2, Bool()))
    val Datain = Input(Vec(2, new DataStruct.Packet))
    val Ackout = Output(Vec(2, Bool()))
    val TopReqout = Output(Vec(8, Bool()))
    val TopDataout = Output(Vec(8, new DataStruct.Packet))
    val TopAckin = Input(Vec(8, Bool()))
  })

  private val tree = Module(new CMRFatTree(scale = scale))
  for (core <- 0 until scale.coresPerQuad) {
    if (core < 2) {
      tree.io.core_inputs(core).HS.Req := io.Reqin(core)
      tree.io.core_inputs(core).Data := io.Datain(core)
      io.Ackout(core) := tree.io.core_inputs(core).HS.Ack
    } else {
      tree.io.core_inputs(core).HS.Req := false.B
      tree.io.core_inputs(core).Data.flit := 0.U
    }
    tree.io.core_outputs(core).HS.Ack := false.B
  }
  for (lane <- 0 until 8) {
    tree.io.top_input(lane).HS.Req := false.B
    tree.io.top_input(lane).Data.flit := 0.U
    io.TopReqout(lane) := tree.io.top_output(lane).HS.Req
    io.TopDataout(lane) := tree.io.top_output(lane).Data
    tree.io.top_output(lane).HS.Ack := io.TopAckin(lane)
  }
}

object CMRFatTreeSmokeHarnessMain extends App {
  emitVerilog(
    new CMRFatTreeSmokeHarness,
    Array("--target-dir", "generated_cmr/fat_tree_smoke_harness")
  )
}
