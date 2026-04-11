package Router_Architecture.core

import DataStruct._
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import Router_Architecture.ipm.RouterIPM
import Router_Architecture.opm.RouterOPM
import chisel3._

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

  ipm.io.inputs <> io.inputs
  opm.io.outputs <> io.outputs

  for (o <- 0 until config.totalPorts) {
    for (i <- 0 until config.totalPorts) {
      opm.io.fromIpm(o)(i) <> ipm.io.toOpm(i)(o)
    }
  }

  ipm.io.opmHolder := opm.io.holder
  ipm.io.opmAnyPending := opm.io.anyPending
}
