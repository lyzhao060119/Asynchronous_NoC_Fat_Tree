package Router_Architecture.instantiation

import Router_Architecture.wormhole._
import chisel3._

/** Middle-level quadtree preset for the Stage1 no-VC wormhole router. */
class RouterL2WormholeMinimal(
    x_coordinate: Int,
    y_coordinate: Int
) extends RouterWormholeMinimal(
      xCoordinate = x_coordinate,
      yCoordinate = y_coordinate,
      routerLevel = 2
    )

object RouterL2WormholeMinimal extends App {
  emitVerilog(
    new RouterL2WormholeMinimal(0, 0),
    Array("--target-dir", "generated", "RouterL2WormholeMinimal")
  )
}
