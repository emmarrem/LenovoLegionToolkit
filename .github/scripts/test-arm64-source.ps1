param(
    [string]$TemporaryDirectory = (Join-Path ([IO.Path]::GetTempPath()) "llt-arm64-regression-$([guid]::NewGuid())")
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$prepareSource = Join-Path $PSScriptRoot 'prepare-arm64-source.ps1'
New-Item -ItemType Directory -Path $TemporaryDirectory | Out-Null
Push-Location $TemporaryDirectory
try {
    git init --initial-branch=upstream | Out-Null
    git config user.name 'ARM64 regression test'
    git config user.email 'test@example.invalid'
    git config core.autocrlf false
    New-Item -ItemType Directory -Force '.github/workflows' | Out-Null
    'original' | Set-Content '.github/workflows/release.yml'
    $files = @('.gitignore', 'RefreshRate.cs', 'Compatibility.cs', 'PawnIO.cs')
    $padding = (1..12 | ForEach-Object { "// unchanged line $_" }) -join "`n"
    foreach ($file in $files) {
        "mode=base`n$padding" | Set-Content $file
    }
    git add .
    git commit -m base | Out-Null
    $base = git rev-parse HEAD

    git switch -c arm64 | Out-Null
    foreach ($file in $files) {
        "mode=arm64-legacy`n$padding" | Set-Content $file
    }
    git add .
    git commit -m 'old ARM64 port' | Out-Null
    $arm64 = git rev-parse HEAD

    git switch upstream | Out-Null
    foreach ($file in $files) {
        "mode=upstream1`n$padding" | Set-Content $file
    }
    git add .
    git commit -m 'first upstream update' | Out-Null
    $upstream1 = git rev-parse HEAD

    git switch -c released | Out-Null
    foreach ($file in $files) {
        "mode=upstream1`n$padding`narm64-enabled" | Set-Content $file
    }
    @{ upstreamTag='v1.1.0'; upstreamCommit=$upstream1; arm64Commit=$arm64 } |
        ConvertTo-Json | Set-Content arm64-source.json
    git add .
    git commit -m 'previous successful integration' | Out-Null
    $released = git rev-parse HEAD

    git switch upstream | Out-Null
    foreach ($file in $files) {
        "mode=upstream2`n$padding" | Set-Content $file
    }
    'upstream workflow update' | Set-Content '.github/workflows/release.yml'
    git add .
    git commit -m 'next upstream update' | Out-Null
    $upstream2 = git rev-parse HEAD

    $PSNativeCommandUseErrorActionPreference = $false
    $oldMerge = @(git merge-tree --write-tree "--merge-base=$base" $arm64 $upstream2)
    if ($LASTEXITCODE -ne 1) { throw 'Fixture must reproduce the original merge failure.' }
    $PSNativeCommandUseErrorActionPreference = $true

    git switch -c workflow $base | Out-Null
    'fork release automation' | Set-Content '.github/workflows/release.yml'
    git add .
    git commit -m 'fork workflow' | Out-Null
    $workflow = git rev-parse HEAD
    $snapshot = & $prepareSource -UpstreamCommit $upstream2 -UpstreamTag v1.2.0 `
        -WorkflowCommit $workflow -Arm64Ref arm64 -PublishedSourceRef $released
    foreach ($file in $files) {
        if ((Get-Content $file -Raw).Trim() -ne "mode=upstream2`n$padding`narm64-enabled") {
            throw "Lost upstream or ARM64 behavior in $file."
        }
    }
    if ((Get-Content '.github/workflows/release.yml' -Raw).Trim() -ne 'fork release automation') {
        throw 'Fork workflow was overwritten.'
    }
    if ((git rev-parse "$snapshot^") -ne $workflow) { throw 'Invalid release snapshot parent.' }
    $metadata = Get-Content arm64-source.json -Raw | ConvertFrom-Json
    if ($metadata.upstreamCommit -ne $upstream2) { throw 'Source baseline did not advance.' }

    # A later ARM64 branch fix is carried forward from the previous release.
    git switch arm64 | Out-Null
    'new ARM64 fix' | Set-Content new-arm64-fix.txt
    git add .
    git commit -m 'ARM64 follow-up' | Out-Null
    $next = & $prepareSource -UpstreamCommit $upstream2 -UpstreamTag v1.2.0 `
        -WorkflowCommit $workflow -Arm64Ref arm64 -PublishedSourceRef $snapshot
    if ((Get-Content new-arm64-fix.txt -Raw).Trim() -ne 'new ARM64 fix') {
        throw 'Lost changes made to arm64 after the previous release.'
    }

    # Genuine source conflicts still stop before a release can be published.
    git switch -c incompatible $upstream2 | Out-Null
    "mode=incompatible`n$padding" | Set-Content Compatibility.cs
    git add .
    git commit -m 'incompatible API change' | Out-Null
    $incompatible = git rev-parse HEAD
    $caughtConflict = $false
    try {
        & $prepareSource -UpstreamCommit $upstream2 -UpstreamTag v1.2.0 `
            -WorkflowCommit $workflow -Arm64Ref $incompatible -PublishedSourceRef $next | Out-Null
    }
    catch {
        if ($_.Exception.Message -notmatch 'Conflicting files: Compatibility.cs') { throw }
        $caughtConflict = $true
    }
    if (!$caughtConflict) { throw 'An unresolved source conflict was accepted.' }
    Write-Host 'ARM64 source regression checks passed.'
}
finally {
    Pop-Location
}

# The last test deliberately runs Git into a conflict. Report the test result
# instead of leaving that expected native exit code for the Actions wrapper.
exit 0
