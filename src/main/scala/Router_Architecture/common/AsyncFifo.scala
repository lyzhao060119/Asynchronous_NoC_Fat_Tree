package Router_Architecture.common

import DataStruct._
import chisel3._

class AsyncFifo(val depth: Int) extends Module {
  require(depth >= 1)
  val io = IO(new Bundle {
    val enq = new HS_Packet // sink
    val deq = Flipped(new HS_Packet) // source
  })

  val stages = Seq.fill(depth)(Module(new AsyncStage))

  // 串接 stages
  for (k <- 0 until depth - 1) {
    val p = stages(k).io.out
    val c = stages(k + 1).io.in
    p <> c
  }

  // enq -> stage0
  stages.head.io.in <> io.enq

  // last -> deq
  stages.last.io.out <> io.deq
}

//object AsyncFifo extends App {
//  (new chisel3.stage.ChiselStage).execute(
//    Array("-X", "verilog"),
//    Seq(ChiselGeneratorAnnotation(() => new AsyncFifo(3)),
//      TargetDirAnnotation("Outputs/FIFO"))
//  )
//}