package NoC

import chisel3._

/** Emits the Stage1 single-lane/no-VC NoC16 with Verilog top module
  * `NoC_16nodes`.
  */
object NoC_16nodesWormholeMinimal extends App {
  val targetDir =
    args
      .sliding(2)
      .find(_.headOption.contains("--target-dir"))
      .flatMap(_.lift(1))
      .getOrElse("generated_stage1")

  println(
    "NoC_16nodesWormholeMinimal generated " +
      "(Stage1 single-lane/no-VC, top ports 1..3 idle)"
  )
  emitVerilog(
    new stage1.NoC_16nodes,
    Array("--target-dir", targetDir)
  )
}
