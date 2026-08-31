package Router_Architecture.ultra
import chisel3._
import chisel3.util.HasBlackBoxResource

class ReqGenAsymC3 extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "MullerC3"
  val io = IO(new Bundle {
    val reset = Input(Bool()); val Grant = Input(Bool()); val Done = Input(Bool())
    val MG = Input(Bool()); val PPE = Output(Bool())
  })
  addResource("/ASYNC/MullerC3.v")
}

class MousetrapV1(width: Int) extends BlackBox(Map("WIDTH" -> width)) with HasBlackBoxResource {
  override def desiredName: String = "MousetrapStage"
  val io = IO(new Bundle {
    val reset = Input(Bool()); val ReqIn = Input(Bool()); val DataIn = Input(UInt(width.W))
    val ReqX = Output(Bool()); val AckX = Input(Bool()); val DataOut = Output(UInt(width.W))
    val PRSReady = Input(Bool())
  })
  addResource("/ASYNC/MousetrapStage.v"); addResource("/ASYNC/DLatchBank.v")
}
