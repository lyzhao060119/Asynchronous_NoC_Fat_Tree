package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Extra multicast-aware request mask builder for this project.
  *
  * The paper routers emit one request per selected output. Our design adds
  * multicast fan-out, packet-level atomic lane ownership, and multi-lane body
  * bypass, so those behaviors are isolated in this block instead of being mixed
  * into the paper-aligned request generator.
  */
class MulticastRequestMaskModule(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val currentDestVec =
      Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val headSelLane =
      Input(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
    val storedLane =
      Input(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
    val holder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val headAllocOk = Input(Vec(config.totalPorts, Bool()))

    val destMask =
      Output(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  })

  private def anyDest(v: Vec[Bool]): Bool = v.asUInt.orR

  private val headWantedMask = Wire(
    Vec(config.totalPorts, Vec(config.totalPorts, Bool()))
  )
  private val bodyWantedMask = Wire(
    Vec(config.totalPorts, Vec(config.totalPorts, Bool()))
  )
  private val bodyGrantedMask = Wire(
    Vec(config.totalPorts, Vec(config.totalPorts, Bool()))
  )
  private val bodyAtomicOk = Wire(Vec(config.totalPorts, Bool()))

  for (i <- 0 until config.totalPorts) {
    for (o <- 0 until config.totalPorts) {
      headWantedMask(i)(o) := false.B
      bodyWantedMask(i)(o) := false.B
      bodyGrantedMask(i)(o) := false.B
    }

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        when(io.currentDestVec(i)(d) && (io.headSelLane(i)(d) === l.U)) {
          headWantedMask(i)(outIdx) := true.B
        }
      }
    }

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        when(io.currentDestVec(i)(d) && (io.storedLane(i)(d) === l.U)) {
          bodyWantedMask(i)(outIdx) := true.B
        }
      }
    }

    for (o <- 0 until config.totalPorts) {
      bodyGrantedMask(i)(o) := bodyWantedMask(i)(o) && (io.holder(o) === i.U(
        config.holderW.W
      ))
    }

    bodyAtomicOk(i) := true.B
    for (o <- 0 until config.totalPorts) {
      when(bodyWantedMask(i)(o) =/= bodyGrantedMask(i)(o)) {
        bodyAtomicOk(i) := false.B
      }
    }

    when(io.inValid(i) && io.isHead(i) && io.headAllocOk(i)) {
      io.destMask(i) := headWantedMask(i)
    }.elsewhen(
      io.inValid(i) && !io.isHead(i) && anyDest(
        io.currentDestVec(i)
      ) && bodyAtomicOk(i)
    ) {
      io.destMask(i) := bodyGrantedMask(i)
    }.otherwise {
      io.destMask(i) := VecInit(Seq.fill(config.totalPorts)(false.B))
    }
  }
}
