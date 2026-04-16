package Router_Architecture.core

import DataStruct._
import Router_Architecture.algorithm.RoutingLogic
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/**
 * Parameterized quadtree router wrapper.
 *
 * L1 keeps same-direction child connectivity so a source core may still
 * receive its own local copy, while upper levels use strict no-U-turn edges.
 */
class RouterTree_Module(
  x_coordinate: UInt,
  y_coordinate: UInt,
  routerLevel: Int,
  childLanes: Int,
  parentLanes: Int,
  fifoDepth: Int = 1,
  isHead_index: Int = PacketLayout.IsHeadIndex,
  isTail_index: Int = PacketLayout.IsTailIndex
) extends RouterCoreModule(
      config = RouterModuleConfig(
        childLanes = childLanes,
        parentLanes = parentLanes,
        fifoDepth = fifoDepth,
        isHeadIndex = isHead_index,
        isTailIndex = isTail_index,
        allowSameDirChild = (routerLevel == 1),
        allowSameDirParent = false
      ),
      computeHeadRouting = (packet: Packet, inValid: Bool, ingressDir: UInt) =>
        new RoutingLogic(x_coordinate, y_coordinate)
          .computeRouting(packet, inValid, routerLevel.U(3.W), ingressDir)
          .output_valid
    )
