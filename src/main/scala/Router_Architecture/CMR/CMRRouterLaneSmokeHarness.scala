package Router_Architecture.CMR

import DataStruct.Packet
import chisel3._

/** Simulation-only boundary harness for exercising the same two requesters
  * against each exact-width parent direction without padding Router RTL. */
class CMRRouterLaneSmokeHarness(
    routerLevel: Int,
    childLanes: Int,
    parentLanes: Int
) extends Module {
  require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
  require(childLanes >= 1 && parentLanes >= 2)

  val io = IO(new Bundle {
    val Reqin = Input(Vec(2, Bool()))
    val Datain = Input(Vec(2, new Packet))
    val Ackout = Output(Vec(2, Bool()))
    val ParentReqout = Output(Vec(8, Bool()))
    val ParentDataout = Output(Vec(8, new Packet))
    val ParentAckin = Input(Vec(8, Bool()))
  })

  private val router = Module(new CMRRouter(
    xCoordinate = 0,
    yCoordinate = 0,
    routerLevel = routerLevel,
    childLanes = childLanes,
    parentLanes = parentLanes
  ))

  // Use lane zero of two different child directions as independent sources.
  for (direction <- 0 until 4; lane <- 0 until childLanes) {
    val input = router.io.inputs.child(direction)(lane)
    if (lane == 0 && direction < 2) {
      input.HS.Req := io.Reqin(direction)
      input.Data := io.Datain(direction)
      io.Ackout(direction) := input.HS.Ack
    } else {
      input.HS.Req := false.B
      input.Data.flit := 0.U
    }
    // The two test packets route upward, so child outputs remain idle.
    router.io.outputs.child(direction)(lane).HS.Ack := false.B
  }

  for (lane <- 0 until parentLanes) {
    router.io.inputs.parent(lane).HS.Req := false.B
    router.io.inputs.parent(lane).Data.flit := 0.U
    io.ParentReqout(lane) := router.io.outputs.parent(lane).HS.Req
    io.ParentDataout(lane) := router.io.outputs.parent(lane).Data
    router.io.outputs.parent(lane).HS.Ack := io.ParentAckin(lane)
  }
  for (lane <- parentLanes until 8) {
    io.ParentReqout(lane) := false.B
    io.ParentDataout(lane).flit := 0.U
  }
}

object CMRRouterLaneSmokeHarnessMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  private val childLanes = args.drop(1).headOption.map(_.toInt).getOrElse(1)
  private val parentLanes = args.drop(2).headOption.map(_.toInt).getOrElse(2)
  emitVerilog(
    new CMRRouterLaneSmokeHarness(routerLevel, childLanes, parentLanes),
    Array("--target-dir", s"generated_cmr/lane_harness_l${routerLevel}")
  )
}
