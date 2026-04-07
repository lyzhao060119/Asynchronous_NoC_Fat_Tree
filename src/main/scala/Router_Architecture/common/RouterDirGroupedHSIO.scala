package Router_Architecture.common

import DataStruct._
import chisel3._

class RouterDirGroupedHSIO(childLanes: Int, parentLanes: Int) extends Bundle {
  val child = Vec(4, Vec(childLanes, new HS_Packet))
  val parent = Vec(parentLanes, new HS_Packet)
}
