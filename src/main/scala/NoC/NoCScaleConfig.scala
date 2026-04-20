package NoC

// Shared scale metadata for the tiled NoC top-level generators.
final case class NoCScaleConfig(quadNumX: Int, quadNumY: Int) {
  require(quadNumX > 0, s"quadNumX must be positive, got $quadNumX")
  require(quadNumY > 0, s"quadNumY must be positive, got $quadNumY")

  val tileEdge: Int = 8
  val coresPerQuad: Int = tileEdge * tileEdge
  val quadNum: Int = quadNumX * quadNumY
  val totalNodes: Int = quadNum * coresPerQuad
}

object NoCScaleConfig {
  // Default full-NoC regression scale: 2x2 quadtree tiles = 256 cores.
  val Verification256: NoCScaleConfig = NoCScaleConfig(2, 2)

  // Paper-scale system: 4x4 quadtree tiles = 1024 cores.
  val Paper1024: NoCScaleConfig = NoCScaleConfig(4, 4)
}

final case class NoCGenOptions(scale: NoCScaleConfig, targetDir: String = "generated")

object NoCGenOptions {
  def parse(args: Array[String], defaultScale: NoCScaleConfig): NoCGenOptions = {
    var quadNumX = defaultScale.quadNumX
    var quadNumY = defaultScale.quadNumY
    var targetDir = "generated"

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
        case "--paper-1024" =>
          quadNumX = NoCScaleConfig.Paper1024.quadNumX
          quadNumY = NoCScaleConfig.Paper1024.quadNumY
        case "--verify-256" =>
          quadNumX = NoCScaleConfig.Verification256.quadNumX
          quadNumY = NoCScaleConfig.Verification256.quadNumY
        case unknown =>
          throw new IllegalArgumentException(
            s"Unknown argument '$unknown'. Supported flags: " +
              "--quad-num-x/--grid-x, --quad-num-y/--grid-y, --target-dir, --verify-256, --paper-1024"
          )
      }
      idx += 1
    }

    NoCGenOptions(NoCScaleConfig(quadNumX, quadNumY), targetDir)
  }

  private def requireValue(args: Array[String], idx: Int, flag: String): Int = {
    if (idx + 1 >= args.length) {
      throw new IllegalArgumentException(s"Missing value for $flag")
    }
    idx + 1
  }
}
