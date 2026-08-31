package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Extra multicast-aware request mask builder for this project.
  *
  * Head flits build a direction/lane mask; body and tail flits reuse the stored
  * mask from packet context. Holder filtering is done in InputEligibilityModule.
  */
class MulticastRequestMaskModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val currentDestVec =
      Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val headSelLane =
      Input(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
    val storedMask =
      Input(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
    val headAllocOk = Input(Vec(config.totalPorts, Bool()))

    val destMask =
      Output(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  })

  private val headWantedMask = Wire(
    Vec(config.totalPorts, Vec(config.totalPorts, Bool()))
  )
  private val zeroMask = VecInit(Seq.fill(config.totalPorts)(false.B))

  for (i <- 0 until config.totalPorts) {
    for (o <- 0 until config.totalPorts) {
      val dir = config.dirOfPhys(o)
      val lane = config.laneOfPhys(o)
      headWantedMask(i)(o) :=
        io.currentDestVec(i)(dir) &&
          (io.headSelLane(i)(dir) === lane.U(config.laneW.W))
    }

    val useHead = io.inValid(i) && io.isHead(i) && io.headAllocOk(i)
    val useStore =
      io.inValid(i) && !io.isHead(i) && io.storedMask(i).asUInt.orR
    io.destMask(i) :=
      Mux(useHead, headWantedMask(i), Mux(useStore, io.storedMask(i), zeroMask))
  }
}
