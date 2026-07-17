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
$characterActorQuestPath = Join-Path $runtimeRoot "Entities/Characters/CharacterActor.Quest.cs"
$text = Read-Text $characterActorQuestPath

$hasStartLifecycle = $text -match "protected\s+(virtual|override)?\s*void\s+Start\s*\("
if ($hasStartLifecycle) {
    [void]$violations.Add("CharacterActor quest floating icon events must not be bound in Start; use OnEnable/OnDisable.")
}

$hasEnableDisable =
    $text -match "protected\s+override\s+void\s+OnEnable\s*\(\s*\)[\s\S]*?StartQuestStatusListening\s*\(\s*\)" -and
    $text -match "protected\s+override\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?StopQuestStatusListening\s*\(\s*\)"
if (-not $hasEnableDisable) {
    [void]$violations.Add("CharacterActor quest floating icon events must be registered on enable and unregistered on disable.")
}

$hasListeningGuard =
    $text -match "bool\s+m_questStatusListening" -and
    $text -match "if\s*\(\s*m_questStatusListening\s*\)" -and
    $text -match "if\s*\(\s*!m_questStatusListening\s*\)"
if (-not $hasListeningGuard) {
    [void]$violations.Add("CharacterActor quest floating icon listener lifecycle must be idempotent.")
}

$destroyStopsBeforeBase =
    $text -match "protected\s+override\s+void\s+OnDestroy\s*\(\s*\)[\s\S]*?StopQuestStatusListening\s*\(\s*\)\s*;[\s\S]*?base\.OnDestroy\s*\(\s*\)"
if (-not $destroyStopsBeforeBase) {
    [void]$violations.Add("CharacterActor.OnDestroy must stop quest status listening before base cleanup as a lifecycle fallback.")
}

$updateFloatingIconGuarded =
    $text -match "GameManager\.Exists\s*\(\s*\)" -and
    $text -match "GameManager\.HasSystem<JournalSystem>\s*\(\s*\)"
if (-not $updateFloatingIconGuarded) {
    [void]$violations.Add("CharacterActor.UpdateFloatingIcon must guard against GameManager/JournalSystem not being ready during OnEnable.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    HasStartLifecycle = $hasStartLifecycle
    HasEnableDisable = $hasEnableDisable
    HasListeningGuard = $hasListeningGuard
    DestroyStopsBeforeBase = $destroyStopsBeforeBase
    UpdateFloatingIconGuarded = $updateFloatingIconGuarded
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "CharacterActor runtime static gate passed."
    }
    else {
        Write-Host "CharacterActor runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
