package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.log2Ceil

/** Paper-aligned packet route selector.
  *
  * Head flits run the routing algorithm once. Body/tail flits bypass fresh
  * route computation and reuse the packet context captured when the head
  * launched.
  */
class PacketRouteSelector(
    config: RouterModuleConfig,
    computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  private val dirW = math.max(1, log2Ceil(config.nDirs))

  val io = IO(new Bundle {
    val inBits = Input(Vec(config.totalPorts, new Packet))
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val storedDir = Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val currentDestVec =
      Output(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
  })

  for (i <- 0 until config.totalPorts) {
    val ingressDir = config.dirOfPhys(i).U(dirW.W)
    val headDecision =
      computeHeadRouting(io.inBits(i), io.inValid(i), ingressDir)
    when(io.isHead(i)) {
      io.currentDestVec(i) := headDecision
    }.otherwise {
      io.currentDestVec(i) := io.storedDir(i)
    }
  }
}
