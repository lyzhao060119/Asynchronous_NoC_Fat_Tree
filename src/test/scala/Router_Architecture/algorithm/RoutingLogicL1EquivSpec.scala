package Router_Architecture.algorithm

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RoutingLogicMaskDut(
    coordinateX: Int,
    coordinateY: Int,
    routerLevel: Int = 1
) extends Module {
  val io = IO(new Bundle {
    val x0 = Input(UInt(6.W))
    val y0 = Input(UInt(6.W))
    val x1 = Input(UInt(6.W))
    val y1 = Input(UInt(6.W))
    val valid = Input(Bool())
    val ingress = Input(UInt(3.W))
    val mask = Output(UInt(5.W))
  })
  io.mask := new RoutingLogic(coordinateX, coordinateY).routeMask(
    io.x0,
    io.y0,
    io.x1,
    io.y1,
    io.valid,
    router_level = routerLevel,
    io.ingress
  )
}

class RoutingLogicL1EquivSpec extends AnyFlatSpec with ChiselScalatestTester {
  private val tree0 = for (x <- 0 to 3; y <- 0 to 3) yield (x, y)
  private val extraTrees = Seq((4, 0), (0, 4), (5, 6), (12, 12), (15, 15))
  private val allL1 = tree0 ++ extraTrees
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
    (4, 4, 5, 20)
  )

  private def checkScala(cx: Int, cy: Int, x0: Int, y0: Int, x1: Int, y1: Int, valid: Boolean, ingress: Int): Unit = {
    val frozen = RoutingLogicOracle.mask(cx, cy, 1, ingress, x0, y0, x1, y1, valid)
    val fast = RoutingLogicL1Fast.mask(cx, cy, ingress, x0, y0, x1, y1, valid)
    if (frozen != fast) {
      fail(
        s"L1 fast vs frozen oracle router=($cx,$cy) ingress=$ingress rect=($x0,$y0)-($x1,$y1) valid=$valid oracle=${frozen.toBinaryString} fast=${fast.toBinaryString}"
      )
    }
  }

  "L1 fast path" should "match the frozen clip oracle on every tree-0 L1, extra trees, 32x32 unicast, boundary, and random multicast" in {
    for ((cx, cy) <- allL1; ingress <- 0 to 4) {
      checkScala(cx, cy, 0, 0, 0, 0, valid = false, ingress)
    }
    for ((cx, cy) <- allL1; x <- 0 until 32; y <- 0 until 32; ingress <- 0 to 4) {
      checkScala(cx, cy, x, y, x, y, valid = true, ingress)
    }
    for ((cx, cy) <- allL1; (x0, y0, x1, y1) <- boundary; ingress <- 0 to 4) {
      checkScala(cx, cy, x0, y0, x1, y1, valid = true, ingress)
    }
    val rng = new scala.util.Random(20260827)
    var n = 0
    while (n < 4000) {
      val cxcy = allL1(rng.nextInt(allL1.length))
      checkScala(
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

  private def pokeExpect(
      c: RoutingLogicMaskDut,
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
    val expected = RoutingLogicOracle.mask(cx, cy, 1, ingress, x0, y0, x1, y1, valid)
    val got = c.io.mask.peek().litValue.toInt
    if (got != expected) {
      fail(
        s"Chisel vs oracle router=($cx,$cy) ingress=$ingress rect=($x0,$y0)-($x1,$y1) valid=$valid expected=${expected.toBinaryString} got=${got.toBinaryString}"
      )
    }
  }

  private def chiselSweep(cx: Int, cy: Int, unicastExtent: Int, randomN: Int): Unit = {
    it should s"match the frozen oracle in Chisel at L1 ($cx,$cy)" in {
      test(new RoutingLogicMaskDut(cx, cy)) { c =>
        for (ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, 0, 0, 0, 0, valid = false, ingress)
        }
        for (x <- 0 until unicastExtent; y <- 0 until unicastExtent; ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, x, y, x, y, valid = true, ingress)
        }
        for ((x0, y0, x1, y1) <- boundary; ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, x0, y0, x1, y1, valid = true, ingress)
        }
        val rng = new scala.util.Random(cx * 64 + cy)
        var n = 0
        while (n < randomN) {
          pokeExpect(
            c,
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

  chiselSweep(0, 0, unicastExtent = 32, randomN = 800)
  chiselSweep(3, 3, unicastExtent = 32, randomN = 400)
  chiselSweep(5, 6, unicastExtent = 16, randomN = 400)
  chiselSweep(15, 15, unicastExtent = 16, randomN = 400)
}
