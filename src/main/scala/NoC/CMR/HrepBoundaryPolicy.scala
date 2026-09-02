package NoC.CMR

/** H-REP cluster-boundary split.  Hardware / netlist stay PROP.
  *
  * One original event whose destinations sit in several Q64 clusters becomes
  * one packet per target cluster.  Each packet keeps `originalEventId` and
  * gets a distinct `packetId`.  Local-cluster destinations never enter the
  * Top Mesh; other clusters are unicast across it, then multicast inside
  * the destination Q64.
  */
object HrepBoundaryPolicy {
  val TileEdge: Int = 8

  final case class Rect(x0: Int, y0: Int, x1: Int, y1: Int) {
    def normalized: Rect = {
      val xa = math.min(x0, x1)
      val xb = math.max(x0, x1)
      val ya = math.min(y0, y1)
      val yb = math.max(y0, y1)
      Rect(xa, ya, xb, yb)
    }

    def cores(width: Int): Seq[Int] = {
      val n = normalized
      for {
        y <- n.y0 to n.y1
        x <- n.x0 to n.x1
      } yield peIndex(x, y, width)
    }
  }

  final case class InjectedPacket(
      originalEventId: String,
      packetId: String,
      source: Int,
      destinations: Seq[Int],
      rect: Rect,
      targetCluster: (Int, Int),
      crossesTopMesh: Boolean
  )

  def peIndex(x: Int, y: Int, width: Int): Int = x + width * y

  def peXY(index: Int, width: Int): (Int, Int) = (index % width, index / width)

  def clusterOf(x: Int, y: Int, tileEdge: Int = TileEdge): (Int, Int) =
    (Math.floorDiv(x, tileEdge), Math.floorDiv(y, tileEdge))

  def clusterOfPe(index: Int, width: Int, tileEdge: Int = TileEdge): (Int, Int) = {
    val (x, y) = peXY(index, width)
    clusterOf(x, y, tileEdge)
  }

  def clusterRect(cluster: (Int, Int), tileEdge: Int = TileEdge): Rect = {
    val (tx, ty) = cluster
    Rect(tx * tileEdge, ty * tileEdge, tx * tileEdge + tileEdge - 1, ty * tileEdge + tileEdge - 1)
  }

  def intersect(a: Rect, b: Rect): Option[Rect] = {
    val an = a.normalized
    val bn = b.normalized
    val x0 = math.max(an.x0, bn.x0)
    val y0 = math.max(an.y0, bn.y0)
    val x1 = math.min(an.x1, bn.x1)
    val y1 = math.min(an.y1, bn.y1)
    if (x0 <= x1 && y0 <= y1) Some(Rect(x0, y0, x1, y1)) else None
  }

  def splitDestSet(
      originalEventId: String,
      source: Int,
      destinations: Seq[Int],
      clusterGrid: Int,
      tileEdge: Int = TileEdge
  ): Seq[InjectedPacket] = {
    val width = clusterGrid * tileEdge
    val srcCluster = clusterOfPe(source, width, tileEdge)
    val unique = destinations.distinct.filter(_ != source).sorted
    unique.groupBy(pe => clusterOfPe(pe, width, tileEdge)).toSeq.sortBy(_._1).zipWithIndex.map {
      case ((cluster, dests), idx) =>
        val xs = dests.map(peXY(_, width)._1)
        val ys = dests.map(peXY(_, width)._2)
        InjectedPacket(
          originalEventId = originalEventId,
          packetId = s"$originalEventId#$idx",
          source = source,
          destinations = dests.sorted,
          rect = Rect(xs.min, ys.min, xs.max, ys.max),
          targetCluster = cluster,
          crossesTopMesh = cluster != srcCluster
        )
    }
  }

  def splitRectangle(
      originalEventId: String,
      source: Int,
      rect: Rect,
      clusterGrid: Int,
      tileEdge: Int = TileEdge
  ): Seq[InjectedPacket] = {
    val width = clusterGrid * tileEdge
    val srcCluster = clusterOfPe(source, width, tileEdge)
    val n = rect.normalized
    val tx0 = n.x0 / tileEdge
    val tx1 = n.x1 / tileEdge
    val ty0 = n.y0 / tileEdge
    val ty1 = n.y1 / tileEdge
    val packets = for {
      ty <- ty0 to ty1
      tx <- tx0 to tx1
      clipped <- intersect(n, clusterRect((tx, ty), tileEdge))
    } yield {
      val dests = clipped.cores(width).filter(_ != source)
      (tx, ty, clipped, dests)
    }
    packets.filter(_._4.nonEmpty).zipWithIndex.map { case ((tx, ty, clipped, dests), idx) =>
      InjectedPacket(
        originalEventId = originalEventId,
        packetId = s"$originalEventId#$idx",
        source = source,
        destinations = dests,
        rect = clipped,
        targetCluster = (tx, ty),
        crossesTopMesh = (tx, ty) != srcCluster
      )
    }
  }

  /** PROP injects the original dest set as a single packet. */
  def propPacket(
      originalEventId: String,
      source: Int,
      destinations: Seq[Int],
      width: Int
  ): InjectedPacket = {
    val dests = destinations.distinct.filter(_ != source).sorted
    require(dests.nonEmpty, "PROP packet needs at least one destination")
    val xs = dests.map(peXY(_, width)._1)
    val ys = dests.map(peXY(_, width)._2)
    InjectedPacket(
      originalEventId = originalEventId,
      packetId = s"$originalEventId#0",
      source = source,
      destinations = dests,
      rect = Rect(xs.min, ys.min, xs.max, ys.max),
      targetCluster = clusterOfPe(dests.head, width),
      crossesTopMesh = dests.exists(d => clusterOfPe(d, width) != clusterOfPe(source, width))
    )
  }
}
