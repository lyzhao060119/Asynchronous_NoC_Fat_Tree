package Router_Architecture.instantiation

import Router_Architecture.core.RouterTop_Module
import chisel3._

object RouterTop_param {
  val child_lane = 4
  val parent_lane = 8
}

class RouterTop(x_coordinate: UInt, y_coordinate: UInt) extends
  RouterTop_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    childLanes = RouterTop_param.child_lane,
    parentLanes = RouterTop_param.parent_lane
  )

object RouterTop extends App {
  emitVerilog(new RouterTop(0.U, 0.U), Array("--target-dir", "generated"))
}

