package Router_Architecture.common

import DataStruct._
import chisel3._
import tool.AsyncDelay

/** Common two-phase bundled-data FIFO interface. */
abstract class AsyncFifoLike extends Module {
  val io = IO(new Bundle {
    val enq = new HS_Packet
    val deq = Flipped(new HS_Packet)
  })
}

/** A depth-N asynchronous FIFO built as a chain of AsyncStage modules. */
class AsyncFifo(
    val depth: Int,
    dfireDelayRole: String = AsyncDelay.DefaultRole
) extends AsyncFifoLike {
  require(depth >= 1)

  val stages = Seq.fill(depth)(Module(new AsyncStage(dfireDelayRole)))

  // Connect the stage chain from enqueue to dequeue.
  for (k <- 0 until depth - 1) {
    val p = stages(k).io.out
    val c = stages(k + 1).io.in
    p <> c
  }

  // Feed the first stage from the external enqueue channel.
  stages.head.io.in <> io.enq

  // Present the last stage as the dequeue channel.
  stages.last.io.out <> io.deq
}

//object AsyncFifo extends App {
//  (new chisel3.stage.ChiselStage).execute(
//    Array("-X", "verilog"),
//    Seq(ChiselGeneratorAnnotation(() => new AsyncFifo(3)),
//      TargetDirAnnotation("Outputs/FIFO"))
//  )
//}
