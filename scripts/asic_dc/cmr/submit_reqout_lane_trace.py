"""Bounded c1p4 handover event trace; no modifications to the original DUT."""
from run_remote_cmr_noc16_sdf import connect

BASE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r4_transport_eventprobe/c1p4"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r5_lane_trace"
probe = '''
always @(dut.raw.selector_LaneSelect or dut.raw.selector_PPE or dut.raw.adapter_IPMReqOut or dut.raw.adapter_IPMAckIn or dut.raw.adapter_OPMReqIn or dut.raw.adapter_OPMAckOut or dut.raw.InputPortModules_0_io_Dataout_3_flit or dut.raw.OutputPortModules_4.TailPassed_0 or tb_in_req[0] or tb_in_ack[0]) begin
 if ($realtime>213.9 && $realtime<215.3) begin
  $display("LANE_TRACE t=%.6f inreq=%b inack=%b indata=%h ppe=%b select=%b empty=%b ipmreq=%b ipmack=%b opmreq=%b opmack=%b data=%h tailpass=%b",$realtime,tb_in_req[0],tb_in_ack[0],tb_in_data[27:0],dut.raw.selector_PPE,dut.raw.selector_LaneSelect,dut.raw.selector_LaneIsEmpty,dut.raw.adapter_IPMReqOut,dut.raw.adapter_IPMAckIn,dut.raw.adapter_OPMReqIn,dut.raw.adapter_OPMAckOut,dut.raw.InputPortModules_0_io_Dataout_3_flit,dut.raw.OutputPortModules_4.TailPassed_0);
 end
end
'''
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command(f"mkdir -p {REMOTE}; cp {BASE}/*.v {REMOTE}/; cp {BASE}/*.sv {REMOTE}/; cp {BASE}/rtl.f {REMOTE}/; cp -r {BASE}/hop_binds {REMOTE}/")
    if ch.recv_exit_status():
        raise RuntimeError("Staging failed")
    sftp = client.open_sftp()
    path = REMOTE + "/tb_router_matched_ppa_async.sv"
    with sftp.file(path) as f:
        tb = f.read().decode()
    if tb.count("endmodule") != 1:
        raise RuntimeError("Unexpected TB structure")
    with sftp.file(path, "w") as f:
        f.write(tb.replace("endmodule", probe + "\nendmodule"))
    with sftp.file(REMOTE + "/run.sh", "w") as f:
        f.write(f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds +define+GEOM_C1_P4 -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
./simv +MODE=aggregate +PROBE +NO_FULL_VCD +EVENT_CSV=events.csv > trace.log 2>&1
''')
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command(f"bsub -n 1 -J req_lane_trace -o {REMOTE}/lsf.log bash {REMOTE}/run.sh")
    print(ch.makefile().read().decode())
finally:
    client.close()
