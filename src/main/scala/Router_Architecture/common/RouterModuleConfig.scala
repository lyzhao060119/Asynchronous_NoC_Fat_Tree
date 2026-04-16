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
  parentDir: Int = 4,
  allowSameDirChild: Boolean = false,
  allowSameDirParent: Boolean = false
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

  def canConnect(inIdx: Int, outIdx: Int): Boolean = {
    val inDir = dirOfPhys(inIdx)
    val outDir = dirOfPhys(outIdx)

    if (inDir != outDir) {
      true
    } else if (outDir < 4) {
      allowSameDirChild
    } else {
      allowSameDirParent
    }
  }

  require((0 until totalPorts).forall { inIdx =>
    (0 until totalPorts).exists { outIdx =>
      canConnect(inIdx, outIdx)
    }
  }, "Every input port must retain at least one legal internal edge.")

  require((0 until totalPorts).forall { outIdx =>
    (0 until totalPorts).exists { inIdx =>
      canConnect(inIdx, outIdx)
    }
  }, "Every output port must retain at least one legal internal edge.")

  lazy val legalEdges: IndexedSeq[(Int, Int)] =
    (for {
      inIdx <- 0 until totalPorts
      outIdx <- 0 until totalPorts
      if canConnect(inIdx, outIdx)
    } yield (inIdx, outIdx)).toIndexedSeq

  lazy val edgeCount: Int = legalEdges.length

  lazy val edgeInput: IndexedSeq[Int] =
    legalEdges.map(_._1)

  lazy val edgeOutput: IndexedSeq[Int] =
    legalEdges.map(_._2)

  lazy val edgesByInput: IndexedSeq[IndexedSeq[Int]] =
    (0 until totalPorts).map { inIdx =>
      legalEdges.zipWithIndex.collect {
        case ((srcIdx, _), edgeId) if srcIdx == inIdx => edgeId
      }.toIndexedSeq
    }.toIndexedSeq

  lazy val edgesByOutput: IndexedSeq[IndexedSeq[Int]] =
    (0 until totalPorts).map { outIdx =>
      legalEdges.zipWithIndex.collect {
        case ((_, dstIdx), edgeId) if dstIdx == outIdx => edgeId
      }.toIndexedSeq
    }.toIndexedSeq
}
