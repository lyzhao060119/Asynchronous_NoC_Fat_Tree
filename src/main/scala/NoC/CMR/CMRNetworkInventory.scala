package NoC.CMR

import Router_Architecture.CMR.CMRParameters

/** Machine-readable DATE V3 network DUT structure.  Counts are derived from
  * geometry only; they do not elaborate Chisel and do not require P&R.
  */
final case class CMRPrimitiveCount(
    primitiveId: String,
    level: Int,
    childLanes: Int,
    parentLanes: Int,
    useMeshRouting: Boolean,
    count: Int
)

final case class CMRNetworkStructure(
    designId: String,
    nodes: Int,
    laneProfile: String,
    routing: String,
    clusterGrid: Option[Int],
    topMeshLanes: Int,
    hrepPolicy: Boolean,
    sharesNetlistWith: Option[String],
    elaborated: Boolean,
    routers: Int,
    ipms: Int,
    opms: Int,
    adapters: Int,
    interlevelFifos: Int,
    corePorts: Int,
    topPorts: Int,
    interRouterLinks: Int,
    channelBits: Int,
    maxOpmFanIn: Int,
    mutexWidths: Seq[Int],
    primitives: Seq[CMRPrimitiveCount],
    notes: String = ""
) {
  def asMap: Map[String, Any] = Map(
    "design_id" -> designId,
    "nodes" -> nodes,
    "lane_profile" -> laneProfile,
    "routing" -> routing,
    "cluster_grid" -> clusterGrid.orNull,
    "top_mesh_lanes" -> topMeshLanes,
    "hrep_policy" -> hrepPolicy,
    "shares_netlist_with" -> sharesNetlistWith.orNull,
    "elaborated" -> elaborated,
    "routers" -> routers,
    "ipms" -> ipms,
    "opms" -> opms,
    "adapters" -> adapters,
    "interlevel_fifos" -> interlevelFifos,
    "core_ports" -> corePorts,
    "top_ports" -> topPorts,
    "inter_router_links" -> interRouterLinks,
    "channel_bits" -> channelBits,
    "max_opm_fanin" -> maxOpmFanIn,
    "mutex_widths" -> mutexWidths,
    "ports" -> ipms,
    "notes" -> notes
  )
}

object CMRNetworkInventory {
  val FlitWidthBits: Int = 28
  val TileEdge: Int = 8
  val L1Count: Int = 16
  val L2Count: Int = 4
  val L3Count: Int = 1
  val Q64Routers: Int = L1Count + L2Count + L3Count

  final case class Geom(child: Int, parent: Int) {
    val ports: Int = CMRParameters.portCount(child, parent)
    val adapters: Int = CMRParameters.expectedLaneAdapters(child, parent)
    val maxFanIn: Int = CMRParameters.maxOpmFanIn(child, parent)
    val mutex: Set[Int] = CMRParameters.mutexWidths(child, parent)
  }

  val Thin11: Geom = Geom(1, 1)
  val Fat12: Geom = Geom(1, 2)
  val Prop22: Geom = Geom(2, 2)
  val Pfat24: Geom = Geom(2, 4)
  val Pfat48: Geom = Geom(4, 8)
  val TopMesh12: Geom = Geom(1, 2)
  val TopMesh22: Geom = Geom(2, 2)

  def q64BypassLinks(l1Parent: Int, l2Parent: Int): Int =
    2 * (L1Count * l1Parent + L2Count * l2Parent)

  def flatMeshLinks(n: Int, childLanes: Int): Int =
    4 * n * (n - 1) * childLanes

  def topMeshLinks(grid: Int, meshLanes: Int): Int =
    4 * grid * (grid - 1) * meshLanes

  def q64ToMeshLinks(grid: Int, localLanes: Int): Int =
    2 * grid * grid * localLanes

  private def q64(
      designId: String,
      profile: String,
      l1: Geom,
      l2: Geom,
      l3: Geom,
      notes: String = ""
  ): CMRNetworkStructure = {
    val ports = L1Count * l1.ports + L2Count * l2.ports + L3Count * l3.ports
    val adapters = L1Count * l1.adapters + L2Count * l2.adapters + L3Count * l3.adapters
    val mutex = (l1.mutex ++ l2.mutex ++ l3.mutex).toSeq.sorted
    val links = q64BypassLinks(l1.parent, l2.parent)
    CMRNetworkStructure(
      designId = designId,
      nodes = 64,
      laneProfile = profile,
      routing = "quadtree",
      clusterGrid = Some(1),
      topMeshLanes = l3.parent,
      hrepPolicy = false,
      sharesNetlistWith = None,
      elaborated = true,
      routers = Q64Routers,
      ipms = ports,
      opms = ports,
      adapters = adapters,
      interlevelFifos = 0,
      corePorts = 64,
      topPorts = l3.parent,
      interRouterLinks = links,
      channelBits = links * FlitWidthBits,
      maxOpmFanIn = Seq(l1.maxFanIn, l2.maxFanIn, l3.maxFanIn).max,
      mutexWidths = mutex,
      primitives = Seq(
        CMRPrimitiveCount(s"async_${if (l1 == Thin11) "thin_1x1" else "fat_1x2"}", 1, l1.child, l1.parent, useMeshRouting = false, L1Count),
        CMRPrimitiveCount(primitiveName(l2, level = 2), 2, l2.child, l2.parent, useMeshRouting = false, L2Count),
        CMRPrimitiveCount(primitiveName(l3, level = 3), 3, l3.child, l3.parent, useMeshRouting = false, L3Count)
      ),
      notes = notes
    )
  }

  private def primitiveName(geom: Geom, level: Int): String = geom match {
    case Thin11 => "async_thin_1x1"
    case Fat12 => "async_fat_1x2"
    case Prop22 => "async_prop_2x2"
    case Pfat24 => "async_pfat_2x4"
    case Pfat48 => "async_pfat_4x8"
    case TopMesh22 => "async_topmesh_2x2"
    case TopMesh12 => "async_topmesh_1x2"
    case _ => s"async_l${level}_c${geom.child}_p${geom.parent}"
  }

  def thin64: CMRNetworkStructure =
    q64("THIN64", "1-1-1-1", Thin11, Thin11, Thin11)

  def prop64: CMRNetworkStructure =
    q64("PROP64", "1-2-2-2", Fat12, Prop22, Prop22)

  def pfat64: CMRNetworkStructure =
    q64(
      "PFAT64",
      "1-2-4-8",
      Fat12,
      Pfat24,
      Pfat48,
      notes = "L3 (4,8) hop PPA signed 20260831_cmr_pfat_l3_c4p8_del050_ackin050. Post-synthesis only."
    )

  def flatMesh(n: Int): CMRNetworkStructure = {
    require(Set(8, 16, 32).contains(n))
    val nodes = n * n
    val ports = nodes * Thin11.ports
    val links = flatMeshLinks(n, 1)
    val designId = s"FM$nodes"
    CMRNetworkStructure(
      designId = designId,
      nodes = nodes,
      laneProfile = "mesh-1",
      routing = "mesh",
      clusterGrid = None,
      topMeshLanes = 0,
      hrepPolicy = false,
      sharesNetlistWith = None,
      elaborated = true,
      routers = nodes,
      ipms = ports,
      opms = ports,
      adapters = 0,
      interlevelFifos = 0,
      corePorts = nodes,
      topPorts = 0,
      interRouterLinks = links,
      channelBits = links * FlitWidthBits,
      maxOpmFanIn = Thin11.maxFanIn,
      mutexWidths = Thin11.mutex.toSeq.sorted,
      primitives = Seq(
        CMRPrimitiveCount("async_flatmesh_1x1", 1, 1, 1, useMeshRouting = true, nodes)
      )
    )
  }

  def clusteredProp(
      clusterGrid: Int,
      meshLanes: Int = 2,
      hrep: Boolean = false,
      designId: Option[String] = None
  ): CMRNetworkStructure = {
    require(Set(2, 4).contains(clusterGrid))
    val tiles = clusterGrid * clusterGrid
    val nodes = tiles * 64
    val localLanes = 2
    val topGeom =
      if (meshLanes == 2) TopMesh22
      else if (meshLanes == 1) TopMesh12
      else {
        return CMRNetworkStructure(
          designId = designId.getOrElse(s"PROP${nodes}_MESH$meshLanes"),
          nodes = nodes,
          laneProfile = "1-2-2-2",
          routing = "quadtree_topmesh",
          clusterGrid = Some(clusterGrid),
          topMeshLanes = meshLanes,
          hrepPolicy = hrep,
          sharesNetlistWith = if (hrep) Some("PROP1024") else None,
          elaborated = false,
          routers = tiles * Q64Routers,
          ipms = 0,
          opms = 0,
          adapters = 0,
          interlevelFifos = 0,
          corePorts = nodes,
          topPorts = 0,
          interRouterLinks = 0,
          channelBits = 0,
          maxOpmFanIn = Prop22.maxFanIn,
          mutexWidths = Seq.empty,
          primitives = Seq.empty,
          notes = s"Mesh$meshLanes needs TopMesh ($meshLanes,$localLanes), which is not in SupportedLaneGeometries. Not elaborated; 4-8 is not reused as a stand-in."
        )
      }

    val l1 = Fat12
    val l2 = Prop22
    val l3 = Prop22
    val treePorts = tiles * (L1Count * l1.ports + L2Count * l2.ports + L3Count * l3.ports)
    val topPorts = tiles * topGeom.ports
    val ports = treePorts + topPorts
    val adapters =
      tiles * (L1Count * l1.adapters + L2Count * l2.adapters + L3Count * l3.adapters) +
        tiles * topGeom.adapters
    val mutex = (l1.mutex ++ l2.mutex ++ l3.mutex ++ topGeom.mutex).toSeq.sorted
    val links =
      tiles * q64BypassLinks(l1.parent, l2.parent) +
        topMeshLinks(clusterGrid, meshLanes) +
        q64ToMeshLinks(clusterGrid, localLanes)
    val id = designId.getOrElse {
      if (hrep) "HREP1024"
      else if (meshLanes == 2 && clusterGrid == 4) "PROP1024"
      else if (meshLanes == 2 && clusterGrid == 2) "PROP256"
      else s"PROP${nodes}_MESH$meshLanes"
    }
    val shares =
      if (hrep) Some("PROP1024")
      else if (id == "PROP1024_MESH2") Some("PROP1024")
      else None
    CMRNetworkStructure(
      designId = id,
      nodes = nodes,
      laneProfile = "1-2-2-2",
      routing = "quadtree_topmesh",
      clusterGrid = Some(clusterGrid),
      topMeshLanes = meshLanes,
      hrepPolicy = hrep,
      sharesNetlistWith = shares,
      elaborated = true,
      routers = tiles * Q64Routers + tiles,
      ipms = ports,
      opms = ports,
      adapters = adapters,
      interlevelFifos = 0,
      corePorts = nodes,
      topPorts = 0,
      interRouterLinks = links,
      channelBits = links * FlitWidthBits,
      maxOpmFanIn = Seq(l1.maxFanIn, l2.maxFanIn, l3.maxFanIn, topGeom.maxFanIn).max,
      mutexWidths = mutex,
      primitives = Seq(
        CMRPrimitiveCount("async_fat_1x2", 1, 1, 2, useMeshRouting = false, tiles * L1Count),
        CMRPrimitiveCount("async_prop_2x2", 2, 2, 2, useMeshRouting = false, tiles * L2Count),
        CMRPrimitiveCount("async_prop_2x2", 3, 2, 2, useMeshRouting = false, tiles * L3Count),
        CMRPrimitiveCount(
          if (meshLanes == 2) "async_topmesh_2x2" else "async_topmesh_1x2",
          1,
          meshLanes,
          localLanes,
          useMeshRouting = true,
          tiles
        )
      ),
      notes = if (hrep) "Same netlist as PROP1024; only the injection policy splits cross-cluster events." else ""
    )
  }

  def allPaperDuts: Seq[CMRNetworkStructure] = Seq(
    thin64,
    prop64,
    pfat64,
    flatMesh(8),
    flatMesh(16),
    flatMesh(32),
    clusteredProp(2, 2, designId = Some("PROP256")),
    clusteredProp(4, 2, designId = Some("PROP1024")),
    clusteredProp(4, 2, hrep = true, designId = Some("HREP1024")),
    clusteredProp(4, 1, designId = Some("PROP1024_MESH1")),
    clusteredProp(4, 2, designId = Some("PROP1024_MESH2")),
    clusteredProp(4, 4, designId = Some("PROP1024_MESH4")),
    thin64.copy(
      designId = "SYNC_THIN64",
      notes = "Sync Thin64; same instance counts as THIN64. Phase 2.5 1-cycle Head."
    ),
    prop64.copy(
      designId = "SYNC_PROP64",
      notes = "Sync PROP64; same instance counts as PROP64. Phase 2.5 1-cycle Head."
    )
  )

  def byId: Map[String, CMRNetworkStructure] =
    allPaperDuts.map(dut => dut.designId -> dut).toMap
}
