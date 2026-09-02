package Router_Architecture.CMR

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.algorithm.{RoutingLogic, RoutingLogic_mesh}
import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.HasBlackBoxResource
import tool.DelayElement

/** Fig. 6 Address Register Unit: Head Predictor, Phase Selector, and Latch Reg. */
class AddressRegisterUnit
    extends BlackBox(Map("ADDRESS_WIDTH" -> CMRParameters.AddressWidth))
    with HasBlackBoxResource {
  override def desiredName: String = "AddressRegisterUnit"
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val Reqin = Input(Bool())
    val Ackout = Input(Bool())
    val Head = Input(Bool())
    val Tail = Input(Bool())
    val Address_field = Input(UInt(CMRParameters.AddressWidth.W))
    val En = Output(Bool())
    val Req_rc = Output(Bool())
    val dest = Output(UInt(CMRParameters.AddressWidth.W))
  })

  addResource("/ASYNC/CMR/AddressRegisterUnit.v")
  addResource("/ASYNC/CMR/HeadPredictor.v")
  addResource("/ASYNC/CMR/PhaseSelector.v")
  addResource("/ASYNC/CMR/Toggle.v")
  addResource("/ASYNC/DLatchBank.v")
}

/** Fig. 6 RouteSel AND: one identical T28 AND2 per multicast bit. */
class RouteSelAnd2 extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "RouteSelAnd2"
  val io = IO(new Bundle {
    val A = Input(Bool())
    val B = Input(Bool())
    val Z = Output(Bool())
  })
  addResource("/ASYNC/CMR/RouteSelAnd2.v")
}

/** Fig. 6 Internal Ack Module. */
class InternalAckModule
    extends BlackBox(Map("PORTS" -> CMRParameters.BranchCount))
    with HasBlackBoxResource {
  override def desiredName: String = "InternalAckModule"
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val RouteSel = Input(UInt(CMRParameters.BranchCount.W))
    val Ack_rc = Output(Bool())
  })

  addResource("/ASYNC/CMR/InternalAckModule.v")
  addResource("/ASYNC/CMR/Toggle.v")
}

/** Fig. 6 OPM Selector containing four packet-lifetime SR Latches. */
class OPMSelector
    extends BlackBox(Map("PORTS" -> CMRParameters.BranchCount))
    with HasBlackBoxResource {
  override def desiredName: String = "OPMSelector"
  val io = IO(new Bundle {
    val reset = Input(Bool())
    val RouteSel = Input(UInt(CMRParameters.BranchCount.W))
    val TailPassed = Input(UInt(CMRParameters.BranchCount.W))
    val PathEnabled = Output(UInt(CMRParameters.BranchCount.W))
  })

  addResource("/ASYNC/CMR/OPMSelector.v")
}

/** Fig. 6 Route Computation Logic adapted to the repository quadtree route. */
class RouteComputationLogic(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int,
    useMeshRouting: Boolean = false,
    meshGridSize: Int = 8,
    meshCoordShift: Int = 0
) extends Module {
  require(routerLevel >= 1 && routerLevel <= 3)
  require(ingressPort >= 0 && ingressPort < config.totalPorts)
  if (useMeshRouting) {
    require(routerLevel == 1)
    require(meshGridSize >= 2 && meshGridSize <= 64)
    require(meshCoordShift >= 0 && meshCoordShift <= 5)
    require(xCoordinate >= 0 && xCoordinate < meshGridSize)
    require(yCoordinate >= 0 && yCoordinate < meshGridSize)
  }
  private val LegalOutputDirections =
    CMRParameters.legalOutputDirections(config, ingressPort)
  require(LegalOutputDirections.length == CMRParameters.BranchCount)
  private val IngressDirection = config.dirOfPhys(ingressPort).U(3.W)

  val io = IO(new Bundle {
    val dest = Input(UInt(CMRParameters.AddressWidth.W))
    val Req_rc = Input(Bool())
    val Ack_rc = Output(Bool())
    val Mat = Output(Vec(CMRParameters.BranchCount, Bool()))
    val RouteSel = Output(Vec(CMRParameters.BranchCount, Bool()))
  })

  val destX0 = io.dest(PacketLayout.X0Hi - PacketLayout.X0Lo, 0)
  val destY0 = io.dest(PacketLayout.Y0Hi - PacketLayout.X0Lo, PacketLayout.Y0Lo - PacketLayout.X0Lo)
  val destX1 = io.dest(PacketLayout.X1Hi - PacketLayout.X0Lo, PacketLayout.X1Lo - PacketLayout.X0Lo)
  val destY1 = io.dest(PacketLayout.Y1Hi - PacketLayout.X0Lo, PacketLayout.Y1Lo - PacketLayout.X0Lo)
  val RouteMask = if (useMeshRouting) {
    new RoutingLogic_mesh(xCoordinate, yCoordinate, meshGridSize, meshCoordShift).routeMask(
      destX0,
      destY0,
      destX1,
      destY1,
      packetValid = true.B,
      ingressDir = IngressDirection
    )
  } else {
    new RoutingLogic(xCoordinate, yCoordinate).routeMask(
      destX0,
      destY0,
      destX1,
      destY1,
      packetValid = true.B,
      router_level = routerLevel,
      ingressDir = IngressDirection
    )
  }

  val Mat = Wire(Vec(CMRParameters.BranchCount, Bool()))
  for ((outputDirection, branch) <- LegalOutputDirections.zipWithIndex) {
    Mat(branch) := RouteMask(outputDirection)
  }
  dontTouch(Mat)

  val RouteSel = Wire(Vec(CMRParameters.BranchCount, Bool()))
  private val InternalAck = Module(new InternalAckModule)
  InternalAck.io.reset := reset.asBool
  InternalAck.io.RouteSel := RouteSel.asUInt
  val Ack_rc = InternalAck.io.Ack_rc

  // RouteSel is self-acknowledging: a transient Mat value can otherwise
  // reach InternalAckModule.Toggle before the route decode has settled and
  // permanently poison Ack_rc with X in the gate-level model.  Preserve a
  // calibrated DelayElement chain on the control launch so Mat precedes
  // RouteSel unless RcuMatchedDelaySteps is 0.
  val BundlingSignal = if (CMRParameters.RcuMatchedDelaySteps > 0) {
    val MatchedDelay = Module(new DelayElement(
      CMRParameters.RcuMatchedDelaySteps,
      DelayUnitPs = CMRParameters.RcuMatchedDelayUnitPs
    ))
    MatchedDelay.io.I := io.Req_rc
    MatchedDelay.io.Z ^ Ack_rc
  } else {
    io.Req_rc ^ Ack_rc
  }
  dontTouch(BundlingSignal)
  Seq.tabulate(CMRParameters.BranchCount) { branch =>
    val And2 = Module(new RouteSelAnd2)
    And2.suggestName(s"RouteSelAnd_$branch")
    And2.io.A := Mat(branch)
    And2.io.B := BundlingSignal
    RouteSel(branch) := And2.io.Z
    And2
  }
  dontTouch(RouteSel)

  io.Ack_rc := Ack_rc
  io.Mat := Mat
  io.RouteSel := RouteSel
}

/** Complete Fig. 6 RCU with native Packet addressing and quadtree routing. */
class RCU(
    config: RouterModuleConfig,
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int,
    ingressPort: Int,
    useMeshRouting: Boolean = false,
    meshGridSize: Int = 8,
    meshCoordShift: Int = 0
) extends Module {
  override def desiredName: String = "RCU"
  require(CMRParameters.SupportedLaneGeometries.contains(
    (config.childLanes, config.parentLanes)
  ))
  require(routerLevel >= 1 && routerLevel <= 3)

  val io = IO(new Bundle {
    val Reqin = Input(Bool())
    val Ackout = Input(Bool())
    val Datain = Input(new Packet)
    val TailPassed = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Mat = Output(Vec(CMRParameters.BranchCount, Bool()))
    val RouteSel = Output(Vec(CMRParameters.BranchCount, Bool()))
    val PathEnabled = Output(Vec(CMRParameters.BranchCount, Bool()))
  })

  private val AddressRegister = Module(new AddressRegisterUnit)
  AddressRegister.io.reset := reset.asBool
  AddressRegister.io.Reqin := io.Reqin
  AddressRegister.io.Ackout := io.Ackout
  AddressRegister.io.Head := io.Datain.flit(PacketLayout.IsHeadIndex)
  AddressRegister.io.Tail := io.Datain.flit(PacketLayout.IsTailIndex)
  AddressRegister.io.Address_field := CMRParameters.Address_field(io.Datain)

  private val RouteComputation = Module(new RouteComputationLogic(
    config, xCoordinate, yCoordinate, routerLevel, ingressPort,
    useMeshRouting, meshGridSize, meshCoordShift
  ))
  RouteComputation.io.dest := AddressRegister.io.dest
  RouteComputation.io.Req_rc := AddressRegister.io.Req_rc

  private val Selector = Module(new OPMSelector)
  Selector.io.reset := reset.asBool
  Selector.io.RouteSel := RouteComputation.io.RouteSel.asUInt
  Selector.io.TailPassed := io.TailPassed.asUInt

  dontTouch(RouteComputation.io.Mat)
  io.Mat := RouteComputation.io.Mat
  io.RouteSel := RouteComputation.io.RouteSel
  io.PathEnabled := VecInit(Selector.io.PathEnabled.asBools)
}

private class AddressRegisterUnitElaboration extends Module {
  val io = IO(new Bundle {
    val Reqin = Input(Bool()); val Ackout = Input(Bool())
    val Head = Input(Bool()); val Tail = Input(Bool())
    val Address_field = Input(UInt(CMRParameters.AddressWidth.W))
    val En = Output(Bool()); val Req_rc = Output(Bool())
    val dest = Output(UInt(CMRParameters.AddressWidth.W))
  })
  private val AddressRegister = Module(new AddressRegisterUnit)
  AddressRegister.io.reset := reset.asBool
  AddressRegister.io.Reqin := io.Reqin
  AddressRegister.io.Ackout := io.Ackout
  AddressRegister.io.Head := io.Head
  AddressRegister.io.Tail := io.Tail
  AddressRegister.io.Address_field := io.Address_field
  io.En := AddressRegister.io.En
  io.Req_rc := AddressRegister.io.Req_rc
  io.dest := AddressRegister.io.dest
}

private class OPMSelectorElaboration extends Module {
  val io = IO(new Bundle {
    val RouteSel = Input(UInt(CMRParameters.BranchCount.W))
    val TailPassed = Input(UInt(CMRParameters.BranchCount.W))
    val PathEnabled = Output(UInt(CMRParameters.BranchCount.W))
  })
  private val Selector = Module(new OPMSelector)
  Selector.io.reset := reset.asBool
  Selector.io.RouteSel := io.RouteSel
  Selector.io.TailPassed := io.TailPassed
  io.PathEnabled := Selector.io.PathEnabled
}

object AddressRegisterUnitMain extends App {
  emitVerilog(
    new AddressRegisterUnitElaboration,
    Array("--target-dir", "generated_cmr/address_register")
  )
}

object OPMSelectorMain extends App {
  emitVerilog(
    new OPMSelectorElaboration,
    Array("--target-dir", "generated_cmr/opm_selector")
  )
}

object RouteComputationLogicMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1, parentLanes = 1, fifoDepth = 5, vcCount = 1,
    allowSameDirChild = false, allowSameDirParent = false
  )
  emitVerilog(
    new RouteComputationLogic(config, 0, 0, routerLevel = 1, ingressPort = 4),
    Array("--target-dir", "generated_cmr/route_computation")
  )
}

object RCUMain extends App {
  private val routerLevel = args.headOption.map(_.toInt).getOrElse(1)
  require(routerLevel >= 1 && routerLevel <= 3)
  private val config = RouterModuleConfig(
    childLanes = 1, parentLanes = 1, fifoDepth = 5, vcCount = 1,
    allowSameDirChild = false, allowSameDirParent = false
  )
  emitVerilog(
    new RCU(config, 0, 0, routerLevel, ingressPort = 4),
    Array("--target-dir", s"generated_cmr/rcu_l$routerLevel")
  )
}
