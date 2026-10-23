"""Restart PFAT power on writable scratch with isolated absolute SDF logs."""
import hashlib
import json
import re
from pathlib import Path
from launch_pfat_fig2_power import STARTER, SCAN, HOME, HERE
from run_remote_cmr_noc16_sdf import connect

ROOT = '/prjtemp/ghy19/formal64_power_pfat/20261020_fig2_8bench_3seed_r2'
NETLIST = HOME+'/outputs/20261019_archive_pfat64_fig2_tailrel100buf0_tt_r1'

def main():
    c = connect()
    c.get_transport().channel_timeout = 600
    s = c.open_sftp()
    s.get_channel().settimeout(600)
    try:
        s.stat(ROOT+'/compile_job.json')
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError('Restart already submitted; inspect instead of duplicating')
    work=ROOT+'/work/PFAT64_fig2_r2'
    compile_script='''#!/bin/bash
set -euo pipefail
mkdir -p "{work}"
cd "{work}"
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
sha256sum {net}/NoC_64nodes_post.v {net}/NoC_64nodes.sdf {scan}/src/async_noc64_port_adapter.sv {scan}/src/tb_noc64_async_boundary.sv {scan}/src/tb_cmr_noc64_async_boundary_failfast.sv > input_hashes.sha256
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk -f filelist.f -top tb_cmr_noc64_async_boundary_failfast -top sdf_boot -o simv -l compile.log
test -x simv
echo PFAT_POWER_COMPILE_PASS
'''.format(work=work,net=NETLIST,scan=SCAN)
    boot='module sdf_boot; integer slot; initial begin\nif (!$value$plusargs("SDF_SLOT=%d",slot)) slot=0;\n'
    for slot in range(3):
        boot+='if (slot==%d) $sdf_annotate("%s/NoC_64nodes.sdf", tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc.noc.dut, , "%s/sdf_slot%d.log", "MAXIMUM", ,);\n'%(slot,NETLIST,work,slot)
    boot+='$display("TB_INFO PFAT POWER MAXIMUM SDF slot=%0d",slot); end endmodule\n'
    filelist='\n'.join(['/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v',NETLIST+'/NoC_64nodes_post.v',SCAN+'/src/async_noc64_port_adapter.sv',SCAN+'/src/tb_noc64_async_boundary.sv',SCAN+'/src/tb_cmr_noc64_async_boundary_failfast.sv',work+'/sdf_boot.sv'])+'\n'
    activity=(HERE/'run_formal64_power_activity_remote.sh').read_text()
    activity=activity.replace('  PROP_M16|FM64)\n','  PFAT64)\n    SIMV="$ASYNC_ROOT/work/PFAT64_fig2_r2/simv"\n    SDF_LOG="$ASYNC_ROOT/work/PFAT64_fig2_r2/sdf_slot${E2_SDF_SLOT:?}.log"\n    ;;\n  PROP_M16|FM64)\n')
    activity=activity.replace('"$SIMV" +CASE_FILE=','"$SIMV" +SDF_SLOT="${E2_SDF_SLOT:?}" +CASE_FILE=')
    activity=activity.replace('cp "$SDF_LOG" "$LOG/sdf_annotate.log" 2>/dev/null || true','test -s "$SDF_LOG"\ngrep -Eq "Total errors:[[:space:]]*0" "$SDF_LOG"\ncp "$SDF_LOG" "$LOG/sdf_annotate.log"\ntest -s "$LOG/sdf_annotate.log"')
    activity=activity.replace(' > "$LOG/input_hashes.sha256" 2>/dev/null || true',' > "$LOG/input_hashes.sha256"')
    starter=STARTER.replace('FORMAL64_ASYNC_ROOT=str(E)','FORMAL64_ASYNC_ROOT=str(R)')
    files={'compile.sh':compile_script,'start.py':starter,'activity.sh':activity,
           'ptpx.py':(HERE/'run_formal64_mesh_ptpx_case.py').read_text(),
           'ptpx.tcl':(HERE.parent/'power/run_ptpx_cmr_mesh_power.tcl').read_text(),
           'archive.py':(HERE/'archive_formal64_power_vcd.py').read_text()}
    for d in [ROOT+'/work',work]:
        try:s.mkdir(d)
        except OSError:s.stat(d)
    files['work/PFAT64_fig2_r2/sdf_boot.sv']=boot
    files['work/PFAT64_fig2_r2/filelist.f']=filelist
    for name,t in files.items():
        with s.file(ROOT+'/'+name,'w') as f:f.write(t.replace('\r\n','\n'))
    with s.file(ROOT+'/scripts_sha256.json','w') as f:
        f.write(json.dumps({k:hashlib.sha256(v.replace('\r\n','\n').encode()).hexdigest() for k,v in files.items()},indent=2))
    s.close()
    cmd='bsub -q normal -n 1 -J pfat_power_compile_r2 -o '+ROOT+'/compile_lsf.log -e '+ROOT+'/compile_lsf.err bash '+ROOT+'/compile.sh'
    i,o,e=c.exec_command(cmd,timeout=600)
    out=o.read().decode();print(out,flush=True)
    if o.channel.recv_exit_status():raise RuntimeError(e.read().decode())
    job=re.search(r'Job <(\d+)>',out).group(1)
    cmd="bsub -q normal -n 1 -w 'done("+job+")' -J pfat_power_dispatch_r2 -o "+ROOT+'/gate.log -e '+ROOT+'/gate.err /soft/GNU/python3.12/bin/python3 '+ROOT+'/start.py'
    i,o,e=c.exec_command(cmd,timeout=600)
    out=o.read().decode();print(out,flush=True)
    if o.channel.recv_exit_status():raise RuntimeError(e.read().decode())
    s=c.open_sftp();s.get_channel().settimeout(600)
    with s.file(ROOT+'/compile_job.json','w') as f:f.write(json.dumps(dict(compile_job=job,dispatch=out,previous_failed_root=HOME+'/formal64_power_pfat/20261020_fig2_8bench_3seed_r1'),indent=2))
    s.close();c.close()

if __name__=='__main__':main()
