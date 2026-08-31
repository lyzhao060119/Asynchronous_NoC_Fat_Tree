package Router_Architecture.ipm

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.{Mux1H, PopCount, log2Ceil}

/** Per-direction coordinated head lane allocation for the async router.
  *
  * Matches the synchronous PerDirHeadAllocator policy:
  * - eligible heads are ranked in RR order from priorityBase
  * - the r-th winner takes the r-th lowest-index free lane
  * - Scheme-5 folds canConnect as an elaboration-time constant per (input, dir)
  * - multicast is atomic: all wanted dirs must match or the input does not commit
  *
  * Same-direction conflicts are resolved here so OPM mutex is not the primary
  * lane-assignment mechanism.
  */
class LaneReservation(config: RouterModuleConfig) extends Module {
  private val nInputs = config.totalPorts
  private val nDirs = config.nDirs
  private val inputIdxW = math.max(1, log2Ceil(nInputs))
  private val noneLiteral = config.noneValue.U(config.holderW.W)
  private val rankW = math.max(1, log2Ceil(nInputs + 1))

  val io = IO(new Bundle {
    val inValid = Input(Vec(nInputs, Bool()))
    val isHead = Input(Vec(nInputs, Bool()))
    val currentDestVec =
      Input(Vec(nInputs, Vec(nDirs, Bool())))
    val holder = Input(Vec(config.totalPorts, UInt(config.holderW.W)))
    /** Highest-priority input index for RR (scan starts at this input). */
    val priorityBase = Input(UInt(inputIdxW.W))

    val headSelLane =
      Output(Vec(nInputs, Vec(nDirs, UInt(config.laneW.W))))
    val headAllocOk = Output(Vec(nInputs, Bool()))
  })

  /** Exclusive parallel prefix: out(i) = sum(bits[0..i)). */
  private def prefixRanks(bits: Vec[Bool], outW: Int): Vec[UInt] = {
    val n = bits.length
    if (n == 0) {
      VecInit(Seq.empty[UInt])
    } else {
      var cur = VecInit(bits.map(b => Mux(b, 1.U(outW.W), 0.U(outW.W))))
      var step = 1
      while (step < n) {
        val prev = cur
        val next = Wire(Vec(n, UInt(outW.W)))
        for (i <- 0 until n) {
          if (i >= step) {
            next(i) := prev(i) + prev(i - step)
          } else {
            next(i) := prev(i)
          }
        }
        cur = next
        step *= 2
      }
      val out = Wire(Vec(n, UInt(outW.W)))
      out(0) := 0.U
      for (i <- 1 until n) {
        out(i) := cur(i - 1)
      }
      out
    }
  }

  // scanOrder(o) = (priorityBase + o) % nInputs; offset 0 is highest priority.
  private val scanOrder = Wire(Vec(nInputs, UInt(inputIdxW.W)))
  for (o <- 0 until nInputs) {
    val sum = io.priorityBase +& o.U(inputIdxW.W)
    scanOrder(o) := Mux(
      sum >= nInputs.U,
      sum - nInputs.U(inputIdxW.W),
      sum
    )(inputIdxW - 1, 0)
  }

  private val orderOH = Wire(Vec(nInputs, Vec(nInputs, Bool())))
  for (o <- 0 until nInputs) {
    for (i <- 0 until nInputs) {
      orderOH(o)(i) := scanOrder(o) === i.U(inputIdxW.W)
    }
  }

  private val tentValid = Wire(Vec(nInputs, Vec(nDirs, Bool())))
  private val tentLane = Wire(Vec(nInputs, Vec(nDirs, UInt(config.laneW.W))))
  for (i <- 0 until nInputs) {
    for (d <- 0 until nDirs) {
      tentValid(i)(d) := false.B
      tentLane(i)(d) := 0.U
    }
  }

  for (d <- 0 until nDirs) {
    val laneCount = config.lanesPerDir(d)
    if (laneCount > 0) {
      val laneRankW =
        math.max(rankW, math.max(1, log2Ceil(laneCount + 1)))
      val freeInit = VecInit((0 until laneCount).map { l =>
        val outIdx = config.physIndex(d, l)
        io.holder(outIdx) === noneLiteral
      })
      val numFree = PopCount(freeInit.asUInt).asUInt
      val freePrefix = prefixRanks(freeInit, laneRankW)

      // Scheme 5: canConnect folded at elaboration, uniform across lanes in a dir.
      val connectOk = VecInit((0 until nInputs).map { i =>
        val outIdx0 = config.physIndex(d, 0)
        config.canConnect(config.physOfInput(i), outIdx0).B
      })

      val elig = VecInit((0 until nInputs).map { i =>
        io.inValid(i) && io.isHead(i) && io.currentDestVec(i)(d) && connectOk(i)
      })

      val eligOff = VecInit((0 until nInputs).map { o =>
        Mux1H(orderOH(o), elig)
      })
      val rankOff = prefixRanks(eligOff, laneRankW)

      val takeOff = Wire(Vec(nInputs, Bool()))
      val chosenOff = Wire(Vec(nInputs, UInt(config.laneW.W)))
      for (o <- 0 until nInputs) {
        val rank = rankOff(o)
        takeOff(o) := eligOff(o) && (rank < numFree)
        val laneMatch = VecInit((0 until laneCount).map { l =>
          freeInit(l) && (freePrefix(l) === rank)
        })
        chosenOff(o) := Mux1H(
          laneMatch,
          VecInit((0 until laneCount).map(_.U(config.laneW.W)))
        )
      }

      for (i <- 0 until nInputs) {
        val sel = VecInit((0 until nInputs).map { o =>
          orderOH(o)(i) && takeOff(o)
        })
        when(sel.asUInt.orR) {
          tentValid(i)(d) := true.B
          tentLane(i)(d) := Mux1H(sel, chosenOff)
        }
      }
    }
  }

  for (i <- 0 until nInputs) {
    val wantsAny = io.currentDestVec(i).asUInt.orR
    val dirsOk = VecInit((0 until nDirs).map { d =>
      !io.currentDestVec(i)(d) || tentValid(i)(d)
    }).asUInt.andR
    val commit =
      io.inValid(i) && io.isHead(i) && wantsAny && dirsOk

    io.headAllocOk(i) := commit
    for (d <- 0 until nDirs) {
      io.headSelLane(i)(d) := Mux(commit, tentLane(i)(d), 0.U)
    }
  }
}
