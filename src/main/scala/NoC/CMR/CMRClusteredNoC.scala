package NoC.CMR

import DataStruct.HS_Packet
import NoC.NoCScaleConfig
import Router_Architecture.CMR.CMRParameters
import chisel3._

/**
  * PROP256 / PROP1024: `clusterGrid` × `clusterGrid` Q64 tiles plus a
  * native-branching CMR TopMesh.  Local hierarchy stays 1-2-2-2 (or the
  * supplied Q64 channel profile).  H-REP uses this exact netlist; the
  * boundary split lives in `HrepBoundaryPolicy`, not in the routers.
  *
  * Mesh1/2 only change TopMesh `(meshLanes, localLanes)` and the Q64
  * top-lane map.  Mesh4 is rejected: `(4,2)` is not a supported geometry.
  */
class CMRClusteredNoC(
    clusterGrid: Int,
    q64: NoCScaleConfig = NoCScaleConfig.fatTree64,
    meshLanes: Int = 2,
    bypassInterLevelFifo: Boolean = true
) extends Module {
  private val localLanes = q64.channels.l3.parentLanes
  private val coresPerTile = q64.coresPerQuad
  private val tileEdge = q64.tileEdge
  private val coreWidth = clusterGrid * tileEdge
  private val coreCount = coreWidth * coreWidth

  override def desiredName: String = s"NoC_${coreCount}nodes"

  require(Set(2, 4).contains(clusterGrid),
    s"PROP clustered DUT is 2x2 (256) or 4x4 (1024), got $clusterGrid")
  require(q64.quadNumX == 1 && q64.quadNumY == 1 && coresPerTile == 64)
  require(bypassInterLevelFifo, "DATE V3 clustered DUT bypasses inter-level FIFOs")
  require(CMRParameters.SupportedLaneGeometries.contains((meshLanes, localLanes)),
    s"TopMesh ($meshLanes,$localLanes) is not a supported geometry. " +
      "Mesh4 / (4,2) is not elaborated on the DATE V3 path.")
  require(q64.channels.l1.childLanes == 1)

  val io = IO(new Bundle {
    val core_inputs = Vec(coreCount, new HS_Packet)
    val core_outputs = Flipped(Vec(coreCount, new HS_Packet))
  })

  private val trees = Seq.tabulate(clusterGrid, clusterGrid) { (tx, ty) =>
    val tree = Module(new CMRFatTree(
      coordinateX = tx,
      coordinateY = ty,
      scale = q64,
      bypassInterLevelFifo = bypassInterLevelFifo
    ))
    tree.suggestName(s"q64_${tx}_${ty}")
    tree
  }

  private val topMesh = Module(new CMRTopMesh(
    gridX = clusterGrid,
    gridY = clusterGrid,
    meshLanes = meshLanes,
    localLanes = localLanes
  ))

  private def globalCoreIndex(tx: Int, ty: Int, localIndex: Int): Int = {
    val localX = localIndex % tileEdge
    val localY = localIndex / tileEdge
    val gx = tx * tileEdge + localX
    val gy = ty * tileEdge + localY
    gx + coreWidth * gy
  }

  private def tileIndex(tx: Int, ty: Int): Int = tx + clusterGrid * ty

  for (ty <- 0 until clusterGrid; tx <- 0 until clusterGrid) {
    val tree = trees(tx)(ty)
    val tile = tileIndex(tx, ty)
    for (local <- 0 until coresPerTile) {
      val global = globalCoreIndex(tx, ty, local)
      tree.io.core_inputs(local) <> io.core_inputs(global)
      tree.io.core_outputs(local) <> io.core_outputs(global)
    }
    for (lane <- 0 until localLanes) {
      tree.io.top_output(lane) <> topMesh.io.local_inputs(tile)(lane)
      topMesh.io.local_outputs(tile)(lane) <> tree.io.top_input(lane)
    }
  }
}

object CMRClusteredNoCMain extends App {
  private val grid = args.headOption.map(_.toInt).getOrElse(2)
  private val meshLanes = args.drop(1).headOption.map(_.toInt).getOrElse(2)
  private val q64 = NoCScaleConfig(1, 1, NoCScaleConfig.FatLane1222)
  emitVerilog(
    new CMRClusteredNoC(clusterGrid = grid, q64 = q64, meshLanes = meshLanes),
    Array("--target-dir", s"generated_cmr/clustered_noc_g${grid}_m$meshLanes")
  )
}
