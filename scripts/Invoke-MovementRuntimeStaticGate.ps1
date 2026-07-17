param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$violations = [System.Collections.Generic.List[string]]::new()
$movementZonePath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Miscellaneous/MovementZone.cs"
$movementZoneText = if (Test-Path -LiteralPath $movementZonePath) {
    Get-Content -Raw -LiteralPath $movementZonePath
}
else {
    ""
}

if ([string]::IsNullOrWhiteSpace($movementZoneText)) {
    [void]$violations.Add("MovementZone runtime file is missing or empty.")
}

$movementZoneGuardsPlayerSystem =
    $movementZoneText.Contains("TryGetCurrentControlledCharacter") -and
    $movementZoneText.Contains("return false;") -and
    $movementZoneText.Contains("movable.SetContextSpeedMultiplier") -and
    $movementZoneText.Contains("movable != currentControlledCharacter")
if (-not $movementZoneGuardsPlayerSystem) {
    [void]$violations.Add("MovementZone must guard PlayerSystem readiness before applying the current-player-only filter.")
}

$movementZoneClearsAppliedMovablesOnDisable =
    $movementZoneText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?ClearAppliedMovables\s*\(\s*\)" -and
    $movementZoneText.Contains("ResetContextSpeedMultiplier") -and
    $movementZoneText.Contains("m_collidingMovables.Clear()")
if (-not $movementZoneClearsAppliedMovablesOnDisable) {
    [void]$violations.Add("MovementZone must reset applied speed multipliers when the zone is disabled.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    MovementZoneGuardsPlayerSystem = $movementZoneGuardsPlayerSystem
    MovementZoneClearsAppliedMovablesOnDisable = $movementZoneClearsAppliedMovablesOnDisable
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Movement runtime static gate passed."
    }
    else {
        Write-Host "Movement runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
