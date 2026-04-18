package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Input-side control shell.
  *
  * This shell keeps the paper-aligned route selector visible while isolating
  * the project-specific packet context, multicast request masking, and lane
  * reservation logic into their own blocks.
  */
class InputControlModule(
    config: RouterModuleConfig,
    computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  val io = IO(new Bundle {
    val inBits = Input(Vec(config.totalPorts, new Packet))
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val storedDir = Input(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val storedLane =
      Input(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))

    val opmHolder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val opmAnyPending = Input(Vec(config.totalPorts, Bool()))

    val nextDir = Output(Vec(config.totalPorts, Vec(config.nDirs, Bool())))
    val nextLane =
      Output(Vec(config.totalPorts, Vec(config.nDirs, UInt(config.laneW.W))))
    val destMask =
      Output(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  })

  private val routeSelector =
    Module(new PacketRouteSelector(config, computeHeadRouting))
  private val laneReservation = Module(new LaneReservation(config))
  private val requestMask = Module(new MulticastRequestMaskModule(config))

  routeSelector.io.inBits := io.inBits
  routeSelector.io.inValid := io.inValid
  routeSelector.io.isHead := io.isHead
  routeSelector.io.storedDir := io.storedDir

  laneReservation.io.inValid := io.inValid
  laneReservation.io.isHead := io.isHead
  laneReservation.io.currentDestVec := routeSelector.io.currentDestVec
  laneReservation.io.holder := io.opmHolder
  laneReservation.io.opmAnyPending := io.opmAnyPending

  requestMask.io.inValid := io.inValid
  requestMask.io.isHead := io.isHead
  requestMask.io.currentDestVec := routeSelector.io.currentDestVec
  requestMask.io.headSelLane := laneReservation.io.headSelLane
  requestMask.io.storedLane := io.storedLane
  requestMask.io.holder := io.opmHolder
  requestMask.io.headAllocOk := laneReservation.io.headAllocOk

  io.nextDir := routeSelector.io.currentDestVec
  io.nextLane := laneReservation.io.headSelLane
  io.destMask := requestMask.io.destMask
}
