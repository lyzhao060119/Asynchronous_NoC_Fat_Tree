package Router_Architecture.algorithm

/** Scala twin of `RoutingLogic.routeMaskL2`. */
object RoutingLogicL2Fast {
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
    val treeX = (coordinateX >> 1) & 0x3
    val treeY = (coordinateY >> 1) & 0x3
    val localX = coordinateX & 0x1
    val localY = coordinateY & 0x1
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val l2MinX = treeBaseX + (localX << 2)
    val l2MaxX = l2MinX + 3
    val l2MinY = treeBaseY + (localY << 2)
    val l2MaxY = l2MinY + 3
    def overlaps(a: Int, b: Int, cMin: Int, cMax: Int): Boolean = {
      val bothBelow = cMin > 0 && a < cMin && b < cMin
      val bothAbove = cMax < 63 && a > cMax && b > cMax
      !(bothBelow || bothAbove)
    }
    def rectOverlaps(xMin: Int, xMax: Int, yMin: Int, yMax: Int): Boolean =
      overlaps(x0, x1, xMin, xMax) && overlaps(y0, y1, yMin, yMax)
    def childHit(xMin: Int, xMax: Int, yMin: Int, yMax: Int, dir: Int): Boolean =
      rectOverlaps(xMin, xMax, yMin, yMax) && ingressDir != dir
    val contained =
      x0 >= l2MinX && x1 >= l2MinX && x0 <= l2MaxX && x1 <= l2MaxX &&
        y0 >= l2MinY && y1 >= l2MinY && y0 <= l2MaxY && y1 <= l2MaxY
    var bits = 0
    if (childHit(l2MinX, l2MinX + 1, l2MinY, l2MinY + 1, 3)) bits |= 1 << 3
    if (childHit(l2MinX + 2, l2MinX + 3, l2MinY, l2MinY + 1, 1)) bits |= 1 << 1
    if (childHit(l2MinX, l2MinX + 1, l2MinY + 2, l2MinY + 3, 2)) bits |= 1 << 2
    if (childHit(l2MinX + 2, l2MinX + 3, l2MinY + 2, l2MinY + 3, 0)) bits |= 1 << 0
    if (ingressDir != 4 && !contained) bits |= 1 << 4
    if (packetValid) bits else 0
  }
}
