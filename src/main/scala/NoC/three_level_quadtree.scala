package NoC

import DataStruct._
import Router_Architecture._
import Router_Architecture.instantiation.{RouterL1, RouterL2, RouterL3}
import chisel3._

class three_level_quadtree(coordinate_x: Int, coordinate_y: Int) extends Module {
  val io = IO(new Bundle {
    val core_inputs = Vec(64, new HS_Packet)
    val core_outputs = Flipped(Vec(64, new HS_Packet))
    val top_input = Vec(8, new HS_Packet)
    val top_output = Flipped(Vec(8, new HS_Packet))
  })
  val routers_L1 = Seq.tabulate(4, 4) { (x, y) =>
    val actual_x = x + coordinate_x * 4
    val actual_y = y + coordinate_y * 4
    Module(new RouterL1(actual_x.U, actual_y.U))
  }
  val routers_L2 = Seq.tabulate(2, 2) { (x, y) =>
    val actual_x = x + coordinate_x * 2
    val actual_y = y + coordinate_y * 2
    Module(new RouterL2(actual_x.U, actual_y.U))
  }
  val routers_L3 = Module(new RouterL3(coordinate_x.U, coordinate_y.U))

  for (y <- 0 until 4) {
    for (x <- 0 until 4) {
      routers_L1(x)(y).io.inputs.child(3)(0) <> io.core_inputs(2 * x + 2 * y * 8)
      routers_L1(x)(y).io.inputs.child(2)(0) <> io.core_inputs(2 * x + (2 * y + 1) * 8)
      routers_L1(x)(y).io.inputs.child(1)(0) <> io.core_inputs(2 * x + 1 + 2 * y * 8)
      routers_L1(x)(y).io.inputs.child(0)(0) <> io.core_inputs(2 * x + 1 + (2 * y + 1) * 8)

      routers_L1(x)(y).io.outputs.child(3)(0) <> io.core_outputs(2 * x + 2 * y * 8)
      routers_L1(x)(y).io.outputs.child(2)(0) <> io.core_outputs(2 * x + (2 * y + 1) * 8)
      routers_L1(x)(y).io.outputs.child(1)(0) <> io.core_outputs(2 * x + 1 + 2 * y * 8)
      routers_L1(x)(y).io.outputs.child(0)(0) <> io.core_outputs(2 * x + 1 + (2 * y + 1) * 8)
    }
  }

  for (y <- 0 until 2) {
    for (x <- 0 until 2) {
      for (i <- 0 until 4) {
        val a = (~i) & 0x3
        val a1 = (a >> 1) & 0x1
        val a0 = a & 0x1
        for (j <- 0 until 2) {
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
    for (j <- 0 until 4) {
      routers_L3.io.inputs.child(i)(j) <> routers_L2(a1)(a0).io.outputs.parent(j)
      routers_L3.io.outputs.child(i)(j) <> routers_L2(a1)(a0).io.inputs.parent(j)
    }
  }
  for (i <- 0 until 8) {
    routers_L3.io.outputs.parent(i) <> io.top_output(i)
    routers_L3.io.inputs.parent(i) <> io.top_input(i)
  }
}

object three_level_quadtree extends App {
  println("Multicast NoC generated")
  emitVerilog(new three_level_quadtree(0, 0), Array("--target-dir", "generated"))
}