[CmdletBinding()]
param(
    [switch]$IncludeGeneratedRoots,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $PSCommandPath
    }

    return [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
}

function Get-EmptyDirectories {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Roots
    )

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Directory -Recurse -Force | ForEach-Object {
            $hasChildren = Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $hasChildren) {
                [void]$result.Add($_.FullName)
            }
        }
    }

    return $result
}

function Convert-ToProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $rootWithSlash = $ProjectRoot.TrimEnd('\') + '\'
    if ($FullPath.StartsWith($rootWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($rootWithSlash.Length).Replace('\', '/')
    }

    return $FullPath.Replace('\', '/')
}

function New-PreflightBucket {
    return [ordered]@{
        ContractPlaceholders = New-Object System.Collections.Generic.List[string]
        GeneratedOutputs = New-Object System.Collections.Generic.List[string]
        PendingEmptyDirs = New-Object System.Collections.Generic.List[string]
        DisallowedFormalArtifacts = New-Object System.Collections.Generic.List[string]
    }
}

$projectRoot = Get-ProjectRoot
$projectSettingsPath = Join-Path $projectRoot "ProjectSettings/ProjectVersion.txt"
if (-not (Test-Path -LiteralPath $projectSettingsPath)) {
    throw "ProjectSettings/ProjectVersion.txt not found. Please run this script from the FantasyWord Unity repository."
}

$formalRoots = @(
    (Join-Path $projectRoot "Assets"),
    (Join-Path $projectRoot "docs"),
    (Join-Path $projectRoot "openspec"),
    (Join-Path $projectRoot ".codex"),
    (Join-Path $projectRoot "scripts")
)

$generatedRoots = @(
    (Join-Path $projectRoot ".codexbridge"),
    (Join-Path $projectRoot "AIBridgeCache"),
    (Join-Path $projectRoot "Library"),
    (Join-Path $projectRoot "Logs"),
    (Join-Path $projectRoot "Temp"),
    (Join-Path $projectRoot "obj")
)

$contractPlaceholderExactPaths = @(
    "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Scripts",
    "Assets/ArtRes/KrishnaPalacio",
    "Assets/Scripts/Presentation/EquipmentSystem/Tools",
    "Assets/Scripts/Presentation/EquipmentSystem/Shaders/Includes",
    "Assets/ThirdParty/MiniFantasyUV",
    "Assets/Plugins/YokiFrame/Core/Runtime/ResKit/Loader/Editor",
    "Assets/Plugins/YokiFrame/Tools/BuffKit/Runtime/Core/Core",
    "Assets/Plugins/YokiFrame/Tools/LocalizationKit/Runtime/Core/Core",
    "Assets/Plugins/YokiFrame/Tools/SceneKit/Tests",
    "openspec/specs",
    "openspec/changes",
    ".codex/skills/unity-production/agents",
    "Assets/ArtRes",
    "Assets/Minifantasy_NPCs_Assets",
    "Assets/Sprites",
    "Assets/Editor/GameCore/Playtest",
    "Assets/Editor/GameCore/Tests/Generated",
    "Assets/GameData/EquipmentSystem/Animator/GeneratedClips/SourceSprites/Dwarf",
    "Assets/GameData/EquipmentSystem/Animator/GeneratedClips/SourceSprites/Elf",
    "Assets/GameData/EquipmentSystem/Animator/GeneratedClips/SourceSprites/Goblin",
    "Assets/GameData/EquipmentSystem/Animator/GeneratedClips/SourceSprites/Orc",
    "Assets/GameData/GameCore/AbilitySamples/AbilityAssets",
    "Assets/GameData/GameCore/AbilitySamples/AbilityExecutions",
    "Assets/GameData/GameCore/AbilitySamples/AbilitySheets",
    "Assets/GameData/GameCore/AbilitySamples/GameplayEffects",
    "Assets/GameData/GameCore/AbilitySamples/GameplayExecutions",
    "Assets/Plugins/Sirenix/Demos",
    "Assets/Prefabs/Abilities/Dash",
    "Assets/Prefabs/Abilities/Passive",
    "Assets/Prefabs/Abilities/Projectile",
    "Assets/Prefabs/Abilities/SelfCast",
    "Assets/Prefabs/Abilities/Summoning",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Formal",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Immediate",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Active",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Execution",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Passive"
)

$disallowedFormalArtifactExactPaths = @(
    "Assets/Editor/com.IvanMurzak",
    "Assets/Resources/Unity-MCP-ConnectionConfig.json",
    "Assets/_Recovery",
    "Assets/_Recovery.meta"
)

$disallowedFormalArtifactPathPrefixes = @(
    "Assets/Editor/com.IvanMurzak/",
    "Assets/_Recovery/"
)

$projectEmptyDirs = Get-EmptyDirectories -Roots $formalRoots
$generatedEmptyDirs = if ($IncludeGeneratedRoots) { Get-EmptyDirectories -Roots $generatedRoots } else { @() }
$bucket = New-PreflightBucket

foreach ($relativePath in $disallowedFormalArtifactExactPaths) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        [void]$bucket.DisallowedFormalArtifacts.Add($relativePath)
    }
}

foreach ($relativePrefix in $disallowedFormalArtifactPathPrefixes) {
    $fullPrefix = Join-Path $projectRoot $relativePrefix
    if (-not (Test-Path -LiteralPath $fullPrefix)) {
        continue
    }

    Get-ChildItem -LiteralPath $fullPrefix -Recurse -Force | ForEach-Object {
        $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
        [void]$bucket.DisallowedFormalArtifacts.Add($relativePath)
    }
}

foreach ($fullPath in $projectEmptyDirs) {
    $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $fullPath
    if ($contractPlaceholderExactPaths -contains $relativePath) {
        [void]$bucket.ContractPlaceholders.Add($relativePath)
    }
    else {
        [void]$bucket.PendingEmptyDirs.Add($relativePath)
    }
}

foreach ($fullPath in $generatedEmptyDirs) {
    $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $fullPath
    [void]$bucket.GeneratedOutputs.Add($relativePath)
}

$generatedRootSummaries = @(
    $bucket.GeneratedOutputs |
        Group-Object { ($_.Split('/'))[0] } |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                Root = $_.Name
                Count = $_.Count
            }
        }
)

$report = [ordered]@{
    ProjectRoot = $projectRoot
    FormalRootCount = $formalRoots.Count
    IncludeGeneratedRoots = [bool]$IncludeGeneratedRoots
    ContractPlaceholderCount = $bucket.ContractPlaceholders.Count
    GeneratedOutputCount = $bucket.GeneratedOutputs.Count
    DisallowedFormalArtifactCount = $bucket.DisallowedFormalArtifacts.Count
    PendingEmptyDirCount = $bucket.PendingEmptyDirs.Count
    ContractPlaceholders = @($bucket.ContractPlaceholders)
    GeneratedRootSummaries = $generatedRootSummaries
    GeneratedOutputs = @($bucket.GeneratedOutputs)
    DisallowedFormalArtifacts = @($bucket.DisallowedFormalArtifacts)
    PendingEmptyDirs = @($bucket.PendingEmptyDirs)
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "FantasyWord workspace preflight"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host "Generated roots are excluded by default: .codexbridge, AIBridgeCache, Library, Logs, Temp, obj"
Write-Host "Use -IncludeGeneratedRoots only when you need a generated-output summary; generated empties are not pending cleanup by default."
Write-Host ("Contract placeholders: {0}" -f $report.ContractPlaceholderCount)
foreach ($path in $report.ContractPlaceholders) {
    Write-Host ("  [contract] {0}" -f $path)
}

Write-Host ("Disallowed formal artifacts: {0}" -f $report.DisallowedFormalArtifactCount)
foreach ($path in $report.DisallowedFormalArtifacts) {
    Write-Host ("  [disallowed] {0}" -f $path)
}

if ($IncludeGeneratedRoots) {
    Write-Host ("Generated outputs: {0}" -f $report.GeneratedOutputCount)
    foreach ($summary in $report.GeneratedRootSummaries) {
        Write-Host ("  [generated] {0}: {1}" -f $summary.Root, $summary.Count)
    }
}

Write-Host ("Pending empty dirs: {0}" -f $report.PendingEmptyDirCount)
foreach ($path in $report.PendingEmptyDirs) {
    Write-Host ("  [pending] {0}" -f $path)
}

if ($report.PendingEmptyDirCount -gt 0 -or $report.DisallowedFormalArtifactCount -gt 0) {
    exit 2
}

exit 0
