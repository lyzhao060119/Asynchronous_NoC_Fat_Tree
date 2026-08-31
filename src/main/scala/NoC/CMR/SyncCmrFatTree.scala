package NoC.CMR

import NoC.NoCScaleConfig
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.sync_cmr.{SyncCmrRouter, SyncVrPacket}
import chisel3._

/** Clocked valid/ready 64-core CMR quadtree.
  *
  * Lane geometry comes from `scale.channels`.  Thin is all (1,1) with one
  * top lane.  Fat 1-2-2-2 is L1 (1,2) and L2/L3 (2,2) with two top lanes.
  * Inter-level links are direct wires; storage is only the in-router
  * 5-cell buffer.
  */
class SyncCmrFatTree(
    coordinateX: Int = 0,
    coordinateY: Int = 0,
    scale: NoCScaleConfig = NoCScaleConfig.thinTree64
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

/** Wrapper-compatible 64-core Thin sync quadtree.  Module name stays
  * `SyncNoC_64nodes` so the clocked TB/adapter can bind without colliding
  * with the async `NoC_64nodes` netlists.
  */
class SyncCmrFatTreeNoC64(
    scale: NoCScaleConfig = NoCScaleConfig.thinTree64
) extends Module {
  override def desiredName: String = "SyncNoC_64nodes"

  require(scale.coresPerQuad == 64)
  require((scale.channels.l1.childLanes, scale.channels.l1.parentLanes) == (1, 1),
    s"Sync Thin L1 must be (1,1), got (${scale.channels.l1.childLanes},${scale.channels.l1.parentLanes})")
  require((scale.channels.l2.childLanes, scale.channels.l2.parentLanes) == (1, 1),
    s"Sync Thin L2 must be (1,1), got (${scale.channels.l2.childLanes},${scale.channels.l2.parentLanes})")
  require((scale.channels.l3.childLanes, scale.channels.l3.parentLanes) == (1, 1),
    s"Sync Thin L3 must be (1,1), got (${scale.channels.l3.childLanes},${scale.channels.l3.parentLanes})")
  require(scale.channels.l3.parentLanes == 1,
    s"Sync Thin NoC64 top lanes must be 1, got ${scale.channels.l3.parentLanes}")

  val io = IO(new Bundle {
    val core_inputs = Vec(64, new SyncVrPacket)
    val core_outputs = Flipped(Vec(64, new SyncVrPacket))
    val top_input = Vec(1, new SyncVrPacket)
    val top_output = Flipped(Vec(1, new SyncVrPacket))
  })

  private val tree = Module(new SyncCmrFatTree(
    coordinateX = 0,
    coordinateY = 0,
    scale = scale
  ))

  io <> tree.io
}

object SyncCmrFatTreeNoC64Main extends App {
  emitVerilog(
    new SyncCmrFatTreeNoC64(NoCScaleConfig.thinTree64),
    Array("--target-dir", "generated_sync_cmr/fat_tree_noc64_thin")
  )
}

/** Fat 1-2-2-2 clocked 64-core tree.  Same `SyncNoC_64nodes` module name as
  * Thin; emit directory and TB `TOP_LANES=2` keep the netlists apart.
  */
class SyncCmrFatTreeNoC64Fat1222(
    scale: NoCScaleConfig = NoCScaleConfig.syncFatTree64_1222
) extends Module {
  override def desiredName: String = "SyncNoC_64nodes"

  require(scale.coresPerQuad == 64)
  require((scale.channels.l1.childLanes, scale.channels.l1.parentLanes) == (1, 2),
    s"Sync Fat1222 L1 must be (1,2), got (${scale.channels.l1.childLanes},${scale.channels.l1.parentLanes})")
  require((scale.channels.l2.childLanes, scale.channels.l2.parentLanes) == (2, 2),
    s"Sync Fat1222 L2 must be (2,2), got (${scale.channels.l2.childLanes},${scale.channels.l2.parentLanes})")
  require((scale.channels.l3.childLanes, scale.channels.l3.parentLanes) == (2, 2),
    s"Sync Fat1222 L3 must be (2,2), got (${scale.channels.l3.childLanes},${scale.channels.l3.parentLanes})")
  require(scale.channels.l3.parentLanes == 2,
    s"Sync Fat1222 top lanes must be 2, got ${scale.channels.l3.parentLanes}")

  val io = IO(new Bundle {
    val core_inputs = Vec(64, new SyncVrPacket)
    val core_outputs = Flipped(Vec(64, new SyncVrPacket))
    val top_input = Vec(2, new SyncVrPacket)
    val top_output = Flipped(Vec(2, new SyncVrPacket))
  })

  private val tree = Module(new SyncCmrFatTree(
    coordinateX = 0,
    coordinateY = 0,
    scale = scale
  ))

  io <> tree.io
}

object SyncCmrFatTreeNoC64Fat1222Main extends App {
  emitVerilog(
    new SyncCmrFatTreeNoC64Fat1222(NoCScaleConfig.syncFatTree64_1222),
    Array("--target-dir", "generated_sync_cmr/fat_tree_noc64_1222")
  )
}
