package Router_Architecture.algorithm

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RoutingLogicUpperEquivSpec extends AnyFlatSpec with ChiselScalatestTester {
  private val tree0L2 = for (x <- 0 to 1; y <- 0 to 1) yield (x, y)
  private val extraL2 = Seq((2, 0), (2, 2), (6, 4), (7, 7))
  private val allL2 = tree0L2 ++ extraL2
  private val allL3 = Seq((0, 0), (1, 1), (3, 3), (2, 0))
  private val boundary = Seq(
    (0, 0, 7, 7),
    (0, 0, 1, 1),
    (0, 0, 10, 1),
    (8, 0, 9, 1),
    (6, 6, 9, 9),
    (0, 0, 31, 31),
    (16, 16, 23, 23),
    (31, 0, 31, 0),
    (0, 8, 7, 15),
    (1, 1, 0, 0),
    (20, 1, 0, 0),
    (4, 4, 5, 20),
    (3, 3, 4, 4)
  )

  private def checkScala(
      level: Int,
      cx: Int,
      cy: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      valid: Boolean,
      ingress: Int
  ): Unit = {
    val frozen = RoutingLogicOracle.mask(cx, cy, level, ingress, x0, y0, x1, y1, valid)
    val fast =
      if (level == 2)
        RoutingLogicL2Fast.mask(cx, cy, ingress, x0, y0, x1, y1, valid)
      else RoutingLogicL3Fast.mask(cx, cy, ingress, x0, y0, x1, y1, valid)
    if (frozen != fast) {
      fail(
        s"L$level fast vs frozen oracle router=($cx,$cy) ingress=$ingress rect=($x0,$y0)-($x1,$y1) valid=$valid oracle=${frozen.toBinaryString} fast=${fast.toBinaryString}"
      )
    }
  }

  private def scalaSweep(level: Int, routers: Seq[(Int, Int)]): Unit = {
    val label = if (level == 2) "L2" else "L3"
    it should s"match the frozen clip oracle on $label routers, 32x32 unicast, boundary, and random multicast" in {
      for ((cx, cy) <- routers; ingress <- 0 to 4) {
        checkScala(level, cx, cy, 0, 0, 0, 0, valid = false, ingress)
      }
      for ((cx, cy) <- routers; x <- 0 until 32; y <- 0 until 32; ingress <- 0 to 4) {
        checkScala(level, cx, cy, x, y, x, y, valid = true, ingress)
      }
      for ((cx, cy) <- routers; (x0, y0, x1, y1) <- boundary; ingress <- 0 to 4) {
        checkScala(level, cx, cy, x0, y0, x1, y1, valid = true, ingress)
      }
      val rng = new scala.util.Random(20260827 + level)
      var n = 0
      while (n < 4000) {
        val cxcy = routers(rng.nextInt(routers.length))
        checkScala(
          level,
          cxcy._1,
          cxcy._2,
          rng.nextInt(64),
          rng.nextInt(64),
          rng.nextInt(64),
          rng.nextInt(64),
          valid = true,
          ingress = rng.nextInt(5)
        )
        n += 1
      }
    }
  }

  scalaSweep(2, allL2)
  scalaSweep(3, allL3)

  private def pokeExpect(
      c: RoutingLogicMaskDut,
      level: Int,
      cx: Int,
      cy: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      valid: Boolean,
      ingress: Int
  ): Unit = {
    c.io.x0.poke(x0.U)
    c.io.y0.poke(y0.U)
    c.io.x1.poke(x1.U)
    c.io.y1.poke(y1.U)
    c.io.valid.poke(valid.B)
    c.io.ingress.poke(ingress.U)
    val expected = RoutingLogicOracle.mask(cx, cy, level, ingress, x0, y0, x1, y1, valid)
    val got = c.io.mask.peek().litValue.toInt
    if (got != expected) {
      fail(
        s"Chisel L$level vs oracle router=($cx,$cy) ingress=$ingress rect=($x0,$y0)-($x1,$y1) valid=$valid expected=${expected.toBinaryString} got=${got.toBinaryString}"
      )
    }
  }

  private def chiselSweep(
      level: Int,
      cx: Int,
      cy: Int,
      unicastExtent: Int,
      randomN: Int
  ): Unit = {
    it should s"match the frozen oracle in Chisel at L$level ($cx,$cy)" in {
      test(new RoutingLogicMaskDut(cx, cy, level)) { c =>
        for (ingress <- 0 to 4) {
          pokeExpect(c, level, cx, cy, 0, 0, 0, 0, valid = false, ingress)
        }
        for (x <- 0 until unicastExtent; y <- 0 until unicastExtent; ingress <- 0 to 4) {
          pokeExpect(c, level, cx, cy, x, y, x, y, valid = true, ingress)
        }
        for ((x0, y0, x1, y1) <- boundary; ingress <- 0 to 4) {
          pokeExpect(c, level, cx, cy, x0, y0, x1, y1, valid = true, ingress)
        }
        val rng = new scala.util.Random(level * 1000 + cx * 64 + cy)
        var n = 0
        while (n < randomN) {
          pokeExpect(
            c,
            level,
            cx,
            cy,
            rng.nextInt(64),
            rng.nextInt(64),
            rng.nextInt(64),
            rng.nextInt(64),
            valid = true,
            ingress = rng.nextInt(5)
          )
          n += 1
        }
      }
    }
  }

  chiselSweep(2, 0, 0, unicastExtent = 32, randomN = 800)
  chiselSweep(2, 1, 1, unicastExtent = 16, randomN = 400)
  chiselSweep(2, 2, 2, unicastExtent = 16, randomN = 400)
  chiselSweep(3, 0, 0, unicastExtent = 32, randomN = 800)
  chiselSweep(3, 1, 1, unicastExtent = 16, randomN = 400)
  chiselSweep(3, 3, 3, unicastExtent = 16, randomN = 400)
}
