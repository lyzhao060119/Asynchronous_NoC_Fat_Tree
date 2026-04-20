package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.PriorityEncoder

/** Extra multi-lane reservation block for this project.
  *
  * This design can have multiple lanes per direction, so head flits need an
  * explicit allocator that reserves one free physical lane for each requested
  * logical direction.
  */
class LaneReservation(config: RouterModuleConfig) extends Module {
  private val noneLiteral = config.noneValue.U(config.holderW.W)

  val io = IO(new Bundle {
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val currentDestVec =
      Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val holder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val opmAnyPending = Input(Vec(config.totalPorts, Bool()))

    val headSelLane =
      Output(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
    val headAllocOk = Output(Vec(config.totalPorts, Bool()))
  })

  private def anyDest(v: Vec[Bool]): Bool = v.asUInt.orR

  private val freeLane0 = Wire(Vec(config.nDirs, Vec(config.maxLanes, Bool())))
  for (d <- 0 until config.nDirs) {
    for (l <- 0 until config.maxLanes) {
      if (l < config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        freeLane0(d)(l) := (io.holder(outIdx) === noneLiteral) && !io
          .opmAnyPending(outIdx)
      } else {
        freeLane0(d)(l) := false.B
      }
    }
  }

  private val remFree =
    Wire(
      Vec(
        config.totalPorts + 1,
        Vec(config.nDirs, Vec(config.maxLanes, Bool()))
      )
    )
  remFree(0) := freeLane0

  for (i <- 0 until config.totalPorts) {
    val hasLanePerDir = Wire(Vec(config.nDirs, Bool()))
    val chosenLane = Wire(Vec(config.nDirs, UInt(config.laneW.W)))

    for (d <- 0 until config.nDirs) {
      chosenLane(d) := PriorityEncoder(remFree(i)(d).asUInt)
      hasLanePerDir(d) := !io.currentDestVec(i)(d) || remFree(i)(d).asUInt.orR
      io.headSelLane(i)(d) := chosenLane(d)
    }

    io.headAllocOk(i) :=
      io.inValid(i) &&
        io.isHead(i) &&
        anyDest(io.currentDestVec(i)) &&
        hasLanePerDir.reduce(_ && _)

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.maxLanes) {
        val consume =
          io.headAllocOk(i) && io.currentDestVec(i)(d) && (chosenLane(
            d
          ) === l.U)
        remFree(i + 1)(d)(l) := remFree(i)(d)(l) && !consume
      }
    }
  }
}
