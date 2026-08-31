package Router_Architecture.core

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import Router_Architecture.ipm.RouterIPM
import Router_Architecture.opm.RouterOPM
import chisel3._

/**
 * Core router shell that wires the input processing module (IPM) to the
 * output processing module (OPM) through the sparse internal edge set.
 */
class RouterCoreModule(
  config: RouterModuleConfig,
  computeHeadRouting: (Packet, Bool, UInt) => Vec[Bool]
) extends Module {
  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(config.childLanes, config.parentLanes)
    val outputs = Flipped(new RouterDirGroupedHSIO(config.childLanes, config.parentLanes))
  })

  private val ipm = Module(new RouterIPM(config, computeHeadRouting))
  private val opm = Module(new RouterOPM(config))

  private def outPort(idx: Int): HS_Packet = {
    val d = config.dirOfPhys(idx)
    val l = config.laneOfPhys(idx)
    if (d < 4) io.outputs.child(d)(l) else io.outputs.parent(l)
  }

  ipm.io.inputs <> io.inputs
  opm.io.outputs <> io.outputs

  // Connect only the legal sparse edges rather than a full dense cross-connect.
  for (edgeId <- 0 until config.edgeCount) {
    opm.io.fromIpm(edgeId) <> ipm.io.toOpm(edgeId)
  }

  ipm.io.opmHolder := opm.io.holder
  for (o <- 0 until config.totalPorts) {
    // Toggle handshake: channel empty when Req and Ack share the same phase.
    ipm.io.opmOutEmpty(o) := outPort(o).HS.Req === outPort(o).HS.Ack
  }
}
