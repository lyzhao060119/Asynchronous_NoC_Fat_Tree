package NoC

final /** Per-level channel geometry. Default fifoDepth=1 targets latency (GLS/E2E);
  * raise depth separately when scanning deadlock / high injection rate. */
case class NoCRouterLevelConfig(
  childLanes: Int,
  parentLanes: Int,
  fifoDepth: Int = 1
) {
  require(childLanes > 0, s"childLanes must be positive, got $childLanes")
  require(parentLanes > 0, s"parentLanes must be positive, got $parentLanes")
  require(fifoDepth > 0, s"fifoDepth must be positive, got $fifoDepth")
}

/** Shared physical-lane presets for each router level in the hierarchy. */
final case class NoCRouterChannelConfig(
  l1ChildLanes: Int = 1,
  l1ParentLanes: Int = 2,
  l2ParentLanes: Int = 4,
  l3ParentLanes: Int = 8,
  topChildLanes: Int = 4,
  l1FifoDepth: Int = 1,
  l2FifoDepth: Int = 1,
  l3FifoDepth: Int = 1,
  topFifoDepth: Int = 1
) {
  val l1: NoCRouterLevelConfig =
    NoCRouterLevelConfig(l1ChildLanes, l1ParentLanes, l1FifoDepth)
  val l2: NoCRouterLevelConfig =
    NoCRouterLevelConfig(l1ParentLanes, l2ParentLanes, l2FifoDepth)
  val l3: NoCRouterLevelConfig =
    NoCRouterLevelConfig(l2ParentLanes, l3ParentLanes, l3FifoDepth)
  val top: NoCRouterLevelConfig =
    NoCRouterLevelConfig(topChildLanes, l3ParentLanes, topFifoDepth)
}

// Shared scale metadata for the tiled NoC top-level generators.
final case class NoCScaleConfig(
  quadNumX: Int,
  quadNumY: Int,
  channels: NoCRouterChannelConfig = NoCScaleConfig.DefaultRouterChannels
) {
  require(quadNumX > 0, s"quadNumX must be positive, got $quadNumX")
  require(quadNumY > 0, s"quadNumY must be positive, got $quadNumY")

  val tileEdge: Int = 8
  val leafRouterGridX: Int = tileEdge / 2
  val leafRouterGridY: Int = tileEdge / 2
  val midRouterGridX: Int = leafRouterGridX / 2
  val midRouterGridY: Int = leafRouterGridY / 2
  val coresPerQuad: Int = tileEdge * tileEdge * channels.l1.childLanes
  val topPortsPerQuad: Int = channels.top.parentLanes
  val quadNum: Int = quadNumX * quadNumY
  val totalNodes: Int = quadNum * coresPerQuad

  def localCoreIndex(localX: Int, localY: Int, lane: Int): Int = {
    require(localX >= 0 && localX < tileEdge, s"localX out of range: $localX")
    require(localY >= 0 && localY < tileEdge, s"localY out of range: $localY")
    require(
      lane >= 0 && lane < channels.l1.childLanes,
      s"lane out of range: $lane"
    )
    (localX + tileEdge * localY) * channels.l1.childLanes + lane
  }
}

object NoCScaleConfig {
  /** PFAT 1-2-4-8: L1 1→2, L2 2→4, L3 4→8, eight top parent lanes. */
  val FatLane1248: NoCRouterChannelConfig = NoCRouterChannelConfig()

  // M16 PROP is a separate three-level tree (1x4 at each level), not a
  // NoCRouterChannelConfig: its L2/L3 child geometries do not follow the
  // conventional shared-lane quadtree relation encoded by this case class.
  // This config is therefore the remaining conventional fat-tree profile.
  val DefaultRouterChannels: NoCRouterChannelConfig = FatLane1248

  def fatLaneProfileName: String = {
    val raw = sys.env.getOrElse("CMR_FAT_LANE_PROFILE", "1248").trim
    raw.toLowerCase.replace("-", "").replace("_", "") match {
      case "1248" | "fatlane1248" | "pfat" => "1248"
      case _ =>
        throw new IllegalArgumentException(
          s"Unknown CMR_FAT_LANE_PROFILE='$raw'. Only 1248 remains; use CMR_Q64_PROFILE=prop for M16."
        )
    }
  }

  def fatLaneChannels: NoCRouterChannelConfig =
    FatLane1248

  def fatLaneTopLanes: Int = fatLaneChannels.l3.parentLanes

  /** One 64-core quadtree tile using the selected Fat lane profile. */
  def fatTree64: NoCScaleConfig = NoCScaleConfig(1, 1, fatLaneChannels)

  /** Conventional Q64 fat tree. PROP/M16 uses its dedicated RTL top. */
  def q64TreeFromEnv: NoCScaleConfig = {
    sys.env.get("CMR_Q64_PROFILE").map(_.trim.toLowerCase.replace("-", "").replace("_", "")) match {
      case Some("1248") | Some("pfat") | Some("fatlane1248") =>
        NoCScaleConfig(1, 1, FatLane1248)
      case Some("prop") | Some("m16") | Some("propm16") =>
        throw new IllegalArgumentException(
          "PROP selects the dedicated PROPtemp64M16 top; it is not a NoCScaleConfig fat tree"
        )
      case Some("thin") | Some("1111") | Some("thin111") | Some("1222") | Some("fatlane1222") =>
        throw new IllegalArgumentException(s"CMR_Q64_PROFILE '${sys.env("CMR_Q64_PROFILE")}' was removed")
      case Some(other) =>
        throw new IllegalArgumentException(
          s"Unknown CMR_Q64_PROFILE='$other'. Supported: prop (M16), 1248."
        )
      case None => fatTree64
    }
  }

  /** Clustered 256/1024 Q64 network.  The TopMesh geometry must match the
    * selected Q64 top interface; PFAT Q64 therefore uses Mesh4/Local8.
    */
  def propClustered(
      clusterGrid: Int,
      q64Channels: NoCRouterChannelConfig = FatLane1248,
      meshLanes: Int = 4
  ): NoCScaleConfig = {
    require(Set(2, 4).contains(clusterGrid), s"PROP cluster grid must be 2 or 4, got $clusterGrid")
    require(
      Router_Architecture.CMR.CMRParameters.SupportedLaneGeometries.contains(
        (meshLanes, q64Channels.l3.parentLanes)
      ),
      s"unsupported TopMesh geometry ($meshLanes,${q64Channels.l3.parentLanes})"
    )
    NoCScaleConfig(clusterGrid, clusterGrid, q64Channels)
  }

  /** Sync Fat 1-2-4-8 64-core tile.  This is explicitly pinned so a
    * synchronous baseline cannot be changed by CMR_FAT_LANE_PROFILE. */
  def syncFatTree64_1248: NoCScaleConfig = NoCScaleConfig(1, 1, FatLane1248)

  // Default full-NoC regression scale: 2x2 quadtree tiles = 256 cores.
  val Verification256: NoCScaleConfig = NoCScaleConfig(2, 2, DefaultRouterChannels)

  // Paper-scale system: 4x4 quadtree tiles = 1024 cores.
  val Paper1024: NoCScaleConfig = NoCScaleConfig(4, 4, DefaultRouterChannels)
}

final case class NoCGenOptions(scale: NoCScaleConfig, targetDir: String = "generated")

object NoCGenOptions {
  def parse(args: Array[String], defaultScale: NoCScaleConfig): NoCGenOptions = {
    var quadNumX = defaultScale.quadNumX
    var quadNumY = defaultScale.quadNumY
    var targetDir = "generated"
    var l1ChildLanes = defaultScale.channels.l1.childLanes
    var l1ParentLanes = defaultScale.channels.l1.parentLanes
    var l2ParentLanes = defaultScale.channels.l2.parentLanes
    var l3ParentLanes = defaultScale.channels.l3.parentLanes
    var topChildLanes = defaultScale.channels.top.childLanes
    var l1FifoDepth = defaultScale.channels.l1.fifoDepth
    var l2FifoDepth = defaultScale.channels.l2.fifoDepth
    var l3FifoDepth = defaultScale.channels.l3.fifoDepth
    var topFifoDepth = defaultScale.channels.top.fifoDepth

    def loadPreset(preset: NoCScaleConfig): Unit = {
      quadNumX = preset.quadNumX
      quadNumY = preset.quadNumY
      l1ChildLanes = preset.channels.l1.childLanes
      l1ParentLanes = preset.channels.l1.parentLanes
      l2ParentLanes = preset.channels.l2.parentLanes
      l3ParentLanes = preset.channels.l3.parentLanes
      topChildLanes = preset.channels.top.childLanes
      l1FifoDepth = preset.channels.l1.fifoDepth
      l2FifoDepth = preset.channels.l2.fifoDepth
      l3FifoDepth = preset.channels.l3.fifoDepth
      topFifoDepth = preset.channels.top.fifoDepth
    }

    var idx = 0
    while (idx < args.length) {
      args(idx) match {
        case "--quad-num-x" | "--grid-x" =>
          idx = requireValue(args, idx, args(idx))
          quadNumX = args(idx).toInt
        case "--quad-num-y" | "--grid-y" =>
          idx = requireValue(args, idx, args(idx))
          quadNumY = args(idx).toInt
        case "--target-dir" =>
          idx = requireValue(args, idx, "--target-dir")
          targetDir = args(idx)
        case "--l1-child-lanes" =>
          idx = requireValue(args, idx, "--l1-child-lanes")
          l1ChildLanes = args(idx).toInt
        case "--l1-parent-lanes" | "--l2-child-lanes" =>
          idx = requireValue(args, idx, args(idx))
          l1ParentLanes = args(idx).toInt
        case "--l2-parent-lanes" | "--l3-child-lanes" =>
          idx = requireValue(args, idx, args(idx))
          l2ParentLanes = args(idx).toInt
        case "--l3-parent-lanes" | "--top-parent-lanes" =>
          idx = requireValue(args, idx, args(idx))
          l3ParentLanes = args(idx).toInt
        case "--top-child-lanes" =>
          idx = requireValue(args, idx, "--top-child-lanes")
          topChildLanes = args(idx).toInt
        case "--l1-fifo-depth" =>
          idx = requireValue(args, idx, "--l1-fifo-depth")
          l1FifoDepth = args(idx).toInt
        case "--l2-fifo-depth" =>
          idx = requireValue(args, idx, "--l2-fifo-depth")
          l2FifoDepth = args(idx).toInt
        case "--l3-fifo-depth" =>
          idx = requireValue(args, idx, "--l3-fifo-depth")
          l3FifoDepth = args(idx).toInt
        case "--top-fifo-depth" =>
          idx = requireValue(args, idx, "--top-fifo-depth")
          topFifoDepth = args(idx).toInt
        case "--paper-1024" =>
          loadPreset(NoCScaleConfig.Paper1024)
        case "--verify-256" =>
          loadPreset(NoCScaleConfig.Verification256)
        case unknown =>
          throw new IllegalArgumentException(
            s"Unknown argument '$unknown'. Supported flags: " +
              "--quad-num-x/--grid-x, --quad-num-y/--grid-y, --target-dir, " +
              "--l1-child-lanes, --l1-parent-lanes/--l2-child-lanes, " +
              "--l2-parent-lanes/--l3-child-lanes, --l3-parent-lanes/--top-parent-lanes, " +
              "--top-child-lanes, --l1-fifo-depth, --l2-fifo-depth, " +
              "--l3-fifo-depth, --top-fifo-depth, --verify-256, --paper-1024"
          )
      }
      idx += 1
    }

    val channels = NoCRouterChannelConfig(
      l1ChildLanes = l1ChildLanes,
      l1ParentLanes = l1ParentLanes,
      l2ParentLanes = l2ParentLanes,
      l3ParentLanes = l3ParentLanes,
      topChildLanes = topChildLanes,
      l1FifoDepth = l1FifoDepth,
      l2FifoDepth = l2FifoDepth,
      l3FifoDepth = l3FifoDepth,
      topFifoDepth = topFifoDepth
    )

    NoCGenOptions(NoCScaleConfig(quadNumX, quadNumY, channels), targetDir)
  }

  private def requireValue(args: Array[String], idx: Int, flag: String): Int = {
    if (idx + 1 >= args.length) {
      throw new IllegalArgumentException(s"Missing value for $flag")
    }
    idx + 1
  }
}
