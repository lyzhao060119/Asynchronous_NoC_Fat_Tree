package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

/**
  * Core-grid X-first, then per-column Y multicast for a CMR mesh.
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

    val eastNeeded = cx < xHi
    val westNeeded = cx > xLo
    val northNeeded = cy < yHi
    val southNeeded = cy > yLo

    var goWest = false
    var goSouth = false
    var goEast = false
    var goNorth = false
    var goLocal = false

    if (ingressDir != DirLocal && localHit) goLocal = true
    ingressDir match {
      // A packet travelling in X keeps travelling in that same X direction.
      // At every covered column it spawns the required Y branch(es).
      case DirWest =>
        goEast = eastNeeded
        if (inRectColumn) {
          goNorth = northNeeded
          goSouth = southNeeded
        }
      case DirEast =>
        goWest = westNeeded
        if (inRectColumn) {
          goNorth = northNeeded
          goSouth = southNeeded
        }
      // Once a branch enters Y, it never returns to X.
      case DirNorth => goSouth = southNeeded
      case DirSouth => goNorth = northNeeded
      case DirLocal =>
        goWest = westNeeded
        goEast = eastNeeded
        if (inRectColumn) {
          goNorth = northNeeded
          goSouth = southNeeded
        }
      case _ =>
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

    val eastNeeded = ltMaxX
    val westNeeded = gtMinX
    val northNeeded = ltMaxY
    val southNeeded = gtMinY

    val expandWest = WireInit(false.B)
    val expandSouth = WireInit(false.B)
    val expandEast = WireInit(false.B)
    val expandNorth = WireInit(false.B)
    switch(ingressDir) {
      is(DirWest) {
        expandEast := eastNeeded
        expandNorth := inRectColumn && northNeeded
        expandSouth := inRectColumn && southNeeded
      }
      is(DirEast) {
        expandWest := westNeeded
        expandNorth := inRectColumn && northNeeded
        expandSouth := inRectColumn && southNeeded
      }
      is(DirNorth) {
        expandSouth := southNeeded
      }
      is(DirSouth) {
        expandNorth := northNeeded
      }
      is(DirLocal) {
        expandWest := westNeeded
        expandEast := eastNeeded
        expandNorth := inRectColumn && northNeeded
        expandSouth := inRectColumn && southNeeded
      }
    }

    val goWest = packetValid && expandWest
    val goSouth = packetValid && expandSouth
    val goEast = packetValid && expandEast
    val goNorth = packetValid && expandNorth
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
