package Router_Architecture.algorithm

import DataStruct._
import chisel3._
import chisel3.util._

class RoutingDecision_top extends Bundle {
  val output_ports = Vec(5, Bool())
  val output_packets = Vec(5, new Packet)
  val output_valid = Vec(5, Bool())
}

class RoutingLogic_top_layer(coordinate_x: UInt, coordinate_y: UInt) {
  private val DirWest = 0.U(3.W)
  private val DirSouth = 1.U(3.W)
  private val DirEast = 2.U(3.W)
  private val DirNorth = 3.U(3.W)
  private val DirLocal = 4.U(3.W)

  private def absDiff(a: UInt, b: UInt): UInt = {
    Mux(a >= b, a - b, b - a)
  }

  def computeRouting(current_Packet: Packet,
                     Packet_valid: Bool,
                     ingressDir: UInt): RoutingDecision_top = {
    val decision = Wire(new RoutingDecision_top)
    for (i <- 0 until 5) {
      decision.output_valid(i) := false.B
      decision.output_ports(i) := false.B
      decision.output_packets(i) := DontCare
    }

    val x0 = current_Packet.flit(PacketLayout.X0Hi, PacketLayout.X0Lo)
    val y0 = current_Packet.flit(PacketLayout.Y0Hi, PacketLayout.Y0Lo)
    val x1 = current_Packet.flit(PacketLayout.X1Hi, PacketLayout.X1Lo)
    val y1 = current_Packet.flit(PacketLayout.Y1Hi, PacketLayout.Y1Lo)

    val xLo = Wire(UInt(6.W))
    val xHi = Wire(UInt(6.W))
    val yLo = Wire(UInt(6.W))
    val yHi = Wire(UInt(6.W))
    xLo := Mux(x0 <= x1, x0, x1)
    xHi := Mux(x0 <= x1, x1, x0)
    yLo := Mux(y0 <= y1, y0, y1)
    yHi := Mux(y0 <= y1, y1, y0)

    val txLo = xLo(5, 3)
    val txHi = xHi(5, 3)
    val tyLo = yLo(5, 3)
    val tyHi = yHi(5, 3)

    val cx = Wire(UInt(2.W))
    val cy = Wire(UInt(2.W))
    cx := coordinate_x
    cy := coordinate_y

    val inRectColumn = (cx >= txLo) && (cx <= txHi)
    val inRectRow = (cy >= tyLo) && (cy <= tyHi)
    val localHit = inRectColumn && inRectRow

    // outside the rectangle, route with XY to the nearest corner.
    val dLL = absDiff(cx, txLo) +& absDiff(cy, tyLo) // (xLo, yLo)
    val dLH = absDiff(cx, txLo) +& absDiff(cy, tyHi) // (xLo, yHi)
    val dHL = absDiff(cx, txHi) +& absDiff(cy, tyLo) // (xHi, yLo)
    val dHH = absDiff(cx, txHi) +& absDiff(cy, tyHi) // (xHi, yHi)

    val chooseLH = dLH < dLL
    val bestXLeft = txLo
    val bestYLeft = Mux(chooseLH, tyHi, tyLo)
    val bestDLeft = Mux(chooseLH, dLH, dLL)

    val chooseHH = dHH < dHL
    val bestXRight = txHi
    val bestYRight = Mux(chooseHH, tyHi, tyLo)
    val bestDRight = Mux(chooseHH, dHH, dHL)

    val chooseRight = bestDRight < bestDLeft
    val targetX = Mux(chooseRight, bestXRight, bestXLeft)
    val targetY = Mux(chooseRight, bestYRight, bestYLeft)

    val eastNeeded = cx < txHi
    val westNeeded = cx > txLo
    val northNeeded = inRectColumn && (cy < tyHi)
    val southNeeded = inRectColumn && (cy > tyLo)

    val goWest = WireInit(false.B)
    val goSouth = WireInit(false.B)
    val goEast = WireInit(false.B)
    val goNorth = WireInit(false.B)
    val goLocal = WireInit(false.B)

    when(Packet_valid) {
      when(!localHit) {
        // XY unicast to nearest corner (no branch).
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
        // inside rectangle, tree-based spreading.
        // Packets entering from local tree have already been delivered locally
        // in quadtree logic;
        // avoid sending back to local to prevent duplicates.
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
            // Entering from north boundary: start X-trunk and Y-branch.
            // Interior vertical branch remain vertical-only to avoid duplicates.
            when(cy === tyHi) {
              goWest := westNeeded
              goEast := eastNeeded
            }
            goSouth := southNeeded
          }
          is(DirSouth) {
            // Entering from south boundary: start X-trunk and Y-branch.
            // Interior vertical branch remain vertical-only to avoid duplicates.
            when(cy === tyLo) {
              goWest := westNeeded
              goEast := eastNeeded
            }
            goNorth := northNeeded
          }
          is(DirLocal) {
            when(cx < txLo) {
              goEast := true.B
            }.elsewhen(cx > txHi) {
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

    val dir = Cat(goLocal, goNorth, goEast, goSouth, goWest)
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
