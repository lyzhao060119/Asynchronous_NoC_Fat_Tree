package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

class RoutingDecision extends Bundle {
  val output_ports = Vec(5, Bool())
  val output_packets = Vec(5, new Packet)
  val output_valid = Vec(5, Bool())
}

class RoutingLogic(coordinate_x: UInt, coordinate_y: UInt) {
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

    val childMask = Wire(Vec(4, Bool()))
    childMask := VecInit(Seq.fill(4)(false.B))
    val toParent = WireInit(false.B)

    for (y <- 0 until 8) {
      for (x <- 0 until 8) {
        val inRect =
          (x.U(3.W) >= xLo) && (x.U(3.W) <= xHi) &&
          (y.U(3.W) >= yLo) && (y.U(3.W) <= yHi)

        val xGroup = (x >> level).U(2.W)
        val yGroup = (y >> level).U(2.W)
        val inSubtree = (xGroup === localRouterX) && (yGroup === localRouterY)

        val xSel = (x >> (level - 1)) & 0x1
        val ySel = (y >> (level - 1)) & 0x1
        val dBit = childDirBit(xSel, ySel)

        when(inRect) {
          when(inSubtree) {
            childMask(dBit) := true.B
          }.otherwise {
            toParent := true.B
          }
        }
      }
    }

    Cat(toParent, childMask.asUInt)
  }

  private def currentTreeCoord(router_level: UInt): (UInt, UInt) = {
    val treeX = WireInit(0.U(2.W))
    val treeY = WireInit(0.U(2.W))

    switch(router_level) {
      is(1.U) {
        treeX := coordinate_x(3, 2)
        treeY := coordinate_y(3, 2)
      }
      is(2.U) {
        treeX := coordinate_x(2, 1)
        treeY := coordinate_y(2, 1)
      }
      is(3.U) {
        treeX := coordinate_x(1, 0)
        treeY := coordinate_y(1, 0)
      }
    }

    (treeX, treeY)
  } // identify tree (0..3, 0..3) in top layer

  private def localRouterCoord(router_level: UInt): (UInt, UInt) = {
    val localX = WireInit(0.U(2.W))
    val localY = WireInit(0.U(2.W))

    switch(router_level) {
      is(1.U) {
        localX := coordinate_x(1, 0)
        localY := coordinate_y(1, 0)
      }
      is(2.U) {
        localX := Cat(0.U(1.W), coordinate_x(0))
        localY := Cat(0.U(1.W), coordinate_y(0))
      }
      is(3.U) {
        localX := 0.U
        localY := 0.U
      }
    }

    (localX, localY)
  } // router index in local tree

  private def localRectInCurrentTree(
    router_level: UInt,
    xLoGlobal: UInt,
    xHiGlobal: UInt,
    yLoGlobal: UInt,
    yHiGlobal: UInt
  ): (Bool, Bool, UInt, UInt, UInt, UInt) = {
    val (treeX, treeY) = currentTreeCoord(router_level)

    val treeBaseX = Cat(0.U(1.W), treeX, 0.U(3.W))
    val treeBaseY = Cat(0.U(1.W), treeY, 0.U(3.W))
    val treeMaxX = Wire(UInt(6.W))
    val treeMaxY = Wire(UInt(6.W))
    treeMaxX := treeBaseX + 7.U
    treeMaxY := treeBaseY + 7.U

    val xIntersects = (xHiGlobal >= treeBaseX) && (xLoGlobal <= treeMaxX)
    val yIntersects = (yHiGlobal >= treeBaseY) && (yLoGlobal <= treeMaxY)
    val treeIntersects = xIntersects && yIntersects
    val treeContainsRect =
      (xLoGlobal >= treeBaseX) && (xHiGlobal <= treeMaxX) &&
      (yLoGlobal >= treeBaseY) && (yHiGlobal <= treeMaxY)

    val xLoLocal6 = Wire(UInt(6.W))
    val xHiLocal6 = Wire(UInt(6.W))
    val yLoLocal6 = Wire(UInt(6.W))
    val yHiLocal6 = Wire(UInt(6.W))

    xLoLocal6 := Mux(xLoGlobal > treeBaseX, xLoGlobal - treeBaseX, 0.U)
    yLoLocal6 := Mux(yLoGlobal > treeBaseY, yLoGlobal - treeBaseY, 0.U)
    xHiLocal6 := Mux(xHiGlobal < treeMaxX, xHiGlobal - treeBaseX, 7.U)
    yHiLocal6 := Mux(yHiGlobal < treeMaxY, yHiGlobal - treeBaseY, 7.U)

    (treeIntersects, treeContainsRect, xLoLocal6(2, 0), xHiLocal6(2, 0), yLoLocal6(2, 0), yHiLocal6(2, 0))
  }

  def computeRouting(current_Packet: Packet,
                     Packet_valid: Bool,
                     router_level: UInt,
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

    val (treeIntersects, treeContainsRect, xMinLocal, xMaxLocal, yMinLocal, yMaxLocal) =
      localRectInCurrentTree(router_level, xLoGlobal, xHiGlobal, yLoGlobal, yHiGlobal)

    val (localX, localY) = localRouterCoord(router_level)

    val projectedDir = WireInit(0.U(5.W))
    when(treeIntersects) {
      switch(router_level) {
        is(1.U) {
          projectedDir := projectRectAtLevel(xMinLocal, xMaxLocal, yMinLocal, yMaxLocal, level = 1, localX, localY)
        }
        is(2.U) {
          projectedDir := projectRectAtLevel(xMinLocal, xMaxLocal, yMinLocal, yMaxLocal, level = 2, localX, localY)
        }
        is(3.U) {
          projectedDir := projectRectAtLevel(xMinLocal, xMaxLocal, yMinLocal, yMaxLocal, level = 3, localX, localY)
        }
      }
    }

    val projectedNoBack = Wire(Vec(5, Bool()))
    val bypassIngressSuppress =
      (router_level === 1.U) && (ingressDir =/= 4.U)
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
        // Only the tree root should duplicate upward for cross-tree multicast.
        when((router_level === 3.U) && !treeContainsRect && (ingressDir =/= 4.U)) {
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
