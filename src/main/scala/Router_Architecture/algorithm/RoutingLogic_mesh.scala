package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

/**
  * Core-grid XY + rectangle expansion for an 8x8 CMR mesh.
  *
  * Same W/S/E/N/Local numbering as `RoutingLogic_top_layer`, but the
  * router coordinate is the core (x, y) itself.  Destination fields are
  * compared in that space; there is no tile `x >> 3` walk.
  */
object RoutingLogicMeshModel {
  val DirWest = 0
  val DirSouth = 1
  val DirEast = 2
  val DirNorth = 3
  val DirLocal = 4

  private def absDiff(a: Int, b: Int): Int = if (a >= b) a - b else b - a

  def routeMask(
      coordinateX: Int,
      coordinateY: Int,
      gridSize: Int,
      ingressDir: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      packetValid: Boolean
  ): Int = {
    require(gridSize >= 2 && gridSize <= 64)
    require(coordinateX >= 0 && coordinateX < gridSize)
    require(coordinateY >= 0 && coordinateY < gridSize)
    require(ingressDir >= 0 && ingressDir <= 4)
    if (!packetValid) return 0

    val xLo = math.min(x0, x1)
    val xHi = math.max(x0, x1)
    val yLo = math.min(y0, y1)
    val yHi = math.max(y0, y1)
    val cx = coordinateX
    val cy = coordinateY
    val inRectColumn = cx >= xLo && cx <= xHi
    val inRectRow = cy >= yLo && cy <= yHi
    val localHit = inRectColumn && inRectRow

    val dLL = absDiff(cx, xLo) + absDiff(cy, yLo)
    val dLH = absDiff(cx, xLo) + absDiff(cy, yHi)
    val dHL = absDiff(cx, xHi) + absDiff(cy, yLo)
    val dHH = absDiff(cx, xHi) + absDiff(cy, yHi)
    val chooseLH = dLH < dLL
    val bestXLeft = xLo
    val bestYLeft = if (chooseLH) yHi else yLo
    val bestDLeft = if (chooseLH) dLH else dLL
    val chooseHH = dHH < dHL
    val bestXRight = xHi
    val bestYRight = if (chooseHH) yHi else yLo
    val bestDRight = if (chooseHH) dHH else dHL
    val chooseRight = bestDRight < bestDLeft
    val targetX = if (chooseRight) bestXRight else bestXLeft
    val targetY = if (chooseRight) bestYRight else bestYLeft

    val eastNeeded = cx < xHi
    val westNeeded = cx > xLo
    val northNeeded = inRectColumn && cy < yHi
    val southNeeded = inRectColumn && cy > yLo

    var goWest = false
    var goSouth = false
    var goEast = false
    var goNorth = false
    var goLocal = false

    if (!localHit) {
      if (cx < targetX) goEast = true
      else if (cx > targetX) goWest = true
      else if (cy < targetY) goNorth = true
      else if (cy > targetY) goSouth = true
    } else {
      if (ingressDir != DirLocal) goLocal = true
      ingressDir match {
        case DirWest =>
          goEast = eastNeeded
          goNorth = northNeeded
          goSouth = southNeeded
        case DirEast =>
          goWest = westNeeded
          goNorth = northNeeded
          goSouth = southNeeded
        case DirNorth =>
          if (cy == yHi) {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goSouth = southNeeded
        case DirSouth =>
          if (cy == yLo) {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goNorth = northNeeded
        case DirLocal =>
          if (cx < xLo) goEast = true
          else if (cx > xHi) goWest = true
          else {
            goWest = westNeeded
            goEast = eastNeeded
          }
          goNorth = northNeeded
          goSouth = southNeeded
        case _ =>
      }
    }

    if (cx == 0) goWest = false
    if (cx == gridSize - 1) goEast = false
    if (cy == 0) goSouth = false
    if (cy == gridSize - 1) goNorth = false

    (if (goWest) 1 << DirWest else 0) |
      (if (goSouth) 1 << DirSouth else 0) |
      (if (goEast) 1 << DirEast else 0) |
      (if (goNorth) 1 << DirNorth else 0) |
      (if (goLocal) 1 << DirLocal else 0)
  }
}

/** Chisel twin of `RoutingLogicMeshModel` for RCU Mat bits. */
class RoutingLogic_mesh(
    coordinate_x: Int,
    coordinate_y: Int,
    gridSize: Int = 8
) {
  require(gridSize >= 2 && gridSize <= 64)
  require(coordinate_x >= 0 && coordinate_x < gridSize)
  require(coordinate_y >= 0 && coordinate_y < gridSize)

  private val DirWest = 0.U(3.W)
  private val DirSouth = 1.U(3.W)
  private val DirEast = 2.U(3.W)
  private val DirNorth = 3.U(3.W)
  private val DirLocal = 4.U(3.W)

  private def absDiff(a: UInt, b: UInt): UInt = Mux(a >= b, a - b, b - a)

  def routeMask(
      x0: UInt,
      y0: UInt,
      x1: UInt,
      y1: UInt,
      packetValid: Bool,
      ingressDir: UInt
  ): UInt = {
    val xLo = Wire(UInt(6.W))
    val xHi = Wire(UInt(6.W))
    val yLo = Wire(UInt(6.W))
    val yHi = Wire(UInt(6.W))
    xLo := Mux(x0 <= x1, x0, x1)
    xHi := Mux(x0 <= x1, x1, x0)
    yLo := Mux(y0 <= y1, y0, y1)
    yHi := Mux(y0 <= y1, y1, y0)

    val cx = coordinate_x.U(6.W)
    val cy = coordinate_y.U(6.W)
    val inRectColumn = (cx >= xLo) && (cx <= xHi)
    val inRectRow = (cy >= yLo) && (cy <= yHi)
    val localHit = inRectColumn && inRectRow

    val dLL = absDiff(cx, xLo) +& absDiff(cy, yLo)
    val dLH = absDiff(cx, xLo) +& absDiff(cy, yHi)
    val dHL = absDiff(cx, xHi) +& absDiff(cy, yLo)
    val dHH = absDiff(cx, xHi) +& absDiff(cy, yHi)

    val chooseLH = dLH < dLL
    val bestXLeft = xLo
    val bestYLeft = Mux(chooseLH, yHi, yLo)
    val bestDLeft = Mux(chooseLH, dLH, dLL)

    val chooseHH = dHH < dHL
    val bestXRight = xHi
    val bestYRight = Mux(chooseHH, yHi, yLo)
    val bestDRight = Mux(chooseHH, dHH, dHL)

    val chooseRight = bestDRight < bestDLeft
    val targetX = Mux(chooseRight, bestXRight, bestXLeft)
    val targetY = Mux(chooseRight, bestYRight, bestYLeft)

    val eastNeeded = cx < xHi
    val westNeeded = cx > xLo
    val northNeeded = inRectColumn && (cy < yHi)
    val southNeeded = inRectColumn && (cy > yLo)

    val goWest = WireInit(false.B)
    val goSouth = WireInit(false.B)
    val goEast = WireInit(false.B)
    val goNorth = WireInit(false.B)
    val goLocal = WireInit(false.B)

    when(packetValid) {
      when(!localHit) {
        when(cx < targetX) {
          goEast := true.B
        }.elsewhen(cx > targetX) {
          goWest := true.B
        }.elsewhen(cy < targetY) {
          goNorth := true.B
        }.elsewhen(cy > targetY) {
          goSouth := true.B
        }
      }.otherwise {
        when(ingressDir =/= DirLocal) {
          goLocal := true.B
        }
        switch(ingressDir) {
          is(DirWest) {
            goEast := eastNeeded
            goNorth := northNeeded
            goSouth := southNeeded
          }
          is(DirEast) {
            goWest := westNeeded
            goNorth := northNeeded
            goSouth := southNeeded
          }
          is(DirNorth) {
            when(cy === yHi) {
              goWest := westNeeded
              goEast := eastNeeded
            }
            goSouth := southNeeded
          }
          is(DirSouth) {
            when(cy === yLo) {
              goWest := westNeeded
              goEast := eastNeeded
            }
            goNorth := northNeeded
          }
          is(DirLocal) {
            when(cx < xLo) {
              goEast := true.B
            }.elsewhen(cx > xHi) {
              goWest := true.B
            }.otherwise {
              goWest := westNeeded
              goEast := eastNeeded
            }
            goNorth := northNeeded
            goSouth := southNeeded
          }
        }
      }
    }

    val westOut = if (coordinate_x == 0) false.B else goWest
    val eastOut = if (coordinate_x == gridSize - 1) false.B else goEast
    val southOut = if (coordinate_y == 0) false.B else goSouth
    val northOut = if (coordinate_y == gridSize - 1) false.B else goNorth
    Cat(goLocal, northOut, eastOut, southOut, westOut)
  }

  def computeRouting(
      current_Packet: Packet,
      Packet_valid: Bool,
      ingressDir: UInt
  ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    val x0 = current_Packet.flit(PacketLayout.X0Hi, PacketLayout.X0Lo)
    val y0 = current_Packet.flit(PacketLayout.Y0Hi, PacketLayout.Y0Lo)
    val x1 = current_Packet.flit(PacketLayout.X1Hi, PacketLayout.X1Lo)
    val y1 = current_Packet.flit(PacketLayout.Y1Hi, PacketLayout.Y1Lo)
    val dir = routeMask(x0, y0, x1, y1, Packet_valid, ingressDir)
    for (i <- 0 until 5) {
      decision.output_valid(i) := dir(i)
      decision.output_ports(i) := dir(i)
      decision.output_packets(i) := Mux(dir(i), current_Packet, 0.U.asTypeOf(new Packet))
    }
    decision
  }
}
