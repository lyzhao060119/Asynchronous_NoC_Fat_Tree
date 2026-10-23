"""Use one explicitly capped core per pending Sync M16 PT-PX case.

Deploy/run on remote login host (scheduler actions only). Running analyses,
simulation inputs, measurement windows and power-model settings are untouched.
"""
from pathlib import Path
import hashlib,json,subprocess,re,shlex,time

R=Path('/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1')
PY='/soft/GNU/python3.12/bin/python3'
PT='/soft/synopsys/prime/V-2023.12/bin/pt_shell'

def run(args):
    out=subprocess.check_output(args,text=True);print(out.strip(),flush=True);return out

def main():
    target=R/'singlecore_recipe_r4'
    assert not (target/'adjustments.json').exists(),'already adjusted; inspect first'
    target.mkdir(exist_ok=True)
    baseline=(R/'ptpx.tcl').read_bytes()
    (target/'base_ptpx.tcl').write_bytes(baseline)
    limits='''if {[catch {
  set_app_var multi_core_allow_overthreading false
  set_host_options -max_cores 1
} err]} { puts "PT_CORE_RECIPE_CHECK_FAIL $err"; exit 2 }
'''
    (target/'core_limits.tcl').write_text(limits)
    check='source '+str(target/'core_limits.tcl')+'\nputs "PT_CORE_RECIPE_CHECK_PASS"\nexit 0\n'
    (target/'check.tcl').write_text(check)
    (target/'ptpx.tcl').write_text('source '+str(target/'core_limits.tcl')+'\nputs "CMR_POWER_EXECUTION max_cores=1"\nsource '+str(target/'base_ptpx.tcl')+'\n')
    test=run(['bsub','-q','normal','-n','1','-J','syncPxCoreCheck','-o',str(target/'check.log'),'-e',str(target/'check.err'),PT,'-f',str(target/'check.tcl')])
    check_id=re.search(r'Job <(\d+)>',test).group(1)
    jobs=json.loads((R/'repair_submission_r2.json').read_text())['jobs']
    result=dict(timestamp=time.strftime('%Y-%m-%d %H:%M:%S'),check_job=check_id,
                base_tcl_sha256=hashlib.sha256(baseline).hexdigest(),recipe_slots=1,
                max_tool_cores=1,overthreading=False,updated=[],untouched=[])
    for j in jobs:
        if not j['tag'].startswith('SYNC_M16'):continue
        p=subprocess.run(['bjobs','-noheader','-o','stat',str(j['ptpx_job'])],capture_output=True,text=True)
        state=p.stdout.strip()
        if state!='PEND':
            result['untouched'].append(dict(tag=j['tag'],state=state or 'HISTORICAL'));continue
        dep='done(%s) && done(%s)'%(j['activity_job'],check_id)
        meta=next(x for x in json.loads((R/'manifest.json').read_text())['jobs'] if x['tag']==j['tag'])
        net=Path('/home/ghy19/Asynchronous_Router_CMR/outputs')/meta['netlist_run']
        top='SyncNoC_64nodes'
        cmd=['env','OMP_NUM_THREADS=1','MKL_NUM_THREADS=1','OPENBLAS_NUM_THREADS=1',PY,str(R/'ptpx.py'),
             '--activity',str(R/'activity'/j['tag']),'--report',j['report_dir'],
             '--tcl',str(target/'ptpx.tcl'),'--netlist-root',str(net),
             '--ddc-name',top+'.ddc','--netlist-name',top+'_post.v',
             '--sdf-name',top+'.sdf','--top',top,'--strip-path',j['strip_path']]
        out=run(['bmod','-n','1','-w',dep,'-Z',shlex.join(cmd),str(j['ptpx_job'])])
        result['updated'].append(dict(tag=j['tag'],job=j['ptpx_job'],dependency=dep,command=cmd,result=out))
        (target/'adjustments.json').write_text(json.dumps(result,indent=2))
    (target/'adjustments.json').write_text(json.dumps(result,indent=2))
    print('SYNC_PTPX_SINGLECORE_PENDING_UPDATED',len(result['updated']),flush=True)
    run(['busers','ghy19'])

if __name__=='__main__':main()
