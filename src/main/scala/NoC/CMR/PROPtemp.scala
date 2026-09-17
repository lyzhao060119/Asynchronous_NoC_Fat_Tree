package NoC.CMR

import DataStruct.HS_Packet
import Router_Architecture.CMR.{CMRParameters, CMRRouter}
import chisel3._

/** One 8x8 B8 tile. Indices q and i encode (x,y) as 2*x+y. */
class PROPtempTile(
    tileX: Int = 0,
    tileY: Int = 0,
    staticParentLaneMapping: Boolean = false
) extends Module {
  require(tileX >= 0 && tileX < 2 && tileY >= 0 && tileY < 2)
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new HS_Packet)
    val core_outputs = Flipped(Vec(64, new HS_Packet))
    val top_input = Vec(16, new HS_Packet)
    val top_output = Flipped(Vec(16, new HS_Packet))
  })

  private def xy(n: Int): (Int, Int) = (n / 2, n % 2)
  private def topIndex(j: Int, k: Int): Int = 4 * j + k

  private val l1 = Seq.tabulate(4, 4) { (q, i) =>
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val r = Module(new CMRRouter(4 * tileX + 2 * qx + ix,
      4 * tileY + 2 * qy + iy, 1, 1, 4,
      staticParentLaneMapping = staticParentLaneMapping))
    r.suggestName(s"propL1_q${q}_i${i}")
    r
  }
  private val l2 = Seq.tabulate(4, 4) { (q, k) =>
    val (qx, qy) = xy(q)
    val r = Module(new CMRRouter(2 * tileX + qx, 2 * tileY + qy, 2, 1, 4,
      staticParentLaneMapping = staticParentLaneMapping))
    r.suggestName(s"propL2_q${q}_k${k}")
    r
  }
  private val l3 = Seq.tabulate(4, 4) { (j, k) =>
    val r = Module(new CMRRouter(tileX, tileY, 3, 1, 1))
    r.suggestName(s"propL3_j${j}_k${k}")
    r
  }

  // Match the existing quadtree's child-direction and core ordering.
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

class PROPtemp64(staticParentLaneMapping: Boolean = false) extends Module {
  override def desiredName: String =
    if (staticParentLaneMapping) "PROP_temp64_static4" else "PROP_temp64"
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new HS_Packet)
    val core_outputs = Flipped(Vec(64, new HS_Packet))
    val top_input = Vec(16, new HS_Packet)
    val top_output = Flipped(Vec(16, new HS_Packet))
  })
  private val tile = Module(new PROPtempTile(
    staticParentLaneMapping = staticParentLaneMapping
  ))
  io <> tile.io
}

/** Four B8 tiles joined by eight independent 2x2 Mesh(1,2) planes. */
class PROPtemp256 extends Module {
  override def desiredName: String = "PROP_temp256"
  val io = IO(new Bundle {
    val core_inputs = Vec(256, new HS_Packet)
    val core_outputs = Flipped(Vec(256, new HS_Packet))
  })
  private val tiles = Seq.tabulate(2, 2) { (tx, ty) =>
    val t = Module(new PROPtempTile(tx, ty))
    t.suggestName(s"propTile_${tx}_${ty}")
    t
  }
  private val planes = Seq.tabulate(4, 2) { (j, h) =>
    val m = Module(new CMRTopMesh(2, 2, meshLanes = 1, localLanes = 2))
    m.suggestName(s"propMesh_j${j}_h${h}")
    m
  }
  for (ty <- 0 until 2; tx <- 0 until 2) {
    val t = tiles(tx)(ty)
    val tile = tx + 2 * ty
    for (local <- 0 until 64) {
      val x = local % 8 + 8 * tx
      val y = local / 8 + 8 * ty
      val global = x + 16 * y
      t.io.core_inputs(local) <> io.core_inputs(global)
      t.io.core_outputs(local) <> io.core_outputs(global)
    }
    for (j <- 0 until 4; k <- 0 until 4) {
      val m = planes(j)(k / 2)
      val p = 4 * j + k
      t.io.top_output(p) <> m.io.local_inputs(tile)(k % 2)
      m.io.local_outputs(tile)(k % 2) <> t.io.top_input(p)
    }
  }
}

object PROPtemp64Main extends App {
  require(CMRParameters.TreeRcuMatchedDelayUnitPs == 50 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150,
    "PROP_temp emission requires Tree RCU DEL050 and Mesh RCU DEL150")
  emitVerilog(new PROPtemp64, Array("--target-dir", "generated_cmr/prop_temp64"))
}

/** Emit the topology-matched Static4 ablation; no synthesis is implied. */
object PROPtemp64Static4Main extends App {
  require(CMRParameters.TreeRcuMatchedDelayUnitPs == 50 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150,
    "PROP_temp Static4 emission requires Tree RCU DEL050 and Mesh RCU DEL150")
  emitVerilog(new PROPtemp64(staticParentLaneMapping = true),
    Array("--target-dir", "generated_cmr/prop_temp64_static4"))
}

object PROPtemp256Main extends App {
  require(CMRParameters.TreeRcuMatchedDelayUnitPs == 50 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150,
    "PROP_temp emission requires Tree RCU DEL050 and Mesh RCU DEL150")
  emitVerilog(new PROPtemp256,
    Array("--target-dir", "generated_cmr/prop_temp256"))
}

/** One 8x8 M16 tile: L1/L2 B8 plus L3(1,4) with 64 top ports.
  *
  * Top port index is `16*j + 4*k + h` so L3(j,k).parent[h] maps cleanly onto
  * MeshPlane[j][h].local[k] in PROP_temp256_m16.
  */
class PROPtempTileM16(tileX: Int = 0, tileY: Int = 0) extends Module {
  require(tileX >= 0 && tileX < 2 && tileY >= 0 && tileY < 2)
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new HS_Packet)
    val core_outputs = Flipped(Vec(64, new HS_Packet))
    val top_input = Vec(64, new HS_Packet)
    val top_output = Flipped(Vec(64, new HS_Packet))
  })

  private def xy(n: Int): (Int, Int) = (n / 2, n % 2)
  private def topIndex(j: Int, k: Int, h: Int): Int = 16 * j + 4 * k + h

  private val l1 = Seq.tabulate(4, 4) { (q, i) =>
    val (qx, qy) = xy(q)
    val (ix, iy) = xy(i)
    val r = Module(new CMRRouter(4 * tileX + 2 * qx + ix,
      4 * tileY + 2 * qy + iy, 1, 1, 4))
    r.suggestName(s"propL1_q${q}_i${i}")
    r
  }
  private val l2 = Seq.tabulate(4, 4) { (q, k) =>
    val (qx, qy) = xy(q)
    val r = Module(new CMRRouter(2 * tileX + qx, 2 * tileY + qy, 2, 1, 4))
    r.suggestName(s"propL2_q${q}_k${k}")
    r
  }
  private val l3 = Seq.tabulate(4, 4) { (j, k) =>
    val r = Module(new CMRRouter(tileX, tileY, 3, 1, 4))
    r.suggestName(s"propL3_j${j}_k${k}")
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

/** Four M16 tiles joined by sixteen independent 2x2 Mesh(1,4) planes.
  *
  * Same-tile Mesh routers do not interconnect across planes.  Across tiles,
  * plane i connects one-to-one (CMRTopMesh NESW).  Wiring:
  *   L3(j,k).parent[h] <-> MeshPlane[j][h].local[k]
  */
class PROPtemp256M16 extends Module {
  override def desiredName: String = "PROP_temp256_m16"
  val io = IO(new Bundle {
    val core_inputs = Vec(256, new HS_Packet)
    val core_outputs = Flipped(Vec(256, new HS_Packet))
  })
  private val tiles = Seq.tabulate(2, 2) { (tx, ty) =>
    val t = Module(new PROPtempTileM16(tx, ty))
    t.suggestName(s"propTile_${tx}_${ty}")
    t
  }
  private val planes = Seq.tabulate(4, 4) { (j, h) =>
    val m = Module(new CMRTopMesh(2, 2, meshLanes = 1, localLanes = 4))
    m.suggestName(s"propMesh_j${j}_h${h}")
    m
  }
  for (ty <- 0 until 2; tx <- 0 until 2) {
    val t = tiles(tx)(ty)
    val tile = tx + 2 * ty
    for (local <- 0 until 64) {
      val x = local % 8 + 8 * tx
      val y = local / 8 + 8 * ty
      val global = x + 16 * y
      t.io.core_inputs(local) <> io.core_inputs(global)
      t.io.core_outputs(local) <> io.core_outputs(global)
    }
    for (j <- 0 until 4; k <- 0 until 4; h <- 0 until 4) {
      val m = planes(j)(h)
      val p = 16 * j + 4 * k + h
      t.io.top_output(p) <> m.io.local_inputs(tile)(k)
      m.io.local_outputs(tile)(k) <> t.io.top_input(p)
    }
  }
}

object PROPtemp256M16Main extends App {
  require(CMRParameters.RcuMatchedDelaySteps == 1 &&
    CMRParameters.TreeRcuMatchedDelayUnitPs == 100 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150,
    "PROP_temp256_m16 emission requires Tree RCU DEL100 and Mesh RCU DEL150")
  emitVerilog(new PROPtemp256M16,
    Array("--target-dir", "generated_cmr/prop_temp256_m16"))
}
