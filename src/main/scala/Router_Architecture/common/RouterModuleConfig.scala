package Router_Architecture.common

import DataStruct.PacketLayout
import chisel3.util.log2Ceil

final case class RouterModuleConfig(
  childLanes: Int,
  parentLanes: Int,
  fifoDepth: Int = 1,
  isHeadIndex: Int = PacketLayout.IsHeadIndex,
  isTailIndex: Int = PacketLayout.IsTailIndex,
  nDirs: Int = 5,
  parentDir: Int = 4
) {
  require(childLanes > 0)
  require(parentLanes > 0)

  val totalPorts: Int = 4 * childLanes + parentLanes
  val maxLanes: Int = math.max(childLanes, parentLanes)
  val laneW: Int = math.max(1, log2Ceil(maxLanes))
  val holderW: Int = math.max(1, log2Ceil(totalPorts + 1))
  val noneValue: Int = totalPorts

  def lanesPerDir(d: Int): Int =
    if (d < 4) childLanes else parentLanes

  def physBaseOfDir(d: Int): Int =
    if (d < 4) d * childLanes else 4 * childLanes

  def physIndex(d: Int, l: Int): Int =
    physBaseOfDir(d) + l

  def dirOfPhys(idx: Int): Int =
    if (idx < 4 * childLanes) idx / childLanes else parentDir

  def laneOfPhys(idx: Int): Int =
    if (idx < 4 * childLanes) idx % childLanes else idx - 4 * childLanes
}
