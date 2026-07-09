[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$SourceRoot = "",
    [switch]$PruneExtraCopiedFiles
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

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $ProjectRoot "ReferenceSources\TopDownEngine\Assets\TopDownEngine"
}

$resolvedProjectRoot = (Resolve-Path $ProjectRoot).Path
$resolvedSourceRoot = (Resolve-Path $SourceRoot).Path
$destinationRoot = Join-Path $resolvedProjectRoot "Assets\Plugins\TopDownEngine"

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-DirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [switch]$Prune
    )

    Ensure-Directory -Path $TargetPath

    $null = robocopy $SourcePath $TargetPath /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed: $SourcePath -> $TargetPath, exit code: $LASTEXITCODE"
    }

    $sourceMetaPath = $SourcePath + ".meta"
    $targetMetaPath = $TargetPath + ".meta"
    if (Test-Path -LiteralPath $sourceMetaPath) {
        Copy-Item -LiteralPath $sourceMetaPath -Destination $targetMetaPath -Force
    }

    if ($Prune) {
        $targetFiles = Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force
        foreach ($targetFile in $targetFiles) {
            $relativeFile = $targetFile.FullName.Substring($TargetPath.Length).TrimStart('\')
            $sourceFile = Join-Path $SourcePath $relativeFile
            if (-not (Test-Path -LiteralPath $sourceFile)) {
                Remove-Item -LiteralPath $targetFile.FullName -Force
            }
        }

        $targetDirectories = Get-ChildItem -LiteralPath $TargetPath -Recurse -Directory -Force | Sort-Object FullName -Descending
        foreach ($targetDirectory in $targetDirectories) {
            $relativeDirectory = $targetDirectory.FullName.Substring($TargetPath.Length).TrimStart('\')
            $sourceDirectory = Join-Path $SourcePath $relativeDirectory
            if (-not (Test-Path -LiteralPath $sourceDirectory)) {
                Remove-Item -LiteralPath $targetDirectory.FullName -Recurse -Force
                continue
            }

            $hasChildren = Get-ChildItem -LiteralPath $targetDirectory.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $hasChildren) {
                Remove-Item -LiteralPath $targetDirectory.FullName -Force
            }
        }
    }
}

function Remove-RelativePathIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $targetPath = Join-Path $BasePath $RelativePath
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }

    $targetMetaPath = $targetPath + ".meta"
    if (Test-Path -LiteralPath $targetMetaPath) {
        Remove-Item -LiteralPath $targetMetaPath -Force
    }
}

$copySpecs = @(
    @{
        Name = "Common"
        Source = "Common"
        Target = "Common"
        ExcludedChildren = @(
            "ScriptsCinemachine",
            "ScriptsPostProcessing"
        )
    },
    @{
        Name = "Koala2D"
        Source = "Demos\Koala2D"
        Target = "Demos\Koala2D"
        ExcludedChildren = @()
    },
    @{
        Name = "MMTools"
        Source = "ThirdParty\MoreMountains\MMTools"
        Target = "ThirdParty\MoreMountains\MMTools"
        ExcludedChildren = @(
            "Demos",
            "Accessories\MMCinemachine"
        )
    },
    @{
        Name = "MMInterface"
        Source = "ThirdParty\MoreMountains\MMInterface"
        Target = "ThirdParty\MoreMountains\MMInterface"
        ExcludedChildren = @()
    },
    @{
        Name = "InventoryEngine"
        Source = "ThirdParty\MoreMountains\InventoryEngine\InventoryEngine"
        Target = "ThirdParty\MoreMountains\InventoryEngine\InventoryEngine"
        ExcludedChildren = @()
    },
    @{
        Name = "MMFeedbacks Runtime"
        Source = "ThirdParty\MoreMountains\MMFeedbacks\MMFeedbacks"
        Target = "ThirdParty\MoreMountains\MMFeedbacks\MMFeedbacks"
        ExcludedChildren = @()
    },
    @{
        Name = "MMFeedbacks Editor"
        Source = "ThirdParty\MoreMountains\MMFeedbacks\Editor"
        Target = "ThirdParty\MoreMountains\MMFeedbacks\Editor"
        ExcludedChildren = @()
    },
    @{
        Name = "MMFeedbacks Authorizations"
        Source = "ThirdParty\MoreMountains\MMFeedbacks\Authorizations"
        Target = "ThirdParty\MoreMountains\MMFeedbacks\Authorizations"
        ExcludedChildren = @()
    }
)

Ensure-Directory -Path $destinationRoot

Write-Host "FantasyWord top-down runtime subset sync"
Write-Host "ProjectRoot: $resolvedProjectRoot"
Write-Host "SourceRoot: $resolvedSourceRoot"
Write-Host "DestinationRoot: $destinationRoot"
Write-Host "PruneExtraCopiedFiles: $($PruneExtraCopiedFiles.IsPresent)"

foreach ($spec in $copySpecs) {
    $sourcePath = Join-Path $resolvedSourceRoot $spec.Source
    $targetPath = Join-Path $destinationRoot $spec.Target

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Source path not found: $sourcePath"
    }

    Write-Host ""
    Write-Host "[sync] $($spec.Name)"
    Write-Host "  source: $sourcePath"
    Write-Host "  target: $targetPath"

    Copy-DirectoryTree -SourcePath $sourcePath -TargetPath $targetPath -Prune:$PruneExtraCopiedFiles

    foreach ($excludedChild in $spec.ExcludedChildren) {
        Remove-RelativePathIfExists -BasePath $targetPath -RelativePath $excludedChild
    }
}

Write-Host ""
Write-Host "TopDown runtime subset sync completed."
