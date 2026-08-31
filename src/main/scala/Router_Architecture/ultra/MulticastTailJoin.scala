package Router_Architecture.ultra

import Router_Architecture.common.RouterModuleConfig
import chisel3._
import chisel3.util.log2Ceil

/**
  * Per-input multicast Tail completion collector.
  *
  * Each OPM reports one TailPassed level for every legal source IPM. This
  * module maps those local source positions back to global input/output pairs,
  * then retains every observed branch completion until AtomicMulticastAdmission
  * releases the complete packet set.
  */
class MulticastTailJoin(config: RouterModuleConfig) extends Module {
  require(config.totalPorts == 5, "MulticastTailJoin currently targets 5 ports.")
  require(
    config.childLanes == 1 && config.parentLanes == 1,
    "MulticastTailJoin currently targets one lane per direction."
  )

  private val nPorts = config.totalPorts
  private val nSources = nPorts - 1
  private val ownerW = log2Ceil(nPorts + 1)

  val io = IO(new Bundle {
    val TailPassed = Input(Vec(nPorts, Vec(nSources, Bool())))
    val packetMask = Input(Vec(nPorts, UInt(nPorts.W)))
    val packetActive = Input(Vec(nPorts, Bool()))
    val outputOwner = Input(Vec(nPorts, UInt(ownerW.W)))

    val allTailPassed = Output(Vec(nPorts, Bool()))
    val outputTailBusy = Output(Vec(nPorts, Bool()))
  })

  val tailEvent = Wire(Vec(nPorts, Vec(nPorts, Bool())))

  for (output <- 0 until nPorts) {
    io.outputTailBusy(output) := io.TailPassed(output).asUInt.orR

    val legalSources = UltraTopology.legalInputPorts(config, output)
    for (input <- 0 until nPorts) {
      legalSources.indexOf(input) match {
        case localSource if localSource >= 0 =>
          tailEvent(input)(output) :=
            io.packetActive(input) &&
              io.packetMask(input)(output) &&
              io.outputOwner(output) === input.U(ownerW.W) &&
              io.TailPassed(output)(localSource)
        case _ =>
          tailEvent(input)(output) := false.B
      }
    }
  }

  // One WIDTH=5 paper-level latch bank per input stores the sticky completion
  // bitmap. Inactive/reset opens the bank with zero; any Tail event opens it
  // with the accumulated bitmap; otherwise it remains opaque.
  val tailSeenLatches = Seq.fill(nPorts)(Module(new UltraDLatchBank(nPorts)))
  for (input <- 0 until nPorts) {
    val clear = !io.packetActive(input)
    val events = tailEvent(input).asUInt
    val retained = tailSeenLatches(input).io.q

    tailSeenLatches(input).io.reset := reset.asBool
    tailSeenLatches(input).io.en := clear || events.orR
    tailSeenLatches(input).io.d := Mux(clear, 0.U, retained | events)

    io.allTailPassed(input) :=
      io.packetActive(input) &&
        io.packetMask(input).orR &&
        ((retained & io.packetMask(input)) === io.packetMask(input))
  }
}

object MulticastTailJoinMain extends App {
  private val config = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 1,
    fifoDepth = 1,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  emitVerilog(
    new MulticastTailJoin(config),
    Array("--target-dir", "generated_ultra", "MulticastTailJoin")
  )
}
