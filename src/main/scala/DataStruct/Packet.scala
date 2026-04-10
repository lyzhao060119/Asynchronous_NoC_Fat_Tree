package DataStruct

import chisel3._

object PacketLayout {
  val IdHigh = 1
  val IdLow = 0

  val ReservedHigh = 3
  val ReservedLow = 2

  // Tree id in top mesh : treeY * 4 + treeX
  val TreeIdHi = 19
  val TreeIdLo = 16

  // Rectangle multicast region in one tree-local 8x8 space.
  val YMaxHi = 6
  val YMaxLo = 4
  val YMinHi = 9
  val YMinLo = 7
  val XMaxHi = 12
  val XMaxLo = 10
  val XMinHi = 15
  val XMinLo = 13

  val IsTailIndex = 20
  val IsHeadIndex = 21

  val FlitWidth = IsHeadIndex + 1
}

class Packet extends Bundle {
  val flit = UInt(PacketLayout.FlitWidth.W)

  // payload[21]:isHead payload[20]:isTail
  // payload[19:16]:treeId
  // payload[15:13]:xMin payload[12:10]:xMax
  // payload[9:7]:yMin  payload[6:4]:yMax
  // payload[3:2]:reserved payload[1:0]:id

}

