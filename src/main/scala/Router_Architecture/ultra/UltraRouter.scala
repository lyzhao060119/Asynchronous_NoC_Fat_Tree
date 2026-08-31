package Router_Architecture.ultra

import DataStruct.HS_Packet
import Router_Architecture.common.{RouterDirGroupedHSIO, RouterModuleConfig}
import chisel3._

/**
  * One five-port Ultra/Transition multicast router.
  *
  * Forward path:
  *   Modified Mousetrap V1 -> PRS -> Atomic admission -> ReqGeneratorBank
  *   -> OPM
  *
  * Feedback paths:
  *   OPM TP -> MulticastTailJoin -> Atomic admission owner release
  *   OPM Ack/Grant/MG -> ReqGeneratorBank -> Done -> AckGenerator
  */
class UltraRouter(
    xCoordinate: Int,
    yCoordinate: Int,
    routerLevel: Int
) extends Module {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )
  private val nPorts = config.totalPorts
  private val nBranches = nPorts - 1

  val io = IO(new Bundle {
    val inputs = new RouterDirGroupedHSIO(1, 1)
    val outputs = Flipped(new RouterDirGroupedHSIO(1, 1))
  })

  private def inputPort(index: Int): HS_Packet = {
    val direction = config.dirOfPhys(index)
    if (direction < 4) io.inputs.child(direction)(0) else io.inputs.parent(0)
  }

  private def outputPort(index: Int): HS_Packet = {
    val direction = config.dirOfPhys(index)
    if (direction < 4) io.outputs.child(direction)(0) else io.outputs.parent(0)
  }

  private val inputModules = Seq.tabulate(nPorts) { input =>
    Module(new IPM(config, xCoordinate, yCoordinate, routerLevel, input))
  }
  private val requestBanks =
    Seq.fill(nPorts)(Module(new RequestGeneratorBank(nBranches)))
  private val outputModules =
    Seq.tabulate(nPorts)(output => Module(new OPM(config, output)))
  // V2 freezes an asynchronous round into a transaction latch before the
  // single ACG commit.  The legacy AtomicMulticastAdmission remains available
  // as an independent reference implementation.
  private val admission = Module(new AtomicMulticastArbiterV2(config))
  private val tailJoin = Module(new MulticastTailJoin(config))

  // TailJoin is a Router-level reverse-control peer of Atomic admission. It
  // observes Atomic's stable packet ownership state and returns only joined
  // completion and the old-TP reallocation barrier.
  tailJoin.io.packetMask := admission.io.packetMask
  tailJoin.io.packetActive := admission.io.packetActive
  tailJoin.io.outputOwner := admission.io.outputOwner
  admission.io.allTailPassed := tailJoin.io.allTailPassed
  admission.io.outputTailBusy := tailJoin.io.outputTailBusy

  // Input front ends and central packet-set admission.
  for (input <- 0 until nPorts) {
    val port = inputPort(input)
    val ipm = inputModules(input)
    val bank = requestBanks(input)

    ipm.io.ReqIn := port.HS.Req
    ipm.io.DataIn := port.Data
    port.HS.Ack := ipm.io.AckIn

    admission.io.RS(input) := ipm.io.RS
    ipm.io.tailReleaseReady := admission.io.tailReleaseReady(input)
    // The IPM's raw route selection terminates at Atomic.  Only Atomic's
    // winner-preserving admittedRS may enter ReqGeneratorBank as paper RS.
    bank.io.RS := admission.io.admittedRS(input)

    bank.io.ReqX := ipm.io.ReqX
    ipm.io.Done := bank.io.Done
  }

  // The local branch order on both sides is derived once from the explicit
  // no-U-turn topology. Every legal edge receives one forward connection and
  // its corresponding Ack/Grant/MG feedback connection.
  for (input <- 0 until nPorts) {
    val legalOutputs = UltraTopology.legalOutputPorts(config, input)
    require(legalOutputs.length == nBranches)

    for ((output, inputBranch) <- legalOutputs.zipWithIndex) {
      val legalInputs = UltraTopology.legalInputPorts(config, output)
      val outputSource = legalInputs.indexOf(input)
      require(outputSource >= 0)

      outputModules(output).io.Req(outputSource) :=
        requestBanks(input).io.Req(inputBranch)
      outputModules(output).io.PPE(outputSource) :=
        requestBanks(input).io.PPE(inputBranch)
      outputModules(output).io.DataX(outputSource) :=
        inputModules(input).io.DataX

      requestBanks(input).io.Ack(inputBranch) :=
        outputModules(output).io.Ack(outputSource)
      requestBanks(input).io.Grant(inputBranch) :=
        outputModules(output).io.Grant(outputSource)
      requestBanks(input).io.MG(inputBranch) :=
        outputModules(output).io.MG(outputSource)
    }
  }

  // Output handshakes and the reverse Tail completion feedback matrix.
  for (output <- 0 until nPorts) {
    val port = outputPort(output)
    val opm = outputModules(output)

    port.HS.Req := opm.io.ReqOut
    port.Data := opm.io.DataOut
    opm.io.AckOut := port.HS.Ack

    tailJoin.io.TailPassed(output) := opm.io.TailPassed
  }

}

object UltraRouterMain extends App {
  emitVerilog(
    new UltraRouter(
      xCoordinate = 0,
      yCoordinate = 0,
      routerLevel = 1
    ),
    Array("--target-dir", "generated_ultra", "UltraRouter")
  )
}
