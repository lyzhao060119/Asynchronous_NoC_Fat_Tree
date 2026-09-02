package Router_Architecture.sync_cmr

import DataStruct.PacketLayout
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SyncCmrRouterHopLatencySpec extends AnyFlatSpec with ChiselScalatestTester {
  private val FlitsPerPacket = 5

  private def packFlit(
      head: Boolean,
      tail: Boolean,
      id: Int,
      x: Int,
      y: Int
  ): BigInt = {
    var bits = BigInt(id & 0x3)
    bits |= BigInt(x & 0x3f) << PacketLayout.X0Lo
    bits |= BigInt(y & 0x3f) << PacketLayout.Y0Lo
    bits |= BigInt(x & 0x3f) << PacketLayout.X1Lo
    bits |= BigInt(y & 0x3f) << PacketLayout.Y1Lo
    if (tail) bits |= BigInt(1) << PacketLayout.IsTailIndex
    if (head) bits |= BigInt(1) << PacketLayout.IsHeadIndex
    bits
  }

  private def packetFlits(id: Int, x: Int, y: Int): Seq[BigInt] =
    Seq.tabulate(FlitsPerPacket) { index =>
      packFlit(
        head = index == 0,
        tail = index == FlitsPerPacket - 1,
        id = id,
        x = x,
        y = y
      )
    }

  private def pokeAllInputsIdle(
      dut: SyncCmrRouter,
      childLanes: Int,
      parentLanes: Int
  ): Unit = {
    for (direction <- 0 until 4; lane <- 0 until childLanes) {
      dut.io.inputs.child(direction)(lane).hs.valid.poke(false.B)
      dut.io.inputs.child(direction)(lane).data.flit.poke(0.U)
    }
    for (lane <- 0 until parentLanes) {
      dut.io.inputs.parent(lane).hs.valid.poke(false.B)
      dut.io.inputs.parent(lane).data.flit.poke(0.U)
    }
  }

  private def pokeAllOutputReadys(
      dut: SyncCmrRouter,
      childLanes: Int,
      parentLanes: Int,
      value: Boolean
  ): Unit = {
    for (direction <- 0 until 4; lane <- 0 until childLanes) {
      dut.io.outputs.child(direction)(lane).hs.ready.poke(value.B)
    }
    for (lane <- 0 until parentLanes) {
      dut.io.outputs.parent(lane).hs.ready.poke(value.B)
    }
  }

  private def parentValidLane(dut: SyncCmrRouter, parentLanes: Int): Option[Int] =
    (0 until parentLanes).find { lane =>
      dut.io.outputs.parent(lane).hs.valid.peek().litToBoolean
    }

  private def childValidLane(
      dut: SyncCmrRouter,
      direction: Int,
      childLanes: Int
  ): Option[Int] =
    (0 until childLanes).find { lane =>
      dut.io.outputs.child(direction)(lane).hs.valid.peek().litToBoolean
    }

  private def fireAndExpectParent(
      dut: SyncCmrRouter,
      parentLanes: Int,
      bits: BigInt
  ): Unit = {
    val ingress = dut.io.inputs.child(0)(0)
    var guard = 0
    while (!ingress.hs.ready.peek().litToBoolean && guard < 64) {
      dut.clock.step()
      guard += 1
    }
    assert(ingress.hs.ready.peek().litToBoolean, "input ready timeout")
    ingress.data.flit.poke(bits.U)
    ingress.hs.valid.poke(true.B)
    dut.clock.step()
    ingress.hs.valid.poke(false.B)
    val lane = parentValidLane(dut, parentLanes)
    assert(lane.nonEmpty, "flit did not appear on parent the cycle after fire")
    assert(
      dut.io.outputs.parent(lane.get).data.flit.peek().litValue == bits,
      "parent output data mismatch"
    )
    dut.clock.step()
  }

  private def runIsolated(
      childLanes: Int,
      parentLanes: Int,
      level: Int,
      destX: Int,
      destY: Int
  ): Unit = {
    test(new SyncCmrRouter(0, 0, level, childLanes, parentLanes)) { dut =>
      dut.clock.setTimeout(500)
      pokeAllInputsIdle(dut, childLanes, parentLanes)
      pokeAllOutputReadys(dut, childLanes, parentLanes, value = true)
      dut.reset.poke(true.B)
      dut.clock.step(4)
      dut.reset.poke(false.B)
      dut.clock.step(4)

      packetFlits(id = 1, x = destX, y = destY).foreach { bits =>
        fireAndExpectParent(dut, parentLanes, bits)
      }
      packetFlits(id = 2, x = destX, y = destY).foreach { bits =>
        fireAndExpectParent(dut, parentLanes, bits)
      }
    }
  }

  "Sync Thin (1,1)" should "forward isolated 5-flit packets in one clock per flit" in {
    runIsolated(childLanes = 1, parentLanes = 1, level = 1, destX = 8, destY = 8)
  }

  "Sync PROP (2,2)" should "forward isolated 5-flit packets in one clock per flit" in {
    runIsolated(childLanes = 2, parentLanes = 2, level = 2, destX = 8, destY = 8)
  }

  "Sync PROP (2,2)" should "drain two 1-flit packets that contend for the same child OPM" in {
    test(new SyncCmrRouter(0, 0, 2, 2, 2)) { dut =>
      dut.clock.setTimeout(400)
      pokeAllInputsIdle(dut, childLanes = 2, parentLanes = 2)
      pokeAllOutputReadys(dut, childLanes = 2, parentLanes = 2, value = true)
      dut.reset.poke(true.B)
      dut.clock.step(4)
      dut.reset.poke(false.B)
      dut.clock.step(4)

      val parentFlit = packFlit(head = true, tail = true, id = 1, x = 2, y = 2)
      val childFlit = packFlit(head = true, tail = true, id = 2, x = 2, y = 2)
      val parentIn = dut.io.inputs.parent(0)
      val childIn = dut.io.inputs.child(1)(0)
      var sentParent = false
      var sentChild = false
      var gotParent = false
      var gotChild = false
      var cycles = 0

      while ((!gotParent || !gotChild) && cycles < 64) {
        val driveParent = !sentParent && parentIn.hs.ready.peek().litToBoolean
        val driveChild = !sentChild && childIn.hs.ready.peek().litToBoolean
        if (driveParent) {
          parentIn.data.flit.poke(parentFlit.U)
          parentIn.hs.valid.poke(true.B)
        } else {
          parentIn.hs.valid.poke(false.B)
        }
        if (driveChild) {
          childIn.data.flit.poke(childFlit.U)
          childIn.hs.valid.poke(true.B)
        } else {
          childIn.hs.valid.poke(false.B)
        }

        dut.clock.step()

        if (driveParent) sentParent = true
        if (driveChild) sentChild = true
        parentIn.hs.valid.poke(false.B)
        childIn.hs.valid.poke(false.B)

        for (lane <- 0 until 2) {
          if (dut.io.outputs.child(0)(lane).hs.valid.peek().litToBoolean) {
            val bits = dut.io.outputs.child(0)(lane).data.flit.peek().litValue
            if (bits == parentFlit) gotParent = true
            if (bits == childFlit) gotChild = true
          }
        }
        cycles += 1
      }

      assert(gotParent, s"parent 1-flit packet stuck after $cycles cycles")
      assert(gotChild, s"child 1-flit packet stuck after $cycles cycles")
    }
  }
}
