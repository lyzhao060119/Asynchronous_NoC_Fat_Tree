package Router_Architecture.instantiation

import Router_Architecture.wormhole._
import chisel3._

/** Leaf quadtree preset for the Stage1 no-VC wormhole router. */
class RouterL1WormholeMinimal(
    x_coordinate: Int,
    y_coordinate: Int
) extends RouterWormholeMinimal(
      xCoordinate = x_coordinate,
      yCoordinate = y_coordinate,
      routerLevel = 1
    )

object RouterL1WormholeMinimal extends App {
  emitVerilog(
    new RouterL1WormholeMinimal(0, 0),
    Array("--target-dir", "generated", "RouterL1WormholeMinimal")
  )
}
