"""Run on a compute node; remove named obsolete DC artifacts, gzip old logs.

Every mutation is appended to an external stdout journal. No RTL/results/cases
or current campaigns are deleted. Compression is verified before unlinking.
"""
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path('/home/ghy19/Asynchronous_Router_CMR')
OBSOLETE = (
    '20260913_1130_prop256_1248_topmesh48_hierdc_stitch_node19',
    '20260914_prop_temp256_b8_hier_dc_06',
    '20260915_122347_cmr_mesh256_hier_dc',
    '20261013_cmr_mesh256_tt_clickopt_r1',
    '20260915_122347_cmr_pfat_temp256_hier_dc',
)


def journal(**kw):
    print(json.dumps(dict(time=time.time(), **kw)), flush=True)


def digest(path, compressed=False):
    h = hashlib.sha256()
    with (gzip.open(path, 'rb') if compressed else path.open('rb')) as f:
        for block in iter(lambda: f.read(4*1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def allocated(path):
    total = 0
    for base, dirs, files in os.walk(path, followlinks=False):
        for name in files:
            p = Path(base)/name
            if not p.is_symlink():
                total += p.stat().st_blocks*512
    return total


def main():
    query = subprocess.run(['bjobs', '-u', 'ghy19', '-l'], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, universal_newlines=True)
    active = query.stdout
    if query.returncode and 'No unfinished job found' not in active:
        raise RuntimeError('cannot audit active jobs: '+active[-1000:])
    journal(action='START', root=str(ROOT), active_jobs_audited=True)
    freed = 0
    # Exact historical families; includes uniquely compiled child outputs.
    for d in sorted((ROOT/'outputs').iterdir()):
        if not d.is_dir() or d.is_symlink():
            continue
        if not any(d.name == old or d.name.startswith(old+'_c') for old in OBSOLETE):
            continue
        target = d.resolve()
        assert target.parent == (ROOT/'outputs').resolve()
        if d.name in active:
            journal(action='SKIP_ACTIVE', path=str(d)); continue
        size = allocated(d)
        journal(action='DELETE_BEGIN', path=str(d), bytes=size)
        shutil.rmtree(d)
        freed += size
        journal(action='DELETE_DONE', path=str(d), bytes=size)
    # Old DC work is rebuildable. Exclude every modern/current campaign.
    for d in sorted((ROOT/'work').iterdir()):
        if not d.is_dir() or d.is_symlink() or 'dc' not in d.name.lower():
            continue
        if not ('202609' in d.name or any(old in d.name for old in OBSOLETE)):
            continue
        assert d.resolve().parent == (ROOT/'work').resolve()
        if d.name in active or any(old in active for old in OBSOLETE if old in d.name):
            journal(action='SKIP_ACTIVE', path=str(d)); continue
        size = allocated(d)
        journal(action='DELETE_BEGIN', path=str(d), bytes=size)
        shutil.rmtree(d)
        freed += size
        journal(action='DELETE_DONE', path=str(d), bytes=size)
    cutoff = time.time()-48*3600
    count = 0
    suffixes = {'.log', '.err', '.out', '.txt', '.rpt', '.vcd', '.fsdb'}
    for base, dirs, files in os.walk(ROOT/'logs', followlinks=False):
        dirs[:] = [d for d in dirs if not (Path(base)/d).is_symlink()]
        for name in files:
            p = Path(base)/name
            if p.is_symlink() or p.suffix.lower() not in suffixes:
                continue
            st = p.stat()
            if st.st_size < 1024*1024 or st.st_mtime >= cutoff:
                continue
            relative = str(p.relative_to(ROOT/'logs'))
            if str(p) in active or name in active or relative.split('/')[0] == 'dc' and p.stem in active:
                journal(action='SKIP_ACTIVE', path=str(p)); continue
            zipped = p.with_name(p.name+'.gz')
            temp = p.with_name(p.name+'.gz.cleanup_tmp')
            if zipped.exists() or temp.exists():
                journal(action='SKIP_EXISTING_ARCHIVE', path=str(p)); continue
            journal(action='GZIP_BEGIN', path=str(p), bytes=st.st_size)
            original_hash = digest(p)
            try:
                with p.open('rb') as src, gzip.open(temp, 'wb', compresslevel=1) as dst:
                    shutil.copyfileobj(src, dst, 4*1024*1024)
                assert digest(temp, True) == original_hash, 'gzip verification failed'
                now = p.stat()
                assert (now.st_size, now.st_mtime_ns) == (st.st_size, st.st_mtime_ns), 'source changed'
                if temp.stat().st_size >= st.st_size:
                    temp.unlink(); journal(action='SKIP_NO_SAVINGS', path=str(p)); continue
                os.utime(temp, ns=(st.st_atime_ns, st.st_mtime_ns))
                os.replace(temp, zipped)
                saving = st.st_blocks*512-zipped.stat().st_blocks*512
                p.unlink()
                freed += saving; count += 1
                journal(action='GZIP_DONE', path=str(p), archive=str(zipped),
                        sha256=original_hash, freed_bytes=saving)
            except Exception as exc:
                journal(action='ERROR', path=str(p), error=repr(exc))
                if temp.exists(): temp.unlink()
                raise
    journal(action='CLEANUP_PASS', compressed_files=count, freed_bytes=freed)


if __name__ == '__main__': main()
