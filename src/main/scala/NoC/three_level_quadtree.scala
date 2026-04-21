package NoC

import DataStruct._
import Router_Architecture._
import Router_Architecture.instantiation.{RouterL1, RouterL2, RouterL3}
import chisel3._

class three_level_quadtree(
    coordinate_x: Int,
    coordinate_y: Int,
    val scale: NoCScaleConfig = NoCScaleConfig.Verification256
) extends Module {
  def this(coordinate_x: Int, coordinate_y: Int) =
    this(coordinate_x, coordinate_y, NoCScaleConfig.Verification256)

  private val l1Config = scale.channels.l1
  private val l2Config = scale.channels.l2
  private val l3Config = scale.channels.l3

  val io = IO(new Bundle {
    val core_inputs = Vec(scale.coresPerQuad, new HS_Packet)
    val core_outputs = Flipped(Vec(scale.coresPerQuad, new HS_Packet))
    val top_input = Vec(scale.topPortsPerQuad, new HS_Packet)
    val top_output = Flipped(Vec(scale.topPortsPerQuad, new HS_Packet))
  })
  val routers_L1 = Seq.tabulate(scale.leafRouterGridX, scale.leafRouterGridY) { (x, y) =>
    val actual_x = x + coordinate_x * scale.leafRouterGridX
    val actual_y = y + coordinate_y * scale.leafRouterGridY
    Module(
      new RouterL1(
        actual_x,
        actual_y,
        childLanes = l1Config.childLanes,
        parentLanes = l1Config.parentLanes,
        fifoDepth = l1Config.fifoDepth
      )
    )
  }
  val routers_L2 = Seq.tabulate(scale.midRouterGridX, scale.midRouterGridY) { (x, y) =>
    val actual_x = x + coordinate_x * scale.midRouterGridX
    val actual_y = y + coordinate_y * scale.midRouterGridY
    Module(
      new RouterL2(
        actual_x,
        actual_y,
        childLanes = l2Config.childLanes,
        parentLanes = l2Config.parentLanes,
        fifoDepth = l2Config.fifoDepth
      )
    )
  }
  val routers_L3 = Module(
    new RouterL3(
      coordinate_x,
      coordinate_y,
      childLanes = l3Config.childLanes,
      parentLanes = l3Config.parentLanes,
      fifoDepth = l3Config.fifoDepth
    )
  )

  for (y <- 0 until scale.leafRouterGridY) {
    for (x <- 0 until scale.leafRouterGridX) {
      val localX0 = 2 * x
      val localY0 = 2 * y
      for (lane <- 0 until l1Config.childLanes) {
        routers_L1(x)(y).io.inputs.child(3)(lane) <> io.core_inputs(scale.localCoreIndex(localX0, localY0, lane))
        routers_L1(x)(y).io.inputs.child(2)(lane) <> io.core_inputs(scale.localCoreIndex(localX0, localY0 + 1, lane))
        routers_L1(x)(y).io.inputs.child(1)(lane) <> io.core_inputs(scale.localCoreIndex(localX0 + 1, localY0, lane))
        routers_L1(x)(y).io.inputs.child(0)(lane) <> io.core_inputs(scale.localCoreIndex(localX0 + 1, localY0 + 1, lane))

        routers_L1(x)(y).io.outputs.child(3)(lane) <> io.core_outputs(scale.localCoreIndex(localX0, localY0, lane))
        routers_L1(x)(y).io.outputs.child(2)(lane) <> io.core_outputs(scale.localCoreIndex(localX0, localY0 + 1, lane))
        routers_L1(x)(y).io.outputs.child(1)(lane) <> io.core_outputs(scale.localCoreIndex(localX0 + 1, localY0, lane))
        routers_L1(x)(y).io.outputs.child(0)(lane) <> io.core_outputs(scale.localCoreIndex(localX0 + 1, localY0 + 1, lane))
      }
    }
  }

  for (y <- 0 until scale.midRouterGridY) {
    for (x <- 0 until scale.midRouterGridX) {
      for (i <- 0 until 4) {
        val a = (~i) & 0x3
        val a1 = (a >> 1) & 0x1
        val a0 = a & 0x1
        for (j <- 0 until l2Config.childLanes) {
          routers_L2(x)(y).io.inputs.child(i)(j) <> routers_L1(2 * x + a1)(2 * y + a0).io.outputs.parent(j)
          routers_L2(x)(y).io.outputs.child(i)(j) <> routers_L1(2 * x + a1)(2 * y + a0).io.inputs.parent(j)
        }
      }
    }
  }
  for (i <- 0 until 4) {
    val a = (~i) & 0x3
    val a1 = (a >> 1) & 0x1
    val a0 = a & 0x1
    for (j <- 0 until l3Config.childLanes) {
      routers_L3.io.inputs.child(i)(j) <> routers_L2(a1)(a0).io.outputs.parent(j)
      routers_L3.io.outputs.child(i)(j) <> routers_L2(a1)(a0).io.inputs.parent(j)
    }
  }
  for (i <- 0 until l3Config.parentLanes) {
    routers_L3.io.outputs.parent(i) <> io.top_output(i)
    routers_L3.io.inputs.parent(i) <> io.top_input(i)
  }
}

object three_level_quadtree extends App {
  val options = NoCGenOptions.parse(args, NoCScaleConfig.Verification256)
  println(
    s"three_level_quadtree generated (local=${options.scale.channels.l1.childLanes}, " +
      s"L1->L2=${options.scale.channels.l1.parentLanes}, " +
      s"L2->L3=${options.scale.channels.l2.parentLanes}, " +
      s"L3->Top=${options.scale.channels.l3.parentLanes})"
  )
  emitVerilog(
    new three_level_quadtree(0, 0, options.scale),
    Array("--target-dir", options.targetDir)
  )
}
