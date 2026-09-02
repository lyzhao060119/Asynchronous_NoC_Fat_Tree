package NoC.CMR

import org.scalatest.flatspec.AnyFlatSpec

class CMRNetworkDutSpec extends AnyFlatSpec {
  private def assertClean(label: String, result: CMRNetworkRouteOracle.Delivery): Unit = {
    assert(!result.loss, s"$label loss path=${result.path}")
    assert(!result.duplicate, s"$label duplicate path=${result.path}")
    assert(!result.cycle, s"$label cycle path=${result.path}")
  }

  "CMRNetworkInventory" should "match the V3 structure freeze for 64-node Q64 tiles" in {
    val thin = CMRNetworkInventory.thin64
    assert(thin.routers == 21)
    assert(thin.ipms == 105)
    assert(thin.adapters == 0)
    assert(thin.interlevelFifos == 0)
    assert(thin.topPorts == 1)
    assert(thin.maxOpmFanIn == 4)

    val prop = CMRNetworkInventory.prop64
    assert(prop.routers == 21)
    assert(prop.ipms == 146)
    assert(prop.adapters == 264)
    assert(prop.interlevelFifos == 0)
    assert(prop.topPorts == 2)
    assert(prop.maxOpmFanIn == 8)
    assert(prop.mutexWidths == Seq(2, 4, 5, 8))

    val pfat = CMRNetworkInventory.pfat64
    assert(pfat.routers == 21)
    assert(pfat.ipms == 168)
    assert(pfat.adapters == 352)
    assert(pfat.topPorts == 8)
    assert(pfat.maxOpmFanIn == 20)
    assert(pfat.elaborated)
    assert(!pfat.notes.contains("still open"))
    assert(pfat.notes.contains("20260831_cmr_pfat_l3_c4p8_del050_ackin050"))
  }

  it should "count FM64/256/1024 as n x n Thin mesh routers" in {
    assert(CMRNetworkInventory.flatMesh(8).routers == 64)
    assert(CMRNetworkInventory.flatMesh(16).routers == 256)
    assert(CMRNetworkInventory.flatMesh(32).routers == 1024)
    assert(CMRNetworkInventory.flatMesh(16).adapters == 0)
    assert(CMRNetworkInventory.flatMesh(32).maxOpmFanIn == 4)
  }

  it should "count PROP256/1024 as Q64 tiles plus TopMesh2" in {
    val p256 = CMRNetworkInventory.clusteredProp(2, 2, designId = Some("PROP256"))
    assert(p256.routers == 88)
    assert(p256.ipms == 624)
    assert(p256.adapters == 1216)
    assert(p256.interlevelFifos == 0)
    assert(p256.maxOpmFanIn == 8)

    val p1024 = CMRNetworkInventory.clusteredProp(4, 2, designId = Some("PROP1024"))
    assert(p1024.routers == 352)
    assert(p1024.ipms == 2496)
    assert(p1024.adapters == 4864)
    assert(p1024.nodes == 1024)
  }

  it should "give H-REP the PROP1024 netlist counts" in {
    val prop = CMRNetworkInventory.byId("PROP1024")
    val hrep = CMRNetworkInventory.byId("HREP1024")
    assert(hrep.sharesNetlistWith.contains("PROP1024"))
    assert(hrep.hrepPolicy)
    assert(!prop.hrepPolicy)
    assert(hrep.routers == prop.routers)
    assert(hrep.adapters == prop.adapters)
    assert(hrep.interRouterLinks == prop.interRouterLinks)
    assert(hrep.channelBits == prop.channelBits)
  }

  it should "parameterize Mesh1 as TopMesh (1,2) and refuse Mesh4 elaboration" in {
    val mesh1 = CMRNetworkInventory.byId("PROP1024_MESH1")
    assert(mesh1.elaborated)
    assert(mesh1.routers == 352)
    assert(mesh1.topMeshLanes == 1)
    assert(mesh1.primitives.exists(p => p.useMeshRouting && p.childLanes == 1 && p.parentLanes == 2 && p.count == 16))

    val mesh4 = CMRNetworkInventory.byId("PROP1024_MESH4")
    assert(!mesh4.elaborated)
    assert(mesh4.notes.nonEmpty)
  }

  "Q64 route oracle" should "deliver every 64-node unicast pair" in {
    for (sy <- 0 until 8; sx <- 0 until 8; dy <- 0 until 8; dx <- 0 until 8 if sx != dx || sy != dy) {
      val result = CMRNetworkRouteOracle.deliverUnicast(sx, sy, dx, dy, clusterGrid = 1)
      assertClean(s"64 ($sx,$sy)->($dx,$dy)", result)
      assert(result.destinations == Set((dx, dy)))
    }
  }

  it should "deliver representative 64-node rectangles" in {
    val rects = Seq(
      (0, 0, 1, 1),
      (2, 2, 3, 3),
      (0, 0, 7, 7),
      (0, 0, 3, 0)
    )
    for ((x0, y0, x1, y1) <- rects) {
      val result = CMRNetworkRouteOracle.deliver(0, 0, x0, y0, x1, y1, clusterGrid = 1)
      assertClean(s"64 rect ($x0,$y0)-($x1,$y1)", result)
    }
  }

  it should "deliver 256-node directed corners and random unicasts" in {
    val corners = Seq(
      (0, 0), (7, 0), (0, 7), (7, 7),
      (8, 0), (15, 0), (8, 7), (15, 7),
      (0, 8), (7, 8), (0, 15), (7, 15),
      (8, 8), (15, 8), (8, 15), (15, 15)
    )
    for ((sx, sy) <- corners; (dx, dy) <- corners if sx != dx || sy != dy) {
      val result = CMRNetworkRouteOracle.deliverUnicast(sx, sy, dx, dy, clusterGrid = 2)
      assertClean(s"256 corner ($sx,$sy)->($dx,$dy)", result)
      assert(result.destinations == Set((dx, dy)))
    }
    val rng = new scala.util.Random(1)
    for (_ <- 0 until 200) {
      val sx = rng.nextInt(16)
      val sy = rng.nextInt(16)
      var dx = rng.nextInt(16)
      var dy = rng.nextInt(16)
      if (dx == sx && dy == sy) dx = (dx + 1) % 16
      val result = CMRNetworkRouteOracle.deliverUnicast(sx, sy, dx, dy, clusterGrid = 2)
      assertClean(s"256 rand ($sx,$sy)->($dx,$dy)", result)
    }
  }

  it should "deliver 138→37 through L3(0,0) parent then child dir 1" in {
    val result = CMRNetworkRouteOracle.deliverUnicast(10, 8, 5, 2, clusterGrid = 2)
    assertClean("256 138->37", result)
    assert(result.destinations == Set((5, 2)))
    assert(result.path.exists(_.startsWith("L3(0,0)")))
    assert(result.path.exists(_.startsWith("L2(1,0)")))
  }

  it should "deliver 15→0 through L3(0,0) parent then child dir 3" in {
    val result = CMRNetworkRouteOracle.deliverUnicast(15, 0, 0, 0, clusterGrid = 2)
    assertClean("256 15->0", result)
    assert(result.destinations == Set((0, 0)))
    assert(result.path.exists(_.startsWith("L3(0,0)")))
    assert(result.path.exists(_.startsWith("L2(0,0)")))
  }

  it should "native-branch a two-tile rectangle on TopMesh" in {
    val result = CMRNetworkRouteOracle.deliver(0, 0, 0, 0, 15, 0, clusterGrid = 2)
    assertClean("256 span x", result)
    assert(result.meshHops >= 1)
    assert(result.destinations.contains((8, 0)))
    assert(result.destinations.contains((15, 0)))
  }

  it should "deliver FM8 exhaustive unicasts and FM16 key cases" in {
    for (sy <- 0 until 8; sx <- 0 until 8; dy <- 0 until 8; dx <- 0 until 8 if sx != dx || sy != dy) {
      val result = CMRNetworkRouteOracle.deliverFlatMesh(sx, sy, dx, dy, n = 8)
      assertClean(s"FM8 ($sx,$sy)->($dx,$dy)", result)
    }
    val result = CMRNetworkRouteOracle.deliverFlatMesh(0, 0, 15, 15, n = 16)
    assertClean("FM16 corner", result)
  }

  "HrepBoundaryPolicy" should "emit one packet when all destinations share a cluster" in {
    val dests = Seq(2, 3, 4, 5)
    val packets = HrepBoundaryPolicy.splitDestSet("e0", source = 0, dests, clusterGrid = 4)
    assert(packets.length == 1)
    assert(packets.head.originalEventId == "e0")
    assert(packets.head.destinations.toSet == dests.toSet)
    assert(!packets.head.crossesTopMesh)
  }

  it should "split one original event per target cluster and keep the id" in {
    val dests = Seq(0, 8, 256, 264)
    val packets = HrepBoundaryPolicy.splitDestSet("e1", source = 1, dests, clusterGrid = 4)
    assert(packets.length == 4)
    assert(packets.forall(_.originalEventId == "e1"))
    assert(packets.map(_.packetId).distinct.length == 4)
    assert(packets.map(_.destinations).flatten.sorted == dests.filter(_ != 1).sorted)
    assert(packets.count(_.crossesTopMesh) == 3)
    assert(packets.exists(p => !p.crossesTopMesh && p.targetCluster == ((0, 0))))
  }

  it should "clip a spanning rectangle into per-cluster packets" in {
    val packets = HrepBoundaryPolicy.splitRectangle(
      "e2",
      source = 0,
      rect = HrepBoundaryPolicy.Rect(0, 0, 15, 0),
      clusterGrid = 2
    )
    assert(packets.length == 2)
    assert(packets.forall(_.originalEventId == "e2"))
    assert(packets.map(_.targetCluster).toSet == Set((0, 0), (1, 0)))
  }
}
