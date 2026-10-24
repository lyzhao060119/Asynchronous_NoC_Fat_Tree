"""Submit four coordinate-correct mapped quadrant links and a gated final link."""
import hashlib
import json
import re
import shlex
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
LOCAL = ROOT / 'results/mesh1024_quadrants_20261023_r1'
REMOTE = '/home/ghy19/Asynchronous_Router_CMR/campaigns/mesh1024_quadrants_20261023_r1'
BASE = '/home/ghy19/Asynchronous_Router_CMR/campaigns/20261020_split1024_tt_r1'


def tcl(top, refs, final=False):
    reads = []
    for ref in refs:
        if final:
            path = f'{REMOTE}/outputs/{ref}/{ref}.ddc'
        else:
            path = f'{BASE}/outputs/$cid/{ref}.ddc'
            reads.append(f'set matches [glob -nocomplain {BASE}/outputs/*/{ref}.ddc]\nif {{[llength $matches] != 1}} {{error "child_ddc_count {ref}"}}\nset path [lindex $matches 0]')
        if final:
            reads.append(f'set path {path}')
        reads.append('if {![file exists $path] || [file size $path] == 0} {error "missing_ddc $path"}\nread_ddc $path')
        if not final:
            reads.append(f'''foreach_in_collection d [get_designs *] {{
  set dn [get_object_name $d]
  if {{![string match "CMRRouter_split_*" $dn]}} {{
    rename_design $dn "{ref}__$dn"
  }}
}}''')
        reads.append(f'set_dont_touch [get_designs {ref}] true')
    body = f'''set R {REMOTE}
set O "$R/outputs/{top}"
file mkdir $O
source {BASE}/rtl/tech_t28ss.tcl
define_design_lib WORK -path "$R/work/{top}"
analyze -format verilog "$R/rtl/{top}.v"
{chr(10).join(reads)}
elaborate {top}
current_design {top}
if {{![link]}} {{error "link_failed"}}
set_boundary_optimization [get_designs *] false
set_ungroup [get_designs *] false
set n 0
foreach_in_collection rc [get_cells -hierarchical -filter {{ref_name =~ CMRRouter_split_*}}] {{
  if {{[regexp {{^CMRRouter_split_l1_c1_p1_x[0-9]+_y[0-9]+_m1_g32_s0_a0$}} [get_attribute $rc ref_name]]}} {{incr n}}
}}
if {{$n != {1024 if final else 256}}} {{error "router_count=$n"}}
redirect "$O/check_design.rpt" {{check_design}}
set unresolved [get_cells -hierarchical -quiet -filter {{is_unresolved == true}}]
if {{[sizeof_collection $unresolved] != 0}} {{error "unresolved_cells"}}
source {BASE}/rtl/assert_no_gtech.tcl
if {{[async_assert_no_gtech $O] != 0 || [async_assert_no_seqgen $O] != 0}} {{error "unmapped_logic"}}
set nipm 0
set nopm 0
for {{set i 0}} {{$i < 5}} {{incr i}} {{
  incr nipm [sizeof_collection [get_cells -hierarchical -quiet InputPortModules_$i]]
  incr nopm [sizeof_collection [get_cells -hierarchical -quiet OutputPortModules_$i]]
}}
if {{$nipm != {5120 if final else 1280} || $nopm != {5120 if final else 1280}}} {{error "ipm_opm_count ipm=$nipm opm=$nopm"}}
puts "MESH_QUADRANT_EXPORT_BEGIN top={top} routers=$n"
write -hierarchy -format ddc -output "$O/{top}.ddc"
write -hierarchy -format verilog -output "$O/{top}_post.v"
write_sdf "$O/{top}.sdf"
exec sha256sum "$O/{top}.ddc" "$O/{top}_post.v" "$O/{top}.sdf" > "$O/hashes.sha256"
puts "{'MESH1024_FOUR_BLOCK_PASS' if final else 'MESH_QUADRANT_PASS'} top={top} routers=$n"
'''
    return 'if {[catch {\n' + body + '\n} message options]} {\nputs "MESH_BLOCK_FAIL $message"\nexit 2\n}\nquit\n'


def main():
    manifest = json.loads((LOCAL / 'manifest.json').read_text())
    c = connect()
    def run(cmd):
        _, o, e = c.exec_command(cmd, timeout=180)
        out, err = o.read().decode(), e.read().decode()
        if o.channel.recv_exit_status():
            raise RuntimeError(out + err)
        print(out, flush=True)
        return out
    run(f'test ! -e {REMOTE} && mkdir -p {REMOTE}/rtl {REMOTE}/scripts {REMOTE}/logs {REMOTE}/work {REMOTE}/outputs')
    s = c.open_sftp()
    for name, digest in manifest['hashes'].items():
        path = LOCAL / name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
        s.put(str(path), f'{REMOTE}/rtl/{name}')
    jobs = []
    for q in range(4):
        top = f'Mesh1024Quadrant{q}'
        refs = (LOCAL / f'q{q}_refs.txt').read_text().splitlines()
        script = tcl(top, refs)
        with s.open(f'{REMOTE}/scripts/{top}.tcl', 'w') as f:
            f.write(script)
        shell = f'#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nset -eo pipefail\ncd {REMOTE}\nmkdir -p work/{top}\nexec dc_shell-t -64 -f scripts/{top}.tcl\n'
        with s.open(f'{REMOTE}/scripts/{top}.sh', 'w') as f:
            f.write(shell)
        output = run(f'bsub -n 1 -J meshq{q}_1024 -o {REMOTE}/logs/{top}.log -e {REMOTE}/logs/{top}.err bash {REMOTE}/scripts/{top}.sh')
        jobs.append(re.search(r'Job <(\d+)>', output)[1])
    with s.open(f'{REMOTE}/scripts/CMRMeshNoC.tcl', 'w') as f:
        f.write(tcl('CMRMeshNoC', [f'Mesh1024Quadrant{q}' for q in range(4)], True))
    shell = '#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nset -eo pipefail\n'
    for q in range(4):
        shell += f'grep -q "^MESH_QUADRANT_PASS " {REMOTE}/logs/Mesh1024Quadrant{q}.log\n'
    shell += f'cd {REMOTE}\nmkdir -p work/CMRMeshNoC\nexec dc_shell-t -64 -f scripts/CMRMeshNoC.tcl\n'
    with s.open(f'{REMOTE}/scripts/final.sh', 'w') as f:
        f.write(shell)
    dependency = ' && '.join(f'done({j})' for j in jobs)
    output = run(f'bsub -n 1 -w {shlex.quote(dependency)} -J mesh1024_fourblock -o {REMOTE}/logs/final.log -e {REMOTE}/logs/final.err bash {REMOTE}/scripts/final.sh')
    manifest.update(remote=REMOTE, quadrant_jobs=jobs, final_job=re.search(r'Job <(\d+)>', output)[1], mode='mapped-child link-only; no compile_ultra')
    (LOCAL / 'jobs.json').write_text(json.dumps(manifest, indent=2))
    s.close()
    c.close()


if __name__ == '__main__':
    main()
