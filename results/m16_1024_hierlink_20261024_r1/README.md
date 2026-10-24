# M16-1024 mapped hierarchical assembly

This candidate reuses the 352 frozen mapped Router DDCs from
`20261020_split1024_tt_r1`. It does not re-emit or recompile Router RTL.
The original network is partitioned along its existing hierarchy: 16 distinct
48-Router tree tiles and one 16-Router Mesh plane instantiated 16 times.
The final expected structure is 1024 Routers, 8192 IPMs, 8192 OPMs and 4096
LanePhaseAdapters. The source and extracted module hashes are in `manifest.json`.

Remote campaign:
`/home/ghy19/Asynchronous_Router_CMR/campaigns/m16_1024_hierlink_20261024_r1`

`jobs.json` records the source audit, 17 block links, final link and completion
audit. Up to eight one-slot block jobs run concurrently. Each subsequent block
requires its predecessor lane to finish successfully; the final link requires
all blocks. The source audit checks actual DDC hashes against frozen records.

Monitor with:

```powershell
D:\anaconda\python.exe -u scripts/asic_dc/cmr/monitor_m16_1024_link.py --watch --interval 600
```

`status.json` is an observation snapshot, not completion evidence by itself.
Completion requires all structural/PASS markers and the remote
`completion_audit.json` with SHA-256 verification of every DDC, netlist and SDF.
Large artifacts remain remote. This verifies mapped assembly and artifact
integrity only; automatic timing-loop cuts remain recorded and this is not
STA or SDF simulation signoff.
