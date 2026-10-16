package NoC.CMR

import NoC.NoCScaleConfig
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.sync_cmr.{SyncCmrRouter, SyncVrPacket}
import chisel3._

/** Clocked valid/ready 64-core PFAT 1-2-4-8 quadtree.
  *
  * Lane geometry comes from `scale.channels`. Inter-level links are direct
  * wires; storage is only the in-router 5-cell buffer. M16 PROP is an
  * asynchronous three-level tree and is not represented by this module.
  */
class SyncCmrFatTree(
    coordinateX: Int = 0,
    coordinateY: Int = 0,
    scale: NoCScaleConfig = NoCScaleConfig.fatTree64
) extends Module {
  private val l1 = scale.channels.l1
  private val l2 = scale.channels.l2
  private val l3 = scale.channels.l3
  require(scale.coresPerQuad == 64)
  require(l1.childLanes == 1,
    s"Sync 64-core L1 child lanes must be 1, got ${l1.childLanes}")
  require(l2.childLanes == l1.parentLanes)
  require(l3.childLanes == l2.parentLanes)
  require(CMRParameters.SupportedLaneGeometries.contains((l1.childLanes, l1.parentLanes)),
    s"unsupported L1 geometry (${l1.childLanes},${l1.parentLanes})")
  require(CMRParameters.SupportedLaneGeometries.contains((l2.childLanes, l2.parentLanes)),
    s"unsupported L2 geometry (${l2.childLanes},${l2.parentLanes})")
  require(CMRParameters.SupportedLaneGeometries.contains((l3.childLanes, l3.parentLanes)),
    s"unsupported L3 geometry (${l3.childLanes},${l3.parentLanes})")

  val io = IO(new Bundle {
    val core_inputs = Vec(scale.coresPerQuad, new SyncVrPacket)
    val core_outputs = Flipped(Vec(scale.coresPerQuad, new SyncVrPacket))
    val top_input = Vec(l3.parentLanes, new SyncVrPacket)
    val top_output = Flipped(Vec(l3.parentLanes, new SyncVrPacket))
  })

  private val routersL1 = Seq.tabulate(
    scale.leafRouterGridX,
    scale.leafRouterGridY
  ) { (x, y) =>
    Module(new SyncCmrRouter(
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
    Module(new SyncCmrRouter(
      x + coordinateX * scale.midRouterGridX,
      y + coordinateY * scale.midRouterGridY,
      routerLevel = 2,
      childLanes = l2.childLanes,
      parentLanes = l2.parentLanes
    ))
  }
  private val routerL3 = Module(new SyncCmrRouter(
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

  for (y <- 0 until scale.midRouterGridY; x <- 0 until scale.midRouterGridX) {
    for (direction <- 0 until 4) {
      val selector = (~direction) & 0x3
      val childX = 2 * x + ((selector >> 1) & 1)
      val childY = 2 * y + (selector & 1)
      for (lane <- 0 until l2.childLanes) {
        routersL1(childX)(childY).io.outputs.parent(lane) <>
          routersL2(x)(y).io.inputs.child(direction)(lane)
        routersL2(x)(y).io.outputs.child(direction)(lane) <>
          routersL1(childX)(childY).io.inputs.parent(lane)
      }
    }
  }

  for (direction <- 0 until 4) {
    val selector = (~direction) & 0x3
    val childX = (selector >> 1) & 1
    val childY = selector & 1
    for (lane <- 0 until l3.childLanes) {
      routersL2(childX)(childY).io.outputs.parent(lane) <>
        routerL3.io.inputs.child(direction)(lane)
      routerL3.io.outputs.child(direction)(lane) <>
        routersL2(childX)(childY).io.inputs.parent(lane)
    }
  }

  for (lane <- 0 until l3.parentLanes) {
    routerL3.io.inputs.parent(lane) <> io.top_input(lane)
    routerL3.io.outputs.parent(lane) <> io.top_output(lane)
  }
}

/** Fat 1-2-4-8 clocked 64-core tree.  It is the synchronous Q64 counterpart
  * of the PFAT tile: L1 1->2, L2 2->4, L3 4->8, with eight top lanes.
  */
class SyncCmrFatTreeNoC64Fat1248(
    scale: NoCScaleConfig = NoCScaleConfig.syncFatTree64_1248
) extends Module {
  override def desiredName: String = "SyncNoC_64nodes"

  require(scale.coresPerQuad == 64)
  require((scale.channels.l1.childLanes, scale.channels.l1.parentLanes) == (1, 2),
    s"Sync Fat1248 L1 must be (1,2), got (${scale.channels.l1.childLanes},${scale.channels.l1.parentLanes})")
  require((scale.channels.l2.childLanes, scale.channels.l2.parentLanes) == (2, 4),
    s"Sync Fat1248 L2 must be (2,4), got (${scale.channels.l2.childLanes},${scale.channels.l2.parentLanes})")
  require((scale.channels.l3.childLanes, scale.channels.l3.parentLanes) == (4, 8),
    s"Sync Fat1248 L3 must be (4,8), got (${scale.channels.l3.childLanes},${scale.channels.l3.parentLanes})")
  require(scale.channels.l3.parentLanes == 8,
    s"Sync Fat1248 NoC64 top lanes must be 8, got ${scale.channels.l3.parentLanes}")

  val io = IO(new Bundle {
    val core_inputs = Vec(64, new SyncVrPacket)
    val core_outputs = Flipped(Vec(64, new SyncVrPacket))
    val top_input = Vec(8, new SyncVrPacket)
    val top_output = Flipped(Vec(8, new SyncVrPacket))
  })

  private val tree = Module(new SyncCmrFatTree(
    coordinateX = 0,
    coordinateY = 0,
    scale = scale
  ))
  io <> tree.io
}

object SyncCmrFatTreeNoC64Fat1248Main extends App {
  emitVerilog(
    new SyncCmrFatTreeNoC64Fat1248(NoCScaleConfig.syncFatTree64_1248),
    Array("--target-dir", "generated_sync_cmr/fat_tree_noc64_1248")
  )
}

/** Topology-matched synchronous implementation of PROP_temp64 B8.
  *
  * This mirrors PROPtempTile rather than the 21-router shared-tree variants:
  * sixteen independent L1, L2 and L3 routers preserve the four parallel
  * planes at each hierarchy boundary.
  */
class SyncPROPtemp64 extends Module {
  // Keep the established clocked-flow top name; the frozen run ID and design
  // manifest distinguish this 48-router B8 implementation from old 21-router
  // Sync variants.
  override def desiredName: String = "SyncNoC_64nodes"
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new SyncVrPacket)
    val core_outputs = Flipped(Vec(64, new SyncVrPacket))
    val top_input = Vec(16, new SyncVrPacket)
    val top_output = Flipped(Vec(16, new SyncVrPacket))
  })

  private def xy(n: Int): (Int, Int) = (n / 2, n % 2)
  private def topIndex(j: Int, k: Int): Int = 4 * j + k

  private val l1 = Seq.tabulate(4, 4) { (q, i) =>
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val r = Module(new SyncCmrRouter(2 * qx + ix, 2 * qy + iy,
      routerLevel = 1, childLanes = 1, parentLanes = 4))
    r.suggestName(s"syncPropL1_q${q}_i${i}")
    r
  }
  private val l2 = Seq.tabulate(4, 4) { (q, k) =>
    val (qx, qy) = xy(q)
    val r = Module(new SyncCmrRouter(qx, qy, routerLevel = 2,
      childLanes = 1, parentLanes = 4))
    r.suggestName(s"syncPropL2_q${q}_k${k}")
    r
  }
  private val l3 = Seq.tabulate(4, 4) { (j, k) =>
    val r = Module(new SyncCmrRouter(0, 0, routerLevel = 3,
      childLanes = 1, parentLanes = 1))
    r.suggestName(s"syncPropL3_j${j}_k${k}")
    r
  }

  for (q <- 0 until 4; i <- 0 until 4) {
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val x = 4 * qx + 2 * ix
    val y = 4 * qy + 2 * iy
    val cores = Seq((x + 1) + 8 * (y + 1), (x + 1) + 8 * y,
      x + 8 * (y + 1), x + 8 * y)
    for (d <- 0 until 4) {
      l1(q)(i).io.inputs.child(d)(0) <> io.core_inputs(cores(d))
      l1(q)(i).io.outputs.child(d)(0) <> io.core_outputs(cores(d))
    }
  }
  for (q <- 0 until 4; i <- 0 until 4; k <- 0 until 4) {
    val d = (~i) & 3
    l1(q)(i).io.outputs.parent(k) <> l2(q)(k).io.inputs.child(d)(0)
    l2(q)(k).io.outputs.child(d)(0) <> l1(q)(i).io.inputs.parent(k)
  }
  for (q <- 0 until 4; k <- 0 until 4; j <- 0 until 4) {
    val d = (~q) & 3
    l2(q)(k).io.outputs.parent(j) <> l3(j)(k).io.inputs.child(d)(0)
    l3(j)(k).io.outputs.child(d)(0) <> l2(q)(k).io.inputs.parent(j)
  }
  for (j <- 0 until 4; k <- 0 until 4) {
    val p = topIndex(j, k)
    l3(j)(k).io.inputs.parent(0) <> io.top_input(p)
    l3(j)(k).io.outputs.parent(0) <> io.top_output(p)
  }
}

object SyncPROPtemp64Main extends App {
  emitVerilog(new SyncPROPtemp64,
    Array("--target-dir", "generated_sync_cmr/prop_temp64_b8"))
}

/** Clocked topology match for PROPtemp64M16.
  *
  * L1/L2/L3 are all c1p4 and the sixteen L3 routers expose 64 parent lanes.
  * No upper Mesh is instantiated in this standalone 64-core experiment.
  */
class SyncPROPtemp64M16 extends Module {
  override def desiredName: String = "SyncNoC_64nodes"
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new SyncVrPacket)
    val core_outputs = Flipped(Vec(64, new SyncVrPacket))
    val top_input = Vec(64, new SyncVrPacket)
    val top_output = Flipped(Vec(64, new SyncVrPacket))
  })

  private def xy(n: Int): (Int, Int) = (n / 2, n % 2)
  private def topIndex(j: Int, k: Int, h: Int): Int = 16 * j + 4 * k + h

  private val l1 = Seq.tabulate(4, 4) { (q, i) =>
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val r = Module(new SyncCmrRouter(2 * qx + ix, 2 * qy + iy,
      routerLevel = 1, childLanes = 1, parentLanes = 4))
    r.suggestName(s"syncPropM16L1_q${q}_i${i}")
    r
  }
  private val l2 = Seq.tabulate(4, 4) { (q, k) =>
    val (qx, qy) = xy(q)
    val r = Module(new SyncCmrRouter(qx, qy, routerLevel = 2,
      childLanes = 1, parentLanes = 4))
    r.suggestName(s"syncPropM16L2_q${q}_k${k}")
    r
  }
  private val l3 = Seq.tabulate(4, 4) { (j, k) =>
    val r = Module(new SyncCmrRouter(0, 0, routerLevel = 3,
      childLanes = 1, parentLanes = 4))
    r.suggestName(s"syncPropM16L3_j${j}_k${k}")
    r
  }

  for (q <- 0 until 4; i <- 0 until 4) {
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val x = 4 * qx + 2 * ix
    val y = 4 * qy + 2 * iy
    val cores = Seq((x + 1) + 8 * (y + 1), (x + 1) + 8 * y,
      x + 8 * (y + 1), x + 8 * y)
    for (d <- 0 until 4) {
      l1(q)(i).io.inputs.child(d)(0) <> io.core_inputs(cores(d))
      l1(q)(i).io.outputs.child(d)(0) <> io.core_outputs(cores(d))
    }
  }
  for (q <- 0 until 4; i <- 0 until 4; k <- 0 until 4) {
    val d = (~i) & 3
    l1(q)(i).io.outputs.parent(k) <> l2(q)(k).io.inputs.child(d)(0)
    l2(q)(k).io.outputs.child(d)(0) <> l1(q)(i).io.inputs.parent(k)
  }
  for (q <- 0 until 4; k <- 0 until 4; j <- 0 until 4) {
    val d = (~q) & 3
    l2(q)(k).io.outputs.parent(j) <> l3(j)(k).io.inputs.child(d)(0)
    l3(j)(k).io.outputs.child(d)(0) <> l2(q)(k).io.inputs.parent(j)
  }
  for (j <- 0 until 4; k <- 0 until 4; h <- 0 until 4) {
    val p = topIndex(j, k, h)
    l3(j)(k).io.inputs.parent(h) <> io.top_input(p)
    l3(j)(k).io.outputs.parent(h) <> io.top_output(p)
  }
}

object SyncPROPtemp64M16Main extends App {
  emitVerilog(new SyncPROPtemp64M16,
    Array("--target-dir", "generated_sync_cmr/prop_temp64_m16"))
}
