param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$UpstreamCommit,

    [Parameter(Mandatory)]
    [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$')]
    [string]$UpstreamTag,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$WorkflowCommit,

    [string]$Arm64Ref = 'origin/arm64',
    [string]$PublishedSourceRef
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$metadataPath = 'arm64-source.json'

function Test-Ancestor([string]$Ancestor, [string]$Descendant) {
    $PSNativeCommandUseErrorActionPreference = $false
    git merge-base --is-ancestor $Ancestor $Descendant
    if ($LASTEXITCODE -gt 1) {
        throw "Cannot compare source ancestry for $Ancestor and $Descendant."
    }
    return $LASTEXITCODE -eq 0
}

function Get-SourceMetadata([string]$Ref) {
    $PSNativeCommandUseErrorActionPreference = $false
    git cat-file -e "${Ref}:$metadataPath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    $PSNativeCommandUseErrorActionPreference = $true
    $metadata = (git show "${Ref}:$metadataPath") | ConvertFrom-Json
    if ($metadata.upstreamCommit -cnotmatch '^[0-9a-f]{40}$' -or
        $metadata.arm64Commit -cnotmatch '^[0-9a-f]{40}$') {
        throw "Invalid ARM64 source metadata in $Ref."
    }
    return $metadata
}

function Merge-SourceTree([string]$Base, [string]$Local, [string]$Incoming) {
    $PSNativeCommandUseErrorActionPreference = $false
    $result = @(git -c core.quotepath=false merge-tree --write-tree --name-only "--merge-base=$Base" $Local $Incoming)
    $mergeExit = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $true
    if ($mergeExit -gt 1 -or !$result -or $result[0] -cnotmatch '^[0-9a-f]{40}$') {
        throw "Cannot prepare ARM64 source. Git merge-tree exited with $mergeExit."
    }
    if ($mergeExit -eq 1) {
        $conflicts = @()
        foreach ($line in ($result | Select-Object -Skip 1)) {
            if (!$line) { break }
            if (!$line.StartsWith('.github/workflows/')) {
                $conflicts += $line
            }
        }
        if ($conflicts.Count) {
            throw "ARM64 source needs a compatibility update. Conflicting files: $($conflicts -join ', ')"
        }
    }
    return $result[0]
}

$arm64Commit = git rev-parse "$Arm64Ref^{commit}"
$sourceCommit = $arm64Commit
$baseCommit = git merge-base $arm64Commit $UpstreamCommit

if ($PublishedSourceRef) {
    $released = Get-SourceMetadata $PublishedSourceRef
    if ($released -and (Test-Ancestor $baseCommit $released.upstreamCommit) -and
        (Test-Ancestor $released.upstreamCommit $UpstreamCommit)) {
        # Carry forward the last successful integration, including fixes committed
        # to arm64 since that release. Avoid replaying the full original fork delta.
        $tree = Merge-SourceTree $released.arm64Commit $PublishedSourceRef $arm64Commit
        $sourceCommit = git commit-tree $tree -p $arm64Commit -m 'Apply ARM64 changes since the previous release'
        $baseCommit = $released.upstreamCommit
        Write-Host "Continuing from $PublishedSourceRef (upstream $($released.upstreamTag))."
    }
}

$tree = Merge-SourceTree $baseCommit $sourceCommit $UpstreamCommit
git switch --detach $WorkflowCommit | Out-Host
git read-tree --reset -u $tree
git restore --source $WorkflowCommit --staged --worktree -- .github/workflows

[ordered]@{
    upstreamTag = $UpstreamTag
    upstreamCommit = $UpstreamCommit
    arm64Commit = $arm64Commit
} | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8
git add -- $metadataPath
$tree = git write-tree
# GitHub's Actions token may tag source changes when workflows match its parent.
$snapshot = git commit-tree $tree -p $WorkflowCommit -m "Build ARM64 from upstream $UpstreamTag ($UpstreamCommit)"
git switch --force-create arm64-release-source $snapshot | Out-Host
return $snapshot
