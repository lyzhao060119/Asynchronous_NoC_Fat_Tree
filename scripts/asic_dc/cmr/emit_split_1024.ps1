$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $repoPath
$runPath = Join-Path $repoPath 'generated_cmr/split1024_20261020'
New-Item -ItemType Directory -Force -Path $runPath | Out-Null
# The two networks run sequentially. JVM heap is bounded independently of the
# network size; all internal router compilations are sequential and resumable.
$env:_JAVA_OPTIONS = '-Xms512m -Xmx6g -XX:MaxMetaspaceSize=1g'
& sbt `
  'runMain Router_Architecture.CMR.CMRSplitNetworkEmitMain m16_1024 generated_cmr/split1024_20261020/m16' `
  'runMain Router_Architecture.CMR.CMRSplitNetworkEmitMain mesh1024 generated_cmr/split1024_20261020/mesh'
$emitExit = $LASTEXITCODE
Set-Content -LiteralPath (Join-Path $runPath 'exit_status.txt') -Value $emitExit
exit $emitExit
