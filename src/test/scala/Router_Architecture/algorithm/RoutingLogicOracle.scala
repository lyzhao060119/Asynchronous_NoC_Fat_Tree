package Router_Architecture.algorithm

/** Frozen 2026-08-27 copy of `RoutingLogic.computeRouting` before the L1
  * global point-in-rect rewrite.  Bit-accurate unsigned 6-bit / 3-bit
  * arithmetic, including the tree-local subtract clip.  Used only as the
  * equivalence oracle for the L1 fast path.
  */
object RoutingLogicOracle {
  def mask(
      coordinateX: Int,
      coordinateY: Int,
      routerLevel: Int,
      ingressDir: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      packetValid: Boolean
  ): Int = {
    require(routerLevel >= 1 && routerLevel <= 3)
    require(ingressDir >= 0 && ingressDir <= 4)
    val xLo = minU6(x0, x1)
    val xHi = maxU6(x0, x1)
    val yLo = minU6(y0, y1)
    val yHi = maxU6(y0, y1)
    val (treeIntersects, treeContains, xMinLocal, xMaxLocal, yMinLocal, yMaxLocal) =
      localRectInCurrentTree(coordinateX, coordinateY, routerLevel, xLo, xHi, yLo, yHi)
    val (localX, localY) = localRouterCoord(coordinateX, coordinateY, routerLevel)
    val projected =
      if (treeIntersects)
        projectRectAtLevel(
          xMinLocal,
          xMaxLocal,
          yMinLocal,
          yMaxLocal,
          routerLevel,
          localX,
          localY
        )
      else 0
    val bypassIngressSuppress = routerLevel == 1 && ingressDir != 4
    var projectedNoBack = 0
    var bit = 0
    while (bit < 5) {
      val keep = ((projected >> bit) & 1) != 0
      val suppressed = !bypassIngressSuppress && ingressDir == bit
      if (keep && !suppressed) projectedNoBack |= 1 << bit
      bit += 1
    }
    if (!packetValid) 0
    else if (treeIntersects) {
      if (!treeContains && ingressDir != 4) projectedNoBack | 0x10
      else projectedNoBack
    } else if (ingressDir != 4) 0x10
    else 0
  }

  private def u6(value: Int): Int = value & 0x3f

  private def minU6(a: Int, b: Int): Int = {
    val aa = u6(a)
    val bb = u6(b)
    if (aa <= bb) aa else bb
  }

  private def maxU6(a: Int, b: Int): Int = {
    val aa = u6(a)
    val bb = u6(b)
    if (aa <= bb) bb else aa
  }

  private def currentTreeCoord(
      coordinateX: Int,
      coordinateY: Int,
      routerLevel: Int
  ): (Int, Int) =
    routerLevel match {
      case 1 => ((coordinateX >> 2) & 0x3, (coordinateY >> 2) & 0x3)
      case 2 => ((coordinateX >> 1) & 0x3, (coordinateY >> 1) & 0x3)
      case 3 => (coordinateX & 0x3, coordinateY & 0x3)
    }

  private def localRouterCoord(
      coordinateX: Int,
      coordinateY: Int,
      routerLevel: Int
  ): (Int, Int) =
    routerLevel match {
      case 1 => (coordinateX & 0x3, coordinateY & 0x3)
      case 2 => (coordinateX & 0x1, coordinateY & 0x1)
      case 3 => (0, 0)
    }

  private def localRectInCurrentTree(
      coordinateX: Int,
      coordinateY: Int,
      routerLevel: Int,
      xLoGlobal: Int,
      xHiGlobal: Int,
      yLoGlobal: Int,
      yHiGlobal: Int
  ): (Boolean, Boolean, Int, Int, Int, Int) = {
    val (treeX, treeY) = currentTreeCoord(coordinateX, coordinateY, routerLevel)
    val treeBaseX = (treeX << 3) & 0x3f
    val treeBaseY = (treeY << 3) & 0x3f
    val treeMaxX = ((treeX << 3) + 7) & 0x3f
    val treeMaxY = ((treeY << 3) + 7) & 0x3f
    val treeIntersects =
      (xHiGlobal >= treeBaseX) && (xLoGlobal <= treeMaxX) &&
        (yHiGlobal >= treeBaseY) && (yLoGlobal <= treeMaxY)
    val treeContains =
      (xLoGlobal >= treeBaseX) && (xHiGlobal <= treeMaxX) &&
        (yLoGlobal >= treeBaseY) && (yHiGlobal <= treeMaxY)
    val xLoLocal6 =
      if (xLoGlobal > treeBaseX) u6(xLoGlobal - treeBaseX) else 0
    val yLoLocal6 =
      if (yLoGlobal > treeBaseY) u6(yLoGlobal - treeBaseY) else 0
    val xHiLocal6 =
      if (xHiGlobal < treeMaxX) u6(xHiGlobal - treeBaseX) else 7
    val yHiLocal6 =
      if (yHiGlobal < treeMaxY) u6(yHiGlobal - treeBaseY) else 7
    (
      treeIntersects,
      treeContains,
      xLoLocal6 & 7,
      xHiLocal6 & 7,
      yLoLocal6 & 7,
      yHiLocal6 & 7
    )
  }

  private def projectRectAtLevel(
      xMin: Int,
      xMax: Int,
      yMin: Int,
      yMax: Int,
      level: Int,
      localRouterX: Int,
      localRouterY: Int
  ): Int = {
    var projected = 0
    if (level == 3) {
      if ((xMin <= 3) && (yMin <= 3)) projected |= 1 << 3
      if ((xMax > 3) && (yMin <= 3)) projected |= 1 << 1
      if ((xMin <= 3) && (yMax > 3)) projected |= 1 << 2
      if ((xMax > 3) && (yMax > 3)) projected |= 1 << 0
    } else if (level == 2) {
      val baseX = (localRouterX & 1) << 2
      val baseY = (localRouterY & 1) << 2
      val c00x = baseX
      val c00y = baseY
      val c01x = baseX | 2
      val c01y = baseY
      val c10x = baseX
      val c10y = baseY | 2
      val c11x = baseX | 2
      val c11y = baseY | 2
      if (((c00x | 1) >= xMin) && (c00x <= xMax) && ((c00y | 1) >= yMin) && (c00y <= yMax))
        projected |= 1 << 3
      if (((c01x | 1) >= xMin) && (c01x <= xMax) && ((c01y | 1) >= yMin) && (c01y <= yMax))
        projected |= 1 << 1
      if (((c10x | 1) >= xMin) && (c10x <= xMax) && ((c10y | 1) >= yMin) && (c10y <= yMax))
        projected |= 1 << 2
      if (((c11x | 1) >= xMin) && (c11x <= xMax) && ((c11y | 1) >= yMin) && (c11y <= yMax))
        projected |= 1 << 0
      val contained =
        (xMin >= c00x) && (xMax <= (c01x | 1)) && (yMin >= c00y) && (yMax <= (c10y | 1))
      if (!contained) projected |= 1 << 4
    } else {
      val baseX = (localRouterX & 3) << 1
      val baseY = (localRouterY & 3) << 1
      val c00x = baseX
      val c00y = baseY
      val c01x = baseX | 1
      val c01y = baseY
      val c10x = baseX
      val c10y = baseY | 1
      val c11x = baseX | 1
      val c11y = baseY | 1
      if ((c00x >= xMin) && (c00x <= xMax) && (c00y >= yMin) && (c00y <= yMax))
        projected |= 1 << 3
      if ((c01x >= xMin) && (c01x <= xMax) && (c01y >= yMin) && (c01y <= yMax))
        projected |= 1 << 1
      if ((c10x >= xMin) && (c10x <= xMax) && (c10y >= yMin) && (c10y <= yMax))
        projected |= 1 << 2
      if ((c11x >= xMin) && (c11x <= xMax) && (c11y >= yMin) && (c11y <= yMax))
        projected |= 1 << 0
      val contained =
        (xMin >= c00x) && (xMax <= c01x) && (yMin >= c00y) && (yMax <= c10y)
      if (!contained) projected |= 1 << 4
    }
    projected
  }
}
