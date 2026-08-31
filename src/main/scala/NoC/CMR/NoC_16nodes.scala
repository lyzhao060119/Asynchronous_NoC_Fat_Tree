package NoC.CMR

import DataStruct.HS_Packet
import Router_Architecture.CMR.CMRRouter
import Router_Architecture.common.{AsyncFifo, AsyncFifoLike, CircularFifo}
import chisel3._
import tool.AsyncDelay

/**
  * Wrapper-compatible 16-core CMR NoC.
  *
  * The physical core, quadrant and inter-level FIFO mapping is intentionally
  * identical to NoC.ultra.NoC_16nodes so the same remote TAB/VCTM harness and
  * case files can be used without translation.
  *
  * Set CMR_USE_CIRCULAR_FIFO=1 to replace the inter-level AsyncFifo chain with
  * the Transition-paper circular FIFO. Circular mode is selected only on the
  * existing depth-three links; the unmodified four-slot paper FIFO can retain
  * four flits internally.
  *
  * Set CMR_BYPASS_INTERLEVEL_FIFO=1 to omit those eight links and wire each
  * L1 parent port directly to the matching L2 child port. Bypass takes
  * priority over CircularFIFO and is a diagnostic topology, not a product
  * configuration.
  */
class NoC_16nodes(interLevelFifoDepth: Int = 3) extends Module {
  require(interLevelFifoDepth >= 1)
  private val topCompatPorts = 4
  private val bypassInterLevelFifo = sys.env.get("CMR_BYPASS_INTERLEVEL_FIFO").contains("1")
  private val circularFifoRequested =
    !bypassInterLevelFifo && sys.env.get("CMR_USE_CIRCULAR_FIFO").contains("1")
  require(!circularFifoRequested || interLevelFifoDepth == 3,
    s"Transition CircularFIFO is enabled only for existing depth-three links, got $interLevelFifoDepth")

  val io = IO(new Bundle {
    val core_inputs = Vec(16, new HS_Packet)
    val core_outputs = Flipped(Vec(16, new HS_Packet))
    val top_input = Vec(topCompatPorts, new HS_Packet)
    val top_output = Flipped(Vec(topCompatPorts, new HS_Packet))
  })

  private val routerL1 = Seq.tabulate(2, 2) { (x, y) =>
    Module(new CMRRouter(xCoordinate = x, yCoordinate = y, routerLevel = 1))
  }
  private val routerL2 =
    Module(new CMRRouter(xCoordinate = 0, yCoordinate = 0, routerLevel = 2))

  private def interLevelFifo(depth: Int): AsyncFifoLike =
    if (circularFifoRequested) Module(new CircularFifo(compatibilityDepth = depth))
    else Module(new AsyncFifo(depth, AsyncDelay.FifoDfire))

  private val upwardLinkFifos =
    if (bypassInterLevelFifo) Seq.empty else Seq.fill(4)(interLevelFifo(interLevelFifoDepth))
  private val downwardLinkFifos =
    if (bypassInterLevelFifo) Seq.empty else Seq.fill(4)(interLevelFifo(interLevelFifoDepth))

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

  for (dir <- 0 until 4) {
    val selector = (~dir) & 0x3
    val l1X = (selector >> 1) & 0x1
    val l1Y = selector & 0x1
    if (bypassInterLevelFifo) {
      routerL1(l1X)(l1Y).io.outputs.parent(0) <> routerL2.io.inputs.child(dir)(0)
      routerL2.io.outputs.child(dir)(0) <> routerL1(l1X)(l1Y).io.inputs.parent(0)
    } else {
      upwardLinkFifos(dir).io.enq <> routerL1(l1X)(l1Y).io.outputs.parent(0)
      upwardLinkFifos(dir).io.deq <> routerL2.io.inputs.child(dir)(0)
      downwardLinkFifos(dir).io.enq <> routerL2.io.outputs.child(dir)(0)
      downwardLinkFifos(dir).io.deq <> routerL1(l1X)(l1Y).io.inputs.parent(0)
    }
  }

  routerL2.io.inputs.parent(0) <> io.top_input(0)
  routerL2.io.outputs.parent(0) <> io.top_output(0)

  private val zeroPacket = 0.U.asTypeOf(io.top_output(0).Data)
  for (port <- 1 until topCompatPorts) {
    io.top_input(port).HS.Ack := io.top_input(port).HS.Req
    io.top_output(port).HS.Req := io.top_output(port).HS.Ack
    io.top_output(port).Data := zeroPacket
  }
}

object CMRNoC16Main extends App {
  emitVerilog(new NoC_16nodes, Array("--target-dir", "generated_cmr/noc16"))
}
