package NoC

import DataStruct._
import Router_Architecture._
import Router_Architecture.instantiation.RouterTop_param
import chisel3._
import chisel3.util._

class quadtree_and_mesh extends Module {
  val quad_num_x = 2
  val quad_num_y = 2
  val quad_num = quad_num_y * quad_num_x
  val io = IO(new Bundle {
    val inputs = Vec(quad_num, Vec(64, new HS_Packet))
    val outputs = Flipped(Vec(quad_num, Vec(64, new HS_Packet)))
    val East_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_y, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val North_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_x, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val West_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_y, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val South_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(quad_num_x, Vec(RouterTop_param.child_lane, new HS_Packet)))

    val East_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_y, Vec(RouterTop_param.child_lane, new HS_Packet))
    val North_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_x, Vec(RouterTop_param.child_lane, new HS_Packet))
    val West_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_y, Vec(RouterTop_param.child_lane,new HS_Packet))
    val South_toPEs: Vec[Vec[HS_Packet]] = Vec(quad_num_x, Vec(RouterTop_param.child_lane, new HS_Packet))
  })

  val quad_tree = Seq.tabulate(quad_num_x, quad_num_y) { (x, y) =>
    Module(new three_level_quadtree(x, y))
  }
  val routers_top = Module(new TopLayer(quad_num_x, quad_num_y))

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

      for (y_1 <- 0 until 8) {
        for (x_1 <- 0 until 8) {
          quad_tree(x)(y).io.core_inputs(x_1 + 8 * y_1) <> io.inputs(x + quad_num_x * y)(x_1 + 8 * y_1)
          quad_tree(x)(y).io.core_outputs(x_1 + 8 * y_1) <> io.outputs(x + quad_num_x * y)(x_1 + 8 * y_1)
        }
      }
    }
  }
}

object quadtree_and_mesh extends App {
  println("Multicast NoC generated")
  emitVerilog(new quadtree_and_mesh, Array("--target-dir", "generated"))
}
