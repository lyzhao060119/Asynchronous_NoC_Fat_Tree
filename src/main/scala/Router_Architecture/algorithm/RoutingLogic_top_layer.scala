package Router_Architecture.algorithm

import DataStruct._
import chisel3._

class RoutingDecision_top extends Bundle {
  val output_ports = Vec(5, Bool())
  val output_packets = Vec(5, new Packet)
  val output_valid = Vec(5, Bool())
}

class RoutingLogic_top_layer(coordinate_x: UInt, coordinate_y: UInt) {
  def computeRouting(current_Packet: Packet,
                     Packet_valid: Bool): RoutingDecision_top = {
    val decision = Wire(new RoutingDecision_top)
    for (i <- 0 until 5) {
      decision.output_valid(i) := false.B
      decision.output_ports(i) := false.B
      decision.output_packets(i) := DontCare
    }

    val dest_x = current_Packet.flit(19, 17) //dest(5, 3)
    val dest_y = current_Packet.flit(13, 11)
    val dir = WireInit(0.U(5.W))
    when(Packet_valid) {
      when(dest_x > coordinate_x) {
        dir := "b00100".U
      }.elsewhen(dest_x < coordinate_x) {
        dir := "b00001".U
      }.elsewhen(dest_y > coordinate_y) {
        dir := "b01000".U
      }.elsewhen(dest_y < coordinate_y) {
        dir := "b00010".U
      }.otherwise {
        dir := "b10000".U
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
