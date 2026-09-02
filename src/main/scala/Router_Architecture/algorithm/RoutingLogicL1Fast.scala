package Router_Architecture.algorithm

/** Scala twin of `RoutingLogic.routeMaskL1`.  Exhaustive vs the frozen clip
  * oracle; the Chisel DUT is checked on a dense subset of the same vectors.
  */
object RoutingLogicL1Fast {
  def mask(
      coordinateX: Int,
      coordinateY: Int,
      ingressDir: Int,
      x0In: Int,
      y0In: Int,
      x1In: Int,
      y1In: Int,
      packetValid: Boolean
  ): Int = {
    val x0 = x0In & 0x3f
    val y0 = y0In & 0x3f
    val x1 = x1In & 0x3f
    val y1 = y1In & 0x3f
    val treeX = (coordinateX >> 2) & 0x3
    val treeY = (coordinateY >> 2) & 0x3
    val localX = coordinateX & 0x3
    val localY = coordinateY & 0x3
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val l1MinX = treeBaseX + (localX << 1)
    val l1MaxX = l1MinX + 1
    val l1MinY = treeBaseY + (localY << 1)
    val l1MaxY = l1MinY + 1
    def covers(a: Int, b: Int, p: Int): Boolean =
      (a <= p && b >= p) || (b <= p && a >= p)
    def coreHit(gx: Int, gy: Int): Boolean =
      covers(x0, x1, gx) && covers(y0, y1, gy)
    val bypass = ingressDir != 4
    val clippedInL1 =
      x0 >= l1MinX && x1 >= l1MinX &&
        x0 <= l1MaxX && x1 <= l1MaxX &&
        y0 >= l1MinY && y1 >= l1MinY &&
        y0 <= l1MaxY && y1 <= l1MaxY
    var bits = 0
    if (coreHit(l1MinX, l1MinY) && (bypass || ingressDir != 3)) bits |= 1 << 3
    if (coreHit(l1MaxX, l1MinY) && (bypass || ingressDir != 1)) bits |= 1 << 1
    if (coreHit(l1MinX, l1MaxY) && (bypass || ingressDir != 2)) bits |= 1 << 2
    if (coreHit(l1MaxX, l1MaxY) && (bypass || ingressDir != 0)) bits |= 1 << 0
    if (bypass && !clippedInL1) bits |= 1 << 4
    if (packetValid) bits else 0
  }
}
