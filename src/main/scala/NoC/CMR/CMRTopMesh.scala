package NoC.CMR

import DataStruct.HS_Packet
import Router_Architecture.CMR.{CMRParameters, CMRRouter}
import chisel3._

/**
  * Cluster-level mesh of `CMRRouter` instances with mesh routing.
  *
  * Child 0-3 are W/S/E/N.  Parent is Local toward the Q64 tile at
  * `(x, y)`.  Destination PE coordinates are shifted by `coordShift=3`
  * (8×8 tiles) so the same `RoutingLogic_mesh` oracle walks cluster
  * space.  Mesh2 is `(2,2)` and matches Table I TopMesh2.  Mesh1 is
  * `(1,2)`: one mesh lane, both Q64 top lanes on Local.  Mesh4 would
  * need `(4,2)`, which is not a supported geometry and is not elaborated.
  *
  * Replaces leftover `NoC.TopLayer` / `RouterTop` on the DATE V3 path.
  */
class CMRTopMesh(
    gridX: Int,
    gridY: Int,
    meshLanes: Int = 2,
    localLanes: Int = 2,
    coordShift: Int = 3
) extends Module {
  override def desiredName: String = "CMRTopMesh"

  require(gridX >= 2 && gridX <= 8, s"TopMesh gridX must be 2..8, got $gridX")
  require(gridY >= 2 && gridY <= 8, s"TopMesh gridY must be 2..8, got $gridY")
  require(CMRParameters.SupportedLaneGeometries.contains((meshLanes, localLanes)),
    s"unsupported TopMesh geometry ($meshLanes,$localLanes)")
  require(coordShift == 3, s"Q64 TopMesh uses 8x8 tile shift, got $coordShift")
  require(gridX == gridY, "DATE V3 TopMesh is square")

  private val tiles = gridX * gridY
  val io = IO(new Bundle {
    val local_inputs = Vec(tiles, Vec(localLanes, new HS_Packet))
    val local_outputs = Flipped(Vec(tiles, Vec(localLanes, new HS_Packet)))
  })

  private val routers = Seq.tabulate(gridX, gridY) { (x, y) =>
    val router = Module(new CMRRouter(
      xCoordinate = x,
      yCoordinate = y,
      routerLevel = 1,
      childLanes = meshLanes,
      parentLanes = localLanes,
      useMeshRouting = true,
      meshGridSize = gridX,
      meshCoordShift = coordShift
    ))
    router.suggestName(s"topMesh_${x}_${y}")
    router
  }

  private def tieOffInput(port: HS_Packet): Unit = {
    port.HS.Req := false.B
    port.Data.flit := 0.U
  }

  private def tieOffOutput(port: HS_Packet): Unit = {
    port.HS.Ack := false.B
  }

  private def tileIndex(x: Int, y: Int): Int = x + gridX * y

  for (y <- 0 until gridY; x <- 0 until gridX) {
    val router = routers(x)(y)
    val tile = tileIndex(x, y)
    for (lane <- 0 until localLanes) {
      router.io.inputs.parent(lane) <> io.local_inputs(tile)(lane)
      router.io.outputs.parent(lane) <> io.local_outputs(tile)(lane)
    }

    for (lane <- 0 until meshLanes) {
      if (x < gridX - 1) {
        router.io.outputs.child(2)(lane) <> routers(x + 1)(y).io.inputs.child(0)(lane)
      } else {
        tieOffInput(router.io.inputs.child(2)(lane))
        tieOffOutput(router.io.outputs.child(2)(lane))
      }
      if (x > 0) {
        router.io.outputs.child(0)(lane) <> routers(x - 1)(y).io.inputs.child(2)(lane)
      } else {
        tieOffInput(router.io.inputs.child(0)(lane))
        tieOffOutput(router.io.outputs.child(0)(lane))
      }
      if (y < gridY - 1) {
        router.io.outputs.child(3)(lane) <> routers(x)(y + 1).io.inputs.child(1)(lane)
      } else {
        tieOffInput(router.io.inputs.child(3)(lane))
        tieOffOutput(router.io.outputs.child(3)(lane))
      }
      if (y > 0) {
        router.io.outputs.child(1)(lane) <> routers(x)(y - 1).io.inputs.child(3)(lane)
      } else {
        tieOffInput(router.io.inputs.child(1)(lane))
        tieOffOutput(router.io.outputs.child(1)(lane))
      }
    }
  }
}

object CMRTopMeshMain extends App {
  private val grid = args.headOption.map(_.toInt).getOrElse(2)
  private val meshLanes = args.drop(1).headOption.map(_.toInt).getOrElse(2)
  private val localLanes = args.drop(2).headOption.map(_.toInt).getOrElse(2)
  emitVerilog(
    new CMRTopMesh(grid, grid, meshLanes, localLanes),
    Array("--target-dir", s"generated_cmr/top_mesh_${meshLanes}${localLanes}_g$grid")
  )
}
