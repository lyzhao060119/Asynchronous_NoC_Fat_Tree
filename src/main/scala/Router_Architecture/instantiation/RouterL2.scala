package Router_Architecture.instantiation

import NoC.NoCScaleConfig
import Router_Architecture.core.RouterTree_Module
import chisel3._

/** Middle-level quadtree router preset. */
class RouterL2(
    x_coordinate: Int,
    y_coordinate: Int,
    childLanes: Int = NoCScaleConfig.DefaultRouterChannels.l2.childLanes,
    parentLanes: Int = NoCScaleConfig.DefaultRouterChannels.l2.parentLanes,
    fifoDepth: Int = NoCScaleConfig.DefaultRouterChannels.l2.fifoDepth
)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 2,
    childLanes = childLanes,
    parentLanes = parentLanes,
    fifoDepth = fifoDepth,
  )
