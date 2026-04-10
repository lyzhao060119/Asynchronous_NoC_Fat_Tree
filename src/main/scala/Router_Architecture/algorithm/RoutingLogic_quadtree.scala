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
    childMask := VecInit(Seq.fill(4)(false.B)) // downstream to children
    val toParent = WireInit(false.B)

    for (y <- 0 until 8) {
      for (x <- 0 until 8) {
        val inRect =
          (x.U(3.W) >= xLo) && (x.U(3.W) <= xHi) &&
          (y.U(3.W) >= yLo) && (y.U(3.W) <= yHi) //in the target rectangle

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

  private def currentTreeId(router_level: UInt): UInt = {
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

    Cat(treeY, treeX)
  }// identify tree's index

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
  }//router index in the local tree

  def computeRouting(current_Packet: Packet,
                     Packet_valid: Bool,
                     router_level: UInt
                    ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    for (i <- 0 until 5) {
      decision.output_valid(i) := false.B
      decision.output_ports(i) := false.B
      decision.output_packets(i) := DontCare
    } //initialize

    val packetTreeId = current_Packet.flit(PacketLayout.TreeIdHi, PacketLayout.TreeIdLo) //target tree id
    val xMin = current_Packet.flit(PacketLayout.XMinHi, PacketLayout.XMinLo)
    val xMax = current_Packet.flit(PacketLayout.XMaxHi, PacketLayout.XMaxLo)
    val yMin = current_Packet.flit(PacketLayout.YMinHi, PacketLayout.YMinLo)
    val yMax = current_Packet.flit(PacketLayout.YMaxHi, PacketLayout.YMaxLo)

    val thisTreeId = currentTreeId(router_level)
    val sameTree = packetTreeId === thisTreeId
    val (localX, localY) = localRouterCoord(router_level)

    val projectedDir = WireInit(0.U(5.W))
    switch(router_level) {
      is(1.U) {
        projectedDir := projectRectAtLevel(xMin, xMax, yMin, yMax, level = 1, localX, localY)
      }
      is(2.U) {
        projectedDir := projectRectAtLevel(xMin, xMax, yMin, yMax, level = 2, localX, localY)
      }
      is(3.U) {
        projectedDir := projectRectAtLevel(xMin, xMax, yMin, yMax, level = 3, localX, localY)
      }
    }

    val dir = WireInit(0.U(5.W))
    when(Packet_valid) {
      when(sameTree) {
        dir := projectedDir
      }.otherwise {
        dir := "b10000".U // route upward until reaching target tree in top layer
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
