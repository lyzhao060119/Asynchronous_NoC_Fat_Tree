package NoC

import DataStruct._
import Router_Architecture._
import chisel3._

class quadtree_and_mesh(
    val scale: NoCScaleConfig = NoCScaleConfig.Verification256
) extends Module {
  def this(quad_num_x: Int, quad_num_y: Int) =
    this(NoCScaleConfig(quad_num_x, quad_num_y))

  val quad_num_x = scale.quadNumX
  val quad_num_y = scale.quadNumY
  val quad_num = scale.quadNum
  private val topConfig = scale.channels.top
  val io = IO(new Bundle {
    val inputs = Vec(quad_num, Vec(scale.coresPerQuad, new HS_Packet))
    val outputs = Flipped(Vec(quad_num, Vec(scale.coresPerQuad, new HS_Packet)))
    val East_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_y, Vec(topConfig.childLanes, new HS_Packet)))
    val North_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_x, Vec(topConfig.childLanes, new HS_Packet)))
    val West_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_y, Vec(topConfig.childLanes, new HS_Packet)))
    val South_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_x, Vec(topConfig.childLanes, new HS_Packet)))

    val East_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_y, Vec(topConfig.childLanes, new HS_Packet))
    val North_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_x, Vec(topConfig.childLanes, new HS_Packet))
    val West_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_y, Vec(topConfig.childLanes,new HS_Packet))
    val South_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_x, Vec(topConfig.childLanes, new HS_Packet))
  })

  val quad_tree = Seq.tabulate(quad_num_x, quad_num_y) { (x, y) =>
    Module(new three_level_quadtree(x, y, scale))
  }
  val routers_top = Module(new TopLayer(scale))

  routers_top.io.East_fromPEs <> io.East_fromPEs
  routers_top.io.North_fromPEs <> io.North_fromPEs
  routers_top.io.West_fromPEs <> io.West_fromPEs
  routers_top.io.South_fromPEs <> io.South_fromPEs
  routers_top.io.East_toPEs <> io.East_toPEs
  routers_top.io.North_toPEs <> io.North_toPEs
  routers_top.io.West_toPEs <> io.West_toPEs
  routers_top.io.South_toPEs <> io.South_toPEs

  for (y <- 0 until quad_num_y) {
    for (x <- 0 until quad_num_x) {
      quad_tree(x)(y).io.top_input <> routers_top.io.outputs(x + quad_num_x * y)
      quad_tree(x)(y).io.top_output <> routers_top.io.inputs(x + quad_num_x * y)

      for (coreIdx <- 0 until scale.coresPerQuad) {
        quad_tree(x)(y).io.core_inputs(coreIdx) <> io.inputs(x + quad_num_x * y)(coreIdx)
        quad_tree(x)(y).io.core_outputs(coreIdx) <> io.outputs(x + quad_num_x * y)(coreIdx)
      }
    }
  }
}

object quadtree_and_mesh extends App {
  val options = NoCGenOptions.parse(args, NoCScaleConfig.Verification256)

  def emitNoCVerilog(): Unit =
    emitVerilog(
      new quadtree_and_mesh(options.scale),
      Array("--target-dir", options.targetDir)
    )

  println(
    s"Multicast NoC generated (${options.scale.quadNumX}x${options.scale.quadNumY} tiles, " +
      s"L1->L2=${options.scale.channels.l1.parentLanes}, " +
      s"L2->L3=${options.scale.channels.l2.parentLanes}, " +
      s"L3->Top=${options.scale.channels.l3.parentLanes}, " +
      s"meshChild=${options.scale.channels.top.childLanes})"
  )
  println(s"Writing Verilog output under ${options.targetDir}")
  emitNoCVerilog()
}
