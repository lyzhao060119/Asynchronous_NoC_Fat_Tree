package NoC.CMR

import DataStruct.HS_Packet
import Router_Architecture.CMR.{CMRParameters, CMRRouter}
import chisel3._

/**
  * 8x8 asynchronous CMR mesh of 64 cores.
  *
  * Each router is `CMRRouter(x, y, level=1)` with constructor
  * `useMeshRouting=true`.  Child 0-3 are W/S/E/N; parent is Local to the
  * PE at physical port `x + n*y`.  There is no top port.  Default lane
  * geometry is (1,1); extra lanes are wired neighbor-to-neighbor and do
  * not block the first GLS.
  */
class CMRMeshNoC(
    n: Int = 8,
    childLanes: Int = 1,
    parentLanes: Int = 1
) extends Module {
  override def desiredName: String = "CMRMeshNoC"

  require(n == 8, s"paper DUT is 8x8 / 64 cores, got n=$n")
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)),
    s"unsupported mesh geometry ($childLanes,$parentLanes)")

  private val coreCount = n * n
  val io = IO(new Bundle {
    val core_inputs = Vec(coreCount, new HS_Packet)
    val core_outputs = Flipped(Vec(coreCount, new HS_Packet))
  })

  private val routers = Seq.tabulate(n, n) { (x, y) =>
    val router = Module(new CMRRouter(
      xCoordinate = x,
      yCoordinate = y,
      routerLevel = 1,
      childLanes = childLanes,
      parentLanes = parentLanes,
      useMeshRouting = true,
      meshGridSize = n
    ))
    router.suggestName(s"meshR_${x}_${y}")
    router
  }

  private def tieOffInput(port: HS_Packet): Unit = {
    port.HS.Req := false.B
    port.Data.flit := 0.U
  }

  private def tieOffOutput(port: HS_Packet): Unit = {
    port.HS.Ack := false.B
  }

  for (y <- 0 until n; x <- 0 until n) {
    val router = routers(x)(y)
    val core = x + n * y
    router.io.inputs.parent(0) <> io.core_inputs(core)
    router.io.outputs.parent(0) <> io.core_outputs(core)
    for (lane <- 1 until parentLanes) {
      tieOffInput(router.io.inputs.parent(lane))
      tieOffOutput(router.io.outputs.parent(lane))
    }

    for (lane <- 0 until childLanes) {
      if (x < n - 1) {
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
      if (y < n - 1) {
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

object CMRMeshNoCMain extends App {
  private val childLanes = args.headOption.map(_.toInt).getOrElse(1)
  private val parentLanes = args.drop(1).headOption.map(_.toInt).getOrElse(1)
  emitVerilog(
    new CMRMeshNoC(n = 8, childLanes = childLanes, parentLanes = parentLanes),
    Array("--target-dir", "generated_cmr/mesh_noc64_11")
  )
}
