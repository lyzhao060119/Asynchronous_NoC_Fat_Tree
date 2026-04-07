package Router_Architecture.instantiation

import Router_Architecture.core.RouterTree_Module
import chisel3._

class RouterL2(x_coordinate: UInt, y_coordinate: UInt)
  extends RouterTree_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    routerLevel = 2,
    childLanes = 2,
    parentLanes = 4,
  )
