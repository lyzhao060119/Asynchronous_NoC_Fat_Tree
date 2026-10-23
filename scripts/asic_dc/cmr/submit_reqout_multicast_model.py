"""Directed native multicast and skewed branch-Ack tests on frozen r6 models."""
from pathlib import Path
import argparse
import re
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--base-run", default="rtl_reqout_calibration_20261022_r6_ordering_model")
parser.add_argument("--run", default="rtl_reqout_calibration_20261022_r7_multicast")
parser.add_argument("--unique-payload", action="store_true")
args = parser.parse_args()
if not all(re.fullmatch(r"[A-Za-z0-9_]+", v) for v in (args.base_run,args.run)):
    raise ValueError("Unsafe run name")
BASE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + args.base_run
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + args.run


def tb(kind):
    mesh = kind == "thin"
    ports = 5 if mesh else 8
    ingress = 4 if mesh else 0
    expected = "(dir==2 || dir==3)" if mesh else "(dir==1 || dir==2 || dir==3 || dir==4)"
    copies = 2 if mesh else 4
    bind = f"async_ports_c1_p{1 if mesh else 4}.vi"
    body = "if(flit!=0) v[25:2]=24'h25a507 ^ ((packet+1)*24'h9e3779) ^ (flit*24'h85ebcb);" if args.unique_payload else ""
    return f'''`timescale 1ns/1ps
module tb_model_multicast;
localparam FLIT_W=28, PORTS={ports}, PACKETS=20;
wire unused_clock=0;
reg reset=1;
reg [PORTS-1:0] tb_in_req=0, tb_out_ack=0;
wire [PORTS-1:0] tb_in_ack,tb_out_req;
reg [PORTS*28-1:0] tb_in_data=0;
wire [PORTS*28-1:0] tb_out_data;
integer packet_seen[0:4], flit_seen[0:4], received=0;
real branch_ack_ns;
CMRRouter dut (`include "{bind}");
function automatic [27:0] expected_flit(input integer packet,flit);
 reg [27:0] v;
 begin
 v=0; v[27]=(flit==0); v[26]=(flit==4);
 v[7:2]=0; v[13:8]=0; v[19:14]=6'd{1 if mesh else 8}; v[25:20]=6'd{1 if mesh else 8};
 {body}
 v[1:0]=(packet+1)%4; expected_flit=v;
 end
endfunction
task automatic sink(input integer port);
 integer dir,pk,fl;
 reg phase;
 reg [27:0] value;
 begin
 dir=(port<4)?port:4;
 forever begin
 wait(reset===0);
 wait(tb_out_req[port]!==tb_out_ack[port]);
 phase=tb_out_req[port]; #0.09; value=tb_out_data[port*28+:28];
 if (!{expected}) $fatal(1,"Unexpected multicast direction port=%0d",port);
 pk=packet_seen[dir]; fl=flit_seen[dir];
 if (pk>=PACKETS || value!==expected_flit(pk,fl))
  $fatal(1,"Multicast mismatch port=%0d packet=%0d flit=%0d data=%h",port,pk,fl,value);
 received=received+1;
 if (fl==4) begin packet_seen[dir]=pk+1; flit_seen[dir]=0; end
 else flit_seen[dir]=fl+1;
 #(branch_ack_ns*(dir%3));
 if(tb_out_req[port]!==phase || tb_out_data[port*28+:28]!==value)
  $fatal(1,"Pending branch changed before Ack");
 tb_out_ack[port]=phase;
 end
 end
endtask
genvar lane;
generate for(lane=0;lane<PORTS;lane=lane+1) begin
 initial sink(lane);
end endgenerate
initial begin
 integer pk,fl,i;
 if(!$value$plusargs("BRANCH_ACK_NS=%f",branch_ack_ns)) branch_ack_ns=0;
 for(i=0;i<5;i=i+1) begin packet_seen[i]=0;flit_seen[i]=0;end
 #200;reset=0;#10;
 for(pk=0;pk<PACKETS;pk=pk+1) for(fl=0;fl<5;fl=fl+1) begin
  wait(tb_in_req[{ingress}]===tb_in_ack[{ingress}]);
  tb_in_data[{ingress}*28+:28]=expected_flit(pk,fl);#0.05;
  tb_in_req[{ingress}]=~tb_in_req[{ingress}];
  wait(tb_in_req[{ingress}]===tb_in_ack[{ingress}]);
 end
 wait(received==PACKETS*5*{copies});#5;
 for(i=0;i<5;i=i+1) begin
  if (({expected.replace('dir','i')}) && packet_seen[i]!=PACKETS) $fatal(1,"Missing branch");
 end
 if (tb_in_req!==tb_in_ack || tb_out_req!==tb_out_ack) $fatal(1,"Undrained pending");
 $display("MODEL_MULTICAST_PASS kind={kind} input_flits=100 delivered=%0d expected={100*copies} ack_ns=%.3f",received,branch_ack_ns);
 $finish;
end
initial begin #100000;$fatal(1,"Multicast watchdog received=%0d",received);end
endmodule
'''


client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"mkdir -p {REMOTE}/{k}; cp {BASE}/{k}/*.v {REMOTE}/{k}/; cp -r {BASE}/{k}/hop_binds {REMOTE}/{k}/" for k in ("thin", "c1p4")))
    if ch.recv_exit_status():
        raise RuntimeError("Stage failed")
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        code = tb(kind)
        local = ROOT / "results" / args.run / kind
        local.mkdir(parents=True, exist_ok=True)
        (local / "tb_model_multicast.sv").write_text(code)
        with sftp.file(f"{REMOTE}/{kind}/tb_model_multicast.sv", "w") as f:
            f.write(code)
        with sftp.file(f"{REMOTE}/run_{kind}.sh", "w") as f:
            f.write(f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
find . -maxdepth 1 -name '*.v' ! -name '*_ASIC.v' | sort > rtl.f
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds -f rtl.f tb_model_multicast.sv -top tb_model_multicast -o simv > compile.log 2>&1
for delay in 0 0.5 2; do
 ./simv +BRANCH_ACK_NS=$delay > multicast_$delay.log 2>&1
 grep -q MODEL_MULTICAST_PASS multicast_$delay.log
done
echo MODEL_MULTICAST_SUITE_PASS
''')
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqmc_{k} -o {REMOTE}/{k}/lsf.log bash {REMOTE}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
