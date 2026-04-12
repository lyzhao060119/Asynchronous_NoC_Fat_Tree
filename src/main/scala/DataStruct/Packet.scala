package DataStruct

import chisel3._

object PacketLayout {
  val IdHi = 1
  val IdLo = 0

  // Rectangle corners in global 32x32 space.
  // Two diagonal points: (x0, y0) and (x1, y1), each coordinate is 6 bits.
  val X0Lo = 2
  val X0Hi = 7
  val Y0Lo = 8
  val Y0Hi = 13
  val X1Lo = 14
  val X1Hi = 19
  val Y1Lo = 20
  val Y1Hi = 25

  val IsTailIndex = 26
  val IsHeadIndex = 27

  val FlitWidth = IsHeadIndex + 1
}

class Packet extends Bundle {
  val flit = UInt(PacketLayout.FlitWidth.W)

  // payload[27]:isHead payload[26]:isTail
  // payload[25:20]:y1 payload[19:14]:x1
  // payload[13:8]:y0 payload[7:2]:x0
  // payload[1:0]:id

}
