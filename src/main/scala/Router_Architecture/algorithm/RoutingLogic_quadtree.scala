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
  * The logic first clips the global rectangle to the current tree, projects the
  * relevant region onto the current router level, and then decides which child
  * quadrants and/or parent port should receive the packet.
  */
class RoutingLogic(coordinate_x: Int, coordinate_y: Int) {
  private def childDirBit(xSel: Int, ySel: Int): Int = {
    // (x,y)=00 -> child3, 01 -> child2, 10 -> child1, 11 -> child0
    3 - ((xSel << 1) | ySel)
  }

  private def projectRectAtLevel(
      xMin: UInt,
      xMax: UInt,
      yMin: UInt,
      yMax: UInt,
      level: Int,
      localRouterX: UInt,
      localRouterY: UInt
  ): UInt = {
    require(level >= 1 && level <= 3)

    val xLo = Wire(UInt(3.W))
    val xHi = Wire(UInt(3.W))
    val yLo = Wire(UInt(3.W))
    val yHi = Wire(UInt(3.W))

    xLo := Mux(xMin <= xMax, xMin, xMax)
    xHi := Mux(xMin <= xMax, xMax, xMin)
    yLo := Mux(yMin <= yMax, yMin, yMax)
    yHi := Mux(yMin <= yMax, yMax, yMin)

    val projectedDir = Wire(Vec(5, Bool()))

    if (level == 3) {
      projectedDir(3) := (xMin <= 3.U) && (yMin <= 3.U)
      projectedDir(1) := (xMax > 3.U) && (yMin <= 3.U)
      projectedDir(2) := (xMin <= 3.U) && (yMax > 3.U)
      projectedDir(0) := (xMax > 3.U) && (yMax > 3.U)
      projectedDir(4) := false.B
    } else if (level == 2) {
      // L2 routers are indexed globally across the whole NoC, but the clipped
      // rectangle we compare against is always local to the current 8x8 tree.
      // Project each child L1 subtree using the router's local (0..1, 0..1)
      // coordinate inside that tree rather than the absolute router index.
      val baseX = Cat(localRouterX(0), 0.U(2.W))
      val baseY = Cat(localRouterY(0), 0.U(2.W))
      val coords_00_x = baseX
      val coords_00_y = baseY
      val coords_01_x = baseX | 0x2.U
      val coords_01_y = baseY
      val coords_10_x = baseX
      val coords_10_y = baseY | 0x2.U
      val coords_11_x = baseX | 0x2.U
      val coords_11_y = baseY | 0x2.U
      projectedDir(
        3
      ) := ((coords_00_x | 0x1.U) >= xMin) && (coords_00_x <= xMax) && ((coords_00_y | 0x1.U) >= yMin) && (coords_00_y <= yMax)
      projectedDir(
        1
      ) := ((coords_01_x | 0x1.U) >= xMin) && (coords_01_x <= xMax) && ((coords_01_y | 0x1.U) >= yMin) && (coords_01_y <= yMax)
      projectedDir(
        2
      ) := ((coords_10_x | 0x1.U) >= xMin) && (coords_10_x <= xMax) && ((coords_10_y | 0x1.U) >= yMin) && (coords_10_y <= yMax)
      projectedDir(
        0
      ) := ((coords_11_x | 0x1.U) >= xMin) && (coords_11_x <= xMax) && ((coords_11_y | 0x1.U) >= yMin) && (coords_11_y <= yMax)
      projectedDir(
        4
      ) := !((xMin >= coords_00_x) && (xMax <= (coords_01_x | 0x1.U)) && (yMin >= coords_00_y) && (yMax <= (coords_10_y | 0x1.U)))
    } else if (level == 1) {
      // L1 routers are also globally indexed; convert back to the current
      // tree-local 2x2 core window before comparing against local coordinates.
      val baseX = Cat(localRouterX, 0.U(1.W))
      val baseY = Cat(localRouterY, 0.U(1.W))
      val coords_00_x = baseX
      val coords_00_y = baseY
      val coords_01_x = baseX | 0x1.U
      val coords_01_y = baseY
      val coords_10_x = baseX
      val coords_10_y = baseY | 0x1.U
      val coords_11_x = baseX | 0x1.U
      val coords_11_y = baseY | 0x1.U
      projectedDir(
        3
      ) := (coords_00_x >= xMin) && (coords_00_x <= xMax) && (coords_00_y >= yMin) && (coords_00_y <= yMax)
      projectedDir(
        1
      ) := (coords_01_x >= xMin) && (coords_01_x <= xMax) && (coords_01_y >= yMin) && (coords_01_y <= yMax)
      projectedDir(
        2
      ) := (coords_10_x >= xMin) && (coords_10_x <= xMax) && (coords_10_y >= yMin) && (coords_10_y <= yMax)
      projectedDir(
        0
      ) := (coords_11_x >= xMin) && (coords_11_x <= xMax) && (coords_11_y >= yMin) && (coords_11_y <= yMax)
      projectedDir(
        4
      ) := !((xMin >= coords_00_x) && (xMax <= coords_01_x) && (yMin >= coords_00_y) && (yMax <= coords_10_y))
    }
    
    projectedDir.asUInt
  }

  private def currentTreeCoord(router_level: Int): (Int, Int) = {
    require(router_level >= 1 && router_level <= 3)

    router_level match {
      case 1 => ((coordinate_x >> 2) & 0x3, (coordinate_y >> 2) & 0x3)
      case 2 => ((coordinate_x >> 1) & 0x3, (coordinate_y >> 1) & 0x3)
      case 3 => (coordinate_x & 0x3, coordinate_y & 0x3)
    }
  } // identify the enclosing 8x8 tree instance in the top layer

  private def localRouterCoord(router_level: Int): (UInt, UInt) = {
    require(router_level >= 1 && router_level <= 3)

    router_level match {
      case 1 => ((coordinate_x & 0x3).U(2.W), (coordinate_y & 0x3).U(2.W))
      case 2 => ((coordinate_x & 0x1).U(2.W), (coordinate_y & 0x1).U(2.W))
      case 3 => (0.U(2.W), 0.U(2.W))
    }
  } // identify this router's subtree coordinate inside the current tree

  private def localRectInCurrentTree(
      router_level: Int,
      xLoGlobal: UInt,
      xHiGlobal: UInt,
      yLoGlobal: UInt,
      yHiGlobal: UInt
  ): (Bool, Bool, UInt, UInt, UInt, UInt) = {
    val (treeX, treeY) = currentTreeCoord(
      router_level
    ) // identify the current tree id

    val treeBaseX = (treeX << 3).U(6.W)
    val treeBaseY = (treeY << 3).U(6.W)
    val treeMaxX = ((treeX << 3) + 7).U(6.W)
    val treeMaxY = ((treeY << 3) + 7).U(6.W) // bounds of the current 8x8 tree

    val xIntersects = (xHiGlobal >= treeBaseX) && (xLoGlobal <= treeMaxX)
    val yIntersects = (yHiGlobal >= treeBaseY) && (yLoGlobal <= treeMaxY)
    val treeIntersects =
      xIntersects && yIntersects // rectangle overlaps this tree at all
    val treeContainsRect =
      (xLoGlobal >= treeBaseX) && (xHiGlobal <= treeMaxX) &&
        (yLoGlobal >= treeBaseY) && (yHiGlobal <= treeMaxY) // rectangle is fully contained in this tree

    val xLoLocal6 = Wire(UInt(6.W))
    val xHiLocal6 = Wire(UInt(6.W))
    val yLoLocal6 = Wire(UInt(6.W))
    val yHiLocal6 = Wire(UInt(6.W))

    xLoLocal6 := Mux(xLoGlobal > treeBaseX, xLoGlobal - treeBaseX, 0.U)
    yLoLocal6 := Mux(yLoGlobal > treeBaseY, yLoGlobal - treeBaseY, 0.U)
    xHiLocal6 := Mux(xHiGlobal < treeMaxX, xHiGlobal - treeBaseX, 7.U)
    yHiLocal6 := Mux(
      yHiGlobal < treeMaxY,
      yHiGlobal - treeBaseY,
      7.U
    ) // clipped rectangle in local tree coordinates

    (
      treeIntersects,
      treeContainsRect,
      xLoLocal6(2, 0),
      xHiLocal6(2, 0),
      yLoLocal6(2, 0),
      yHiLocal6(2, 0)
    )
  }

  def computeRouting(
      current_Packet: Packet,
      Packet_valid: Bool,
      router_level: Int,
      ingressDir: UInt
  ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    for (i <- 0 until 5) {
      decision.output_valid(i) := false.B
      decision.output_ports(i) := false.B
      decision.output_packets(i) := DontCare
    }

    val x0 = current_Packet.flit(PacketLayout.X0Hi, PacketLayout.X0Lo)
    val y0 = current_Packet.flit(PacketLayout.Y0Hi, PacketLayout.Y0Lo)
    val x1 = current_Packet.flit(PacketLayout.X1Hi, PacketLayout.X1Lo)
    val y1 = current_Packet.flit(PacketLayout.Y1Hi, PacketLayout.Y1Lo)

    val xLoGlobal = Wire(UInt(6.W))
    val xHiGlobal = Wire(UInt(6.W))
    val yLoGlobal = Wire(UInt(6.W))
    val yHiGlobal = Wire(UInt(6.W))
    xLoGlobal := Mux(x0 <= x1, x0, x1)
    xHiGlobal := Mux(x0 <= x1, x1, x0)
    yLoGlobal := Mux(y0 <= y1, y0, y1)
    yHiGlobal := Mux(y0 <= y1, y1, y0)

    val (
      treeIntersects,
      treeContainsRect,
      xMinLocal,
      xMaxLocal,
      yMinLocal,
      yMaxLocal
    ) =
      localRectInCurrentTree(
        router_level,
        xLoGlobal,
        xHiGlobal,
        yLoGlobal,
        yHiGlobal
      )

    val (localX, localY) = localRouterCoord(router_level)

    // projectedDir is the raw child/parent decision before ingress suppression.
    val projectedDir = WireInit(0.U(5.W))
    when(treeIntersects) {
      projectedDir := projectRectAtLevel(
        xMinLocal,
        xMaxLocal,
        yMinLocal,
        yMaxLocal,
        level = router_level,
        localX,
        localY
      )
    }

    val projectedNoBack = Wire(Vec(5, Bool()))
    val bypassIngressSuppress =
      if (router_level == 1) ingressDir =/= 4.U
      else false.B // L1 keeps same-direction local child delivery
    for (i <- 0 until 5) {
      projectedNoBack(i) := projectedDir(i)
      when(!bypassIngressSuppress && (ingressDir === i.U)) {
        projectedNoBack(i) := false.B
      }
    }

    val dir = WireInit(0.U(5.W))
    when(Packet_valid) {
      when(treeIntersects) {
        dir := projectedNoBack.asUInt
        // If the global rectangle is only partially covered by the current subtree,
        // keep a copy moving upward so ancestors can fan out into sibling subtrees
        // or other tiles. Limiting this to the root traps packets whose local slice
        // stays inside the source-side subtree.
        when(!treeContainsRect && (ingressDir =/= 4.U)) {
          dir := projectedNoBack.asUInt | "b10000".U
        }
      }.otherwise {
        // Not this tree: keep going up, except packet coming from parent (drop to avoid bounce).
        when(ingressDir =/= 4.U) {
          dir := "b10000".U
        }.otherwise {
          dir := 0.U
        }
      }
    }

    for (i <- 0 until 5) {
      when(dir(i)) {
        decision.output_packets(i) := current_Packet
        decision.output_ports(i) := true.B
        decision.output_valid(i) := true.B
      }
    }
    decision
  }
}
