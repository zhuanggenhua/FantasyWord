[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetProjectRoot,
    [string]$ProjectRoot,
    [ValidateSet("core", "full")]
    [string]$Profile = "full"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-RelativeItem {
    param(
        [string]$BaseRoot,
        [string]$RelativePath,
        [string]$DestinationRoot
    )

    $sourcePath = Join-Path $BaseRoot $RelativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Template item not found: $sourcePath"
    }

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    Ensure-Directory -Path (Split-Path -Parent $destinationPath)

    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        Ensure-Directory -Path $destinationPath
        $null = robocopy $sourcePath $destinationPath /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed: $sourcePath -> $destinationPath, exit code: $LASTEXITCODE"
        }

        $sourceMetaPath = $sourcePath + ".meta"
        $destinationMetaPath = $destinationPath + ".meta"
        if (Test-Path -LiteralPath $sourceMetaPath) {
            Copy-Item -LiteralPath $sourceMetaPath -Destination $destinationMetaPath -Force
        }
        return
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

$cacheRoot = Join-Path $ProjectRoot "Temp\FoundationBootstrapCache\$Profile"
if (Test-Path -LiteralPath $cacheRoot) {
    Remove-Item -LiteralPath $cacheRoot -Recurse -Force
}

$exportScript = Join-Path $ProjectRoot "scripts\Export-FoundationTemplate.ps1"
& $exportScript -ProjectRoot $ProjectRoot -OutputRoot $cacheRoot -Profile $Profile

$manifestPath = Join-Path $cacheRoot "foundation-template-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Exported template is missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Ensure-Directory -Path $TargetProjectRoot

foreach ($item in $manifest.items) {
    Copy-RelativeItem -BaseRoot $cacheRoot -RelativePath $item -DestinationRoot $TargetProjectRoot
}

$installReceipt = [ordered]@{
    installedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    sourceProjectRoot = $ProjectRoot
    templateCacheRoot = $cacheRoot
    targetProjectRoot = $TargetProjectRoot
    profile = $Profile
    items = $manifest.items
}

$receiptPath = Join-Path $TargetProjectRoot "foundation-install-receipt.json"
$installReceipt | ConvertTo-Json -Depth 6 | Set-Content -Path $receiptPath -Encoding UTF8

Write-Host "Foundation bootstrap finished."
Write-Host "TargetProjectRoot:" $TargetProjectRoot
Write-Host "Profile:" $Profile
