package Router_Architecture.common

import DataStruct._
import chisel3._
import chisel3.util.HasBlackBoxResource

/** Black-box wrapper for the Transition paper Fig. 6 circular FIFO.
  *
  * The underlying Verilog implements Fig. 7(a) Write Control Blocks and
  * Fig. 7(b) Read Control Blocks. The paper ring has four physical slots and
  * the unmodified Fig. 6/7 equations accept four flits. `compatibilityDepth`
  * remains 3 only to select it at existing NoC links configured as depth-3.
  */
class CircularFifoBlackBox(
    compatibilityDepth: Int = 3,
    flitLength: Int = 28
) extends BlackBox(Map("DEPTH" -> 4, "FLIT_LENGTH" -> flitLength))
    with HasBlackBoxResource {

  require(compatibilityDepth == 3,
    s"Transition Fig. 6 CircularFifo is enabled only for existing depth-3 links, got $compatibilityDepth")

  override def desiredName: String = "CircularFIFO"

  val io = IO(new Bundle {
    val reset    = Input(Bool())
    val Reqin    = Input(Bool())
    val Ackin    = Input(Bool())
    val Data_in  = Input(UInt(flitLength.W))
    val Ackout   = Output(Bool())
    val Reqout   = Output(Bool())
    val Data_out = Output(UInt(flitLength.W))
  })

  addResource("/ASYNC/CMR/CircularFIFO.v")
  addResource("/ASYNC/CMR/WriteControlBlock.v")
  addResource("/ASYNC/CMR/ReadControlBlock.v")
  addResource("/ASYNC/CMR/CircularWriteCounter.v")
  addResource("/ASYNC/CMR/CircularReadCounter.v")
  addResource("/ASYNC/CMR/PhaseResetDLatch.v")
  addResource("/ASYNC/DLatchBank.v")
}

/** Drop-in replacement for AsyncFifo using the Transition circular FIFO.
  *
  * Exposes the same two-phase bundled-data `HS_Packet` interface so it can
  * be swapped into the CMR inter-level link positions.
  */
class CircularFifo(
    compatibilityDepth: Int = 3
) extends AsyncFifoLike {

  require(compatibilityDepth == 3,
    s"Transition Fig. 6 CircularFifo is enabled only for existing depth-3 links, got $compatibilityDepth")

  private val bb = Module(new CircularFifoBlackBox(compatibilityDepth = compatibilityDepth))

  bb.io.reset   := reset.asBool
  bb.io.Reqin   := io.enq.HS.Req
  bb.io.Data_in := io.enq.Data.flit
  io.enq.HS.Ack := bb.io.Ackout

  io.deq.HS.Req := bb.io.Reqout
  io.deq.Data.flit := bb.io.Data_out
  bb.io.Ackin   := io.deq.HS.Ack
}
