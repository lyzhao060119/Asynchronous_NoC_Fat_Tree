package DataStruct

import chisel3._
import tool._

class HS_Packet extends Bundle {
  val HS   = new HS_IO
  val Data = Input(new Packet)
}
