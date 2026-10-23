"""Bounded per-branch multicast boundary trace using r7 frozen inputs."""
from run_remote_cmr_noc16_sdf import connect
BASE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r7_multicast"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r8_multicast_trace"
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"mkdir -p {REMOTE}/{k}; cp {BASE}/{k}/*.v {REMOTE}/{k}/; cp {BASE}/{k}/*.sv {REMOTE}/{k}/; cp {BASE}/{k}/rtl.f {REMOTE}/{k}/; cp -r {BASE}/{k}/hop_binds {REMOTE}/{k}/" for k in ("thin", "c1p4")))
    if ch.recv_exit_status():
        raise RuntimeError("Copy failed")
    sftp = client.open_sftp()
    for kind, ingress in (("thin", 4), ("c1p4", 0)):
        raw = f"dut.raw.InputPortModules_{ingress}"
        vector = lambda signal: "{" + ",".join(f"{raw}.{signal}_{i}" for i in (3,2,1,0)) + "}"
        ppe, req, ack, tail = (vector(s) for s in ("io_PathEnabled", "io_Reqout", "io_Ackin", "io_TailPassed"))
        probe = f'''
always @(tb_in_req[{ingress}] or tb_in_ack[{ingress}] or {ppe} or {req} or {ack} or {tail}) begin
 if($realtime>210 && $realtime<220)
 $display("MC_TRACE t=%.6f inreq=%b inack=%b indata=%h ppe=%b req=%b ack=%b tailpass=%b readData0=%h readData1=%h readData2=%h readData3=%h",$realtime,tb_in_req[{ingress}],tb_in_ack[{ingress}],tb_in_data[{ingress}*28+:28],{ppe},{req},{ack},{tail},{raw}.io_Dataout_0_flit,{raw}.io_Dataout_1_flit,{raw}.io_Dataout_2_flit,{raw}.io_Dataout_3_flit);
end
'''
        path = f"{REMOTE}/{kind}/tb_model_multicast.sv"
        with sftp.file(path) as f:
            code = f.read().decode()
        code = code.replace("endmodule", probe + "\nendmodule")
        with sftp.file(path, "w") as f:
            f.write(code)
        with sftp.file(f"{REMOTE}/run_{kind}.sh", "w") as f:
            f.write(f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds -f rtl.f tb_model_multicast.sv -top tb_model_multicast -o simv > compile.log 2>&1
./simv +BRANCH_ACK_NS=0 +PROBE > trace.log 2>&1
''')
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqmctrace_{k} -o {REMOTE}/{k}/lsf.log bash {REMOTE}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
