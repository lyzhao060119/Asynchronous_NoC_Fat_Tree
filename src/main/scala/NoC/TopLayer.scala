package NoC

import DataStruct._
import Router_Architecture._
import Router_Architecture.instantiation.RouterTop
import chisel3._

class TopLayer(val scale: NoCScaleConfig = NoCScaleConfig.Paper1024) extends Module {
  def this(gridX: Int, gridY: Int) = this(NoCScaleConfig(gridX, gridY))

  private val gridX = scale.quadNumX
  private val gridY = scale.quadNumY
  private val topConfig = scale.channels.top
  val number_port = scale.quadNum
  val io = IO(new Bundle {
    val inputs = Vec(number_port, Vec(topConfig.parentLanes, new HS_Packet))
    val outputs = Flipped(Vec(number_port, Vec(topConfig.parentLanes, new HS_Packet)))

    val East_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(gridY, Vec(topConfig.childLanes, new HS_Packet)))
    val North_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(gridX, Vec(topConfig.childLanes, new HS_Packet)))
    val West_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(gridY, Vec(topConfig.childLanes, new HS_Packet)))
    val South_fromPEs: Vec[Vec[HS_Packet]] = Flipped(Vec(gridX, Vec(topConfig.childLanes, new HS_Packet)))

    val East_toPEs: Vec[Vec[HS_Packet]] = Vec(gridY, Vec(topConfig.childLanes, new HS_Packet))
    val North_toPEs: Vec[Vec[HS_Packet]] = Vec(gridX, Vec(topConfig.childLanes, new HS_Packet))
    val West_toPEs: Vec[Vec[HS_Packet]] = Vec(gridY, Vec(topConfig.childLanes, new HS_Packet))
    val South_toPEs: Vec[Vec[HS_Packet]] = Vec(gridX, Vec(topConfig.childLanes, new HS_Packet))
  })

  val routers_top = Seq.tabulate(gridX, gridY) { (x, y) =>
    Module(
      new RouterTop(
        x.U,
        y.U,
        childLanes = topConfig.childLanes,
        parentLanes = topConfig.parentLanes,
        fifoDepth = topConfig.fifoDepth
      )
    )
  }

  for (x <- 0 until gridX) {
    routers_top(x)(0).io.inputs.child(1) <> io.South_toPEs(x)
    routers_top(x)(0).io.outputs.child(1) <> io.South_fromPEs(x)
    routers_top(x)(gridY - 1).io.inputs.child(3) <> io.North_toPEs(x)
    routers_top(x)(gridY - 1).io.outputs.child(3) <> io.North_fromPEs(x)
  }

  for (y <- 0 until gridY) {
    routers_top(0)(y).io.inputs.child(0) <> io.West_toPEs(y)
    routers_top(0)(y).io.outputs.child(0) <> io.West_fromPEs(y)
    routers_top(gridX - 1)(y).io.inputs.child(2) <> io.East_toPEs(y)
    routers_top(gridX - 1)(y).io.outputs.child(2) <> io.East_fromPEs(y)
  }
  for (y <- 0 until gridY) {
    for (x <- 0 until gridX) {
      for (i <- 0 until topConfig.childLanes) {
        if (y < gridY - 1) {
          routers_top(x)(y).io.outputs.child(3)(i) <> routers_top(x)(y + 1).io.inputs.child(1)(i)
        }
        if (x < gridX - 1) {
          routers_top(x)(y).io.outputs.child(2)(i) <> routers_top(x + 1)(y).io.inputs.child(0)(i)
        }
        if (y > 0) {
          routers_top(x)(y).io.outputs.child(1)(i) <> routers_top(x)(y - 1).io.inputs.child(3)(i)
        }
        if (x > 0) {
          routers_top(x)(y).io.outputs.child(0)(i) <> routers_top(x - 1)(y).io.inputs.child(2)(i)
        }
      }
      for (j <- 0 until topConfig.parentLanes) {
        routers_top(x)(y).io.outputs.parent(j) <> io.outputs(x + gridX * y)(j)
        routers_top(x)(y).io.inputs.parent(j) <> io.inputs(x + gridX * y)(j)
      }
    }
  }
}

object TopLayer extends App {
  val options = NoCGenOptions.parse(args, NoCScaleConfig.Paper1024)
  emitVerilog(
    new TopLayer(options.scale),
    Array("--target-dir", options.targetDir)
  )
  println(
    s"TopLayer generated (${options.scale.quadNumX}x${options.scale.quadNumY} tiles, " +
      s"meshChild=${options.scale.channels.top.childLanes}, " +
      s"treePorts=${options.scale.channels.top.parentLanes})"
  )
}
