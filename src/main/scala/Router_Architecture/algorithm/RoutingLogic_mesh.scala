package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

/**
  * Core-grid XY + rectangle expansion for an 8x8 CMR mesh.
  *
  * Same W/S/E/N/Local numbering as `RoutingLogic_top_layer`.  Flat mesh
  * uses PE coordinates (`coordShift=0`).  Q64 TopMesh uses cluster
  * coordinates (`coordShift=3` so dest PE `x >> 3`).
  */
object RoutingLogicMeshModel {
  val DirWest = 0
  val DirSouth = 1
  val DirEast = 2
  val DirNorth = 3
  val DirLocal = 4

  private def absDiff(a: Int, b: Int): Int = if (a >= b) a - b else b - a

  def routeMask(
      coordinateX: Int,
      coordinateY: Int,
      gridSize: Int,
      ingressDir: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      packetValid: Boolean,
      coordShift: Int = 0
  ): Int = {
    require(gridSize >= 2 && gridSize <= 64)
    require(coordShift >= 0 && coordShift <= 5)
    require(coordinateX >= 0 && coordinateX < gridSize)
    require(coordinateY >= 0 && coordinateY < gridSize)
    require(ingressDir >= 0 && ingressDir <= 4)
    if (!packetValid) return 0

    val xLo = math.min(x0, x1) >> coordShift
    val xHi = math.max(x0, x1) >> coordShift
    val yLo = math.min(y0, y1) >> coordShift
    val yHi = math.max(y0, y1) >> coordShift
    val cx = coordinateX
    val cy = coordinateY
    val inRectColumn = cx >= xLo && cx <= xHi
    val inRectRow = cy >= yLo && cy <= yHi
    val localHit = inRectColumn && inRectRow

    val dLL = absDiff(cx, xLo) + absDiff(cy, yLo)
    val dLH = absDiff(cx, xLo) + absDiff(cy, yHi)
    val dHL = absDiff(cx, xHi) + absDiff(cy, yLo)
    val dHH = absDiff(cx, xHi) + absDiff(cy, yHi)
    val chooseLH = dLH < dLL
    val bestXLeft = xLo
    val bestYLeft = if (chooseLH) yHi else yLo
    val bestDLeft = if (chooseLH) dLH else dLL
    val chooseHH = dHH < dHL
    val bestXRight = xHi
    val bestYRight = if (chooseHH) yHi else yLo
    val bestDRight = if (chooseHH) dHH else dHL
    val chooseRight = bestDRight < bestDLeft
    val targetX = if (chooseRight) bestXRight else bestXLeft
    val targetY = if (chooseRight) bestYRight else bestYLeft

    val eastNeeded = cx < xHi
    val westNeeded = cx > xLo
    val northNeeded = inRectColumn && cy < yHi
    val southNeeded = inRectColumn && cy > yLo

    var goWest = false
    var goSouth = false
    var goEast = false
    var goNorth = false
    var goLocal = false

    if (!localHit) {
      if (cx < targetX) goEast = true
      else if (cx > targetX) goWest = true
      else if (cy < targetY) goNorth = true
      else if (cy > targetY) goSouth = true
    } else {
      if (ingressDir != DirLocal) goLocal = true
      ingressDir match {
        case DirWest =>
          goEast = eastNeeded
          goNorth = northNeeded
          goSouth = southNeeded
        case DirEast =>
          goWest = westNeeded
          goNorth = northNeeded
          goSouth = southNeeded
        case DirNorth =>
          if (cy == yHi) {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goSouth = southNeeded
        case DirSouth =>
          if (cy == yLo) {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goNorth = northNeeded
        case DirLocal =>
          if (cx < xLo) goEast = true
          else if (cx > xHi) goWest = true
          else {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goNorth = northNeeded
          goSouth = southNeeded
        case _ =>
      }
    }

    if (cx == 0) goWest = false
    if (cx == gridSize - 1) goEast = false
    if (cy == 0) goSouth = false
    if (cy == gridSize - 1) goNorth = false

    (if (goWest) 1 << DirWest else 0) |
      (if (goSouth) 1 << DirSouth else 0) |
      (if (goEast) 1 << DirEast else 0) |
      (if (goNorth) 1 << DirNorth else 0) |
      (if (goLocal) 1 << DirLocal else 0)
  }
}

/** Chisel twin of `RoutingLogicMeshModel` for RCU Mat bits. */
class RoutingLogic_mesh(
    coordinate_x: Int,
    coordinate_y: Int,
    gridSize: Int = 8,
    coordShift: Int = 0
) {
  require(gridSize >= 2 && gridSize <= 64)
  require(coordShift >= 0 && coordShift <= 5)
  require(coordinate_x >= 0 && coordinate_x < gridSize)
  require(coordinate_y >= 0 && coordinate_y < gridSize)

  private val DirWest = 0.U(3.W)
  private val DirSouth = 1.U(3.W)
  private val DirEast = 2.U(3.W)
  private val DirNorth = 3.U(3.W)
  private val DirLocal = 4.U(3.W)

  /** 6-bit <= compile-time constant.  Power-of-two-minus-one collapses. */
  private def leU6(a: UInt, c: Int): Bool = {
    require(c >= 0 && c <= 63)
    val aa = a.asTypeOf(UInt(6.W))
    if (c >= 63) true.B
    else if (c == 0) aa === 0.U
    else if (((c + 1) & c) == 0) {
      val k = Integer.numberOfTrailingZeros(c + 1)
      if (k >= 6) true.B else aa(5, k) === 0.U
    } else {
      aa <= c.U(6.W)
    }
  }

  /** 6-bit >= compile-time constant.  Power-of-two bounds collapse to orR. */
  private def geU6(a: UInt, c: Int): Bool = {
    require(c >= 0 && c <= 63)
    val aa = a.asTypeOf(UInt(6.W))
    if (c <= 0) true.B
    else if ((c & (c - 1)) == 0) {
      val k = Integer.numberOfTrailingZeros(c)
      aa(5, k).orR
    } else {
      aa >= c.U(6.W)
    }
  }

  /** True if compile-time c lies in the unordered interval [a, b]. */
  private def inIntervalU6(a: UInt, b: UInt, c: Int): Bool = {
    val bothBelow =
      if (c <= 0) false.B else leU6(a, c - 1) && leU6(b, c - 1)
    val bothAbove =
      if (c >= 63) false.B else geU6(a, c + 1) && geU6(b, c + 1)
    !(bothBelow || bothAbove)
  }

  /**
    * True iff the unordered pair is strictly closer to the high endpoint.
    * `|c-max| < |c-min|` iff `a+b < 2c`.  Sum is commutative, so `a`/`b`
    * need not be ordered; adding them in parallel with min/max avoids
    * sitting the 7-bit adder behind the compare-mux.
    */
  private def closerHiU6(a: UInt, b: UInt, c: Int): Bool = {
    (a +& b) < (2 * c).U(7.W)
  }

  def routeMask(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      ingressDir: UInt
  ): UInt = {
    def shifted(raw: UInt): UInt = {
      val bits = raw.asTypeOf(UInt(6.W))
      if (coordShift == 0) bits else (bits >> coordShift).asTypeOf(UInt(6.W))
    }
    val xs0 = shifted(x0)
    val xs1 = shifted(x1)
    val ys0 = shifted(y0)
    val ys1 = shifted(y1)

    val cx = coordinate_x
    val cy = coordinate_y

    // Unordered vs compile-time c: no 6-bit min/max on the Mat cone.
    val ltMaxX = !(leU6(xs0, cx) && leU6(xs1, cx))
    val gtMinX = !(geU6(xs0, cx) && geU6(xs1, cx))
    val ltMinX =
      if (cx >= 63) false.B else geU6(xs0, cx + 1) && geU6(xs1, cx + 1)
    val gtMaxX =
      if (cx <= 0) false.B else leU6(xs0, cx - 1) && leU6(xs1, cx - 1)
    val ltMaxY = !(leU6(ys0, cy) && leU6(ys1, cy))
    val gtMinY = !(geU6(ys0, cy) && geU6(ys1, cy))
    val ltMinY =
      if (cy >= 63) false.B else geU6(ys0, cy + 1) && geU6(ys1, cy + 1)
    val gtMaxY =
      if (cy <= 0) false.B else leU6(ys0, cy - 1) && leU6(ys1, cy - 1)

    val inRectColumn = !(gtMaxX || ltMinX)
    val inRectRow = !(gtMaxY || ltMinY)
    val localHit = inRectColumn && inRectRow

    // closerHi is a+b<2c (parallel with the compares).  Walk flags are
    // 1-bit muxes of those compares, not (cx < Mux(min,max)).
    val closerXHi = closerHiU6(xs0, xs1, cx)
    val closerYHi = closerHiU6(ys0, ys1, cy)
    val xyEast = Mux(closerXHi, ltMaxX, ltMinX)
    val xyWest = Mux(closerXHi, gtMaxX, gtMinX)
    val atTargetX = !(xyEast || xyWest)
    val xyNorth = atTargetX && Mux(closerYHi, ltMaxY, ltMinY)
    val xySouth = atTargetX && Mux(closerYHi, gtMaxY, gtMinY)

    val eastNeeded = ltMaxX
    val westNeeded = gtMinX
    val northNeeded = inRectColumn && ltMaxY
    val southNeeded = inRectColumn && gtMinY
    val atMaxY = !(ltMaxY || gtMaxY)
    val atMinY = !(ltMinY || gtMinY)

    val expandWest = WireInit(false.B)
    val expandSouth = WireInit(false.B)
    val expandEast = WireInit(false.B)
    val expandNorth = WireInit(false.B)
    switch(ingressDir) {
      is(DirWest) {
        expandEast := eastNeeded
        expandNorth := northNeeded
        expandSouth := southNeeded
      }
      is(DirEast) {
        expandWest := westNeeded
        expandNorth := northNeeded
        expandSouth := southNeeded
      }
      is(DirNorth) {
        expandWest := atMaxY && westNeeded
        expandEast := atMaxY && eastNeeded
        expandSouth := southNeeded
      }
      is(DirSouth) {
        expandWest := atMinY && westNeeded
        expandEast := atMinY && eastNeeded
        expandNorth := northNeeded
      }
      is(DirLocal) {
        expandWest := westNeeded
        expandEast := eastNeeded
        expandNorth := northNeeded
        expandSouth := southNeeded
      }
    }

    val goWest = packetValid && Mux(localHit, expandWest, xyWest)
    val goSouth = packetValid && Mux(localHit, expandSouth, xySouth)
    val goEast = packetValid && Mux(localHit, expandEast, xyEast)
    val goNorth = packetValid && Mux(localHit, expandNorth, xyNorth)
    val goLocal = packetValid && localHit && (ingressDir =/= DirLocal)

    val westOut = if (coordinate_x == 0) false.B else goWest
    val eastOut = if (coordinate_x == gridSize - 1) false.B else goEast
    val southOut = if (coordinate_y == 0) false.B else goSouth
    val northOut = if (coordinate_y == gridSize - 1) false.B else goNorth
    Cat(goLocal, northOut, eastOut, southOut, westOut)
  }

  def computeRouting(
      current_Packet: Packet,
      Packet_valid: Bool,
      ingressDir: UInt
  ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    val x0 = current_Packet.flit(PacketLayout.X0Hi, PacketLayout.X0Lo)
    val y0 = current_Packet.flit(PacketLayout.Y0Hi, PacketLayout.Y0Lo)
    val x1 = current_Packet.flit(PacketLayout.X1Hi, PacketLayout.X1Lo)
    val y1 = current_Packet.flit(PacketLayout.Y1Hi, PacketLayout.Y1Lo)
    val dir = routeMask(x0, y0, x1, y1, Packet_valid, ingressDir)
    for (i <- 0 until 5) {
      decision.output_valid(i) := dir(i)
      decision.output_ports(i) := dir(i)
      decision.output_packets(i) := Mux(dir(i), current_Packet, 0.U.asTypeOf(new Packet))
    }
    decision
  }
}
