package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.log2Ceil

/**
 * Computes route destinations for head flits and reuses the stored
 * direction vector for body/tail flits.
 */
class RouterRouteSelectionModule(
  config: RouterModuleConfig,
  computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  private val dirW = math.max(1, log2Ceil(config.nDirs))
  val io = IO(new Bundle {
    val inBits = Input(Vec(config.totalPorts, new Packet))
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val storedDir = Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val currentDestVec = Output(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
  })

  for (i <- 0 until config.totalPorts) {
    val ingressDir = config.dirOfPhys(i).U(dirW.W)
    // The ingress direction is implied by the physical port index.
    val headDecision = computeHeadRouting(io.inBits(i), io.inValid(i), ingressDir)
    when(io.isHead(i)) {
      io.currentDestVec(i) := headDecision
    }.otherwise {
      io.currentDestVec(i) := io.storedDir(i)
    }
  }
}
