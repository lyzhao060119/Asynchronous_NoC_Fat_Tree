#!/usr/bin/env python3
"""Emit tb_cmr_ft_noc16_x_probe.sv from the frozen fat-tree netlist names."""
from pathlib import Path

OUT = Path(__file__).with_name("tb_cmr_ft_noc16_x_probe.sv")
DUT = "$root.tb_noc16_async_axi_bram.dut.dut"
WRAP = "$root.tb_noc16_async_axi_bram.dut"
L1 = ("routerL1_0_0", "routerL1_0_1", "routerL1_1_0", "routerL1_1_1")
FIFOS = ("upward",) + tuple(f"upward_{i}" for i in range(1, 8)) + (
    "downward",
) + tuple(f"downward_{i}" for i in range(1, 8))
# Child IPMs 0-7: branch 3 is the 4-lane parent. Parent IPMs 8-11 are all 2-lane.
L2_LANES4 = {3, 7, 11, 15, 19, 23, 27, 31}


def adapter_name(index):
    return "adapter" if index == 0 else "adapter_%d" % index


signals = []


def add(name, expr):
    signals.append((name, expr))


for i in range(20):
    add("wrap.out_req[%d]" % i, "%s.out_req[%d]" % (WRAP, i))
for i in range(16):
    add("wrap.in_req[%d]" % i, "%s.in_req[%d]" % (WRAP, i))

for router in L1:
    for direction in range(4):
        add(
            "%s.child%d.req" % (router, direction),
            "%s.%s.io_outputs_child_%d_0_HS_Req" % (DUT, router, direction),
        )
    for lane in range(2):
        add(
            "%s.parent%d.req" % (router, lane),
            "%s.%s.io_outputs_parent_%d_HS_Req" % (DUT, router, lane),
        )
    for index in range(6):
        add(
            "%s.OPM%d.Reqout" % (router, index),
            "%s.%s.OutputPortModules_%d.io_Reqout" % (DUT, router, index),
        )
        add(
            "%s.IPM%d.Req_rc" % (router, index),
            "%s.%s.InputPortModules_%d.RouteComputationUnit.AddressRegister.Req_rc"
            % (DUT, router, index),
        )
        add(
            "%s.IPM%d.En" % (router, index),
            "%s.%s.InputPortModules_%d.RouteComputationUnit.AddressRegister.En"
            % (DUT, router, index),
        )
        add(
            "%s.IPM%d.LatchD24" % (router, index),
            "%s.%s.InputPortModules_%d.RouteComputationUnit.AddressRegister.LatchD[24]"
            % (DUT, router, index),
        )
    for index in range(4):
        adapter = adapter_name(index)
        prefix = "%s.%s" % (router, adapter)
        path = "%s.%s.%s" % (DUT, router, adapter)
        add("%s.Reqin" % prefix, "%s.Reqin" % path)
        add("%s.Ackout" % prefix, "%s.Ackout" % path)
        add("%s.PhaseOffset" % prefix, "%s.PhaseOffset" % path)
        for bit in range(2):
            add("%s.Reqout[%d]" % (prefix, bit), "%s.Reqout[%d]" % (path, bit))
            add("%s.Commit[%d]" % (prefix, bit), "%s.Commit[%d]" % (path, bit))
            add("%s.Ackin[%d]" % (prefix, bit), "%s.Ackin[%d]" % (path, bit))

for fifo in FIFOS:
    add("%s.deq_req" % fifo, "%s.%s.io_deq_HS_Req" % (DUT, fifo))
    add("%s.enq_ack" % fifo, "%s.%s.io_enq_HS_Ack" % (DUT, fifo))

for direction in range(4):
    for lane in range(2):
        add(
            "routerL2.child%d_%d.req" % (direction, lane),
            "%s.routerL2.io_outputs_child_%d_%d_HS_Req" % (DUT, direction, lane),
        )
for lane in range(4):
    add(
        "routerL2.parent%d.req" % lane,
        "%s.routerL2.io_outputs_parent_%d_HS_Req" % (DUT, lane),
    )

for index in range(12):
    add(
        "routerL2.OPM%d.Reqout" % index,
        "%s.routerL2.OutputPortModules_%d.io_Reqout" % (DUT, index),
    )
    add(
        "routerL2.IPM%d.Req_rc" % index,
        "%s.routerL2.InputPortModules_%d.RouteComputationUnit.AddressRegister.Req_rc"
        % (DUT, index),
    )
    add(
        "routerL2.IPM%d.En" % index,
        "%s.routerL2.InputPortModules_%d.RouteComputationUnit.AddressRegister.En"
        % (DUT, index),
    )
    add(
        "routerL2.IPM%d.LatchD24" % index,
        "%s.routerL2.InputPortModules_%d.RouteComputationUnit.AddressRegister.LatchD[24]"
        % (DUT, index),
    )

for index in range(48):
    adapter = adapter_name(index)
    prefix = "routerL2.%s" % adapter
    path = "%s.routerL2.%s" % (DUT, adapter)
    width = 4 if index in L2_LANES4 else 2
    add("%s.Reqin" % prefix, "%s.Reqin" % path)
    add("%s.Ackout" % prefix, "%s.Ackout" % path)
    add("%s.PhaseOffset" % prefix, "%s.PhaseOffset" % path)
    for bit in range(width):
        add("%s.Reqout[%d]" % (prefix, bit), "%s.Reqout[%d]" % (path, bit))
        add("%s.Commit[%d]" % (prefix, bit), "%s.Commit[%d]" % (path, bit))
        add("%s.Ackin[%d]" % (prefix, bit), "%s.Ackin[%d]" % (path, bit))

width = len(signals)
case_lines = []
for idx, (name, _expr) in enumerate(signals):
    case_lines.append('      %d: sig_name = "%s";' % (idx, name))

assign_lines = []
for idx, (_name, expr) in enumerate(signals):
    assign_lines.append("  assign watch[%d] = %s;" % (idx, expr))

sv = """`timescale 1ns/1ps

// Diagnostic-only first-X probe for the frozen CMR fat-tree NoC16 netlist.
// Hierarchy names come from outputs/20260821_cmr_ft_noc16_addrbuf_p50_sdf.
module tb_cmr_ft_noc16_x_probe;
  wire reset_released = $root.tb_noc16_async_axi_bram.s_axi_aresetn;
  bit armed;
  bit seen;
  integer idx;
  integer also;
  wire [%d:0] watch;
%s

  function automatic string sig_name(input integer i);
    begin
      case (i)
%s
        default: sig_name = "unknown";
      endcase
    end
  endfunction

  task automatic report_x(input string why);
    integer unknown_count;
    begin
      if (seen)
        return;
      seen = 1;
      idx = -1;
      unknown_count = 0;
      for (also = 0; also <= %d; also = also + 1) begin
        if ($isunknown(watch[also])) begin
          unknown_count = unknown_count + 1;
          if (idx < 0) begin
            idx = also;
            $display("X_FIRST time=%%0t why=%%s idx=%%0d name=%%s value=%%b",
                     $time, why, also, sig_name(also), watch[also]);
          end else begin
            $display("X_ALSO time=%%0t idx=%%0d name=%%s value=%%b",
                     $time, also, sig_name(also), watch[also]);
          end
        end
      end
      $display("X_COUNT unknown=%%0d", unknown_count);
      $display("X_GROUP wrap.out_req=%%b wrap.in_req=%%b",
               $root.tb_noc16_async_axi_bram.dut.out_req,
               $root.tb_noc16_async_axi_bram.dut.in_req[15:0]);
      $display("X_FINISH");
      #0.001;
      $finish;
    end
  endtask

  initial begin
    wait (reset_released === 1'b1);
    #1.0;
    armed = 1;
    if ($isunknown(watch))
      report_x("arm");
  end

  always @(watch) begin
    if (armed && !seen && $isunknown(watch))
      report_x("edge");
  end

  integer unknown_hb;
  always begin
    #1000.0;
    if (armed && !seen) begin
      unknown_hb = 0;
      for (also = 0; also <= %d; also = also + 1)
        if ($isunknown(watch[also]))
          unknown_hb = unknown_hb + 1;
      $display("X_HEARTBEAT time=%%0t watch_unknown=%%0d out_req=%%b",
               $time, unknown_hb,
               $root.tb_noc16_async_axi_bram.dut.out_req);
    end
  end
endmodule
""" % (
    width - 1,
    "\n".join(assign_lines),
    "\n".join(case_lines),
    width - 1,
    width - 1,
)

OUT.write_text(sv.replace("\r\n", "\n"), encoding="utf-8")
print("wrote", OUT, "signals", width)


if __name__ == "__main__":
    pass
