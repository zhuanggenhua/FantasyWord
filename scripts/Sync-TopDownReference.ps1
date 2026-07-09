[CmdletBinding()]
param(
    [string]$SourceRoot = "C:\Gamedev\Unity\Engine\TopDown Engine\TopDown Engine v4.1\Assets\TopDownEngine",
    [string]$DestinationRoot = "",
    [switch]$PruneExtraCopiedFiles
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DestinationRoot)) {
    $DestinationRoot = Join-Path $projectRoot "ReferenceSources\TopDownEngine"
}

$resolvedProjectRoot = (Resolve-Path $projectRoot).Path
$resolvedSourceRoot = (Resolve-Path $SourceRoot).Path

if (-not (Test-Path $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
}

$resolvedDestinationRoot = (Resolve-Path $DestinationRoot).Path

if (-not $resolvedDestinationRoot.StartsWith($resolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "DestinationRoot must stay inside project root. Destination: $resolvedDestinationRoot"
}

$copySpecs = @(
    @{
        Name = "Common"
        RelativePath = "Common"
    },
    @{
        Name = "Koala2D"
        RelativePath = "Demos\Koala2D"
    },
    @{
        Name = "MoreMountains"
        RelativePath = "ThirdParty\MoreMountains"
    }
)

function Copy-DirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [switch]$Prune
    )

    if (-not (Test-Path $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    $sourceDirectories = Get-ChildItem -Path $SourcePath -Recurse -Directory -Force
    foreach ($directory in $sourceDirectories) {
        $relativeDirectory = $directory.FullName.Substring($SourcePath.Length).TrimStart('\')
        $targetDirectory = Join-Path $TargetPath $relativeDirectory
        if (-not (Test-Path $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
    }

    $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File -Force
    foreach ($file in $sourceFiles) {
        $relativeFile = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
        $targetFile = Join-Path $TargetPath $relativeFile
        $targetDirectory = Split-Path -Parent $targetFile
        if (-not (Test-Path $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
        Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force
    }

    if ($Prune) {
        $targetFiles = Get-ChildItem -Path $TargetPath -Recurse -File -Force
        foreach ($targetFile in $targetFiles) {
            $relativeFile = $targetFile.FullName.Substring($TargetPath.Length).TrimStart('\')
            $sourceFile = Join-Path $SourcePath $relativeFile
            if (-not (Test-Path $sourceFile)) {
                Remove-Item -LiteralPath $targetFile.FullName -Force
            }
        }

        $targetDirectories = Get-ChildItem -Path $TargetPath -Recurse -Directory -Force | Sort-Object FullName -Descending
        foreach ($targetDirectory in $targetDirectories) {
            $relativeDirectory = $targetDirectory.FullName.Substring($TargetPath.Length).TrimStart('\')
            $sourceDirectory = Join-Path $SourcePath $relativeDirectory
            if (-not (Test-Path $sourceDirectory)) {
                Remove-Item -LiteralPath $targetDirectory.FullName -Recurse -Force
                continue
            }

            $hasChildren = Get-ChildItem -LiteralPath $targetDirectory.FullName -Force
            if ($null -eq $hasChildren) {
                Remove-Item -LiteralPath $targetDirectory.FullName -Force
            }
        }
    }
}

Write-Host "FantasyWord top-down reference sync"
Write-Host "ProjectRoot: $resolvedProjectRoot"
Write-Host "SourceRoot: $resolvedSourceRoot"
Write-Host "DestinationRoot: $resolvedDestinationRoot"
Write-Host "PruneExtraCopiedFiles: $($PruneExtraCopiedFiles.IsPresent)"

foreach ($spec in $copySpecs) {
    $sourcePath = Join-Path $resolvedSourceRoot $spec.RelativePath
    $targetPath = Join-Path $resolvedDestinationRoot (Join-Path "Assets\TopDownEngine" $spec.RelativePath)

    if (-not (Test-Path $sourcePath)) {
        throw "Source path not found: $sourcePath"
    }

    Write-Host ""
    Write-Host "[sync] $($spec.Name)"
    Write-Host "  source: $sourcePath"
    Write-Host "  target: $targetPath"

    Copy-DirectoryTree -SourcePath $sourcePath -TargetPath $targetPath -Prune:$PruneExtraCopiedFiles
}

Write-Host ""
Write-Host "TopDown reference sync completed."
