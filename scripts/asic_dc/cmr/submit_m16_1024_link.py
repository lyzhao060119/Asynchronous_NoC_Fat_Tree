"""Bounded, link-only M16-1024 assembly from existing frozen Router DDCs."""
import collections
import hashlib
import json
import re
import shlex
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from prepare_m16_1024_link import ROOT, OUT, TOP

BASE = '/home/ghy19/Asynchronous_Router_CMR/campaigns/20261020_split1024_tt_r1'
REMOTE = '/home/ghy19/Asynchronous_Router_CMR/campaigns/m16_1024_hierlink_20261024_r1'


def child_id(ref, index):
    return f'20261020_split1024_tt_r1_m16_c{index:02d}_' + ref.replace('CMRRouter', 'r', 1).replace('_', '')


PREFLIGHT = r'''
import gzip,hashlib,json,sys,time
from pathlib import Path
r,base=map(Path,sys.argv[1:3]); m=json.loads((r/'rtl/manifest.json').read_text())
assert hashlib.sha256((base/'rtl/split/m16/top/PROP_temp1024_m16.v').read_bytes()).hexdigest()==m['source_sha256']
sources=[]
for ref,meta in m['router_metadata'].items():
    cid='20261020_split1024_tt_r1_m16_c%02d_'%meta['index']+ref.replace('CMRRouter','r',1).replace('_','')
    folder=base/'outputs'/cid
    paths=[folder/(ref+s) for s in ('.ddc','_post.v','.sdf')]
    assert all(p.is_file() and p.stat().st_size>0 for p in paths),(cid,'missing_artifact')
    log=base/'logs/dc'/(cid+'.log')
    if log.is_file():
        with log.open('rb') as f:
            f.seek(max(0,log.stat().st_size-65536)); tail=f.read().decode(errors='replace')
    elif Path(str(log)+'.gz').is_file():
        with gzip.open(str(log)+'.gz','rt',errors='replace') as f: tail=f.read()[-65536:]
    else: raise RuntimeError('missing_child_pass_log '+cid)
    assert 'CMR_HIER_CHILD_DC_PASS ref='+ref+' ' in tail,(cid,'pass_missing')
    hashes={Path(p).name:h for h,p in (line.split(maxsplit=1) for line in (base/'reports/dc'/cid/'post_hashes.sha256').read_text().splitlines())}
    h=hashlib.sha256()
    with paths[0].open('rb') as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b''):h.update(chunk)
    assert h.hexdigest()==hashes[ref+'.ddc'],(cid,'ddc_hash_mismatch')
    with paths[2].open('rb') as f: header=f.read(4096)
    assert b'(PROCESS "tt0p8v25c")' in header and b'(VOLTAGE 0.80:0.80:0.80)' in header and b'(TEMPERATURE 25.00:25.00:25.00)' in header,(cid,'corner_mismatch')
    sources.append(dict(ref=ref,ddc=str(paths[0]),ddc_sha256=h.hexdigest(),ddc_bytes=paths[0].stat().st_size))
    if len(sources)%32==0: print('M16_SOURCE_VERIFIED',len(sources),flush=True)
assert len(sources)==352
result=dict(status='PASS',checked_unix=time.time(),corner='tt0p8v25c',sources=sources,source_top_sha256=m['source_sha256'])
(r/'source_audit.json').write_text(json.dumps(result,indent=2))
print('M16_SOURCE_AUDIT_PASS count=352',flush=True)
'''


def make_tcl(block, manifest, final=False):
    name = block['top']
    reads = []
    refs = block['refs']
    if final:
        for b in manifest['blocks']:
            t = b['top']
            reads.append(f'read_ddc {REMOTE}/outputs/{t}/{t}.ddc\nset_dont_touch [get_designs {t}] true')
    else:
        for ref in refs:
            cid = child_id(ref, manifest['router_metadata'][ref]['index'])
            reads.append(f'''read_ddc {BASE}/outputs/{cid}/{ref}.ddc
foreach_in_collection d [get_designs *] {{
  set dn [get_object_name $d]
  if {{![string match "CMRRouter_split_*" $dn]}} {{rename_design $dn "{ref}__$dn"}}
}}
set_dont_touch [get_designs {ref}] true''')
    expected = ' '.join(f'{ref} {count}' for ref, count in refs.items())
    body = f'''set R {REMOTE}
set O "$R/outputs/{name}"
file mkdir $O
file mkdir "$R/work/{name}"
source {BASE}/rtl/tech_t28ss.tcl
define_design_lib WORK -path "$R/work/{name}"
analyze -format verilog "$R/rtl/{name}.v"
{chr(10).join(reads)}
elaborate {name}
current_design {name}
if {{![link]}} {{error "link_failed"}}
set expected [dict create {expected}]
set seen [dict create]
set n 0
foreach_in_collection rc [get_cells -hierarchical -filter {{ref_name =~ CMRRouter_split_*}}] {{
  set ref [get_attribute $rc ref_name]
  if {{[regexp {{^CMRRouter_split_l[0-9]+_c[0-9]+_p[0-9]+_x[0-9]+_y[0-9]+_m[01]_g[0-9]+_s[0-9]+_a[01]$}} $ref]}} {{
    if {{![dict exists $expected $ref]}} {{error "unexpected_router_ref $ref"}}
    dict incr seen $ref
    incr n
  }}
}}
dict for {{ref count}} $expected {{
  if {{![dict exists $seen $ref] || [dict get $seen $ref] != $count}} {{error "router_ref_count $ref expected=$count"}}
}}
if {{$n != {block['routers']}}} {{error "router_count=$n"}}
set nipm 0
set nopm 0
for {{set i 0}} {{$i < 8}} {{incr i}} {{
  incr nipm [sizeof_collection [get_cells -hierarchical -quiet InputPortModules_$i]]
  incr nopm [sizeof_collection [get_cells -hierarchical -quiet OutputPortModules_$i]]
}}
set nadapter 0
foreach an {{adapter adapter_1 adapter_2 adapter_3}} {{
  incr nadapter [sizeof_collection [get_cells -hierarchical -quiet $an]]
}}
if {{$nipm != {block['ports']} || $nopm != {block['ports']} || $nadapter != {block['adapters']}}} {{error "structure_count ipm=$nipm opm=$nopm adapters=$nadapter"}}
if {{[sizeof_collection [get_cells -hierarchical -quiet -filter {{is_unresolved == true}}]] != 0}} {{error "unresolved_cells"}}
redirect "$O/check_design.rpt" {{check_design}}
source {BASE}/rtl/assert_no_gtech.tcl
if {{[async_assert_no_gtech $O] != 0 || [async_assert_no_seqgen $O] != 0}} {{error "unmapped_logic"}}
foreach_in_collection d [get_designs *] {{
  set dn [get_object_name $d]
  if {{$dn ne "{name}" && ![string match "CMRRouter_split_*" $dn] && ![string match "M16BLK_*" $dn]}} {{rename_design $dn "M16BLK_{name}__$dn"}}
}}
puts "M16_LINK_STRUCTURE_PASS top={name} routers=$n ipms=$nipm opms=$nopm adapters=$nadapter"
write -hierarchy -format ddc -output "$O/{name}.ddc"
write -hierarchy -format verilog -output "$O/{name}_post.v"
write_sdf "$O/{name}.sdf"
exec sha256sum "$O/{name}.ddc" "$O/{name}_post.v" "$O/{name}.sdf" > "$O/hashes.sha256"
puts "{'M16_NETWORK_LINK_PASS' if final else 'M16_BLOCK_LINK_PASS'} top={name} routers=$n"
'''
    # Final source block names must remain bound to the original top RTL.
    if final:
        start = body.index('foreach_in_collection d [get_designs *]', body.index('source ' + BASE + '/rtl/assert_no_gtech.tcl'))
        end = body.index('puts "M16_LINK_STRUCTURE_PASS', start)
        body = body[:start] + body[end:]
    return 'if {[catch {\n' + body + '\n} message options]} {\nputs "M16_LINK_FAIL $message"\nexit 2\n}\nquit\n'


def main():
    m = json.loads((OUT / 'manifest.json').read_text())
    assert not (OUT / 'jobs.json').exists(), 'Already submitted: inspect jobs.json instead of submitting twice'
    c = connect()
    def run(cmd):
        _, o, e = c.exec_command(cmd, timeout=180)
        text, err = o.read().decode(), e.read().decode()
        if o.channel.recv_exit_status():
            raise RuntimeError(text + err)
        print(text, flush=True)
        return text
    run(f'test ! -e {REMOTE} && mkdir -p {REMOTE}/scripts {REMOTE}/rtl {REMOTE}/outputs {REMOTE}/logs {REMOTE}/work')
    s = c.open_sftp()
    s.put(str(ROOT / 'scripts/asic_dc/cmr/prepare_m16_1024_link.py'), REMOTE + '/scripts/prepare.py')
    text = run(f'/soft/GNU/python3.12/bin/python3 {REMOTE}/scripts/prepare.py --source {BASE}/rtl/split/m16 --out {REMOTE}/rtl')
    with s.open(REMOTE + '/rtl/manifest.json') as f:
        remote_manifest = json.loads(f.read())
    assert remote_manifest['source_sha256'] == m['source_sha256']
    assert remote_manifest['rtl_hashes'] == m['rtl_hashes'], 'Remote/local extracted RTL mismatch'
    with s.open(REMOTE + '/scripts/source_audit.py', 'w') as f:
        f.write(PREFLIGHT)
    def shell(path, command, checks=''):
        text = '#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nset -eo pipefail\n'
        text += checks + f'cd {REMOTE}\n' + command + '\n'
        with s.open(REMOTE + '/scripts/' + path + '.sh', 'w') as f:
            f.write(text)
    shell('source_audit', f'exec /soft/GNU/python3.12/bin/python3 scripts/source_audit.py {REMOTE} {BASE}')
    jobs = dict(remote=REMOTE, base=BASE, parallel_slots=8, blocks={}, mode='link-only, no compile_ultra', sdf_monitor_interval_seconds=600)
    def save():
        (OUT / 'jobs.json').write_text(json.dumps(jobs, indent=2))
    def submit(name, script, dependency=''):
        dep = ' -w ' + shlex.quote(dependency) if dependency else ''
        out = run(f'bsub -n 1{dep} -J {name} -o {REMOTE}/logs/{script}.log -e {REMOTE}/logs/{script}.err bash {REMOTE}/scripts/{script}.sh')
        return re.search(r'Job <(\d+)>', out)[1]
    jobs['source_audit_job'] = submit('m16_source_audit', 'source_audit')
    save()
    slots = [jobs['source_audit_job']] * 8
    for i, b in enumerate(m['blocks']):
        name = b['top']
        with s.open(REMOTE + '/scripts/' + name + '.tcl', 'w') as f:
            f.write(make_tcl(b, m))
        checks = f'grep -q "^M16_SOURCE_AUDIT_PASS count=352" {REMOTE}/logs/source_audit.log\n'
        if i >= 8:
            prev = m['blocks'][i-8]['top']
            checks += f'grep -q "^M16_BLOCK_LINK_PASS " {REMOTE}/logs/{prev}.log\n'
            checks += f'if grep -Eq "^Error:|^M16_LINK_FAIL|UIO-92" {REMOTE}/logs/{prev}.log; then exit 2; fi\n'
        shell(name, f'exec dc_shell-t -64 -f scripts/{name}.tcl', checks)
        jid = submit(f'm16_link_{i:02d}', name, f'done({slots[i%8]})')
        slots[i%8] = jid
        jobs['blocks'][name] = jid
        save()
    total = collections.Counter()
    for b in m['blocks']:
        for ref, count in b['refs'].items():
            total[ref] += count * b['instances']
    final = dict(top=TOP, refs=dict(total), routers=1024, ports=8192, adapters=4096)
    with s.open(REMOTE + '/scripts/final.tcl', 'w') as f:
        f.write(make_tcl(final, m, True))
    checks = ''
    for name in jobs['blocks']:
        checks += f'grep -q "^M16_BLOCK_LINK_PASS " {REMOTE}/logs/{name}.log\n'
        checks += f'if grep -Eq "^Error:|^M16_LINK_FAIL|UIO-92" {REMOTE}/logs/{name}.log; then exit 2; fi\n'
    shell('final', 'exec dc_shell-t -64 -f scripts/final.tcl', checks)
    jobs['final_job'] = submit('m16_1024_hierlink', 'final', ' && '.join('done(' + j + ')' for j in jobs['blocks'].values()))
    save()
    run(f'cd {REMOTE} && sha256sum rtl/*.v scripts/*.tcl scripts/*.py scripts/*.sh > inputs.sha256 && bjobs -w {jobs["source_audit_job"]} {jobs["final_job"]}')
    s.close()
    c.close()


if __name__ == '__main__':
    main()
