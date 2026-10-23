"""Isolated egress timing surrogate. Does not alter DUT RTL or Chisel sources."""
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "results/rtl_reqout_calibration_20261022_r1"
OUT = ROOT / "results/rtl_reqout_calibration_20261022_r2"


def build():
    for kind, head, odd, even, gap_odd, gap_even in (
        ("thin", .472, .339, .389, .6395, .7245),
        ("c1p4", .419, .455, .491, .8865, .9525),
    ):
        folder = OUT / kind
        folder.mkdir(parents=True, exist_ok=True)
        source = (BASE / kind / "CMRRouter.v").read_text()
        header = re.search(r"module CMRRouter\((.*?)\n\);", source, re.S).group(1)
        ports = re.findall(r"\b(input|output)\s+(?:\[[^]]+\]\s*)?(\w+)", header)
        reqs = [p for d, p in ports if d == "output" and p.startswith("io_outputs_") and p.endswith("_HS_Req")]
        lines = ["`timescale 1ns/1ps", "// Simulation-only calibrated egress; not synthesizable.",
                 "module CMRRouter(" + header + "\n);"]
        for req in reqs:
            data = req.replace("_HS_Req", "_Data_flit")
            ack = req.replace("_HS_Req", "_HS_Ack")
            lines += [f"  wire raw_{req};", f"  reg delayed_{req} = 0;", f"  reg busy_{req} = 0;",
                      f"  always @({data}) if (busy_{req}) $fatal(1, \"Egress data changed before Ack\");",
                      f"  assign {req} = delayed_{req};",
                      f"  initial begin : model_{req}",
                      "    integer flit; reg phase; reg [27:0] snapshot;",
                      "    realtime due_time, last_delivery, propagation, interval;",
                      "    flit=0; last_delivery=-1000;", "    wait(reset === 1'b0);",
                      "    forever begin", f"      @(raw_{req});",
                      f"      if (reset) $fatal(1, \"In-flight reset unsupported by egress model\");",
                      f"      if ((^{data}) === 1'bx) $fatal(1, \"Unknown egress data\");",
                      f"      phase=raw_{req}; snapshot={data}; busy_{req}=1;",
                      "      if (snapshot[27]) flit=0;",
                      f'      if ($test$plusargs("PROBE") && $realtime<240) $display("EGRESS_EVENT port={req} t=%.6f phase=%b index=%0d data=%h",$realtime,phase,flit,snapshot);',
                      "      if ((flit==0) != snapshot[27] || (flit==4) != snapshot[26])",
                      '        $fatal(1, "Malformed fixed-five-flit egress packet index=%0d data=%h",flit,snapshot);',
                      f"      propagation=(flit==0)?{head}:((flit%2)?{odd}:{even});",
                      f"      interval=(flit%2)?{gap_odd}:{gap_even};",
                      "      due_time=$realtime+propagation;",
                      "      if (last_delivery+interval > due_time) due_time=last_delivery+interval;",
                      "      #(due_time-$realtime);",
                      f"      if ({data} !== snapshot || raw_{req} !== phase)",
                      '        $fatal(1, "Raw egress changed before delayed delivery");',
                      f"      delayed_{req}=phase; last_delivery=$realtime;",
                      f"      wait({ack} === phase);",
                      f"      if ({data} !== snapshot) $fatal(1, \"Data changed while Req pending\");",
                      f"      busy_{req}=0;", "      flit=(flit==4)?0:flit+1;", "    end", "  end"]
        lines += ["  CMRRouterRaw raw ("]
        lines += [f"    .{p}({'raw_' + p if p in reqs else p})" + ("," if i < len(ports)-1 else "")
                  for i, (_, p) in enumerate(ports)]
        lines += ["  );", "endmodule"]
        (folder / "CMRRouter.v").write_text("\n".join(lines) + "\n")
        tb = (BASE / kind / "tb_router_matched_ppa_async.sv").read_text()
        if kind == "thin":
            tb = tb.replace("6'd8", "6'd0")
        tb = tb.replace("real setup_ns, capture_ns;", "real setup_ns, capture_ns, ack_delay_ns;\n  integer single_packets;")
        tb = tb.replace('npackets=(mode=="aggregate")?AGG_PACKETS:1;', 'npackets=(mode=="aggregate")?AGG_PACKETS:single_packets;')
        tb = tb.replace('    if(!$value$plusargs("MODE=%s",mode))',
                        '    if(!$value$plusargs("SINGLE_PACKETS=%d",single_packets)) single_packets=1;\n'
                        '    if(!$value$plusargs("ACK_DELAY_NS=%f",ack_delay_ns)) ack_delay_ns=0;\n'
                        '    if(!$value$plusargs("MODE=%s",mode))')
        tb = tb.replace("        tb_out_ack[port]=tb_out_req[port];", "        #(ack_delay_ns); tb_out_ack[port]=tb_out_req[port];")
        tb = tb.replace(":FLITS_PER_PACKET;", ":single_packets*FLITS_PER_PACKET;")
        tb = tb.replace("endmodule", '''
  initial begin
    if ($test$plusargs("PROBE")) begin
      #212;
      repeat (6) begin
        $display("MODEL_PROBE t=%0t req=%b ack=%b",$time,tb_in_req,tb_in_ack);
        $display("MODEL_PROBE IPM1 mat=%b ppe=%b readreq=%b rcreq=%b rcack=%b dest=%h",
          {dut.raw.InputPortModules_1.RouteComputationUnit_io_Mat_3,dut.raw.InputPortModules_1.RouteComputationUnit_io_Mat_2,dut.raw.InputPortModules_1.RouteComputationUnit_io_Mat_1,dut.raw.InputPortModules_1.RouteComputationUnit_io_Mat_0},
          {dut.raw.InputPortModules_1.io_PathEnabled_3,dut.raw.InputPortModules_1.io_PathEnabled_2,dut.raw.InputPortModules_1.io_PathEnabled_1,dut.raw.InputPortModules_1.io_PathEnabled_0},
          {dut.raw.InputPortModules_1.io_Reqout_3,dut.raw.InputPortModules_1.io_Reqout_2,dut.raw.InputPortModules_1.io_Reqout_1,dut.raw.InputPortModules_1.io_Reqout_0},
          dut.raw.InputPortModules_1.RouteComputationUnit.AddressRegister.io_Req_rc,
          dut.raw.InputPortModules_1.RouteComputationUnit.AddressRegister.io_Ack_rc,
          dut.raw.InputPortModules_1.RouteComputationUnit.AddressRegister.io_dest);
        #5;
      end
    end
  end
  initial begin
    #100000;
    $display("MODEL_ARBITER req=%b grant=%b reqmerged=%b ackmerged=%b fire=%b rawreq=%b tailpass=%b tailflag=%b capin=%b capout=%b",dut.raw.OutputPortModules_4.Arbiter_req,dut.raw.OutputPortModules_4.Arbiter_grant,dut.raw.OutputPortModules_4.ReqMerged,dut.raw.OutputPortModules_4.AckMerged,dut.raw.OutputPortModules_4.RegEnable,dut.raw.OutputPortModules_4.io_Reqout,dut.raw.OutputPortModules_4.TailPassed_0,dut.raw.OutputPortModules_4.DataReg_ff[26],dut.raw.OutputPortModules_4.TailCaptureDelay_0_I,dut.raw.OutputPortModules_4.TailCaptureDelay_0_Z);
    $display("MODEL_WATCHDOG in_req=%b in_ack=%b out_req=%b out_ack=%b sent=%0d,%0d,%0d,%0d received=%0d", tb_in_req,tb_in_ack,tb_out_req,tb_out_ack,sent_flits[0],sent_flits[1],sent_flits[2],sent_flits[3],received);
    $fatal(1,"Independent full-test watchdog expired");
  end
endmodule''')
        (folder / "tb_router_matched_ppa_async.sv").write_text(tb)
        manifest = dict(kind=kind, head_delay_ns=head, odd_body_delay_ns=odd, even_body_delay_ns=even,
                        minimum_interval_odd_ns=gap_odd, minimum_interval_even_ns=gap_even,
                        scope="fixed 5-flit simulation surrogate; not gate-level or STA evidence",
                        target="Thin approximates Mesh; c1p4 approximates M16",
                        target_source="results/single_router_latency_power_audit_20261022_r3/flit_events.csv",
                        wrapper_sha256=hashlib.sha256((folder / "CMRRouter.v").read_bytes()).hexdigest())
        (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
        print(json.dumps(manifest))


if __name__ == "__main__":
    build()
