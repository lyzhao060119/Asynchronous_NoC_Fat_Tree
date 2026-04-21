package Router_Architecture.instantiation

import NoC.NoCScaleConfig
import Router_Architecture.core.RouterTree_Module
import chisel3._

/** Leaf quadtree router preset. */
class RouterL1(
    x_coordinate: Int,
    y_coordinate: Int,
    childLanes: Int = NoCScaleConfig.DefaultRouterChannels.l1.childLanes,
    parentLanes: Int = NoCScaleConfig.DefaultRouterChannels.l1.parentLanes,
    fifoDepth: Int = NoCScaleConfig.DefaultRouterChannels.l1.fifoDepth
)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 1,
    childLanes = childLanes,
    parentLanes = parentLanes,
    fifoDepth = fifoDepth
  )

object RouterL1 extends App {
    emitVerilog(new RouterL1(0, 0), Array("--target-dir", "generated", "RouterL1"))
}

