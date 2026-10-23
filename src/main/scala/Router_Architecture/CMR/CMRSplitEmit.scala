package Router_Architecture.CMR

import chisel3._
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets.UTF_8

/** Elaboration-only switch. Normal emission continues to elaborate real routers. */
object CMRSplitEmit {
  case class Key(x: Int, y: Int, level: Int, child: Int, parent: Int,
                 mesh: Boolean, grid: Int, shift: Int, static: Boolean) {
    def name: String = s"CMRRouter_split_l${level}_c${child}_p${parent}_x${x}_y${y}_m${if(mesh) 1 else 0}_g${grid}_s${shift}_a${if(static) 1 else 0}"
  }
  var cataloguing = false
  val keys = scala.collection.mutable.LinkedHashSet.empty[Key]
}

/** Emit wiring using the existing topology, then bounded-size router compilations.
  * Each child directory is an independent synthesis input (do not concatenate
  * duplicate helper modules from different child directories).
  */
object CMRSplitNetworkEmitMain extends App {
  import CMRSplitEmit._
  val kind = args.headOption.getOrElse("mesh1024")
  val root = args.drop(1).headOption.getOrElse(s"generated_cmr/${kind}_split")
  val limit = args.drop(2).headOption.map(_.toInt).getOrElse(Int.MaxValue)
  require(Set("mesh1024", "m16_1024", "mesh16").contains(kind))
  Files.createDirectories(Paths.get(root))
  val digest = java.security.MessageDigest.getInstance("SHA-256")
  val sources = Files.walk(Paths.get("src/main"))
  try {
    import scala.jdk.CollectionConverters._
    sources.iterator.asScala.filter(Files.isRegularFile(_)).toVector.sortBy(_.toString).foreach { p =>
      digest.update(p.toString.getBytes(UTF_8))
      digest.update(Files.readAllBytes(p))
    }
  } finally sources.close()
  sys.env.toVector.filter(_._1.startsWith("CMR_")).sortBy(_._1).foreach { case (k,v) =>
    digest.update(s"$k=$v\n".getBytes(UTF_8))
  }
  val fingerprint = digest.digest.map(b => f"${b & 255}%02x").mkString
  val frozen = Paths.get(root, "source_environment.sha256")
  if (Files.exists(frozen)) require(new String(Files.readAllBytes(frozen), UTF_8).trim == fingerprint,
    "Source/environment changed: select a new output directory before resuming")
  else Files.write(frozen, s"$fingerprint\n".getBytes(UTF_8))
  keys.clear()
  cataloguing = true
  try {
    kind match {
      case "mesh16" => emitVerilog(new NoC.CMR.CMRMeshNoC(4), Array("--target-dir", s"$root/top"))
      case "mesh1024" => emitVerilog(new NoC.CMR.CMRMeshNoC(32), Array("--target-dir", s"$root/top"))
      case "m16_1024" => emitVerilog(new NoC.CMR.PROPtemp1024M16, Array("--target-dir", s"$root/top"))
    }
  } finally { cataloguing = false }
  val rows = keys.toVector
  Files.write(Paths.get(root, "routers.tsv"),
    ("ref\tx\ty\tlevel\tchild\tparent\tmesh\tgrid\tshift\tstatic\n" + rows.map(k =>
      s"${k.name}\t${k.x}\t${k.y}\t${k.level}\t${k.child}\t${k.parent}\t${k.mesh}\t${k.grid}\t${k.shift}\t${k.static}"
    ).mkString("\n") + "\n").getBytes(UTF_8))
  println(s"CMR_SPLIT_CATALOG_PASS kind=$kind unique=${rows.size}")
  rows.take(limit).zipWithIndex.foreach { case (k, i) =>
    val dir = s"$root/children/${k.name}"
    val output = Paths.get(dir, s"${k.name}.v")
    // Resume only a child with an explicit completion marker from this run.
    val marker = Paths.get(dir, "EMIT_PASS")
    if (!Files.exists(marker)) {
      emitVerilog(new CMRRouter(k.x, k.y, k.level, k.child, k.parent,
        k.mesh, k.grid, k.shift, k.static) {
          override def desiredName: String = k.name
        }, Array("--target-dir", dir))
      require(Files.size(output) > 0)
      Files.write(marker, s"${k.name}\n".getBytes(UTF_8))
    }
    println(s"CMR_SPLIT_CHILD_PASS ${i+1}/${rows.size} ${k.name}")
    System.gc()
  }
  if (limit >= rows.size) println(s"CMR_SPLIT_EMIT_PASS kind=$kind children=${rows.size}")
}
