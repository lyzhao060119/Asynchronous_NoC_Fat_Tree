package Router_Architecture.instantiation

import NoC.NoCScaleConfig
import Router_Architecture.core.RouterTop_Module
import chisel3._

/** Default lane counts used by the standalone top-layer mesh router. */
object RouterTop_param {
  private val defaultConfig = NoCScaleConfig.DefaultRouterChannels.top
  val child_lane: Int = defaultConfig.childLanes
  val parent_lane: Int = defaultConfig.parentLanes
}

/** Top-layer mesh router preset. */
class RouterTop(
    x_coordinate: UInt,
    y_coordinate: UInt,
    childLanes: Int = NoCScaleConfig.DefaultRouterChannels.top.childLanes,
    parentLanes: Int = NoCScaleConfig.DefaultRouterChannels.top.parentLanes,
    fifoDepth: Int = NoCScaleConfig.DefaultRouterChannels.top.fifoDepth
) extends
  RouterTop_Module(
    x_coordinate = x_coordinate,
    y_coordinate = y_coordinate,
    childLanes = childLanes,
    parentLanes = parentLanes,
    fifoDepth = fifoDepth
  )

object RouterTop extends App {
  emitVerilog(new RouterTop(0.U, 0.U), Array("--target-dir", "generated"))
}

