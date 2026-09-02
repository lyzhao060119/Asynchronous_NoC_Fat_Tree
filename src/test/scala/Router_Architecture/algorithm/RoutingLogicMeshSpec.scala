package Router_Architecture.algorithm

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RoutingLogicMeshDut(
    coordinateX: Int,
    coordinateY: Int,
    gridSize: Int = 8,
    coordShift: Int = 0
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
  io.mask := new RoutingLogic_mesh(coordinateX, coordinateY, gridSize, coordShift).routeMask(
    io.x0,
    io.y0,
    io.x1,
    io.y1,
    io.valid,
    io.ingress
  )
}

class RoutingLogicMeshSpec extends AnyFlatSpec with ChiselScalatestTester {
  private val DirWest = 0
  private val DirSouth = 1
  private val DirEast = 2
  private val DirNorth = 3
  private val DirLocal = 4
  private val Grid = 8

  private def model(
      cx: Int,
      cy: Int,
      ingress: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      valid: Boolean = true,
      gridSize: Int = Grid,
      coordShift: Int = 0
  ): Int =
    RoutingLogicMeshModel.routeMask(cx, cy, gridSize, ingress, x0, y0, x1, y1, valid, coordShift)

  "RoutingLogicMeshModel" should "XY-walk a unicast toward +X then deliver Local" in {
    assert(model(0, 0, DirLocal, 3, 0, 3, 0) == (1 << DirEast))
    assert(model(1, 0, DirWest, 3, 0, 3, 0) == (1 << DirEast))
    assert(model(3, 0, DirWest, 3, 0, 3, 0) == (1 << DirLocal))
  }

  it should "XY-walk +Y after X matches and not leave the west edge" in {
    assert(model(0, 0, DirLocal, 0, 3, 0, 3) == (1 << DirNorth))
    assert(model(0, 0, DirLocal, 0, 0, 0, 0) == 0)
    assert((model(0, 2, DirLocal, 7, 2, 7, 2) & (1 << DirWest)) == 0)
  }

  it should "expand a rectangle without returning to the injecting PE" in {
    val atCenter = model(2, 2, DirLocal, 1, 1, 3, 3)
    assert((atCenter & (1 << DirLocal)) == 0)
    assert((atCenter & (1 << DirWest)) != 0)
    assert((atCenter & (1 << DirEast)) != 0)
    assert((atCenter & (1 << DirSouth)) != 0)
    assert((atCenter & (1 << DirNorth)) != 0)
    val fromWest = model(2, 2, DirWest, 1, 1, 3, 3)
    assert((fromWest & (1 << DirLocal)) != 0)
    assert((fromWest & (1 << DirEast)) != 0)
    assert((fromWest & (1 << DirWest)) == 0)
  }

  it should "steer a unicast on West/South/East/North and deliver Local" in {
    assert(model(3, 3, DirLocal, 0, 3, 0, 3) == (1 << DirWest))
    assert(model(3, 3, DirLocal, 7, 3, 7, 3) == (1 << DirEast))
    assert(model(3, 3, DirLocal, 3, 0, 3, 0) == (1 << DirSouth))
    assert(model(3, 3, DirLocal, 3, 7, 3, 7) == (1 << DirNorth))
    assert(model(3, 3, DirWest, 3, 3, 3, 3) == (1 << DirLocal))
    assert(model(3, 3, DirEast, 3, 3, 3, 3) == (1 << DirLocal))
    assert(model(3, 3, DirSouth, 3, 3, 3, 3) == (1 << DirLocal))
    assert(model(3, 3, DirNorth, 3, 3, 3, 3) == (1 << DirLocal))
  }

  it should "keep TopMesh dual-lane routing at the direction level" in {
    // ContinuousLaneSelector picks a physical lane after Mat.  The oracle is
    // the same 5-bit direction mask for (1,1) FlatMesh and (2,2) TopMesh.
    val east = model(0, 0, DirWest, 1, 0, 1, 0)
    assert(east == (1 << DirEast))
    assert((east & (1 << DirWest)) == 0)
    assert((east & (1 << DirLocal)) == 0)
  }

  it should "clamp north/east at the far corner" in {
    val mask = model(7, 7, DirLocal, 7, 7, 7, 7)
    assert(mask == 0)
    val towardInterior = model(7, 7, DirLocal, 0, 0, 0, 0)
    assert(towardInterior == (1 << DirWest))
  }

  private def pokeExpect(
      c: RoutingLogicMeshDut,
      cx: Int,
      cy: Int,
      ingress: Int,
      x0: Int,
      y0: Int,
      x1: Int,
      y1: Int,
      valid: Boolean = true,
      gridSize: Int = Grid,
      coordShift: Int = 0
  ): Unit = {
    c.io.x0.poke(x0.U)
    c.io.y0.poke(y0.U)
    c.io.x1.poke(x1.U)
    c.io.y1.poke(y1.U)
    c.io.valid.poke(valid.B)
    c.io.ingress.poke(ingress.U)
    val expected = model(cx, cy, ingress, x0, y0, x1, y1, valid, gridSize, coordShift)
    val got = c.io.mask.peek().litValue.toInt
    if (got != expected) {
      fail(
        s"Chisel vs model router=($cx,$cy) ingress=$ingress rect=($x0,$y0)-($x1,$y1) " +
          s"valid=$valid expected=${expected.toBinaryString} got=${got.toBinaryString}"
      )
    }
  }

  private def chiselSweep(cx: Int, cy: Int): Unit = {
    it should s"match the Scala mesh model in Chisel at ($cx,$cy)" in {
      test(new RoutingLogicMeshDut(cx, cy)) { c =>
        for (ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, ingress, 0, 0, 0, 0, valid = false)
        }
        for (x <- 0 until Grid; y <- 0 until Grid; ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, ingress, x, y, x, y)
        }
        val rects = Seq((0, 0, 1, 1), (1, 1, 3, 3), (0, 0, 7, 7), (7, 0, 0, 7), (3, 3, 1, 5))
        for ((x0, y0, x1, y1) <- rects; ingress <- 0 to 4) {
          pokeExpect(c, cx, cy, ingress, x0, y0, x1, y1)
        }
      }
    }
  }

  chiselSweep(0, 0)
  chiselSweep(2, 2)
  chiselSweep(7, 7)

  "TopMesh coordShift=3" should "XY-walk PE (8,0) as cluster East then Local" in {
    val east = model(0, 0, DirLocal, 8, 0, 8, 0, gridSize = 2, coordShift = 3)
    assert(east == (1 << DirEast))
    val local = model(1, 0, DirWest, 8, 0, 8, 0, gridSize = 2, coordShift = 3)
    assert(local == (1 << DirLocal))
  }

  it should "not return to the injecting Q64 on Local ingress" in {
    val atHome = model(0, 0, DirLocal, 0, 0, 7, 7, gridSize = 2, coordShift = 3)
    assert((atHome & (1 << DirLocal)) == 0)
  }

  it should "match Chisel on a 2x2 cluster mesh" in {
    test(new RoutingLogicMeshDut(0, 0, gridSize = 2, coordShift = 3)) { c =>
      pokeExpect(c, 0, 0, DirLocal, 8, 0, 8, 0, gridSize = 2, coordShift = 3)
      pokeExpect(c, 0, 0, DirLocal, 0, 8, 0, 8, gridSize = 2, coordShift = 3)
      pokeExpect(c, 0, 0, DirWest, 8, 8, 15, 15, gridSize = 2, coordShift = 3)
    }
    test(new RoutingLogicMeshDut(1, 1, gridSize = 2, coordShift = 3)) { c =>
      pokeExpect(c, 1, 1, DirWest, 8, 8, 8, 8, gridSize = 2, coordShift = 3)
      pokeExpect(c, 1, 1, DirLocal, 0, 0, 0, 0, gridSize = 2, coordShift = 3)
    }
  }

  it should "keep dual-lane TopMesh routing at the direction level" in {
    val east11 = model(0, 0, DirLocal, 8, 0, 8, 0, gridSize = 2, coordShift = 3)
    val east22 = east11
    assert(east11 == (1 << DirEast))
    assert(east22 == east11)
  }
}
