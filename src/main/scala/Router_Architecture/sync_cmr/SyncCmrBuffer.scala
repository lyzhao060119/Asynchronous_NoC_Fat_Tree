package Router_Architecture.sync_cmr

import DataStruct.{Packet, PacketLayout}
import Router_Architecture.CMR.CMRParameters
import chisel3._
import chisel3.util.{Mux1H, OHToUInt}

/** Five clocked storage cells.  One write, four independent reads. */
class SyncCmrStorage extends Module {
  val io = IO(new Bundle {
    val writeFire = Input(Bool())
    val WritePointer = Input(UInt(CMRParameters.CellCount.W))
    val Datain = Input(new Packet)
    val Dataout = Output(Vec(CMRParameters.CellCount, new Packet))
    val Tail = Output(Vec(CMRParameters.CellCount, Bool()))
  })

  private val cells = RegInit(VecInit(Seq.fill(CMRParameters.CellCount) {
    0.U.asTypeOf(new Packet)
  }))
  when (io.writeFire) {
    cells(OHToUInt(io.WritePointer)) := io.Datain
  }
  io.Dataout := cells
  io.Tail := VecInit(cells.map(_.flit(PacketLayout.IsTailIndex)))
}

/**
  * Clocked Fig. 7 Write Interface: 5-slot one-hot write pointer.
  * Backpressure when the pointed cell is still occupied.  A Tail write
  * raises a drain barrier so the next packet Head cannot enter until
  * every read interface has consumed that Tail cell.
  */
class SyncWriteInterface extends Module {
  override def desiredName: String = "SyncWriteInterface"

  val io = IO(new Bundle {
    val validIn = Input(Bool())
    val readyOut = Output(Bool())
    val CellEmpty = Input(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
    val Tail = Input(Vec(CMRParameters.CellCount, Bool()))
    val WritePointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellFull = Output(Vec(CMRParameters.CellCount, Bool()))
  })

  private val writePtr = RegInit(SyncCmrOneHot.init)
  private val cellFull = RegInit(VecInit(Seq.fill(CMRParameters.CellCount)(false.B)))

  private val allEmpty = VecInit.tabulate(CMRParameters.CellCount) { cell =>
    VecInit.tabulate(CMRParameters.BranchCount) { branch =>
      io.CellEmpty(branch)(cell)
    }.asUInt.andR
  }
  private val tailBarrier = VecInit.tabulate(CMRParameters.CellCount) { cell =>
    cellFull(cell) && io.Tail(cell) && !allEmpty(cell)
  }.asUInt.orR
  private val canWrite = Mux1H(writePtr, VecInit(cellFull.map(!_)))
  private val ready = canWrite && !tailBarrier
  private val writeFire = io.validIn && ready

  when (writeFire) {
    cellFull(OHToUInt(writePtr)) := true.B
    writePtr := SyncCmrOneHot.rotate(writePtr)
  }
  for (cell <- 0 until CMRParameters.CellCount) {
    when (cellFull(cell) && allEmpty(cell) && !(writeFire && writePtr(cell))) {
      cellFull(cell) := false.B
    }
  }

  io.readyOut := ready
  io.WritePointer := VecInit(writePtr.asBools)
  io.CellFull := cellFull
}

/**
  * Clocked Fig. 8 Read Interface for one of four multicast branches.
  * Independent one-hot read pointer.  A live PathEnabled bit sends the
  * cell; a wrong-path bit skips one cell per cycle; PathEnabled=0000
  * blocks so an illegal route cannot silently drain.
  */
class SyncReadInterface(localBranch: Int) extends Module {
  override def desiredName: String = "SyncReadInterface"
  require(localBranch >= 0 && localBranch < CMRParameters.BranchCount)

  val io = IO(new Bundle {
    val CellFull = Input(Vec(CMRParameters.CellCount, Bool()))
    val Datain = Input(Vec(CMRParameters.CellCount, new Packet))
    val PathEnabled = Input(Vec(CMRParameters.BranchCount, Bool()))
    val readyIn = Input(Bool())
    val validOut = Output(Bool())
    val Dataout = Output(new Packet)
    val ReadPointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellEmpty = Output(Vec(CMRParameters.CellCount, Bool()))
  })

  private val readPtr = RegInit(SyncCmrOneHot.init)
  private val seen = RegInit(VecInit(Seq.fill(CMRParameters.CellCount)(false.B)))

  private val localOn = io.PathEnabled(localBranch)
  private val anyOn = io.PathEnabled.asUInt.orR
  private val fullHere = Mux1H(readPtr, io.CellFull)
  private val seenHere = Mux1H(readPtr, seen)
  private val doSend = fullHere && localOn && !seenHere
  private val doSkip = fullHere && anyOn && !localOn && !seenHere
  private val consume = (doSend && io.readyIn) || doSkip

  when (consume) {
    seen(OHToUInt(readPtr)) := true.B
    readPtr := SyncCmrOneHot.rotate(readPtr)
  }
  for (cell <- 0 until CMRParameters.CellCount) {
    when (!io.CellFull(cell) && seen(cell)) {
      seen(cell) := false.B
    }
  }

  io.validOut := doSend
  io.Dataout := Mux1H(readPtr, io.Datain)
  io.ReadPointer := VecInit(readPtr.asBools)
  io.CellEmpty := VecInit.tabulate(CMRParameters.CellCount) { cell =>
    seen(cell) || !io.CellFull(cell)
  }
}

/** Clocked Fig. 5 CMR Buffer: 5 cells, one write, four multicast reads. */
class SyncCmrBuffer extends Module {
  override def desiredName: String = "SyncCmrBuffer"

  val io = IO(new Bundle {
    val validIn = Input(Bool())
    val Datain = Input(new Packet)
    val readyOut = Output(Bool())
    val PathEnabled = Input(Vec(CMRParameters.BranchCount, Bool()))
    val readyIn = Input(Vec(CMRParameters.BranchCount, Bool()))
    val validOut = Output(Vec(CMRParameters.BranchCount, Bool()))
    val Dataout = Output(Vec(CMRParameters.BranchCount, new Packet))
    val WritePointer = Output(Vec(CMRParameters.CellCount, Bool()))
    val ReadPointer = Output(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
    val CellFull = Output(Vec(CMRParameters.CellCount, Bool()))
    val CellEmpty = Output(Vec(CMRParameters.BranchCount, Vec(CMRParameters.CellCount, Bool())))
  })

  private val WriteInterface = Module(new SyncWriteInterface)
  private val StorageUnit = Module(new SyncCmrStorage)
  private val ReadInterface = Seq.tabulate(CMRParameters.BranchCount) { branch =>
    Module(new SyncReadInterface(branch))
  }

  private val writeFire = io.validIn && WriteInterface.io.readyOut
  WriteInterface.io.validIn := io.validIn
  WriteInterface.io.CellEmpty := VecInit(ReadInterface.map(_.io.CellEmpty))
  WriteInterface.io.Tail := StorageUnit.io.Tail

  StorageUnit.io.writeFire := writeFire
  StorageUnit.io.WritePointer := WriteInterface.io.WritePointer.asUInt
  StorageUnit.io.Datain := io.Datain

  for (port <- 0 until CMRParameters.BranchCount) {
    ReadInterface(port).io.CellFull := WriteInterface.io.CellFull
    ReadInterface(port).io.Datain := StorageUnit.io.Dataout
    ReadInterface(port).io.PathEnabled := io.PathEnabled
    ReadInterface(port).io.readyIn := io.readyIn(port)
    io.validOut(port) := ReadInterface(port).io.validOut
    io.Dataout(port) := ReadInterface(port).io.Dataout
    io.ReadPointer(port) := ReadInterface(port).io.ReadPointer
    io.CellEmpty(port) := ReadInterface(port).io.CellEmpty
  }

  io.readyOut := WriteInterface.io.readyOut
  io.WritePointer := WriteInterface.io.WritePointer
  io.CellFull := WriteInterface.io.CellFull
}

object SyncWriteInterfaceMain extends App {
  emitVerilog(
    new SyncWriteInterface,
    Array("--target-dir", "generated_sync_cmr/write_interface")
  )
}

object SyncReadInterfaceMain extends App {
  private val localBranch = args.headOption.map(_.toInt).getOrElse(0)
  require(localBranch >= 0 && localBranch < CMRParameters.BranchCount)
  emitVerilog(
    new SyncReadInterface(localBranch),
    Array("--target-dir", s"generated_sync_cmr/read_interface_$localBranch")
  )
}

object SyncCmrBufferMain extends App {
  emitVerilog(new SyncCmrBuffer, Array("--target-dir", "generated_sync_cmr/buffer"))
}
