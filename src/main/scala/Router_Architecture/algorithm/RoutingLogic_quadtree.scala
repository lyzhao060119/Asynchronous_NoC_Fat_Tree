package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

/** Direction-and-packet bundle emitted by the quadtree routing logic. */
class RoutingDecision extends Bundle {
  val output_ports = Vec(5, Bool())
  val output_packets = Vec(5, new Packet)
  val output_valid = Vec(5, Bool())
}

/** Computes routing decisions for one quadtree router.
  *
  * All three levels compare the unordered global rectangle against compile-
  * time AABB constants so the Mat cone does not serialize a 6-bit x0-vs-x1
  * sort or a tree-local subtract clip.
  */
class RoutingLogic(coordinate_x: Int, coordinate_y: Int) {
  private def currentTreeCoord(router_level: Int): (Int, Int) = {
    require(router_level >= 1 && router_level <= 3)

    router_level match {
      case 1 => ((coordinate_x >> 2) & 0x3, (coordinate_y >> 2) & 0x3)
      case 2 => ((coordinate_x >> 1) & 0x3, (coordinate_y >> 1) & 0x3)
      case 3 => (coordinate_x & 0x3, (coordinate_y & 0x3))
    }
  }

  /** 6-bit <= compile-time constant without a variable-vs-variable ripple.
    * Power-of-two-minus-one bounds collapse to a high-bit zero test.
    */
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

  /** Unordered 6-bit interval vs compile-time [cMin, cMax]. */
  private def overlapsU6(ax: UInt, bx: UInt, cMin: Int, cMax: Int): Bool = {
    require(cMin >= 0 && cMax >= cMin && cMax <= 63)
    val bothBelow =
      if (cMin <= 0) false.B else !geU6(ax, cMin) && !geU6(bx, cMin)
    val bothAbove =
      if (cMax >= 63) false.B else geU6(ax, cMax + 1) && geU6(bx, cMax + 1)
    !(bothBelow || bothAbove)
  }

  private def rectOverlaps(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      xMin: Int,
      xMax: Int,
      yMin: Int,
      yMax: Int
  ): Bool =
    overlapsU6(x0, x1, xMin, xMax) && overlapsU6(y0, y1, yMin, yMax)

  private def bothInU6(a: UInt, b: UInt, cMin: Int, cMax: Int): Bool =
    geU6(a, cMin) && geU6(b, cMin) && leU6(a, cMax) && leU6(b, cMax)

  /** L1 Mat bits: four core constants vs the unordered rectangle.
    *
    * Covering a core in this L1 already implies tree overlap, and both
    * corners inside this L1 already implies tree containment, so the Mat
    * cone does not mux on treeIntersects / treeContainsRect.  Ingress is a
    * per-RCU constant and folds.
    */
  private def routeMaskL1(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      ingressDir: UInt
  ): UInt = {
    val (treeX, treeY) = currentTreeCoord(1)
    val localX = coordinate_x & 0x3
    val localY = coordinate_y & 0x3
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val l1MinX = treeBaseX + (localX << 1)
    val l1MaxX = l1MinX + 1
    val l1MinY = treeBaseY + (localY << 1)
    val l1MaxY = l1MinY + 1

    def covers(ax: UInt, bx: UInt, p: Int): Bool =
      (leU6(ax, p) && geU6(bx, p)) || (leU6(bx, p) && geU6(ax, p))

    def coreHit(gx: Int, gy: Int): Bool =
      covers(x0, x1, gx) && covers(y0, y1, gy)

    val bypass = ingressDir =/= 4.U
    val clippedInL1 =
      geU6(x0, l1MinX) && geU6(x1, l1MinX) &&
        leU6(x0, l1MaxX) && leU6(x1, l1MaxX) &&
        geU6(y0, l1MinY) && geU6(y1, l1MinY) &&
        leU6(y0, l1MaxY) && leU6(y1, l1MaxY)

    val bits = Wire(Vec(5, Bool()))
    bits(3) := coreHit(l1MinX, l1MinY) && (bypass || (ingressDir =/= 3.U))
    bits(1) := coreHit(l1MaxX, l1MinY) && (bypass || (ingressDir =/= 1.U))
    bits(2) := coreHit(l1MinX, l1MaxY) && (bypass || (ingressDir =/= 2.U))
    bits(0) := coreHit(l1MaxX, l1MaxY) && (bypass || (ingressDir =/= 0.U))
    bits(4) := bypass && !clippedInL1
    Mux(packetValid, bits.asUInt, 0.U(5.W))
  }

  /** L2 Mat: four 2x2 L1 AABBs plus containment in this 4x4.  No ingress
    * u-turn.  Overlapping a child in this tree already implies tree overlap.
    */
  private def routeMaskL2(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      ingressDir: UInt
  ): UInt = {
    val (treeX, treeY) = currentTreeCoord(2)
    val localX = coordinate_x & 0x1
    val localY = coordinate_y & 0x1
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val l2MinX = treeBaseX + (localX << 2)
    val l2MaxX = l2MinX + 3
    val l2MinY = treeBaseY + (localY << 2)
    val l2MaxY = l2MinY + 3

    def childHit(xMin: Int, xMax: Int, yMin: Int, yMax: Int, dir: Int): Bool =
      rectOverlaps(x0, y0, x1, y1, xMin, xMax, yMin, yMax) && (ingressDir =/= dir.U)

    val contained =
      bothInU6(x0, x1, l2MinX, l2MaxX) && bothInU6(y0, y1, l2MinY, l2MaxY)

    val bits = Wire(Vec(5, Bool()))
    bits(3) := childHit(l2MinX, l2MinX + 1, l2MinY, l2MinY + 1, 3)
    bits(1) := childHit(l2MinX + 2, l2MinX + 3, l2MinY, l2MinY + 1, 1)
    bits(2) := childHit(l2MinX, l2MinX + 1, l2MinY + 2, l2MinY + 3, 2)
    bits(0) := childHit(l2MinX + 2, l2MinX + 3, l2MinY + 2, l2MinY + 3, 0)
    bits(4) := (ingressDir =/= 4.U) && !contained
    Mux(packetValid, bits.asUInt, 0.U(5.W))
  }

  /** L3 Mat: four 4x4 quadrants of the current 8x8 tree.  Parent is only
    * "not fully inside this tree".
    */
  private def routeMaskL3(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      ingressDir: UInt
  ): UInt = {
    val (treeX, treeY) = currentTreeCoord(3)
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val treeMaxX = treeBaseX + 7
    val treeMaxY = treeBaseY + 7
    val midX = treeBaseX + 3
    val midY = treeBaseY + 3

    def childHit(xMin: Int, xMax: Int, yMin: Int, yMax: Int, dir: Int): Bool =
      rectOverlaps(x0, y0, x1, y1, xMin, xMax, yMin, yMax) && (ingressDir =/= dir.U)

    val contained =
      bothInU6(x0, x1, treeBaseX, treeMaxX) && bothInU6(y0, y1, treeBaseY, treeMaxY)

    val bits = Wire(Vec(5, Bool()))
    bits(3) := childHit(treeBaseX, midX, treeBaseY, midY, 3)
    bits(1) := childHit(treeBaseX + 4, treeMaxX, treeBaseY, midY, 1)
    bits(2) := childHit(treeBaseX, midX, treeBaseY + 4, treeMaxY, 2)
    bits(0) := childHit(treeBaseX + 4, treeMaxX, treeBaseY + 4, treeMaxY, 0)
    bits(4) := (ingressDir =/= 4.U) && !contained
    Mux(packetValid, bits.asUInt, 0.U(5.W))
  }

  /** Five-bit direction mask, bit i = output_valid(i). */
  def routeMask(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      router_level: Int,
      ingressDir: UInt
  ): UInt = {
    require(router_level >= 1 && router_level <= 3)
    if (router_level == 1)
      routeMaskL1(x0, y0, x1, y1, packetValid, ingressDir)
    else if (router_level == 2)
      routeMaskL2(x0, y0, x1, y1, packetValid, ingressDir)
    else
      routeMaskL3(x0, y0, x1, y1, packetValid, ingressDir)
  }

  def computeRouting(
      current_Packet: Packet,
      Packet_valid: Bool,
      router_level: Int,
      ingressDir: UInt
  ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    val x0 = current_Packet.flit(PacketLayout.X0Hi, PacketLayout.X0Lo)
    val y0 = current_Packet.flit(PacketLayout.Y0Hi, PacketLayout.Y0Lo)
    val x1 = current_Packet.flit(PacketLayout.X1Hi, PacketLayout.X1Lo)
    val y1 = current_Packet.flit(PacketLayout.Y1Hi, PacketLayout.Y1Lo)
    val dir = routeMask(x0, y0, x1, y1, Packet_valid, router_level, ingressDir)
    for (i <- 0 until 5) {
      decision.output_valid(i) := dir(i)
      decision.output_ports(i) := dir(i)
      decision.output_packets(i) := Mux(dir(i), current_Packet, 0.U.asTypeOf(new Packet))
    }
    decision
  }
}
