package DataStruct

import chisel3._

class Packet extends Bundle {
  val flit = UInt(22.W)

  //payload[21]:isHead payload[20]:isTail
  //payload[1:0]:id
  //payload[19:14]:destX payload[13:8]:destY
  //payload[7:5]:copyX payload[4:2]:copyY

}


