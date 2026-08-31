package Router_Architecture.sync_cmr

import DataStruct.Packet
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.Cat

/** Clocked valid/ready twin of `tool.HS_IO`. */
class SyncVrIO extends Bundle {
  val valid = Input(Bool())
  val ready = Output(Bool())
}

/** Clocked twin of `DataStruct.HS_Packet`. */
class SyncVrPacket extends Bundle {
  val hs = new SyncVrIO
  val data = Input(new Packet)
}

/** Same direction grouping as `RouterDirGroupedHSIO`, valid/ready pins. */
class SyncDirGroupedIO(childLanes: Int, parentLanes: Int) extends Bundle {
  val child = Vec(4, Vec(childLanes, new SyncVrPacket))
  val parent = Vec(parentLanes, new SyncVrPacket)
}

object SyncCmrConfig {
  def apply(childLanes: Int, parentLanes: Int): RouterModuleConfig = {
    require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
    RouterModuleConfig(
      childLanes = childLanes,
      parentLanes = parentLanes,
      fifoDepth = CMRParameters.CellCount,
      vcCount = 1,
      allowSameDirChild = false,
      allowSameDirParent = false
    )
  }
}

object SyncCmrOneHot {
  def init: UInt = 1.U(CMRParameters.CellCount.W)

  /** Cell 0 -> 1 -> 2 -> 3 -> 4 -> 0. Bit 0 is the LSB (cell 0). */
  def rotate(ptr: UInt): UInt = {
    val n = CMRParameters.CellCount
    require(ptr.getWidth == n)
    Cat(ptr(n - 2, 0), ptr(n - 1))
  }
}
