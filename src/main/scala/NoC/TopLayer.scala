package NoC

import DataStruct._
import Router_Architecture._
import Router_Architecture.instantiation.{RouterTop, RouterTop_param}
import chisel3._
import chisel3.util._

class TopLayer(Grid_x: Int, Grid_y: Int) extends Module {
  val number_port = Grid_x * Grid_y
  val io = IO(new Bundle {
    val inputs = Vec(number_port, Vec(8, new HS_Packet))
    val outputs = Flipped(Vec(number_port, Vec(8, new HS_Packet)))

    val East_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(Grid_y, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val North_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(Grid_x, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val West_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(Grid_y, Vec(RouterTop_param.child_lane, new HS_Packet)))
    val South_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(Grid_x, Vec(RouterTop_param.child_lane, new HS_Packet)))

    val East_toPEs: Vec[Vec[HS_Packet]] = Vec(Grid_y, Vec(RouterTop_param.child_lane, new HS_Packet))
    val North_toPEs: Vec[Vec[HS_Packet]] = Vec(Grid_x, Vec(RouterTop_param.child_lane, new HS_Packet))
    val West_toPEs: Vec[Vec[HS_Packet]] = Vec(Grid_y, Vec(RouterTop_param.child_lane, new HS_Packet))
    val South_toPEs: Vec[Vec[HS_Packet]] = Vec(Grid_x, Vec(RouterTop_param.child_lane, new HS_Packet))
  })

  val routers_top = Seq.tabulate(Grid_x, Grid_y) { (x, y) =>
    Module(new RouterTop(x.U, y.U))
  }

  for (x <- 0 until Grid_x) {
    routers_top(x)(0).io.inputs.child(1) <> io.South_toPEs(x)
    routers_top(x)(0).io.outputs.child(1) <> io.South_fromPEs(x)
    routers_top(x)(Grid_y - 1).io.inputs.child(3) <> io.North_toPEs(x)
    routers_top(x)(Grid_y - 1).io.outputs.child(3) <> io.North_fromPEs(x)
  }

  for (y <- 0 until Grid_y) {
    routers_top(0)(y).io.inputs.child(0) <> io.West_toPEs(y)
    routers_top(0)(y).io.outputs.child(0) <> io.West_fromPEs(y)
    routers_top(Grid_x - 1)(y).io.inputs.child(2) <> io.East_toPEs(y)
    routers_top(Grid_x - 1)(y).io.outputs.child(2) <> io.East_fromPEs(y)
  }
  for (y <- 0 until Grid_y) {
    for (x <- 0 until Grid_x) {
      for (i <- 0 until RouterTop_param.child_lane) {
        if (y < Grid_y - 1) {
          routers_top(x)(y).io.outputs.child(3)(i) <> routers_top(x)(y + 1).io.inputs.child(1)(i)
        }
        if (x < Grid_x - 1) {
          routers_top(x)(y).io.outputs.child(2)(i) <> routers_top(x + 1)(y).io.inputs.child(0)(i)
        }
        if (y > 0) {
          routers_top(x)(y).io.outputs.child(1)(i) <> routers_top(x)(y - 1).io.inputs.child(3)(i)
        }
        if (x > 0) {
          routers_top(x)(y).io.outputs.child(0)(i) <> routers_top(x - 1)(y).io.inputs.child(2)(i)
        }
      }
      for (j <- 0 until RouterTop_param.parent_lane) {
        routers_top(x)(y).io.outputs.parent(j) <> io.outputs(x + Grid_x * y)(j)
        routers_top(x)(y).io.inputs.parent(j) <> io.inputs(x + Grid_x * y)(j)
      }
    }
  }
}

object TopLayer extends App {
  emitVerilog(new TopLayer(4, 4), Array("--target-dir", "generated"))
  println("Multicast NoC generated")
}