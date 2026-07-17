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
$conditionBasePath = Join-Path $runtimeRoot "Conditional/Conditions/ABaseCondition.cs"
$areConditionsPath = Join-Path $runtimeRoot "Conditional/Conditions/AreConditionsMet.cs"
$stateMachinePath = Join-Path $runtimeRoot "Conditional/StateMachines/AConditionalStateMachine.cs"
$conditionalInteractionPath = Join-Path $runtimeRoot "Interactions/ConditionalInteraction.cs"
$isAbilityUnlockedPath = Join-Path $runtimeRoot "Conditional/Conditions/IsAbilityUnlocked.cs"
$isItemInInventoryPath = Join-Path $runtimeRoot "Conditional/Conditions/IsItemInInventory.cs"

$conditionBaseText = Read-Text $conditionBasePath
$areConditionsText = Read-Text $areConditionsPath
$stateMachineText = Read-Text $stateMachinePath
$conditionalInteractionText = Read-Text $conditionalInteractionPath
$isAbilityUnlockedText = Read-Text $isAbilityUnlockedPath
$isItemInInventoryText = Read-Text $isItemInInventoryPath

$conditionUsesAssertStop = $conditionBaseText -match "Debug\.Assert" -or $conditionBaseText -match "using\s+System\.Diagnostics"
if ($conditionUsesAssertStop) {
    [void]$violations.Add("ABaseCondition.StopListening must be idempotent and must not rely on Debug.Assert for lifecycle correctness.")
}

$conditionNotifyNullSafe = $conditionBaseText -match "m_stateChangedCallback\?\.Invoke\s*\("
if (-not $conditionNotifyNullSafe) {
    [void]$violations.Add("ABaseCondition.NotifyStateChange must be null-safe after StopListening.")
}

$conditionStartStopsExisting = $conditionBaseText -match "public\s+virtual\s+void\s+StartListening[\s\S]*?StopListening\s*\(\s*\)"
if (-not $conditionStartStopsExisting) {
    [void]$violations.Add("ABaseCondition.StartListening must stop any previous listener before replacing the callback.")
}

$conditionHasListeningFlag = $conditionBaseText -match "bool\s+m_isListening" -and $conditionBaseText -match "if\s*\(\s*!m_isListening\s*\)"
if (-not $conditionHasListeningFlag) {
    [void]$violations.Add("ABaseCondition must track listening state so StopListening can be called safely more than once.")
}

$areConditionsNullSafe = $areConditionsText -match "Array\.Empty<ICondition>\s*\(\s*\)" -and $areConditionsText -match "GetConditions\s*\("
if (-not $areConditionsNullSafe) {
    [void]$violations.Add("AreConditionMet must treat a null condition array as empty instead of throwing during Evaluate or listening.")
}

$areConditionsStopsChildrenBeforeBase =
    $areConditionsText -match "public\s+override\s+void\s+StopListening\s*\(\s*\)[\s\S]*?foreach\s*\(ICondition\s+condition\s+in\s+GetConditions\s*\(\s*\)\)[\s\S]*?base\.StopListening\s*\(\s*\)"
if (-not $areConditionsStopsChildrenBeforeBase) {
    [void]$violations.Add("AreConditionMet.StopListening must stop child conditions before clearing its own callback.")
}

$stateMachineUsesStartLifecycle = $stateMachineText -match "private\s+void\s+Start\s*\("
if ($stateMachineUsesStartLifecycle) {
    [void]$violations.Add("AConditionalStateMachine must not bind condition listening only in Start; it must follow enable/disable lifecycle.")
}

$stateMachineUsesEnableDisable =
    $stateMachineText -match "private\s+void\s+OnEnable\s*\(" -and
    $stateMachineText -match "private\s+void\s+OnDisable\s*\(" -and
    $stateMachineText -match "StartConditionListening\s*\(" -and
    $stateMachineText -match "StopConditionListening\s*\("
if (-not $stateMachineUsesEnableDisable) {
    [void]$violations.Add("AConditionalStateMachine must start condition listening on enable and stop it on disable.")
}

$stateMachineListeningGuard = $stateMachineText -match "bool\s+m_isListening" -and $stateMachineText -match "!m_isListening"
if (-not $stateMachineListeningGuard) {
    [void]$violations.Add("AConditionalStateMachine must guard condition listener start/stop with a listening flag.")
}

$conditionalInteractionNullSafe =
    $conditionalInteractionText -match "if\s*\(\s*m_interaction\s*==\s*null\s*\)" -and
    $conditionalInteractionText -match "Debug\.LogError" -and
    $conditionalInteractionText -match "Task\.FromResult\s*\(\s*false\s*\)"
if (-not $conditionalInteractionNullSafe) {
    [void]$violations.Add("ConditionalInteraction must report a missing target interaction and return false instead of throwing a NullReferenceException.")
}

$abilityConditionGuardsPlayerSystem =
    $isAbilityUnlockedText.Contains("TryGetPlayerSystem") -and
    $isAbilityUnlockedText.Contains("TryGetCurrentControlledCharacter") -and
    $isAbilityUnlockedText.Contains("return false;") -and
    $isAbilityUnlockedText.Contains("HasFormalGasAbility")
if (-not $abilityConditionGuardsPlayerSystem) {
    [void]$violations.Add("IsAbilityUnlocked must guard PlayerSystem readiness before evaluating the current controlled character.")
}

$inventoryConditionGuardsSystems =
    $isItemInInventoryText.Contains("TryGetInventorySystem") -and
    $isItemInInventoryText.Contains("TryGetInventoryOwner") -and
    $isItemInInventoryText.Contains("TryGetPlayerSystem") -and
    $isItemInInventoryText.Contains("case EInventoryQueryScope.CurrentControlledCharacter:") -and
    $isItemInInventoryText.Contains("return false;") -and
    $isItemInInventoryText.Contains("owner = inventorySystem.GetOwner(currentControlledCharacter)") -and
    $isItemInInventoryText.Contains("owner = InventoryOwnerHandle.DefaultParty")
if (-not $inventoryConditionGuardsSystems) {
    [void]$violations.Add("IsItemInInventory must guard InventorySystem/PlayerSystem readiness and must not turn a current-character query into a default party query.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    ConditionUsesAssertStop = $conditionUsesAssertStop
    ConditionNotifyNullSafe = $conditionNotifyNullSafe
    ConditionStartStopsExisting = $conditionStartStopsExisting
    ConditionHasListeningFlag = $conditionHasListeningFlag
    AreConditionsNullSafe = $areConditionsNullSafe
    AreConditionsStopsChildrenBeforeBase = $areConditionsStopsChildrenBeforeBase
    StateMachineUsesStartLifecycle = $stateMachineUsesStartLifecycle
    StateMachineUsesEnableDisable = $stateMachineUsesEnableDisable
    StateMachineListeningGuard = $stateMachineListeningGuard
    ConditionalInteractionNullSafe = $conditionalInteractionNullSafe
    AbilityConditionGuardsPlayerSystem = $abilityConditionGuardsPlayerSystem
    InventoryConditionGuardsSystems = $inventoryConditionGuardsSystems
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Conditional runtime static gate passed."
    }
    else {
        Write-Host "Conditional runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
