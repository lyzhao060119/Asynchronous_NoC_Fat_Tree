package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._

class RouterIPM(
  config: RouterModuleConfig,
  computeHeadRouting: (Packet, Bool) => Vec[Bool]
) extends Module {
  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(config.childLanes, config.parentLanes)
    val toOpm = Vec(config.totalPorts, Vec(config.totalPorts, Flipped(new HS_Packet)))

    val opmHolder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val opmAnyPending = Input(Vec(config.totalPorts, Bool()))
  })

  private def inPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.inputs.child(d)(l) else io.inputs.parent(l)
  }

  private val inputPorts = Seq.fill(config.totalPorts)(Module(new RouterInputPortModule(config)))
  for (i <- 0 until config.totalPorts) {
    inputPorts(i).io.in <> inPort(i)
  }

  private val routeSelection = Module(new RouterRouteSelectionModule(config, computeHeadRouting))
  private val laneAllocator = Module(new RouterHeadLaneAllocator(config))
  private val maskBuilder = Module(new RouterMulticastMaskBuilder(config))

  for (i <- 0 until config.totalPorts) {
    routeSelection.io.inBits(i) := inputPorts(i).io.inBits
    routeSelection.io.inValid(i) := inputPorts(i).io.inValid
    routeSelection.io.isHead(i) := inputPorts(i).io.isHead
    routeSelection.io.storedDir(i) := inputPorts(i).io.storedDir
  }

  laneAllocator.io.holder := io.opmHolder
  laneAllocator.io.opmAnyPending := io.opmAnyPending
  laneAllocator.io.currentDestVec := routeSelection.io.currentDestVec
  for (i <- 0 until config.totalPorts) {
    laneAllocator.io.inValid(i) := inputPorts(i).io.inValid
    laneAllocator.io.isHead(i) := inputPorts(i).io.isHead
  }

  maskBuilder.io.currentDestVec := routeSelection.io.currentDestVec
  maskBuilder.io.headSelLane := laneAllocator.io.headSelLane
  maskBuilder.io.holder := io.opmHolder
  maskBuilder.io.headAllocOk := laneAllocator.io.headAllocOk
  for (i <- 0 until config.totalPorts) {
    maskBuilder.io.inValid(i) := inputPorts(i).io.inValid
    maskBuilder.io.isHead(i) := inputPorts(i).io.isHead
    maskBuilder.io.storedLane(i) := inputPorts(i).io.storedLane
  }

  for (i <- 0 until config.totalPorts) {
    inputPorts(i).io.nextDir := routeSelection.io.currentDestVec(i)
    inputPorts(i).io.nextLane := laneAllocator.io.headSelLane(i)
    inputPorts(i).io.destMask := maskBuilder.io.destMask(i)
    io.toOpm(i) <> inputPorts(i).io.forkOutputs
  }
}
