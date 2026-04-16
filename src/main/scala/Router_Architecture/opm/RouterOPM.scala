package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._

/**
 * Output processing module.
 *
 * The OPM instantiates one output-port controller per physical lane and wires
 * each of them only to the legal sparse edge set that can reach that lane.
 */
class RouterOPM(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val fromIpm = Vec(config.edgeCount, new HS_Packet)
    val outputs = Flipped(new RouterDirGroupedHSIO(config.childLanes, config.parentLanes))

    val holder = Output(Vec(config.totalPorts, UInt(config.holderW.W)))
    val anyPending = Output(Vec(config.totalPorts, Bool()))
  })

  private def outPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.outputs.child(d)(l) else io.outputs.parent(l)
  }

  private val outputPorts = Seq.tabulate(config.totalPorts) { o =>
    Module(new RouterOutputPortModule(config, config.edgesByOutput(o).map(edgeId => config.edgeInput(edgeId))))
  }
  for (o <- 0 until config.totalPorts) {
    outputPorts(o).io.out <> outPort(o)
  }
  for (o <- 0 until config.totalPorts) {
    for ((edgeId, localIdx) <- config.edgesByOutput(o).zipWithIndex) {
      // Translate the global sparse edge id into this output port's local input list.
      outputPorts(o).io.inputs(localIdx) <> io.fromIpm(edgeId)
    }
    io.holder(o) := outputPorts(o).io.holder
    io.anyPending(o) := outputPorts(o).io.anyPending
  }
}
