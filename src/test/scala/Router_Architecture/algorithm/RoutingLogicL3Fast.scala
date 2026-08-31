package Router_Architecture.algorithm

/** Scala twin of `RoutingLogic.routeMaskL3`. */
object RoutingLogicL3Fast {
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
    val treeX = coordinateX & 0x3
    val treeY = coordinateY & 0x3
    val treeBaseX = treeX << 3
    val treeBaseY = treeY << 3
    val treeMaxX = treeBaseX + 7
    val treeMaxY = treeBaseY + 7
    val midX = treeBaseX + 3
    val midY = treeBaseY + 3
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
      x0 >= treeBaseX && x1 >= treeBaseX && x0 <= treeMaxX && x1 <= treeMaxX &&
        y0 >= treeBaseY && y1 >= treeBaseY && y0 <= treeMaxY && y1 <= treeMaxY
    var bits = 0
    if (childHit(treeBaseX, midX, treeBaseY, midY, 3)) bits |= 1 << 3
    if (childHit(treeBaseX + 4, treeMaxX, treeBaseY, midY, 1)) bits |= 1 << 1
    if (childHit(treeBaseX, midX, treeBaseY + 4, treeMaxY, 2)) bits |= 1 << 2
    if (childHit(treeBaseX + 4, treeMaxX, treeBaseY + 4, treeMaxY, 0)) bits |= 1 << 0
    if (ingressDir != 4 && !contained) bits |= 1 << 4
    if (packetValid) bits else 0
  }
}
