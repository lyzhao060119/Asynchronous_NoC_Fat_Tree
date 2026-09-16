package NoC.CMR

import DataStruct.HS_Packet
import NoC.NoCScaleConfig
import Router_Architecture.CMR.CMRParameters
import chisel3._

/**
  * Paper PFAT256 baseline: four PFAT64 (1-2-4-8) tiles plus an upper Mesh
  * built from the same Mesh(1,2) cell as PROP_temp256.
  *
  * Each PFAT64 tile exposes eight top lanes, so this network uses four
  * independent Mesh(1,2) planes (fully populated). PROP_temp256 uses eight
  * Mesh(1,2) planes because each B8 tile exposes sixteen top ports. Both
  * designs share the Mesh(1,2) microarchitecture; plane count follows the
  * tile top-port width.
  */
class PFATtemp256 extends Module {
  override def desiredName: String = "PFAT_temp256"

  private val q64 = NoCScaleConfig(1, 1, NoCScaleConfig.FatLane1248)
  require(q64.channels.l3.parentLanes == 8)
  require(CMRParameters.TreeRcuMatchedDelayUnitPs == 50 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150)

  val io = IO(new Bundle {
    val core_inputs = Vec(256, new HS_Packet)
    val core_outputs = Flipped(Vec(256, new HS_Packet))
  })

  private val tiles = Seq.tabulate(2, 2) { (tx, ty) =>
    val t = Module(new CMRFatTree(
      coordinateX = tx,
      coordinateY = ty,
      scale = q64,
      bypassInterLevelFifo = true
    ))
    t.suggestName(s"pfatTile_${tx}_${ty}")
    t
  }

  // Four Mesh(1,2) planes: 4 tiles * 2 local lanes = 8 tops per tile.
  private val planes = Seq.tabulate(4) { j =>
    val m = Module(new CMRTopMesh(2, 2, meshLanes = 1, localLanes = 2))
    m.suggestName(s"pfatMesh_j$j")
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
    for (j <- 0 until 4; lane <- 0 until 2) {
      val p = 2 * j + lane
      t.io.top_output(p) <> planes(j).io.local_inputs(tile)(lane)
      planes(j).io.local_outputs(tile)(lane) <> t.io.top_input(p)
    }
  }
}

object PFATtemp256Main extends App {
  require(CMRParameters.TreeRcuMatchedDelayUnitPs == 50 &&
    CMRParameters.MeshRcuMatchedDelayUnitPs == 150,
    "PFAT_temp256 emission requires Tree RCU DEL050 and Mesh RCU DEL150")
  emitVerilog(new PFATtemp256,
    Array("--target-dir", "generated_cmr/pfat_temp256"))
}
