package NoC.stage1

import DataStruct.HS_Packet
import Router_Architecture.instantiation.{
  RouterL1WormholeMinimal,
  RouterL2WormholeMinimal
}
import chisel3._

/** Stage1 16-core NoC using single-lane/no-VC wormhole routers.
  *
  * The Verilog top module intentionally remains `NoC_16nodes` so the existing
  * AsyncNoC AXI wrapper can be reused. The wrapper exposes four top ports; this
  * Stage1 topology has one real L2 parent lane and keeps top ports 1..3 idle.
  */
class NoC_16nodes extends Module {
  private val topCompatPorts = 4

  val io = IO(new Bundle {
    val core_inputs = Vec(16, new HS_Packet)
    val core_outputs = Flipped(Vec(16, new HS_Packet))
    val top_input = Vec(topCompatPorts, new HS_Packet)
    val top_output = Flipped(Vec(topCompatPorts, new HS_Packet))
    val debug = Output(new Bundle {
      val l1InputValid = Vec(4, UInt(5.W))
      val l1OutputValid = Vec(4, UInt(5.W))
      val l1ContextActive = Vec(4, UInt(5.W))
      val l1Winner = Vec(4, UInt(5.W))
      val l1Commit = Vec(4, UInt(5.W))
      val l1CommitReady = Vec(4, UInt(5.W))
      val l1CommitRaw = Vec(4, Bool())
      val l1GlobalCommitEvent = Vec(4, Bool())
      val l1CommitConflict = Vec(4, UInt(5.W))
      val l1OutputWinner = Vec(4, Vec(5, UInt(5.W)))
      val l1GrantedAll = Vec(4, UInt(5.W))
      val l1RequestMask = Vec(4, Vec(5, UInt(5.W)))
      val l1OutputHolder = Vec(4, Vec(5, UInt(3.W)))
      val l1InputSlotReq = Vec(4, UInt(5.W))
      val l1InputSlotAck = Vec(4, UInt(5.W))
      val l1OutputSlotReq = Vec(4, UInt(5.W))
      val l1OutputSlotAck = Vec(4, UInt(5.W))
      val l2InputValid = UInt(5.W)
      val l2OutputValid = UInt(5.W)
      val l2ContextActive = UInt(5.W)
      val l2Winner = UInt(5.W)
      val l2Commit = UInt(5.W)
      val l2CommitReady = UInt(5.W)
      val l2CommitRaw = Bool()
      val l2GlobalCommitEvent = Bool()
      val l2CommitConflict = UInt(5.W)
      val l2OutputWinner = Vec(5, UInt(5.W))
      val l2GrantedAll = UInt(5.W)
      val l2RequestMask = Vec(5, UInt(5.W))
      val l2OutputHolder = Vec(5, UInt(3.W))
      val l2InputSlotReq = UInt(5.W)
      val l2InputSlotAck = UInt(5.W)
      val l2OutputSlotReq = UInt(5.W)
      val l2OutputSlotAck = UInt(5.W)
      val linkL1ParentOutReq = Vec(4, Bool())
      val linkL1ParentOutAck = Vec(4, Bool())
      val linkL1ParentOutData = Vec(4, UInt(28.W))
      val linkL2ChildOutReq = Vec(4, Bool())
      val linkL2ChildOutAck = Vec(4, Bool())
      val linkL2ChildOutData = Vec(4, UInt(28.W))
      val linkL2ParentInReq = Bool()
      val linkL2ParentInAck = Bool()
      val linkL2ParentInData = UInt(28.W)
      val linkL2ParentOutReq = Bool()
      val linkL2ParentOutAck = Bool()
      val linkL2ParentOutData = UInt(28.W)
    })
  })

  private def zeroPacket = 0.U.asTypeOf(io.top_output(0).Data)

  val routerl1 = Seq.tabulate(2, 2) { (x, y) =>
    Module(new RouterL1WormholeMinimal(x, y))
  }
  val routerl2 = Module(new RouterL2WormholeMinimal(0, 0))

  for (x <- 0 until 2) {
    for (y <- 0 until 2) {
      for (dir <- 0 until 4) {
        val a = (~dir) & 0x3
        val a1 = (a >> 1) & 0x1
        val a0 = a & 0x1
        val coreIdx = 2 * x + a1 + 4 * (2 * y + a0)
        routerl1(x)(y).io.inputs.child(dir)(0) <> io.core_inputs(coreIdx)
        routerl1(x)(y).io.outputs.child(dir)(0) <> io.core_outputs(coreIdx)
      }
    }
  }

  for (dir <- 0 until 4) {
    val a = (~dir) & 0x3
    val a1 = (a >> 1) & 0x1
    val a0 = a & 0x1
    routerl2.io.inputs.child(dir)(0) <> routerl1(a1)(a0).io.outputs.parent(0)
    routerl2.io.outputs.child(dir)(0) <> routerl1(a1)(a0).io.inputs.parent(0)
  }

  routerl2.io.inputs.parent(0) <> io.top_input(0)
  routerl2.io.outputs.parent(0) <> io.top_output(0)

  for (p <- 1 until topCompatPorts) {
    io.top_input(p).HS.Ack := io.top_input(p).HS.Req
    io.top_output(p).HS.Req := io.top_output(p).HS.Ack
    io.top_output(p).Data := zeroPacket
  }

  for (x <- 0 until 2) {
    for (y <- 0 until 2) {
      val idx = x * 2 + y
      val r = routerl1(x)(y)
      io.debug.l1InputValid(idx) := r.io.probe.inputValid.asUInt
      io.debug.l1OutputValid(idx) := r.io.probe.outputValid.asUInt
      io.debug.l1ContextActive(idx) := r.io.probe.contextActive.asUInt
      io.debug.l1Winner(idx) := r.io.probe.winner.asUInt
      io.debug.l1Commit(idx) := r.io.probe.commit.asUInt
      io.debug.l1CommitReady(idx) := r.io.probe.commitReady.asUInt
      io.debug.l1CommitRaw(idx) := r.io.probe.commitRaw
      io.debug.l1GlobalCommitEvent(idx) := r.io.probe.globalCommitEvent
      io.debug.l1CommitConflict(idx) := r.io.probe.commitConflict.asUInt
      io.debug.l1GrantedAll(idx) := r.io.probe.grantedAll.asUInt
      io.debug.l1InputSlotReq(idx) := r.io.probe.inputSlotReq.asUInt
      io.debug.l1InputSlotAck(idx) := r.io.probe.inputSlotAck.asUInt
      io.debug.l1OutputSlotReq(idx) := r.io.probe.outputSlotReq.asUInt
      io.debug.l1OutputSlotAck(idx) := r.io.probe.outputSlotAck.asUInt
      for (p <- 0 until 5) {
        io.debug.l1RequestMask(idx)(p) := r.io.probe.requestMask(p)
        io.debug.l1OutputHolder(idx)(p) := r.io.probe.outputHolder(p)
        io.debug.l1OutputWinner(idx)(p) := r.io.probe.outputWinner(p)
      }
    }
  }
  io.debug.l2InputValid := routerl2.io.probe.inputValid.asUInt
  io.debug.l2OutputValid := routerl2.io.probe.outputValid.asUInt
  io.debug.l2ContextActive := routerl2.io.probe.contextActive.asUInt
  io.debug.l2Winner := routerl2.io.probe.winner.asUInt
  io.debug.l2Commit := routerl2.io.probe.commit.asUInt
  io.debug.l2CommitReady := routerl2.io.probe.commitReady.asUInt
  io.debug.l2CommitRaw := routerl2.io.probe.commitRaw
  io.debug.l2GlobalCommitEvent := routerl2.io.probe.globalCommitEvent
  io.debug.l2CommitConflict := routerl2.io.probe.commitConflict.asUInt
  io.debug.l2GrantedAll := routerl2.io.probe.grantedAll.asUInt
  io.debug.l2InputSlotReq := routerl2.io.probe.inputSlotReq.asUInt
  io.debug.l2InputSlotAck := routerl2.io.probe.inputSlotAck.asUInt
  io.debug.l2OutputSlotReq := routerl2.io.probe.outputSlotReq.asUInt
  io.debug.l2OutputSlotAck := routerl2.io.probe.outputSlotAck.asUInt
  for (p <- 0 until 5) {
    io.debug.l2RequestMask(p) := routerl2.io.probe.requestMask(p)
    io.debug.l2OutputHolder(p) := routerl2.io.probe.outputHolder(p)
    io.debug.l2OutputWinner(p) := routerl2.io.probe.outputWinner(p)
  }
  for (dir <- 0 until 4) {
    val a = (~dir) & 0x3
    val a1 = (a >> 1) & 0x1
    val a0 = a & 0x1
    io.debug.linkL1ParentOutReq(dir) := routerl1(a1)(a0).io.outputs.parent(0).HS.Req
    io.debug.linkL1ParentOutAck(dir) := routerl1(a1)(a0).io.outputs.parent(0).HS.Ack
    io.debug.linkL1ParentOutData(dir) := routerl1(a1)(a0).io.outputs.parent(0).Data.flit
    io.debug.linkL2ChildOutReq(dir) := routerl2.io.outputs.child(dir)(0).HS.Req
    io.debug.linkL2ChildOutAck(dir) := routerl2.io.outputs.child(dir)(0).HS.Ack
    io.debug.linkL2ChildOutData(dir) := routerl2.io.outputs.child(dir)(0).Data.flit
  }
  io.debug.linkL2ParentInReq := routerl2.io.inputs.parent(0).HS.Req
  io.debug.linkL2ParentInAck := routerl2.io.inputs.parent(0).HS.Ack
  io.debug.linkL2ParentInData := routerl2.io.inputs.parent(0).Data.flit
  io.debug.linkL2ParentOutReq := routerl2.io.outputs.parent(0).HS.Req
  io.debug.linkL2ParentOutAck := routerl2.io.outputs.parent(0).HS.Ack
  io.debug.linkL2ParentOutData := routerl2.io.outputs.parent(0).Data.flit
}
