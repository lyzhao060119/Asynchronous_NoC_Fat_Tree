package Router_Architecture.CMR

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.ultra.UltraDLatchBank
import chisel3._
import chisel3.util.{HasBlackBoxResource, Mux1H}

/** Fig. 7 control for one of the five CMR storage cells. */
class WriteControlUnit(initialPhase: Int)
    extends BlackBox(Map("INITIAL_PHASE" -> initialPhase))
    with HasBlackBoxResource {
  require(initialPhase == 0 || initialPhase == 1)
  override def desiredName: String = "WriteControlUnit"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val Reqin = Input(Bool())
    val WritePointer = Input(Bool())
    val Tail = Input(Bool())
    val CellEmpty = Input(UInt(CMRParameters.BranchCount.W))
    val Ackout = Output(Bool())
    val CellFull = Output(Bool())
  })

  addResource("/ASYNC/CMR/WriteControlUnit.v")
  addResource("/ASYNC/CMR/PhaseResetDLatch.v")
  addResource("/ASYNC/CMR/Toggle.v")
}

/** Fig. 7 two-phase five-slot one-hot Write Counter. */
class WriteCounter extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "WriteCounter"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val Reqin = Input(Bool())
    val Ackout = Input(Bool())
    val WritePointer = Output(UInt(CMRParameters.CellCount.W))
  })

  addResource("/ASYNC/CMR/WriteCounter.v")
}

/** Fig. 7 five-input XOR Ack Generator. */
class WriteAckGenerator extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "WriteAckGenerator"

  val io = IO(new Bundle {
    val AckoutCell = Input(UInt(CMRParameters.CellCount.W))
    val Ackout = Output(Bool())
  })

  addResource("/ASYNC/CMR/WriteAckGenerator.v")
}

/** One capture-pass register in the Fig. 5 Storage Unit. */
class StorageCell extends Module {
  val io = IO(new Bundle {
    val En = Input(Bool())
    val Datain = Input(new Packet)
    val Dataout = Output(new Packet)
  })

  private val LatchReg = Module(new UltraDLatchBank(PacketLayout.FlitWidth))
  LatchReg.io.reset := reset.asBool
  LatchReg.io.en := io.En
  LatchReg.io.d := io.Datain.flit
  io.Dataout.flit := LatchReg.io.q
}

/** Complete Continuous paper Fig. 7 Write Interface Control. */
class WriteInterfaceControl extends Module {
  val io = IO(new Bundle {
    val Reqin = Input(Bool())
    val CellEmpty = Input(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
    val Tail = Input(Vec(CMRParameters.CellCount, Bool()))
    val Ackout = Output(Bool())
    val WritePointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellFull = Output(Vec(CMRParameters.CellCount, Bool()))
  })

  private val InitialPhase = Seq(0, 1, 0, 1, 0)
  require(InitialPhase.length == CMRParameters.CellCount)

  private val AckGenerator = Module(new WriteAckGenerator)
  private val Counter = Module(new WriteCounter)
  private val ControlUnit = InitialPhase.map(phase => Module(new WriteControlUnit(phase)))

  Counter.io.reset := reset.asBool
  Counter.io.Reqin := io.Reqin
  Counter.io.Ackout := AckGenerator.io.Ackout
  val WritePointer = VecInit(Counter.io.WritePointer.asBools)

  for (cell <- 0 until CMRParameters.CellCount) {
    ControlUnit(cell).io.reset := reset.asBool
    ControlUnit(cell).io.Reqin := io.Reqin
    ControlUnit(cell).io.WritePointer := WritePointer(cell)
    ControlUnit(cell).io.Tail := io.Tail(cell)
    ControlUnit(cell).io.CellEmpty := VecInit.tabulate(CMRParameters.BranchCount) { branch =>
      io.CellEmpty(branch)(cell)
    }.asUInt
  }

  AckGenerator.io.AckoutCell := VecInit(ControlUnit.map(_.io.Ackout)).asUInt
  io.Ackout := AckGenerator.io.Ackout
  io.WritePointer := WritePointer
  io.CellFull := VecInit(ControlUnit.map(_.io.CellFull))
}

/** Fig. 8 control for one of the five CMR storage cells. */
class ReadControlUnit(initialPhase: Int)
    extends BlackBox(Map("INITIAL_PHASE" -> initialPhase))
    with HasBlackBoxResource {
  require(initialPhase == 0 || initialPhase == 1)
  override def desiredName: String = "ReadControlUnit"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val CellFull = Input(Bool())
    val ReadPointer = Input(Bool())
    val AckX = Input(Bool())
    val Req = Output(Bool())
    val CellEmpty = Output(Bool())
  })

  addResource("/ASYNC/CMR/ReadControlUnit.v")
  addResource("/ASYNC/CMR/PhaseResetDLatch.v")
}

/** Fig. 8 two-phase five-slot one-hot Read Counter. */
class ReadCounter extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "ReadCounter"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val ReqX = Input(Bool())
    val AckX = Input(Bool())
    val ReadPointer = Output(UInt(CMRParameters.CellCount.W))
  })

  addResource("/ASYNC/CMR/ReadCounter.v")
}

/** Fig. 8 five-input XOR Request Generator. */
class ReadRequestGenerator extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "ReadRequestGenerator"

  val io = IO(new Bundle {
    val Req = Input(UInt(CMRParameters.CellCount.W))
    val ReqX = Output(Bool())
  })

  addResource("/ASYNC/CMR/ReadRequestGenerator.v")
}

/** Fig. 8 speculative wrong-path request Phase Selector. */
class ReadPhaseSelector(localBranch: Int)
    extends BlackBox(Map("LOCAL_BRANCH" -> localBranch))
    with HasBlackBoxResource {
  require(localBranch >= 0 && localBranch < CMRParameters.BranchCount)
  override def desiredName: String = "ReadPhaseSelector"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val ReqX = Input(Bool())
    val Ackin = Input(Bool())
    val PathEnabled = Input(UInt(CMRParameters.BranchCount.W))
    val Reqout = Output(Bool())
  })

  addResource("/ASYNC/CMR/ReadPhaseSelector.v")
  addResource("/ASYNC/CMR/Toggle.v")
}

/** Fig. 8 XNOR-completion internal Ack Generator. */
class ReadAckGenerator extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "ReadAckGenerator"

  val io = IO(new Bundle {
    val reset = Input(Bool())
    val Reqout = Input(Bool())
    val Ackin = Input(Bool())
    val AckX = Output(Bool())
  })

  addResource("/ASYNC/CMR/ReadAckGenerator.v")
  addResource("/ASYNC/CMR/Toggle.v")
}

/** Complete Continuous paper Fig. 8 Read Interface Control. */
class ReadInterfaceControl(localBranch: Int) extends Module {
  require(localBranch >= 0 && localBranch < CMRParameters.BranchCount)

  val io = IO(new Bundle {
    val CellFull = Input(Vec(CMRParameters.CellCount, Bool()))
    val Datain = Input(Vec(CMRParameters.CellCount, new Packet))
    val PathEnabled = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Ackin = Input(Bool())
    val Reqout = Output(Bool())
    val Dataout = Output(new Packet)
    val ReadPointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellEmpty = Output(Vec(CMRParameters.CellCount, Bool()))
  })

  private val InitialPhase = Seq(0, 1, 0, 1, 0)
  require(InitialPhase.length == CMRParameters.CellCount)

  private val Counter = Module(new ReadCounter)
  private val ControlUnit = InitialPhase.map(phase => Module(new ReadControlUnit(phase)))
  private val RequestGenerator = Module(new ReadRequestGenerator)
  private val PhaseSelector = Module(new ReadPhaseSelector(localBranch))
  private val AckGenerator = Module(new ReadAckGenerator)

  Counter.io.reset := reset.asBool
  Counter.io.ReqX := RequestGenerator.io.ReqX
  Counter.io.AckX := AckGenerator.io.AckX
  val ReadPointer = VecInit(Counter.io.ReadPointer.asBools)

  for (cell <- 0 until CMRParameters.CellCount) {
    ControlUnit(cell).io.reset := reset.asBool
    ControlUnit(cell).io.CellFull := io.CellFull(cell)
    ControlUnit(cell).io.ReadPointer := ReadPointer(cell)
    ControlUnit(cell).io.AckX := AckGenerator.io.AckX
  }

  RequestGenerator.io.Req := VecInit(ControlUnit.map(_.io.Req)).asUInt
  PhaseSelector.io.reset := reset.asBool
  PhaseSelector.io.ReqX := RequestGenerator.io.ReqX
  PhaseSelector.io.Ackin := io.Ackin
  PhaseSelector.io.PathEnabled := io.PathEnabled.asUInt
  AckGenerator.io.reset := reset.asBool
  AckGenerator.io.Reqout := PhaseSelector.io.Reqout
  AckGenerator.io.Ackin := io.Ackin

  io.Reqout := PhaseSelector.io.Reqout
  io.Dataout := Mux1H(ReadPointer, io.Datain)
  io.ReadPointer := ReadPointer
  io.CellEmpty := VecInit(ControlUnit.map(_.io.CellEmpty))
}

/** Complete Fig. 5 CMR Buffer without the optional Mesh AMU datapath. */
class CMRBuffer extends Module {
  val io = IO(new Bundle {
    val Reqin = Input(Bool())
    val Datain = Input(new Packet)
    val Ackout = Output(Bool())
    val PathEnabled = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Ackin = Input(Vec(CMRParameters.BranchCount, Bool()))
    val Reqout = Output(Vec(CMRParameters.BranchCount, Bool()))
    val Dataout = Output(Vec(CMRParameters.BranchCount, new Packet))
    val WritePointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val ReadPointer = Output(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
    val CellFull = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellEmpty = Output(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
  })

  private val WriteInterface = Module(new WriteInterfaceControl)
  private val StorageUnit = Seq.fill(CMRParameters.CellCount)(Module(new StorageCell))
  private val ReadInterface = Seq.tabulate(CMRParameters.BranchCount) { branch =>
    Module(new ReadInterfaceControl(branch))
  }

  WriteInterface.io.Reqin := io.Reqin
  WriteInterface.io.CellEmpty := VecInit(ReadInterface.map(_.io.CellEmpty))
  WriteInterface.io.Tail := VecInit(StorageUnit.map(_.io.Dataout.flit(PacketLayout.IsTailIndex)))

  for (cell <- 0 until CMRParameters.CellCount) {
    StorageUnit(cell).io.En := WriteInterface.io.WritePointer(cell)
    StorageUnit(cell).io.Datain := io.Datain
  }

  for (port <- 0 until CMRParameters.BranchCount) {
    ReadInterface(port).io.CellFull := WriteInterface.io.CellFull
    ReadInterface(port).io.Datain := VecInit(StorageUnit.map(_.io.Dataout))
    ReadInterface(port).io.PathEnabled := io.PathEnabled
    ReadInterface(port).io.Ackin := io.Ackin(port)
    io.Reqout(port) := ReadInterface(port).io.Reqout
    io.Dataout(port) := ReadInterface(port).io.Dataout
    io.ReadPointer(port) := ReadInterface(port).io.ReadPointer
    io.CellEmpty(port) := ReadInterface(port).io.CellEmpty
  }

  io.Ackout := WriteInterface.io.Ackout
  io.WritePointer := WriteInterface.io.WritePointer
  io.CellFull := WriteInterface.io.CellFull
}

object CMRBufferMain extends App {
  emitVerilog(new CMRBuffer, Array("--target-dir", "generated_cmr/buffer"))
}

private class WriteControlUnitElaboration(initialPhase: Int) extends Module {
  val io = IO(new Bundle {
    val Reqin = Input(Bool())
    val WritePointer = Input(Bool())
    val Tail = Input(Bool())
    val CellEmpty = Input(UInt(CMRParameters.BranchCount.W))
    val Ackout = Output(Bool())
    val CellFull = Output(Bool())
  })
  private val ControlUnit = Module(new WriteControlUnit(initialPhase))
  ControlUnit.io.reset := reset.asBool
  ControlUnit.io.Reqin := io.Reqin
  ControlUnit.io.WritePointer := io.WritePointer
  ControlUnit.io.Tail := io.Tail
  ControlUnit.io.CellEmpty := io.CellEmpty
  io.Ackout := ControlUnit.io.Ackout
  io.CellFull := ControlUnit.io.CellFull
}

private class WriteCounterElaboration extends Module {
  val io = IO(new Bundle {
    val Reqin = Input(Bool())
    val Ackout = Input(Bool())
    val WritePointer = Output(UInt(CMRParameters.CellCount.W))
  })
  private val Counter = Module(new WriteCounter)
  Counter.io.reset := reset.asBool
  Counter.io.Reqin := io.Reqin
  Counter.io.Ackout := io.Ackout
  io.WritePointer := Counter.io.WritePointer
}

object WriteControlUnitMain extends App {
  emitVerilog(
    new WriteControlUnitElaboration(initialPhase = 0),
    Array("--target-dir", "generated_cmr/write_control_unit")
  )
}

object WriteCounterMain extends App {
  emitVerilog(
    new WriteCounterElaboration,
    Array("--target-dir", "generated_cmr/write_counter")
  )
}

object WriteInterfaceControlMain extends App {
  emitVerilog(
    new WriteInterfaceControl,
    Array("--target-dir", "generated_cmr/write_interface")
  )
}

private class ReadControlUnitElaboration(initialPhase: Int) extends Module {
  val io = IO(new Bundle {
    val CellFull = Input(Bool())
    val ReadPointer = Input(Bool())
    val AckX = Input(Bool())
    val Req = Output(Bool())
    val CellEmpty = Output(Bool())
  })
  private val ControlUnit = Module(new ReadControlUnit(initialPhase))
  ControlUnit.io.reset := reset.asBool
  ControlUnit.io.CellFull := io.CellFull
  ControlUnit.io.ReadPointer := io.ReadPointer
  ControlUnit.io.AckX := io.AckX
  io.Req := ControlUnit.io.Req
  io.CellEmpty := ControlUnit.io.CellEmpty
}

private class ReadCounterElaboration extends Module {
  val io = IO(new Bundle {
    val ReqX = Input(Bool())
    val AckX = Input(Bool())
    val ReadPointer = Output(UInt(CMRParameters.CellCount.W))
  })
  private val Counter = Module(new ReadCounter)
  Counter.io.reset := reset.asBool
  Counter.io.ReqX := io.ReqX
  Counter.io.AckX := io.AckX
  io.ReadPointer := Counter.io.ReadPointer
}

private class ReadPhaseSelectorElaboration(localBranch: Int) extends Module {
  val io = IO(new Bundle {
    val ReqX = Input(Bool())
    val Ackin = Input(Bool())
    val PathEnabled = Input(UInt(CMRParameters.BranchCount.W))
    val Reqout = Output(Bool())
  })
  private val PhaseSelector = Module(new ReadPhaseSelector(localBranch))
  PhaseSelector.io.reset := reset.asBool
  PhaseSelector.io.ReqX := io.ReqX
  PhaseSelector.io.Ackin := io.Ackin
  PhaseSelector.io.PathEnabled := io.PathEnabled
  io.Reqout := PhaseSelector.io.Reqout
}

object ReadControlUnitMain extends App {
  emitVerilog(
    new ReadControlUnitElaboration(initialPhase = 0),
    Array("--target-dir", "generated_cmr/read_control_unit")
  )
}

object ReadCounterMain extends App {
  emitVerilog(
    new ReadCounterElaboration,
    Array("--target-dir", "generated_cmr/read_counter")
  )
}

object ReadPhaseSelectorMain extends App {
  emitVerilog(
    new ReadPhaseSelectorElaboration(localBranch = 0),
    Array("--target-dir", "generated_cmr/read_phase_selector")
  )
}

object ReadInterfaceControlMain extends App {
  private val localBranch = args.headOption.map(_.toInt).getOrElse(0)
  require(localBranch >= 0 && localBranch < CMRParameters.BranchCount)
  emitVerilog(
    new ReadInterfaceControl(localBranch),
    Array("--target-dir", s"generated_cmr/read_interface_$localBranch")
  )
}
