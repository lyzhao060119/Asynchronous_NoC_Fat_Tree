package Router_Architecture.CMR

import Router_Architecture.common.RouterModuleConfig
import Router_Architecture.ultra.UltraTopology
import chisel3._

/** Emit L2 (2,2) and L3 (4,8)/(2,2) routers and print adapter/mutex widths. */
object CMRFat64GeometryEmitMain extends App {
  private val LegalOpmSources = Set(4, 5, 8, 10, 16, 20)
  private val jobs = Seq(
    (2, 2, 2),
    (3, 4, 8),
    (3, 2, 2)
  )

  for ((level, childLanes, parentLanes) <- jobs) {
    require(CMRParameters.SupportedLaneGeometries.contains((childLanes, parentLanes)))
    val config = RouterModuleConfig(
      childLanes = childLanes,
      parentLanes = parentLanes,
      fifoDepth = CMRParameters.CellCount,
      vcCount = 1,
      allowSameDirChild = false,
      allowSameDirParent = false
    )
    val adapters = CMRParameters.expectedLaneAdapters(childLanes, parentLanes)
    val sourceCounts = (0 until config.totalPorts).map { egress =>
      UltraTopology.legalInputPorts(config, egress).length
    }
    require(sourceCounts.forall(LegalOpmSources.contains),
      s"L$level c${childLanes}p$parentLanes has illegal OPM SourceCount $sourceCounts")
    val mutexHistogram = sourceCounts.groupBy(identity).view.mapValues(_.size).toMap
    println(
      s"CMR_GEOMETRY L$level c${childLanes}_p$parentLanes ports=${config.totalPorts} " +
        s"ADAPTER=$adapters OPM_SOURCE=${sourceCounts.mkString(",")} " +
        s"MUTEX_N=${mutexHistogram.toSeq.sortBy(_._1).map { case (w, n) => s"$w:$n" }.mkString(",")}"
    )
    emitVerilog(
      new CMRRouter(0, 0, level, childLanes, parentLanes),
      Array(
        "--target-dir",
        s"generated_cmr/router_l${level}_c${childLanes}_p${parentLanes}"
      )
    )
  }
}
