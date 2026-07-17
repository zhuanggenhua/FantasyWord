param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Read-Text {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path
    }

    return ""
}

$violations = [System.Collections.Generic.List[string]]::new()
$runtimePath = Join-Path $ProjectRoot "Assets/Scripts/Presentation/WaterReflection/Runtime/WaterReflectionCaster2D.cs"
$installerPath = Join-Path $ProjectRoot "Assets/Scripts/Presentation/WaterReflection/Editor/ClickMoveTestWaterReflectionInstaller.cs"
$runtimeText = Read-Text $runtimePath
$installerText = Read-Text $installerPath

$casterRequiresExplicitSources =
    $runtimeText -match "ValidateSourceConfiguration\s*\(" -and
    $runtimeText -match "Debug\.LogError\s*\(" -and
    $runtimeText -match "enabled\s*=\s*false\s*;" -and
    $runtimeText -match "AppendActivePresentationRenderers\s*\(" -and
    $runtimeText -notmatch "GetComponentInChildren\s*<\s*EquipmentRenderer\s*>" -and
    $runtimeText -notmatch "GetComponentsInChildren\s*<\s*SpriteRenderer\s*>" -and
    $runtimeText -notmatch "m_collectChildRenderersOnAwake"
if (-not $casterRequiresExplicitSources) {
    [void]$violations.Add("WaterReflectionCaster2D runtime must use explicit EquipmentRenderer/SpriteRenderer sources and fail closed when no source is configured.")
}

$installerDoesNotWriteRemovedSourceFallback =
    $installerText -notmatch "m_collectChildRenderersOnAwake" -and
    $installerText -match "SetObject\s*\(\s*serialized\s*,\s*`"m_equipmentRenderer`"" -and
    $installerText -match "m_sourceRenderers"
if (-not $installerDoesNotWriteRemovedSourceFallback) {
    [void]$violations.Add("ClickMoveTestWaterReflectionInstaller must not write the removed child-renderer fallback field; it must explicitly bind equipment or sprite sources.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    CasterRequiresExplicitSources = $casterRequiresExplicitSources
    InstallerDoesNotWriteRemovedSourceFallback = $installerDoesNotWriteRemovedSourceFallback
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    if ($result.Passed) {
        Write-Host "Water reflection runtime static gate passed."
    }
    else {
        Write-Host "Water reflection runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
