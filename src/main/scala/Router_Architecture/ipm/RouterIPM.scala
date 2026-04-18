package Router_Architecture.ipm

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._

/** Input processing module.
  *
  * Paper-aligned modules are kept visible here: each input port has its own
  * input buffer and request-generator path, while route selection is grouped in
  * a dedicated control shell. Project-specific multi-flit context, lane
  * reservation, and multicast masking are kept as separate submodules.
  */
class RouterIPM(
    config: RouterModuleConfig,
    computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(config.childLanes, config.parentLanes)
    val toOpm = Vec(config.edgeCount, Flipped(new HS_Packet))

    val opmHolder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val opmAnyPending = Input(Vec(config.totalPorts, Bool()))
  })

  private def inPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.inputs.child(d)(l) else io.inputs.parent(l)
  }

  private val inputPorts = Seq.tabulate(config.totalPorts) { i =>
    Module(new InputPortModule(config, config.edgesByInput(i).length))
  }
  for (i <- 0 until config.totalPorts) {
    inputPorts(i).io.in <> inPort(i)
  }

  private val control = Module(
    new InputControlModule(config, computeHeadRouting)
  )

  for (i <- 0 until config.totalPorts) {
    control.io.inBits(i) := inputPorts(i).io.inBits
    control.io.inValid(i) := inputPorts(i).io.inValid
    control.io.isHead(i) := inputPorts(i).io.isHead
    control.io.storedDir(i) := inputPorts(i).io.storedDir
    control.io.storedLane(i) := inputPorts(i).io.storedLane
  }
  control.io.opmHolder := io.opmHolder
  control.io.opmAnyPending := io.opmAnyPending

  for (i <- 0 until config.totalPorts) {
    inputPorts(i).io.nextDir := control.io.nextDir(i)
    inputPorts(i).io.nextLane := control.io.nextLane(i)
    for ((edgeId, localIdx) <- config.edgesByInput(i).zipWithIndex) {
      // Convert dense physical output indexing into the local sparse fork index.
      inputPorts(i).io.destMask(localIdx) := control.io.destMask(i)(
        config.edgeOutput(edgeId)
      )
      io.toOpm(edgeId) <> inputPorts(i).io.forkOutputs(localIdx)
    }
  }
}
