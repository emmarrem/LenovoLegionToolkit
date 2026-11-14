param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')]
    [string]$Version,

    [string]$HardwareMonitorSource = (Join-Path $PSScriptRoot '..\LibreHardwareMonitor'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'build_arm64'),
    [string]$Dotnet = 'dotnet',

    [ValidatePattern('^LenovoLegionToolkit-v\d+\.\d+\.\d+(\.\d+)?-win-arm64\.zip$')]
    [string]$ArchiveName = "LenovoLegionToolkit-v$Version-win-arm64.zip"
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$monitorCommit = 'ad760baba99c7c4ad6c86c5c57fb3ba766a7ee71'
$monitorPackageVersion = '1.0.7-arm64.27'
$localFeed = Join-Path $PSScriptRoot '.arm64-nuget'
$project = Join-Path $PSScriptRoot 'LenovoLegionToolkit.WPF\LenovoLegionToolkit.WPF.csproj'
$config = Join-Path $PSScriptRoot 'NuGet.Arm64.config'

if (!(Test-Path -LiteralPath $HardwareMonitorSource)) {
    git clone --no-checkout https://github.com/LenovoLegionToolkit-Team/LibreHardwareMonitor.git $HardwareMonitorSource
    git -C $HardwareMonitorSource checkout --detach $monitorCommit
}
if ((git -C $HardwareMonitorSource rev-parse HEAD) -ne $monitorCommit -or
    (git -C $HardwareMonitorSource status --porcelain --untracked-files=no)) {
    throw "LibreHardwareMonitor must be a clean checkout at $monitorCommit."
}

New-Item -ItemType Directory -Force -Path $localFeed, $OutputDirectory | Out-Null
$monitorProject = Join-Path $HardwareMonitorSource 'LibreHardwareMonitorLib\LibreHardwareMonitorLib.csproj'
& $Dotnet build $monitorProject -c Release -p:Platform=ARM64 -p:PlatformTarget=arm64 `
    -p:TargetFrameworks=net9.0 -p:RuntimeIdentifiers=win-arm64 -p:LangVersion=preview `
    "-p:Version=$monitorPackageVersion" "-p:PackageOutputPath=$localFeed" -v:q

& $Dotnet restore $project -p:RuntimeIdentifier=win-arm64 -p:SelfContained=true --configfile $config -v:q
$publish = Join-Path $OutputDirectory "LenovoLegionToolkit-$Version-win-arm64"
if (Test-Path -LiteralPath $publish) {
    throw "Choose an empty output directory. The publish folder already exists at $publish."
}
& $Dotnet publish $project -c Release -p:RuntimeIdentifier=win-arm64 --self-contained --no-restore -o $publish `
    "-p:Version=$Version" "-p:FileVersion=$Version" -p:DebugType=None -v:q
Copy-Item (Join-Path $PSScriptRoot 'LICENSE'), (Join-Path $PSScriptRoot 'NOTICE') -Destination $publish

# Check the app host, runtime, and the architecture-specific managed dependency.
foreach ($file in 'Lenovo Legion Toolkit.exe', 'coreclr.dll', 'LibreHardwareMonitorLib.dll') {
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead((Join-Path $publish $file)))
    try {
        $reader.BaseStream.Position = 0x3c
        $reader.BaseStream.Position = $reader.ReadUInt32()
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0xaa64) {
            throw "$file is not an ARM64 PE file."
        }
    }
    finally {
        $reader.Dispose()
    }
}

$archive = Join-Path $OutputDirectory $ArchiveName
Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $archive -Force
$checksum = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
"$checksum  $(Split-Path -Leaf $archive)" | Set-Content -LiteralPath "$archive.sha256" -Encoding ascii
Write-Output $archive
