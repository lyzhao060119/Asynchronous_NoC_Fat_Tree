package Router_Architecture.core

import DataStruct._
import Router_Architecture.algorithm.RoutingLogic
import Router_Architecture.common.RouterModuleConfig
import chisel3._

class RouterTree_Module(
  x_coordinate: UInt,
  y_coordinate: UInt,
  routerLevel: Int,
  childLanes: Int,
  parentLanes: Int,
  fifoDepth: Int = 1,
  isHead_index: Int = 21,
  isTail_index: Int = 20
) extends RouterCoreModule(
      config = RouterModuleConfig(
        childLanes = childLanes,
        parentLanes = parentLanes,
        fifoDepth = fifoDepth,
        isHeadIndex = isHead_index,
        isTailIndex = isTail_index
      ),
      computeHeadRouting = (packet: Packet, inValid: Bool) =>
        new RoutingLogic(x_coordinate, y_coordinate)
          .computeRouting(packet, inValid, routerLevel.U(3.W))
          .output_valid
    )
