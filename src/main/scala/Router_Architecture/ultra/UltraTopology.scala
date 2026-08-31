package Router_Architecture.ultra

import Router_Architecture.common.RouterModuleConfig

/** Static Ultra topology: packets never U-turn toward their ingress direction. */
object UltraTopology {
  def legalOutputPorts(config: RouterModuleConfig, ingressPort: Int): IndexedSeq[Int] = {
    require(ingressPort >= 0 && ingressPort < config.totalPorts)
    val ingressDir = config.dirOfPhys(ingressPort)
    val ports = (0 until config.totalPorts).filter(config.dirOfPhys(_) != ingressDir).toIndexedSeq
    require(ports.nonEmpty, "An Ultra IPM must retain at least one egress direction.")
    ports
  }

  /** Ordered global input ports occupying one OPM's local source positions. */
  def legalInputPorts(config: RouterModuleConfig, egressPort: Int): IndexedSeq[Int] = {
    require(egressPort >= 0 && egressPort < config.totalPorts)
    val ports =
      (0 until config.totalPorts).filter(config.canConnect(_, egressPort)).toIndexedSeq
    require(ports.nonEmpty, "An Ultra OPM must retain at least one source input.")
    ports
  }
}
