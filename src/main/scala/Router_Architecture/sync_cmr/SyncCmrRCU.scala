package Router_Architecture.sync_cmr

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.CMR.CMRParameters
import Router_Architecture.algorithm.RoutingLogic
import Router_Architecture.common.RouterModuleConfig
import chisel3._

  /**
    * Clocked Fig. 6 RCU.  Head latches the destination rectangle; Body/Tail
    * keep that lock.  Quadtree `RoutingLogic` produces Mat combinationally
    * from destReg (visible the cycle after Head fire, same cycle as CellFull).
    * Isolated hop is one clock: PathEnabled from destReg, then combinational
    * liveGrant / LaneSelect in SyncOPM.  There is no DelayElement and no extra
    * match-delay register.  Per-branch TailPassed still drops that bit so a
    * finished output does not keep requesting.
    */
class SyncCmrRCU(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int
) extends Module {
  override def desiredName: String = "SyncCmrRCU"
  require(CMRParameters.SupportedLaneGeometries.contains(
    (config.childLanes, config.parentLanes)
  ))
  require(routerLevel >= 1 && routerLevel <= 3)
  require(ingressPort >= 0 && ingressPort < config.totalPorts)

  private val LegalOutputDirections =
    CMRParameters.legalOutputDirections(config, ingressPort)
  require(LegalOutputDirections.length == CMRParameters.BranchCount)
  private val QuadtreeRoute = new RoutingLogic(xCoordinate, yCoordinate)
  private val IngressDirection = config.dirOfPhys(ingressPort).U(3.W)

  val io = IO(new Bundle {
    val validIn = Input(Bool())
    val readyIn = Input(Bool())
    val Datain = Input(new Packet)
    val TailPassed = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Mat = Output(Vec(CMRParameters.BranchCount, Bool()))
    val RouteSel = Output(Vec(CMRParameters.BranchCount, Bool()))
    val PathEnabled = Output(Vec(CMRParameters.BranchCount, Bool()))
  })

  private val fire = io.validIn && io.readyIn
  private val isHead = io.Datain.flit(PacketLayout.IsHeadIndex)
  private val headFire = fire && isHead

  private val destReg = RegInit(0.U(CMRParameters.AddressWidth.W))
  private val destHold = RegInit(false.B)
  private val tailCleared = RegInit(VecInit(Seq.fill(CMRParameters.BranchCount)(false.B)))

  private val destX0 = destReg(PacketLayout.X0Hi - PacketLayout.X0Lo, 0)
  private val destY0 =
    destReg(PacketLayout.Y0Hi - PacketLayout.X0Lo, PacketLayout.Y0Lo - PacketLayout.X0Lo)
  private val destX1 =
    destReg(PacketLayout.X1Hi - PacketLayout.X0Lo, PacketLayout.X1Lo - PacketLayout.X0Lo)
  private val destY1 =
    destReg(PacketLayout.Y1Hi - PacketLayout.X0Lo, PacketLayout.Y1Lo - PacketLayout.X0Lo)
  private val RouteMask = QuadtreeRoute.routeMask(
    destX0,
    destY0,
    destX1,
    destY1,
    packetValid = destHold,
    router_level = routerLevel,
    ingressDir = IngressDirection
  )

  val Mat = Wire(Vec(CMRParameters.BranchCount, Bool()))
  val PathEnabled = Wire(Vec(CMRParameters.BranchCount, Bool()))
  val RouteSel = Wire(Vec(CMRParameters.BranchCount, Bool()))
  for ((outputDirection, branch) <- LegalOutputDirections.zipWithIndex) {
    Mat(branch) := RouteMask(outputDirection) && destHold
    PathEnabled(branch) := Mat(branch) && !tailCleared(branch)
    RouteSel(branch) := PathEnabled(branch)
    when (io.TailPassed(branch)) {
      tailCleared(branch) := true.B
    }
  }
  dontTouch(Mat)
  dontTouch(RouteSel)

  when (headFire) {
    destReg := CMRParameters.Address_field(io.Datain)
    destHold := true.B
    tailCleared := VecInit(Seq.fill(CMRParameters.BranchCount)(false.B))
  }.elsewhen (destHold && !PathEnabled.asUInt.orR) {
    destHold := false.B
  }

  io.Mat := Mat
  io.RouteSel := RouteSel
  io.PathEnabled := PathEnabled
}

object SyncCmrRCUMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  require(routerLevel >= 1 && routerLevel <= 3)
  private val config = SyncCmrConfig(1, 1)
  emitVerilog(
    new SyncCmrRCU(config, 0, 0, routerLevel, ingressPort = 4),
    Array("--target-dir", s"generated_sync_cmr/rcu_l$routerLevel")
  )
}
