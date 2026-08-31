package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._

/** Gates multicast request masks until all requested outputs can accept a flit.
  *
  * This mirrors the synchronous router's head/body-tail eligibility checks:
  * head flits require free outputs, while body/tail flits require outputs held
  * by the requesting input and ready to accept the next flit.
  *
  * canConnect is folded as elaboration-time constants (Scheme 5). Higher
  * priority head blocking is kept as a protocol guard for interleaved
  * head/body/tail traffic even though LaneReservation handles lane allocation.
  */
class InputEligibilityModule(config: RouterModuleConfig) extends Module {
  private val noneLiteral = config.noneValue.U(config.holderW.W)

  val io = IO(new Bundle {
    val inValid = Input(Vec(config.totalPorts, Bool()))
    val isHead = Input(Vec(config.totalPorts, Bool()))
    val requestMask =
      Input(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
    val headWantedMask =
      Input(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
    val storedMask =
      Input(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
    val holder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    val outEmpty = Input(Vec(config.totalPorts, Bool()))

    val destMask =
      Output(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
    val canLaunch = Output(Vec(config.totalPorts, Bool()))
  })

  private val holderFree = Wire(Vec(config.totalPorts, Bool()))
  private val selfHolds = Wire(Vec(config.totalPorts, Vec(config.totalPorts, Bool())))
  for (outIdx <- 0 until config.totalPorts) {
    holderFree(outIdx) := io.holder(outIdx) === noneLiteral
    for (i <- 0 until config.totalPorts) {
      selfHolds(i)(outIdx) := io.holder(outIdx) === i.U(config.holderW.W)
    }
  }

  private def otherOccupiesOutput(self: Int, outIdx: Int): Bool = {
    VecInit((0 until config.totalPorts).map { j =>
      if (j == self) {
        false.B
      } else {
        val higherPriorityHead =
          io.inValid(j) &&
            io.isHead(j) &&
            io.headWantedMask(j)(outIdx) &&
            (j < self).B
        val holderBlocks = selfHolds(j)(outIdx)
        higherPriorityHead || holderBlocks
      }
    }).asUInt.orR
  }

  for (i <- 0 until config.totalPorts) {
    val physIdx = config.physOfInput(i)
    val requestMask = Wire(Vec(config.totalPorts, Bool()))
    val headOutputReady = Wire(Vec(config.totalPorts, Bool()))
    val bodyTailOutputReady = Wire(Vec(config.totalPorts, Bool()))

    for (outIdx <- 0 until config.totalPorts) {
      requestMask(outIdx) :=
        io.requestMask(i)(outIdx) && config.canConnect(physIdx, outIdx).B
      headOutputReady(outIdx) :=
        !requestMask(outIdx) ||
          (holderFree(outIdx) &&
            io.outEmpty(outIdx) &&
            !otherOccupiesOutput(i, outIdx))
      bodyTailOutputReady(outIdx) :=
        !requestMask(outIdx) ||
          (selfHolds(i)(outIdx) && io.outEmpty(outIdx))
    }

    val headEligible =
      io.inValid(i) &&
        io.isHead(i) &&
        requestMask.asUInt.orR &&
        headOutputReady.asUInt.andR
    val bodyTailEligible =
      io.inValid(i) &&
        !io.isHead(i) &&
        requestMask.asUInt.orR &&
        bodyTailOutputReady.asUInt.andR

    io.canLaunch(i) := headEligible || bodyTailEligible

    when(io.canLaunch(i)) {
      io.destMask(i) := requestMask
    }.otherwise {
      io.destMask(i) := VecInit(Seq.fill(config.totalPorts)(false.B))
    }
  }
}
