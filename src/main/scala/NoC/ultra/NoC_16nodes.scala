package NoC.ultra

import DataStruct.HS_Packet
import Router_Architecture.common.AsyncFifo
import Router_Architecture.ultra.UltraRouter
import chisel3._
import tool.AsyncDelay

/**
  * Wrapper-compatible 16-core Ultra NoC.
  *
  * Four level-1 routers connect the 4x4 core grid to one level-2 router.
  * Ultra currently provides one parent lane, so wrapper top port 0 is the
  * physical L2 parent and compatibility ports 1..3 are kept idle.
  */
class NoC_16nodes(interLevelFifoDepth: Int = 3) extends Module {
  require(interLevelFifoDepth >= 1)
  private val topCompatPorts = 4

  val io = IO(new Bundle {
    val core_inputs = Vec(16, new HS_Packet)
    val core_outputs = Flipped(Vec(16, new HS_Packet))
    val top_input = Vec(topCompatPorts, new HS_Packet)
    val top_output = Flipped(Vec(topCompatPorts, new HS_Packet))
  })

  private val routerL1 = Seq.tabulate(2, 2) { (x, y) =>
    Module(new UltraRouter(xCoordinate = x, yCoordinate = y, routerLevel = 1))
  }
  private val routerL2 =
    Module(new UltraRouter(xCoordinate = 0, yCoordinate = 0, routerLevel = 2))
  private val upwardLinkFifos =
    Seq.fill(4)(Module(new AsyncFifo(interLevelFifoDepth, AsyncDelay.FifoDfire)))
  private val downwardLinkFifos =
    Seq.fill(4)(Module(new AsyncFifo(interLevelFifoDepth, AsyncDelay.FifoDfire)))

  // Preserve the existing NoC16 physical-core/direction mapping.
  for (x <- 0 until 2) {
    for (y <- 0 until 2) {
      for (dir <- 0 until 4) {
        val selector = (~dir) & 0x3
        val localX = (selector >> 1) & 0x1
        val localY = selector & 0x1
        val core = 2 * x + localX + 4 * (2 * y + localY)
        routerL1(x)(y).io.inputs.child(dir)(0) <> io.core_inputs(core)
        routerL1(x)(y).io.outputs.child(dir)(0) <> io.core_outputs(core)
      }
    }
  }

  // Preserve the existing L1-to-L2 quadrant/direction mapping.  A complete
  // 3-flit validation packet fits in each inter-level FIFO.  This decouples
  // an L2 downward multicast from an L1 packet simultaneously holding a local
  // branch while waiting upward, breaking the otherwise possible wormhole
  // dependency cycle without adding a lane or virtual channel.  For a system
  // with longer maximum packets this depth must be raised accordingly.
  for (dir <- 0 until 4) {
    val selector = (~dir) & 0x3
    val l1X = (selector >> 1) & 0x1
    val l1Y = selector & 0x1
    upwardLinkFifos(dir).io.enq <> routerL1(l1X)(l1Y).io.outputs.parent(0)
    upwardLinkFifos(dir).io.deq <> routerL2.io.inputs.child(dir)(0)
    downwardLinkFifos(dir).io.enq <> routerL2.io.outputs.child(dir)(0)
    downwardLinkFifos(dir).io.deq <> routerL1(l1X)(l1Y).io.inputs.parent(0)
  }

  routerL2.io.inputs.parent(0) <> io.top_input(0)
  routerL2.io.outputs.parent(0) <> io.top_output(0)

  // The existing AXI wrapper exposes four top ports. Ultra has one real L2
  // parent lane; unused compatibility inputs are acknowledged and outputs stay
  // empty in the two-phase toggle protocol.
  private val zeroPacket = 0.U.asTypeOf(io.top_output(0).Data)
  for (port <- 1 until topCompatPorts) {
    io.top_input(port).HS.Ack := io.top_input(port).HS.Req
    io.top_output(port).HS.Req := io.top_output(port).HS.Ack
    io.top_output(port).Data := zeroPacket
  }
}

object UltraNoC16Main extends App {
  emitVerilog(
    new NoC_16nodes,
    Array("--target-dir", "generated_ultra")
  )
}
