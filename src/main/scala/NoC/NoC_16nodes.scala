package NoC

import DataStruct.HS_Packet
import Router_Architecture.instantiation.{RouterL1, RouterL2}
import chisel3._

/** 16-core synchronous-style topology generator for async toggle-handshake NoC. */
class NoC_16nodes(val scale: NoCScaleConfig = NoCScaleConfig.Verification256)
    extends Module {
  private val l1Config = scale.channels.l1
  private val l2Config = scale.channels.l2

  val io = IO(new Bundle {
    val core_inputs = Vec(16, new HS_Packet)
    val core_outputs = Flipped(Vec(16, new HS_Packet))
    val top_input = Vec(l2Config.parentLanes, new HS_Packet)
    val top_output = Flipped(Vec(l2Config.parentLanes, new HS_Packet))
  })

  val routerl1 = Seq.tabulate(2, 2) { (x, y) =>
    Module(
      new RouterL1(
        x_coordinate = x,
        y_coordinate = y,
        childLanes = l1Config.childLanes,
        parentLanes = l1Config.parentLanes,
        fifoDepth = l1Config.fifoDepth
      )
    )
  }
  val routerl2 = Module(
    new RouterL2(
      0,
      0,
      childLanes = l2Config.childLanes,
      parentLanes = l2Config.parentLanes,
      fifoDepth = l2Config.fifoDepth
    )
  )

  for (x <- 0 until 2) {
    for (y <- 0 until 2) {
      for (dir <- 0 until 4) {
        val a = (~dir) & 0x3
        val a1 = (a >> 1) & 0x1
        val a0 = a & 0x1
        for (lane <- 0 until l1Config.childLanes) {
          routerl1(x)(y).io.inputs.child(dir)(lane) <> io.core_inputs(
            2 * x + a1 + 4 * (2 * y + a0)
          )
          routerl1(x)(y).io.outputs.child(dir)(lane) <> io.core_outputs(
            2 * x + a1 + 4 * (2 * y + a0)
          )
        }
      }
    }
  }

  for (dir <- 0 until 4) {
    val a = (~dir) & 0x3
    val a1 = (a >> 1) & 0x1
    val a0 = a & 0x1
    for (lane <- 0 until l2Config.childLanes) {
      routerl2.io.inputs.child(dir)(lane) <> routerl1(a1)(a0).io.outputs
        .parent(lane)
      routerl2.io.outputs.child(dir)(lane) <> routerl1(a1)(a0).io.inputs
        .parent(lane)
    }
  }

  for (lane <- 0 until l2Config.parentLanes) {
    routerl2.io.inputs.parent(lane) <> io.top_input(lane)
    routerl2.io.outputs.parent(lane) <> io.top_output(lane)
  }
}

object NoC_16nodes extends App {
  val options = NoCGenOptions.parse(args, NoCScaleConfig.Verification256)
  println(
    s"NoC_16nodes generated (local=${options.scale.channels.l1.childLanes}, " +
      s"L1->L2=${options.scale.channels.l1.parentLanes}, " +
      s"L2->Top=${options.scale.channels.l2.parentLanes})"
  )
  emitVerilog(
    new NoC_16nodes(options.scale),
    Array("--target-dir", options.targetDir)
  )
}
