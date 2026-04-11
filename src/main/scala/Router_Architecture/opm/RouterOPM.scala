package Router_Architecture.opm

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._

class RouterOPM(config: RouterModuleConfig) extends Module {
  val io = IO(new Bundle {
    val fromIpm = Vec(config.totalPorts, Vec(config.totalPorts, new HS_Packet))
    val outputs = Flipped(new RouterDirGroupedHSIO(config.childLanes, config.parentLanes))

    val holder = Output(Vec(config.totalPorts, UInt(config.holderW.W)))
    val anyPending = Output(Vec(config.totalPorts, Bool()))
  })

  private def outPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.outputs.child(d)(l) else io.outputs.parent(l)
  }

  private val outputPorts = Seq.fill(config.totalPorts)(Module(new RouterOutputPortModule(config)))
  for (o <- 0 until config.totalPorts) {
    outputPorts(o).io.out <> outPort(o)
  }
  for (o <- 0 until config.totalPorts) {
    for (i <- 0 until config.totalPorts) {
      outputPorts(o).io.inputs(i) <> io.fromIpm(o)(i)
    }
    io.holder(o) := outputPorts(o).io.holder
    io.anyPending(o) := outputPorts(o).io.anyPending
  }
}
