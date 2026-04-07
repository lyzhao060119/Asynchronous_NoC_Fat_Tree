package Router_Architecture.instantiation

import Router_Architecture.core.RouterTree_Module
import chisel3._

class RouterL1(x_coordinate: UInt, y_coordinate: UInt)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 1,
    childLanes = 1,
    parentLanes = 2,
      fifoDepth = 4
  )

object RouterL1 extends App {
    emitVerilog(new RouterL1(0.U, 0.U), Array("--target-dir", "generated", "RouterL1"))
}

