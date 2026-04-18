package Router_Architecture.common

import DataStruct._
import chisel3._

/**
 * Replicates one input packet to a masked set of output channels.
 *
 * The fork launches all selected outputs together and only acknowledges the
 * input once every selected branch has completed its handshake.
 */
class AsyncFork(val outN: Int) extends Module {
  require(outN >= 1)

  val io = IO(new Bundle {
    val in         = new HS_Packet
    val destMask   = Input(Vec(outN, Bool())) // one bit per legal output edge
    val out        = Vec(outN, Flipped(new HS_Packet))
    val launch     = Output(Bool()) // launch pulse seen by route-state logic
    val launch_clock = Output(Clock())
    val fire       = Output(Bool()) // completion pulse after all branches finish
    val fire_clock = Output(Clock())
  })

  private val requestBlock = Module(new AsyncForkRequestBlock(outN))
  private val ackJoin = Module(new AsyncForkAckJoinBlock)

  requestBlock.io.inReq := io.in.HS.Req
  requestBlock.io.inAck := ackJoin.io.inAck
  requestBlock.io.destMask := io.destMask

  for (j <- 0 until outN) {
    requestBlock.io.outAck(j) := io.out(j).HS.Ack
    io.out(j).HS.Req := requestBlock.io.outReq(j)
    io.out(j).Data := io.in.Data
  }

  ackJoin.io.inReq := io.in.HS.Req
  ackJoin.io.forkBusy := requestBlock.io.forkBusy
  ackJoin.io.pendingAny := requestBlock.io.pendingAny

  io.in.HS.Ack := ackJoin.io.inAck
  io.launch := requestBlock.io.launch
  io.launch_clock := requestBlock.io.launch_clock
  io.fire := ackJoin.io.fire
  io.fire_clock := ackJoin.io.fire_clock
}
