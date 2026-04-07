package Router_Architecture.core

import DataStruct._
import Router_Architecture.algorithm.RoutingLogic_top_layer
import Router_Architecture.common.RouterModuleConfig
import chisel3._

class RouterTop_Module(
  x_coordinate: UInt,
  y_coordinate: UInt,
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
        new RoutingLogic_top_layer(x_coordinate, y_coordinate)
          .computeRouting(packet, inValid)
          .output_valid
    )
