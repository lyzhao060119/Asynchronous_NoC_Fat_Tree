package Router_Architecture.instantiation

import NoC.NoCScaleConfig
import Router_Architecture.core.RouterTree_Module
import chisel3._

/** Root quadtree router preset. */
class RouterL3(
    x_coordinate: Int,
    y_coordinate: Int,
    childLanes: Int = NoCScaleConfig.DefaultRouterChannels.l3.childLanes,
    parentLanes: Int = NoCScaleConfig.DefaultRouterChannels.l3.parentLanes,
    fifoDepth: Int = NoCScaleConfig.DefaultRouterChannels.l3.fifoDepth
)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 3,
    childLanes = childLanes,
    parentLanes = parentLanes,
    fifoDepth = fifoDepth,
  )
