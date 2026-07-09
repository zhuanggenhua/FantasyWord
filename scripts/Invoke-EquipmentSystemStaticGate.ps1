[CmdletBinding()]
param(
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

function Get-FileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw
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

$projectRoot = Get-ProjectRoot
$equipmentDataRoot = Join-Path $projectRoot "Assets/GameData/EquipmentSystem"
$demoScenePath = Join-Path $projectRoot "Assets/Scenes/EquipmentSystemDemo.unity"
$legacyRuntimeRoot = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/Legacy"
$legacyRuntimeFiles = @()
$legacyRuntimeDirectoryExists = Test-Path -LiteralPath $legacyRuntimeRoot

if ($legacyRuntimeDirectoryExists) {
    $legacyRuntimeFiles = Get-ChildItem -LiteralPath $legacyRuntimeRoot -Recurse -File | ForEach-Object {
        Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
    }
}

if (-not (Test-Path -LiteralPath $equipmentDataRoot)) {
    throw "Assets/GameData/EquipmentSystem not found. Please run this script from the FantasyWord Unity repository."
}

$legacyTypePattern = '(Assembly-CSharp::EquipmentSystem\.Data\.|EquipmentSystem::EquipmentSystem\.|FantasyWord\.Presentation\.EquipmentSystem::EquipmentSystem\.)'
$legacyIdentifierFiles = New-Object System.Collections.Generic.List[string]
$businessAssemblyIdentifierFiles = New-Object System.Collections.Generic.List[string]

Get-ChildItem -LiteralPath $equipmentDataRoot -Recurse -File -Filter *.asset | ForEach-Object {
    $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
    $content = Get-FileContent -Path $_.FullName

    if ($content -match $legacyTypePattern) {
        [void]$legacyIdentifierFiles.Add($relativePath)
    }

    if ($content -match 'm_EditorClassIdentifier:\s*(EquipmentSystem|FantasyWord\.Presentation\.EquipmentSystem)::') {
        [void]$businessAssemblyIdentifierFiles.Add($relativePath)
    }
}

$demoSceneContent = Get-FileContent -Path $demoScenePath
$demoSceneMissingPatterns = New-Object System.Collections.Generic.List[string]
foreach ($pattern in @(
    "m_Name: EquipmentSystemDemoCharacter",
    "m_EditorClassIdentifier: ::AnimatorEquipmentSync",
    "m_EditorClassIdentifier: ::EquipmentRenderer",
    "m_EditorClassIdentifier: ::AnimationController",
    "m_Controller:"
)) {
    if (-not $demoSceneContent.Contains($pattern)) {
        [void]$demoSceneMissingPatterns.Add($pattern)
    }
}

$report = [ordered]@{
    ProjectRoot = $projectRoot
    EquipmentDataRoot = $equipmentDataRoot
    DemoScenePath = $demoScenePath
    LegacyRuntimeDirectoryExists = $legacyRuntimeDirectoryExists
    LegacyRuntimeFileCount = @($legacyRuntimeFiles).Count
    LegacyIdentifierFileCount = $legacyIdentifierFiles.Count
    BusinessAssemblyIdentifierFileCount = $businessAssemblyIdentifierFiles.Count
    DemoSceneMissingPatternCount = $demoSceneMissingPatterns.Count
    LegacyRuntimeFiles = @($legacyRuntimeFiles)
    LegacyIdentifierFiles = @($legacyIdentifierFiles)
    BusinessAssemblyIdentifierFiles = @($businessAssemblyIdentifierFiles)
    DemoSceneMissingPatterns = @($demoSceneMissingPatterns)
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "FantasyWord equipment-system static gate"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host ("Equipment data root: {0}" -f $report.EquipmentDataRoot)
Write-Host ("Demo scene: {0}" -f $report.DemoScenePath)
Write-Host ("Legacy runtime directory exists: {0}" -f $report.LegacyRuntimeDirectoryExists)
Write-Host ("Legacy runtime files: {0}" -f $report.LegacyRuntimeFileCount)
foreach ($path in $report.LegacyRuntimeFiles) {
    Write-Host ("  [legacy-runtime] {0}" -f $path)
}

Write-Host ("Legacy class identifier files: {0}" -f $report.LegacyIdentifierFileCount)
foreach ($path in $report.LegacyIdentifierFiles) {
    Write-Host ("  [legacy-id] {0}" -f $path)
}

Write-Host ("Business assembly class identifier files: {0}" -f $report.BusinessAssemblyIdentifierFileCount)
foreach ($path in $report.BusinessAssemblyIdentifierFiles) {
    Write-Host ("  [business-assembly-id] {0}" -f $path)
}

Write-Host ("Demo scene missing patterns: {0}" -f $report.DemoSceneMissingPatternCount)
foreach ($pattern in $report.DemoSceneMissingPatterns) {
    Write-Host ("  [demo-missing] {0}" -f $pattern)
}

if ($report.LegacyRuntimeDirectoryExists -or
    $report.LegacyRuntimeFileCount -gt 0 -or
    $report.LegacyIdentifierFileCount -gt 0 -or
    $report.BusinessAssemblyIdentifierFileCount -gt 0 -or
    $report.DemoSceneMissingPatternCount -gt 0) {
    exit 2
}

exit 0
