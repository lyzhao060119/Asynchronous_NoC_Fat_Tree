"""Queue 24 matched Sync M16 power cases and two async broadcast supplements."""
import hashlib,json,re
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

HERE=Path(__file__).resolve().parent
ROOT='/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1'
PY='/soft/GNU/python3.12/bin/python3'

PREPARE=r'''import os,json,hashlib,subprocess,re,shlex
from pathlib import Path
R=Path(__file__).resolve().parent
H=Path('/home/ghy19/Asynchronous_Router_CMR')
B=Path('/prjtemp/ghy19/date2027_formal64')
C=B/'20261015_193500_formal64_multicast_inputs_r1'
PY='/soft/GNU/python3.12/bin/python3'
if (R/'manifest.json').exists() or (R/'submission_progress.json').exists():raise RuntimeError('already submitted; inspect before retry')
assert os.statvfs(R).f_bavail*os.statvfs(R).f_frsize>100*1024**3,'less than 100 GiB free'
probe=R/'write_probe.tmp'
with probe.open('wb') as f:f.write(b'0'*(8*1024*1024));f.flush();os.fsync(f.fileno())
probe.unlink()
configs={
 'SYNC_M16':dict(run='20261015_194000_sync_prop_m16_tt_dc_r1',top='SyncNoC_64nodes',adapter='sync_noc64_port_adapter.sv',tb='tb_noc64_sync_boundary.sv',wrapper='tb_cmr_noc64_sync_boundary_failfast.sv',scope='tb_cmr_noc64_sync_boundary_failfast.core.noc.dut',define='+define+CMR_SYNC64_TOP64',src=H/'sim/tb'),
 'FM64':dict(run='20261017_190000_mesh64_xfirsty_dc_r3',top='CMRMeshNoC',adapter='async_noc64_mesh_port_adapter.sv',tb='tb_noc64_async_boundary.sv',wrapper='tb_cmr_noc64_async_boundary_failfast.sv',scope='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_mesh.noc.dut',define='+define+CMR_NOC64_MESH',src=C/'src'),
 'PROP_M16':dict(run='20261011_prop_m16_current_timingopt_dc_lmh_r1',top='PROP_temp64_m16',adapter='async_prop_temp64_port_adapter.sv',tb='tb_noc64_async_boundary.sv',wrapper='tb_cmr_noc64_async_boundary_failfast.sv',scope='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp_m16.noc.dut',define='+define+PROP_TEMP64_M16_TOP64',src=C/'src')}
points=[('TOPO-UR',80),('TOPO-BC',40),('HOTSPOT10',80),('MULTICAST5-AABB',40),('MULTICAST10-AABB',20),('MULTICAST-STATIC-AABB',20),('ALL-MULTICAST-AABB',10),('ALL-BROADCAST',5)]
items=[]
for b,load in points:
 for seed in [202701,202702,202703]:
  stem='%s_n64_s%d_m%d_SYNC_PROP_temp64_m16_top64.case'%(b,seed,load)
  roots=[C/'cases',B/'20261015_230000_formal64_unicast_sync_m16_r1/cases']
  p=next((x/stem for x in roots if (x/stem).is_file()),None)
  if p is None:raise RuntimeError('missing case '+stem)
  items.append(dict(design='SYNC_M16',benchmark=b,seed=seed,load=load,case=str(p),tag='SYNC_M16_%s_s%d_m%d'%(b,seed,load)))
for design,suffix in [('FM64','FM64_top0'),('PROP_M16','PROP_temp64_m16_top64')]:
 p=C/'cases'/('ALL-BROADCAST_n64_s202703_m5_'+suffix+'.case')
 assert p.is_file()
 items.append(dict(design=design,benchmark='ALL-BROADCAST',seed=202703,load=5,case=str(p),tag=design+'_ALL-BROADCAST_s202703_m5'))
selection=json.loads((B/'power_selection_r2/mesh64_power_points.json').read_text())
assert {x['benchmark']:x['selected_load'] for x in selection['benchmarks']}==dict(points)
for item in items:item['case_sha256']=hashlib.sha256(Path(item['case']).read_bytes()).hexdigest()
def submit(name,slots,cmd,log,dep=None):
 args=['bsub','-q','normal','-n',str(slots),'-J',name,'-o',str(log),'-e',str(log)+'.err']
 if dep:args+=['-w',dep]
 out=subprocess.check_output(args+cmd,text=True);print(out.strip(),flush=True)
 return re.search(r'Job <(\d+)>',out).group(1)
compilejobs={};frozen={}
for design,cfg in configs.items():
 work=R/'work'/design;src=R/'src'/design;work.mkdir(parents=True);src.mkdir(parents=True)
 net=H/'outputs'/cfg['run'];top=cfg['top']
 files=[net/(top+'.ddc'),net/(top+'_post.v'),net/(top+'.sdf')]
 for name in [cfg['adapter'],cfg['tb'],cfg['wrapper']]:
  p=cfg['src']/name;assert p.is_file(),p
  dest=src/name;dest.write_bytes(p.read_bytes());files.append(dest)
 assert 'DUMP_MEASUREMENT_ONLY' in (src/cfg['tb']).read_text()
 assert all(p.is_file() and p.stat().st_size for p in files)
 frozen[design]={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
 boot='module sdf_boot; integer slot; initial begin\nif (!$value$plusargs("SDF_SLOT=%d",slot)) slot=0;\n'
 for slot in [0,1]:boot+='if(slot==%d) $sdf_annotate("%s", %s, , "%s", "MAXIMUM", ,);\n'%(slot,net/(top+'.sdf'),cfg['scope'],work/('sdf_slot%d.log'%slot))
 boot+='$display("POWER_SDF_ANNOTATION_DONE"); end endmodule\n'
 (work/'sdf_boot.sv').write_text(boot)
 lib=Path('/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v')
 fl=[lib,net/(top+'_post.v'),src/cfg['adapter'],src/cfg['tb'],src/cfg['wrapper'],work/'sdf_boot.sv']
 (work/'filelist.f').write_text('\n'.join(map(str,fl))+'\n')
 shell='#!/bin/bash\nset -euo pipefail\ncd '+shlex.quote(str(work))+'\nexport VCS_HOME=/soft/synopsys/vcs/V-2023.12\nexport PATH="$VCS_HOME/bin:$PATH"\nvcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk '+cfg['define']+' -f filelist.f -top '+cfg['scope'].split('.')[0]+' -top sdf_boot -o simv -l compile.log\ntest -x simv\necho POWER_COMPILE_PASS\n'
 p=work/'compile.sh';p.write_text(shell)
 compilejobs[design]=submit('p64compile_'+design,1,['bash',str(p)],work/'lsf.log')
(R/'frozen_inputs.json').write_text(json.dumps(frozen,indent=2))
previous=[None,None];jobs=[]
for i,item in enumerate(items):
 d=item['design'];cfg=configs[d];tag=item['tag'];a=R/'activity'/tag;l=R/'logs'/tag;r=R/'reports'/tag
 for p in [a,l,r]:p.mkdir(parents=True,exist_ok=True)
 lane=i%2 if d=='SYNC_M16' else 0
 dep='done(%s)'%compilejobs[d]
 if d=='SYNC_M16' and previous[lane]:dep+=' && done(%s)'%previous[lane]
 env=dict(FORMAL64_POWER_DESIGN=d,FORMAL64_POWER_CASE_FILE=item['case'],FORMAL64_POWER_CASE_NAME=tag,FORMAL64_POWER_TAG=tag,FORMAL64_POWER_ROOT=str(R),FORMAL64_ASYNC_ROOT=str(R),FORMAL64_SYNC_SIMV=str(R/'work/SYNC_M16/simv'),FORMAL64_POWER_VCD_STORAGE_DIR=str(R/'vcd'),POWER_SDF_SLOT=str(lane))
 act=submit('p64act_'+tag,1,['env']+[k+'='+v for k,v in env.items()]+['bash',str(R/'activity.sh')],a/'lsf.log',dep)
 # VCS emits a generate-block + instance as one scope containing a dot.
 # Sync TB's core module name is also its emitted VCD wrapper scope.
 strip={'SYNC_M16':'tb_cmr_noc64_sync_boundary_failfast/core/noc/dut','FM64':'tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_mesh.noc/dut','PROP_M16':'tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_prop_temp_m16.noc/dut'}[d]
 px=submit('p64px_'+tag,4,[PY,str(R/'ptpx.py'),'--activity',str(a),'--report',str(r),'--tcl',str(R/'ptpx.tcl'),'--netlist-root',str(H/'outputs'/cfg['run']),'--ddc-name',cfg['top']+'.ddc','--netlist-name',cfg['top']+'_post.v','--sdf-name',cfg['top']+'.sdf','--top',cfg['top'],'--strip-path',strip],l/'ptpx.log','done(%s)'%act)
 archive=submit('p64gz_'+tag,1,[PY,str(R/'archive.py'),'--activity',str(a),'--ptpx-log',str(l/'ptpx.log')],l/'archive.log','done(%s)'%px)
 if d=='SYNC_M16':previous[lane]=archive
 item.update(activity_dir=str(a),report_dir=str(r),ptpx_log=str(l/'ptpx.log'),activity_job=act,ptpx_job=px,archive_job=archive,compile_job=compilejobs[d],netlist_run=cfg['run'])
 jobs.append(item);(R/'submission_progress.json').write_text(json.dumps(jobs,indent=2))
(R/'manifest.json').write_text(json.dumps(dict(schema='formal64-sync-and-broadcast-power-v1',corner='TT 0.8V 25C',sync_clock_period_ns=1.0,compile_jobs=compilejobs,jobs=jobs,limitations=['Existing negative recovery/removal SDF compatibility warnings retained.','Library table extrapolation must be reported; PT errors require classification.']),indent=2))
print('POWER_SUPPLEMENT_QUEUED sync_cases=24 async_broadcast_cases=2',flush=True)
'''

def main():
 c=connect();c.get_transport().channel_timeout=600
 i,o,e=c.exec_command('mkdir -p '+ROOT,timeout=600)
 if o.channel.recv_exit_status():raise RuntimeError(e.read().decode())
 s=c.open_sftp();s.get_channel().settimeout(600)
 try:s.stat(ROOT+'/prepare_job.json');raise RuntimeError('dispatcher already submitted')
 except FileNotFoundError:pass
 activity=(HERE/'run_formal64_power_activity_remote.sh').read_text()
 activity=activity.replace('SDF_LOG="$ASYNC_ROOT/work/$DESIGN/sdf_annotate.log"','SDF_LOG="$ASYNC_ROOT/work/$DESIGN/sdf_slot${POWER_SDF_SLOT:?}.log"')
 activity=activity.replace('SDF_LOG="$(dirname "$SYNC_SIMV")/sdf_annotate.log"','SDF_LOG="$(dirname "$SYNC_SIMV")/sdf_slot${POWER_SDF_SLOT:?}.log"')
 activity=activity.replace('set +e\n"$SIMV"','if [[ "$DESIGN" == SYNC_M16 ]]; then capture=0; else capture=0.1; fi\nset +e\n"$SIMV" +CLOCK_PERIOD_NS=1.0 +SDF_SLOT="${POWER_SDF_SLOT:?}"')
 activity=activity.replace('+RX_CAPTURE_NS=0.1','+RX_CAPTURE_NS="$capture"')
 activity=activity.replace('cp "$SDF_LOG" "$LOG/sdf_annotate.log" 2>/dev/null || true','test -s "$SDF_LOG"\ncp "$SDF_LOG" "$LOG/sdf_annotate.log"\ntest -s "$LOG/sdf_annotate.log"')
 activity=activity.replace(' > "$LOG/input_hashes.sha256" 2>/dev/null || true',' > "$LOG/input_hashes.sha256"')
 activity=activity.replace("! grep -q 'TB_RESULT PASS'", "! grep -Eq 'TB_RESULT PASS injected=55000 delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0'")
 files={'prepare.py':PREPARE,'activity.sh':activity,'ptpx.py':(HERE/'run_formal64_mesh_ptpx_case.py').read_text(),'archive.py':(HERE/'archive_formal64_power_vcd.py').read_text(),'ptpx.tcl':(HERE.parent/'power/run_ptpx_cmr_mesh_power.tcl').read_text()}
 for name,t in files.items():
  with s.file(ROOT+'/'+name,'w') as f:f.write(t.replace('\r\n','\n'))
 with s.file(ROOT+'/scripts_sha256.json','w') as f:f.write(json.dumps({k:hashlib.sha256(v.replace('\r\n','\n').encode()).hexdigest() for k,v in files.items()},indent=2))
 s.close()
 i,o,e=c.exec_command('bsub -q normal -n 1 -J p64_power_prepare -o '+ROOT+'/prepare.log -e '+ROOT+'/prepare.err '+PY+' -u '+ROOT+'/prepare.py',timeout=600)
 out=o.read().decode();print(out,flush=True)
 if o.channel.recv_exit_status():raise RuntimeError(e.read().decode())
 s=c.open_sftp();s.get_channel().settimeout(600)
 with s.file(ROOT+'/prepare_job.json','w') as f:f.write(json.dumps(dict(prepare_job=re.search(r'Job <(\d+)>',out).group(1),root=ROOT),indent=2))
 s.close();c.close()

if __name__=='__main__':main()
