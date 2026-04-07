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
  def computeRouting(current_Packet: Packet,
                     Packet_valid: Bool,
                     router_level: UInt
                    ): RoutingDecision = {
    val decision = Wire(new RoutingDecision)
    for (i <- 0 until 5) {
      decision.output_valid(i) := false.B
      decision.output_ports(i) := false.B
      decision.output_packets(i) := DontCare
    }
    val destX = current_Packet.flit(19, 14)
    val destY = current_Packet.flit(13, 8)
    val copyX = current_Packet.flit(7, 5)
    val copyY = current_Packet.flit(4, 2)
    val to_parent = Wire(Bool())
    to_parent := false.B
    switch(router_level) {
      is(1.U) {
        to_parent := destX(4, 1) =/= coordinate_x || destY(4, 1) =/= coordinate_y
      }
      is(2.U) {
        to_parent := destX(4, 2) =/= coordinate_x || destY(4, 2) =/= coordinate_y
      }
      is(3.U) {
        to_parent := destX(4, 3) =/= coordinate_x || destY(4, 3) =/= coordinate_y
      }
    }
    val dir = WireInit(0.U(5.W))
    when(to_parent && Packet_valid) {
      dir := "b10000".U
    }.elsewhen(copyX(router_level - 1.U) === 0.U
      && copyY(router_level - 1.U) === 0.U
      && Packet_valid) {
      when(destX(router_level - 1.U) === 0.U && destY(router_level - 1.U) === 0.U) {
        dir := "b01000".U
      }.elsewhen(destX(router_level - 1.U) === 0.U && destY(router_level - 1.U) === 1.U) {
        dir := "b00100".U
      }.elsewhen(destX(router_level - 1.U) === 1.U && destY(router_level - 1.U) === 0.U) {
        dir := "b00010".U
      }.elsewhen(destX(router_level - 1.U) === 1.U && destY(router_level - 1.U) === 1.U) {
        dir := "b00001".U
      }
    }.elsewhen(copyX(router_level - 1.U) === 1.U && copyY(router_level - 1.U) === 0.U && Packet_valid) {
      when(destY(router_level - 1.U) === 0.U) {
        dir := "b01010".U
      }.elsewhen(destY(router_level - 1.U) === 1.U) {
        dir := "b00101".U
      }
    }.elsewhen(copyX(router_level - 1.U) === 0.U && copyY(router_level - 1.U) === 1.U && Packet_valid) {
      when(destX(router_level - 1.U) === 0.U) {
        dir := "b01100".U
      }.elsewhen(destX(router_level - 1.U) === 1.U) {
        dir := "b00011".U
      }
    }.elsewhen(copyX(router_level - 1.U) === 1.U && copyY(router_level - 1.U) === 1.U && Packet_valid) {
      dir := "b01111".U
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
