package Router_Architecture.core

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import Router_Architecture.ipm.RouterInputPortModule
import Router_Architecture.opm.RouterOutputPortModule
import chisel3._
import chisel3.util._

class RouterCoreModule(
  config: RouterModuleConfig,
  computeHeadRouting: (Packet, Bool) => Vec[Bool]
) extends Module {

  private val noneLiteral = config.noneValue.U(config.holderW.W)

  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(config.childLanes, config.parentLanes)
    val outputs = Flipped(new RouterDirGroupedHSIO(config.childLanes, config.parentLanes))
  })

  private def inPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.inputs.child(d)(l) else io.inputs.parent(l)
  }

  private def outPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.outputs.child(d)(l) else io.outputs.parent(l)
  }

  private def anyDest(v: Vec[Bool]): Bool = v.asUInt.orR

  private val ipms = Seq.fill(config.totalPorts)(Module(new RouterInputPortModule(config)))
  for (i <- 0 until config.totalPorts) {
    ipms(i).io.in <> inPort(i)
  }

  private val opms = Seq.fill(config.totalPorts)(Module(new RouterOutputPortModule(config)))
  for (o <- 0 until config.totalPorts) {
    opms(o).io.out <> outPort(o)
  }
  for (o <- 0 until config.totalPorts) {
    for (i <- 0 until config.totalPorts) {
      opms(o).io.inputs(i) <> ipms(i).io.forkOutputs(o)
    }
  }

  private val holder = Wire(Vec(config.totalPorts, UInt(config.holderW.W)))
  for (o <- 0 until config.totalPorts) {
    holder(o) := opms(o).io.holder
  }

  private val currentDestVec = Wire(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
  for (i <- 0 until config.totalPorts) {
    val headDecision = computeHeadRouting(ipms(i).io.inBits, ipms(i).io.inValid)
    when(ipms(i).io.isHead) {
      currentDestVec(i) := headDecision
    }.otherwise {
      currentDestVec(i) := ipms(i).io.storedDir
    }
  }

  private val headSelLane = Wire(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
  private val headAllocOk = Wire(Vec(config.totalPorts, Bool()))

  private val freeLane0 = Wire(Vec(config.nDirs, Vec(config.maxLanes, Bool())))
  for (d <- 0 until config.nDirs) {
    for (l <- 0 until config.maxLanes) {
      if (l < config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        freeLane0(d)(l) := (holder(outIdx) === noneLiteral) && !opms(outIdx).io.anyPending
      } else {
        freeLane0(d)(l) := false.B
      }
    }
  }

  private val remFree = Wire(Vec(config.totalPorts + 1, Vec(config.nDirs, Vec(config.maxLanes, Bool()))))
  remFree(0) := freeLane0

  for (i <- 0 until config.totalPorts) {
    val hasLanePerDir = Wire(Vec(config.nDirs, Bool()))
    val chosenLane = Wire(Vec(config.nDirs, UInt(config.laneW.W)))

    for (d <- 0 until config.nDirs) {
      chosenLane(d) := PriorityEncoder(remFree(i)(d).asUInt)
      hasLanePerDir(d) := !currentDestVec(i)(d) || remFree(i)(d).asUInt.orR
      headSelLane(i)(d) := chosenLane(d)
    }

    headAllocOk(i) :=
      ipms(i).io.inValid &&
        ipms(i).io.isHead &&
        anyDest(currentDestVec(i)) &&
        hasLanePerDir.reduce(_ && _)

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.maxLanes) {
        val consume = headAllocOk(i) && currentDestVec(i)(d) && (chosenLane(d) === l.U)
        remFree(i + 1)(d)(l) := remFree(i)(d)(l) && !consume
      }
    }
  }

  private val headWantedMask = Wire(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  private val bodyWantedMask = Wire(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  private val bodyGrantedMask = Wire(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  private val bodyAtomicOk = Wire(Vec(config.totalPorts, Bool()))

  for (i <- 0 until config.totalPorts) {
    ipms(i).io.nextDir := currentDestVec(i)
    ipms(i).io.nextLane := headSelLane(i)

    for (o <- 0 until config.totalPorts) {
      headWantedMask(i)(o) := false.B
      bodyWantedMask(i)(o) := false.B
      bodyGrantedMask(i)(o) := false.B
    }

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        when(currentDestVec(i)(d) && (headSelLane(i)(d) === l.U)) {
          headWantedMask(i)(outIdx) := true.B
        }
      }
    }

    for (d <- 0 until config.nDirs) {
      for (l <- 0 until config.lanesPerDir(d)) {
        val outIdx = config.physIndex(d, l)
        when(currentDestVec(i)(d) && (ipms(i).io.storedLane(d) === l.U)) {
          bodyWantedMask(i)(outIdx) := true.B
        }
      }
    }

    for (o <- 0 until config.totalPorts) {
      bodyGrantedMask(i)(o) := bodyWantedMask(i)(o) && (holder(o) === i.U(config.holderW.W))
    }

    bodyAtomicOk(i) := true.B
    for (o <- 0 until config.totalPorts) {
      when(bodyWantedMask(i)(o) =/= bodyGrantedMask(i)(o)) {
        bodyAtomicOk(i) := false.B
      }
    }

    when(ipms(i).io.inValid && ipms(i).io.isHead && headAllocOk(i)) {
      ipms(i).io.destMask := headWantedMask(i)
    }.elsewhen(ipms(i).io.inValid && !ipms(i).io.isHead && anyDest(currentDestVec(i)) && bodyAtomicOk(i)) {
      ipms(i).io.destMask := bodyGrantedMask(i)
    }.otherwise {
      ipms(i).io.destMask := VecInit(Seq.fill(config.totalPorts)(false.B))
    }
  }
}
