package NoC.CMR

import Router_Architecture.algorithm.{
  RoutingLogicL1Fast,
  RoutingLogicL2Fast,
  RoutingLogicL3Fast,
  RoutingLogicMeshModel
}

/** Cycle-accurate-enough route oracle for DATE V3 Q64 / TopMesh / FM DUTs.
  *
  * Walks direction-level masks from the Scala twins of `RoutingLogic` and
  * `RoutingLogic_mesh`.  Lane multiplicity is not part of the mask: TopMesh2
  * and Mesh1 share the same 5-bit direction oracle.
  */
object CMRNetworkRouteOracle {
  val DirWest = 0
  val DirSouth = 1
  val DirEast = 2
  val DirNorth = 3
  val DirParent = 4
  val TileEdge = 8
  val CoordShift = 3
  val MaxHops = 64

  final case class Delivery(
      destinations: Set[(Int, Int)],
      hops: Int,
      treeHops: Int,
      meshHops: Int,
      duplicate: Boolean,
      loss: Boolean,
      cycle: Boolean,
      path: Seq[String]
  )

  def opposite(dir: Int): Int = dir match {
    case DirWest => DirEast
    case DirEast => DirWest
    case DirSouth => DirNorth
    case DirNorth => DirSouth
    case _ => dir
  }

  def coreDir(x: Int, y: Int): Int = {
    val oddX = (x & 1) != 0
    val oddY = (y & 1) != 0
    if (oddX && oddY) 0
    else if (oddX && !oddY) 1
    else if (!oddX && oddY) 2
    else 3
  }

  def coreAt(l1x: Int, l1y: Int, dir: Int): (Int, Int) = {
    val gx0 = l1x * 2
    val gy0 = l1y * 2
    dir match {
      case 0 => (gx0 + 1, gy0 + 1)
      case 1 => (gx0 + 1, gy0)
      case 2 => (gx0, gy0 + 1)
      case 3 => (gx0, gy0)
      case _ => throw new IllegalArgumentException(s"not a child dir: $dir")
    }
  }

  def l1Coord(x: Int, y: Int): (Int, Int) = (x >> 1, y >> 1)

  def parentChildDir(childX: Int, childY: Int): Int = {
    val selector = ((childX & 1) << 1) | (childY & 1)
    (~selector) & 0x3
  }

  def l2ChildL1(l2x: Int, l2y: Int, dir: Int): (Int, Int) = {
    val selector = (~dir) & 0x3
    val cx = 2 * l2x + ((selector >> 1) & 1)
    val cy = 2 * l2y + (selector & 1)
    (cx, cy)
  }

  def l3ChildL2(l3x: Int, l3y: Int, dir: Int): (Int, Int) = {
    val selector = (~dir) & 0x3
    val cx = 2 * l3x + ((selector >> 1) & 1)
    val cy = 2 * l3y + (selector & 1)
    (cx, cy)
  }

  private def bits(mask: Int): Seq[Int] =
    (0 until 5).filter(bit => ((mask >> bit) & 1) != 0)

  def deliver(
      sx: Int,
      sy: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      clusterGrid: Int,
      excludeSource: Boolean = true
  ): Delivery = {
    require(clusterGrid >= 1 && clusterGrid <= 4)
    val width = clusterGrid * TileEdge
    require(sx >= 0 && sx < width && sy >= 0 && sy < width)

    val expected = (for {
      y <- math.min(y0, y1) to math.max(y0, y1)
      x <- math.min(x0, x1) to math.max(x0, x1)
      if x >= 0 && x < width && y >= 0 && y < width
      if !excludeSource || x != sx || y != sy
    } yield (x, y)).toSet

    var delivered = Set.empty[(Int, Int)]
    var duplicate = false
    var cycle = false
    var treeHops = 0
    var meshHops = 0
    val path = scala.collection.mutable.ArrayBuffer.empty[String]
    val visited = scala.collection.mutable.Set.empty[(String, Int, Int, Int)]
    val queue = scala.collection.mutable.Queue.empty[(String, Int, Int, Int, Int)]

    val (l1x, l1y) = l1Coord(sx, sy)
    queue.enqueue(("L1", l1x, l1y, coreDir(sx, sy), 0))

    def push(kind: String, x: Int, y: Int, ingress: Int, hops: Int): Unit = {
      val key = (kind, x, y, ingress)
      if (hops >= MaxHops) {
        cycle = true
      } else if (!visited.contains(key)) {
        visited += key
        queue.enqueue((kind, x, y, ingress, hops))
      }
    }

    visited += (("L1", l1x, l1y, coreDir(sx, sy)))

    while (queue.nonEmpty) {
      val (kind, rx, ry, ingress, hops) = queue.dequeue()
      path += s"$kind($rx,$ry)<-$ingress"
      kind match {
        case "L1" =>
          treeHops = math.max(treeHops, hops + 1)
          val mask = RoutingLogicL1Fast.mask(rx, ry, ingress, x0, y0, x1, y1, packetValid = true)
          for (dir <- bits(mask) if dir != ingress) {
            if (dir == DirParent) {
              push("L2", rx >> 1, ry >> 1, parentChildDir(rx, ry), hops + 1)
            } else {
              val (cx, cy) = coreAt(rx, ry, dir)
              if (delivered.contains((cx, cy))) duplicate = true
              delivered += ((cx, cy))
            }
          }
        case "L2" =>
          treeHops = math.max(treeHops, hops + 1)
          val mask = RoutingLogicL2Fast.mask(rx, ry, ingress, x0, y0, x1, y1, packetValid = true)
          for (dir <- bits(mask) if dir != ingress) {
            if (dir == DirParent) {
              push("L3", rx >> 1, ry >> 1, parentChildDir(rx, ry), hops + 1)
            } else {
              val (cx, cy) = l2ChildL1(rx, ry, dir)
              push("L1", cx, cy, DirParent, hops + 1)
            }
          }
        case "L3" =>
          treeHops = math.max(treeHops, hops + 1)
          val mask = RoutingLogicL3Fast.mask(rx, ry, ingress, x0, y0, x1, y1, packetValid = true)
          for (dir <- bits(mask) if dir != ingress) {
            if (dir == DirParent) {
              if (clusterGrid == 1) {
                // Single-tile DUT: parent is a dangling top port.  A dest
                // inside the tile must not request it.
              } else {
                push("MESH", rx, ry, DirParent, hops + 1)
              }
            } else {
              val (cx, cy) = l3ChildL2(rx, ry, dir)
              push("L2", cx, cy, DirParent, hops + 1)
            }
          }
        case "MESH" =>
          meshHops = math.max(meshHops, hops + 1)
          val mask = RoutingLogicMeshModel.routeMask(
            rx, ry, clusterGrid, ingress, x0, y0, x1, y1, packetValid = true, coordShift = CoordShift
          )
          for (dir <- bits(mask) if dir != ingress) {
            if (dir == DirParent) {
              push("L3", rx, ry, DirParent, hops + 1)
            } else {
              val (nx, ny) = dir match {
                case DirWest => (rx - 1, ry)
                case DirEast => (rx + 1, ry)
                case DirSouth => (rx, ry - 1)
                case DirNorth => (rx, ry + 1)
              }
              if (nx >= 0 && nx < clusterGrid && ny >= 0 && ny < clusterGrid) {
                push("MESH", nx, ny, opposite(dir), hops + 1)
              }
            }
          }
        case other =>
          throw new IllegalArgumentException(other)
      }
    }

    val loss = expected.exists(pe => !delivered.contains(pe))
    val extra = delivered.exists(pe => !expected.contains(pe))
    Delivery(
      destinations = delivered,
      hops = treeHops + meshHops,
      treeHops = treeHops,
      meshHops = meshHops,
      duplicate = duplicate,
      loss = loss || extra,
      cycle = cycle,
      path = path.toSeq
    )
  }

  def deliverUnicast(sx: Int, sy: Int, dx: Int, dy: Int, clusterGrid: Int): Delivery =
    deliver(sx, sy, dx, dy, dx, dy, clusterGrid)

  def deliverFlatMesh(sx: Int, sy: Int, dx: Int, dy: Int, n: Int): Delivery = {
    require(n >= 2 && n <= 32)
    val expected = Set((dx, dy))
    var delivered = Set.empty[(Int, Int)]
    var duplicate = false
    var cycle = false
    val visited = scala.collection.mutable.Set.empty[(Int, Int, Int)]
    val queue = scala.collection.mutable.Queue.empty[(Int, Int, Int, Int)]
    queue.enqueue((sx, sy, DirParent, 0))
    visited += ((sx, sy, DirParent))
    var hops = 0
    val path = scala.collection.mutable.ArrayBuffer.empty[String]
    while (queue.nonEmpty) {
      val (cx, cy, ingress, hop) = queue.dequeue()
      hops = math.max(hops, hop)
      path += s"FM($cx,$cy)<-$ingress"
      val mask = RoutingLogicMeshModel.routeMask(
        cx, cy, n, ingress, dx, dy, dx, dy, packetValid = true, coordShift = 0
      )
      for (dir <- bits(mask) if dir != ingress) {
        if (dir == DirParent) {
          if (delivered.contains((cx, cy))) duplicate = true
          delivered += ((cx, cy))
        } else {
          val (nx, ny) = dir match {
            case DirWest => (cx - 1, cy)
            case DirEast => (cx + 1, cy)
            case DirSouth => (cx, cy - 1)
            case DirNorth => (cx, cy + 1)
          }
          val key = (nx, ny, opposite(dir))
          if (nx < 0 || nx >= n || ny < 0 || ny >= n) {
            cycle = true
          } else if (hop + 1 >= MaxHops) {
            cycle = true
          } else if (!visited.contains(key)) {
            visited += key
            queue.enqueue((nx, ny, opposite(dir), hop + 1))
          }
        }
      }
    }
    Delivery(
      destinations = delivered,
      hops = hops,
      treeHops = 0,
      meshHops = hops,
      duplicate = duplicate,
      loss = delivered != expected,
      cycle = cycle,
      path = path.toSeq
    )
  }
}
