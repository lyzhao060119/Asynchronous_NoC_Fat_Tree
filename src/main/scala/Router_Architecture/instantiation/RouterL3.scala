package Router_Architecture.instantiation

import Router_Architecture.core.RouterTree_Module
import chisel3._

/** Root quadtree router preset. */
class RouterL3(x_coordinate: UInt, y_coordinate: UInt)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 3,
    childLanes = 4,
    parentLanes = 8,
  )
