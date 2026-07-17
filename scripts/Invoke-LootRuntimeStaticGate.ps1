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
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$pickableItemPath = Join-Path $runtimeRoot "Loot/PickableItem.cs"
$pickableItemText = Read-Text $pickableItemPath

$pickableDelayedDisableUsesPlayerLoop =
    $pickableItemText -match "using\s+Cysharp\.Threading\.Tasks\s*;" -and
    $pickableItemText -match "DisableSelfAfterDelayAsync\s*\(" -and
    $pickableItemText -match "DisableTargetAfterDelayAsync\s*\(" -and
    $pickableItemText -match "destroyCancellationToken" -and
    $pickableItemText -match "\.Forget\s*\(\s*LogAsyncException\s*\)" -and
    $pickableItemText -notmatch "StartCoroutine\s*\(\s*Disable(Self|Target)AfterDelay" -and
    $pickableItemText -notmatch "IEnumerator\s+Disable(Self|Target)AfterDelay" -and
    $pickableItemText -notmatch "new\s+WaitForSeconds\s*\("
if (-not $pickableDelayedDisableUsesPlayerLoop) {
    [void]$violations.Add("PickableItem delayed disable flow must use UniTask player-loop delays, not coroutines owned by an object that may disable itself.")
}

$pickableTargetDelayCapturesTarget =
    $pickableItemText -match "(?s)DisableTargetAfterDelayAsync\s*\(\s*m_targetObjectDisableDelay\s*,\s*m_targetObjectToDisable\s*,\s*destroyCancellationToken\s*\)" -and
    $pickableItemText -match "GameObject\s+targetObject" -and
    $pickableItemText -match "targetObject\s*==\s*null" -and
    $pickableItemText -match "targetObject\.SetActive\s*\(\s*false\s*\)"
if (-not $pickableTargetDelayCapturesTarget) {
    [void]$violations.Add("PickableItem delayed target disable must capture the picked target object and null-check it after the delay.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    PickableDelayedDisableUsesPlayerLoop = $pickableDelayedDisableUsesPlayerLoop
    PickableTargetDelayCapturesTarget = $pickableTargetDelayCapturesTarget
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    if ($result.Passed) {
        Write-Host "Loot runtime static gate passed."
    }
    else {
        Write-Host "Loot runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
