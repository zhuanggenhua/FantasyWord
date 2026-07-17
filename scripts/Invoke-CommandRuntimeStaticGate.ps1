param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function ConvertTo-RepoPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
    if ($fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($rootPath.Length).TrimStart('\', '/').Replace('\', '/')
    }

    return $fullPath.Replace('\', '/')
}

function Read-Text {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path
    }

    return ""
}

$violations = [System.Collections.Generic.List[string]]::new()
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$commandContractPath = Join-Path $runtimeRoot "Commands/ICommand.cs"
$questPath = Join-Path $runtimeRoot "Database/Quest/Quest.cs"
$journalPath = Join-Path $runtimeRoot "Game/Systems/JournalSystem.cs"
$questInteractionPath = Join-Path $runtimeRoot "Interactions/QuestInteraction.cs"
$dialogueNodePath = Join-Path $runtimeRoot "Dialogue/DialogueNode.cs"
$commandTriggerPath = Join-Path $runtimeRoot "Miscellaneous/CommandTrigger.cs"
$persistablePath = Join-Path $runtimeRoot "Persistence/Persistable.cs"
$characterSheetPath = Join-Path $runtimeRoot "Database/Characters/CharacterSheet.cs"
$gameConfigPersistencePath = Join-Path $runtimeRoot "Game/GameConfig.Persistence.cs"
$entityPath = Join-Path $runtimeRoot "Entities/Entity.cs"
$waitCommandPath = Join-Path $runtimeRoot "Commands/Wait.cs"
$gameCommandContextPath = Join-Path $runtimeRoot "Commands/GameCommandContext.cs"
$movePlayerPath = Join-Path $runtimeRoot "Commands/MovePlayer.cs"
$addExperiencePath = Join-Path $runtimeRoot "Commands/AddExperience.cs"
$addOrRemoveAbilityPath = Join-Path $runtimeRoot "Commands/AddOrRemoveAbility.cs"
$addOrRemoveItemPath = Join-Path $runtimeRoot "Commands/AddOrRemoveItem.cs"
$addOrRemoveManaPath = Join-Path $runtimeRoot "Commands/AddOrRemoveMana.cs"
$healOrDamagePlayerPath = Join-Path $runtimeRoot "Commands/HealOrDamagePlayer.cs"
$revivePlayerPath = Join-Path $runtimeRoot "Commands/RevivePlayer.cs"
$executeCommandListPath = Join-Path $runtimeRoot "Commands/ExecuteCommandList.cs"
$destroyEntityPath = Join-Path $runtimeRoot "Commands/DestroyEntity.cs"
$toggleControllerPath = Join-Path $runtimeRoot "Commands/ToggleController.cs"
$moveCharacterBasePath = Join-Path $runtimeRoot "Commands/MoveCharacterBase.cs"
$moveCameraPath = Join-Path $runtimeRoot "Commands/MoveCamera.cs"
$executeCommandHandlerPath = Join-Path $runtimeRoot "Commands/ExecuteCommandHandler.cs"
$commandHandlerPath = Join-Path $runtimeRoot "Database/Utils/CommandHandler.cs"
$playDialogueSequencePath = Join-Path $runtimeRoot "Commands/PlayDialogueSequence.cs"

$commandContractText = Read-Text $commandContractPath
$questText = Read-Text $questPath
$journalText = Read-Text $journalPath
$questInteractionText = Read-Text $questInteractionPath
$dialogueNodeText = Read-Text $dialogueNodePath
$commandTriggerText = Read-Text $commandTriggerPath
$persistableText = Read-Text $persistablePath
$characterSheetText = Read-Text $characterSheetPath
$gameConfigPersistenceText = Read-Text $gameConfigPersistencePath
$entityText = Read-Text $entityPath
$waitCommandText = Read-Text $waitCommandPath
$gameCommandContextText = Read-Text $gameCommandContextPath
$movePlayerText = Read-Text $movePlayerPath
$addExperienceText = Read-Text $addExperiencePath
$addOrRemoveAbilityText = Read-Text $addOrRemoveAbilityPath
$addOrRemoveItemText = Read-Text $addOrRemoveItemPath
$addOrRemoveManaText = Read-Text $addOrRemoveManaPath
$healOrDamagePlayerText = Read-Text $healOrDamagePlayerPath
$revivePlayerText = Read-Text $revivePlayerPath
$executeCommandListText = Read-Text $executeCommandListPath
$destroyEntityText = Read-Text $destroyEntityPath
$toggleControllerText = Read-Text $toggleControllerPath
$moveCharacterBaseText = Read-Text $moveCharacterBasePath
$moveCameraText = Read-Text $moveCameraPath
$executeCommandHandlerText = Read-Text $executeCommandHandlerPath
$commandHandlerText = Read-Text $commandHandlerPath
$playDialogueSequenceText = Read-Text $playDialogueSequencePath

$hasFireAndReport =
    $commandContractText -match "ExecuteFireAndReport\s*\(" -and
    $commandContractText -match "ExecuteFireAndReportAsync\s*\(" -and
    $commandContractText -match "Debug\.LogException" -and
    $commandContractText -match "catch\s*\(\s*Exception\s+exception\s*\)"
if (-not $hasFireAndReport) {
    [void]$violations.Add("ICommand must expose ExecuteFireAndReport so event-style command callers do not drop Task exceptions silently.")
}

$questCompletionReturnsTask =
    $questText -match "public\s+Task\s+ExecuteOnQuestCompletion\s*\(\s*\)" -and
    $questText -match "public\s+Task\s+ExecuteOnQuestCompletion\s*\(\s*GameCommandContext\s+context\s*\)"
if (-not $questCompletionReturnsTask) {
    [void]$violations.Add("Quest.ExecuteOnQuestCompletion must return Task; quest reward commands are part of the completion flow.")
}

$journalCompletionAwaitsTask =
    $journalText -match "public\s+async\s+Task\s+CompleteQuest\s*\(\s*Quest\s+quest\s*,\s*GameCommandContext\s+context\s*\)" -and
    $journalText -match "await\s+quest\.ExecuteOnQuestCompletion\s*\(\s*context\s*\)"
if (-not $journalCompletionAwaitsTask) {
    [void]$violations.Add("JournalSystem.CompleteQuest must be async and await Quest.ExecuteOnQuestCompletion.")
}

$questInteractionAwaitsCompletion =
    $questInteractionText -match "await\s+character\.Say\s*\(\s*quest\.questCompletedDialogue,\s*source\s*\)" -and
    $questInteractionText -match "await\s+GameManager\.JournalSystem\.CompleteQuest\s*\("
if (-not $questInteractionAwaitsCompletion) {
    [void]$violations.Add("QuestInteraction must complete quest after the completion dialogue and await the JournalSystem completion task.")
}

if ($questInteractionText -match "character\.Say\s*\(\s*quest\.questCompletedDialogue\s*,\s*source\s*,") {
    [void]$violations.Add("QuestInteraction must not call CompleteQuest from a synchronous dialogue-ended callback; that drops the completion Task.")
}

$eventEntrancesUseFireAndReport = @{
    "DialogueNode start command" = $dialogueNodeText -match "m_toExecuteOnStart\.ExecuteFireAndReport\s*\("
    "DialogueNode completion command" = $dialogueNodeText -match "m_toExecuteOnCompletion\.ExecuteFireAndReport\s*\("
    "CommandTrigger command" = $commandTriggerText -match "m_toExecute\.ExecuteFireAndReport\s*\("
    "Persistable death command" = $persistableText -match "m_executeOnDeath\.ExecuteFireAndReport\s*\("
    "CharacterSheet death command" = $characterSheetText -match "m_executeOnDeath\.ExecuteFireAndReport\s*\("
    "GameConfig player death command" = $gameConfigPersistenceText -match "m_toExecuteOnPlayerDeath\.ExecuteFireAndReport\s*\("
}

foreach ($entry in $eventEntrancesUseFireAndReport.GetEnumerator()) {
    if (-not $entry.Value) {
        [void]$violations.Add(("{0} must use ExecuteFireAndReport instead of a bare command Execute call." -f $entry.Key))
    }
}

$entityInteractionReports =
    $entityText -match "ExecuteInteractionAndReport\s*\(" -and
    $entityText -match "catch\s*\(\s*Exception\s+exception\s*\)" -and
    $entityText -match "Debug\.LogException"
if (-not $entityInteractionReports) {
    [void]$violations.Add("Entity.OnInteract must route fire-and-forget interaction execution through an exception-reporting helper.")
}

$rawCommandTaskDrops = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $runtimeRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File -Filter "*.cs") {
        $repoPath = ConvertTo-RepoPath $file.FullName
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            $trimmedLine = $line.Trim()
            if ($trimmedLine -notmatch "\.Execute\s*\(\s*context\s*\)\s*;") {
                continue
            }

            if ($trimmedLine -match "^return\b" -or
                $trimmedLine -match "^await\b" -or
                $trimmedLine -match "=" -or
                $trimmedLine -match "ExecuteFireAndReport") {
                continue
            }

            [void]$rawCommandTaskDrops.Add(("{0}:{1}: bare command Execute(context) drops the returned Task; await/return it or use ExecuteFireAndReport: {2}" -f $repoPath, $lineNumber, $trimmedLine))
        }
    }
}

foreach ($violation in $rawCommandTaskDrops) {
    [void]$violations.Add($violation)
}

if ($entityText -match "_\s*=\s*ExecuteInteraction\s*\(") {
    [void]$violations.Add("Entity.OnInteract must not directly discard ExecuteInteraction Task; use ExecuteInteractionAndReport.")
}

$waitCommandUsesPlayerLoopDelay =
    $waitCommandText -match "UniTask\.WaitForSeconds\s*\(" -and
    $waitCommandText -notmatch "GameManager\.Instance" -and
    $waitCommandText -notmatch "StartCoroutine\s*\(" -and
    $waitCommandText -notmatch "WaitCoroutine\s*\(" -and
    $waitCommandText -notmatch "TaskCompletionSource"
if (-not $waitCommandUsesPlayerLoopDelay) {
    [void]$violations.Add("Wait command must use a Unity player-loop delay without GameManager coroutine ownership.")
}

$commandTriggerFrameDelayUsesPlayerLoop =
    $commandTriggerText -match "using\s+Cysharp\.Threading\.Tasks\s*;" -and
    $commandTriggerText -match "ExecuteAfterFrameDelayAsync\s*\(" -and
    $commandTriggerText -match "UniTask\.Yield\s*\(\s*PlayerLoopTiming\.Update\s*,\s*cancellationToken\s*\)" -and
    $commandTriggerText -match "destroyCancellationToken" -and
    $commandTriggerText -match "\.Forget\s*\(\s*LogAsyncException\s*\)" -and
    $commandTriggerText -notmatch "StartCoroutine\s*\(\s*ExecuteAfterFrameDelay" -and
    $commandTriggerText -notmatch "IEnumerator\s+ExecuteAfterFrameDelay" -and
    $commandTriggerText -notmatch "yield\s+return\s+null\s*;"
if (-not $commandTriggerFrameDelayUsesPlayerLoop) {
    [void]$violations.Add("CommandTrigger frame delay must use a Unity player-loop delay without a coroutine owned by the trigger component.")
}

$commandContextKeepsNonThrowingFallback =
    $gameCommandContextText.Contains("TryGetPlayerSystem") -and
    $gameCommandContextText.Contains("public CharacterBase ResolveActorOrCurrentControlledCharacter()") -and
    $gameCommandContextText.Contains("return TryGetPlayerSystem(out PlayerSystem playerSystem)")
if (-not $commandContextKeepsNonThrowingFallback) {
    [void]$violations.Add("GameCommandContext must keep a non-throwing current-controlled actor fallback for preview/menu/query contexts.")
}

$commandContextHasRequiredTargetResolver =
    $gameCommandContextText.Contains("ResolveRequiredActorOrCurrentControlledCharacter") -and
    $gameCommandContextText.Contains("GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance()") -and
    $gameCommandContextText.Contains("throw new InvalidOperationException")
if (-not $commandContextHasRequiredTargetResolver) {
    [void]$violations.Add("GameCommandContext must expose a required actor resolver so player-result commands cannot silently swallow missing targets.")
}

$movePlayerMatchesReferencePlayerShortcut =
    $movePlayerText -match "GameManager\.PlayerSystem\.GetPrimaryPlayerCharacter\s*\("
if (-not $movePlayerMatchesReferencePlayerShortcut) {
    [void]$violations.Add("MovePlayer must keep the 2DRPGEngine same-responsibility flow: player movement resolves through the formal player system/player shortcut, not an empty-target readiness fallback.")
}

$addExperienceUsesCommandContextTarget =
    $addExperienceText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddExperience))") -and
    $addExperienceText.Contains("target.AddExperience(m_experience);") -and
    -not $addExperienceText.Contains("target?.AddExperience") -and
    -not ($addExperienceText -match "GameManager\.PlayerSystem")
if (-not $addExperienceUsesCommandContextTarget) {
    [void]$violations.Add("AddExperience must resolve a required command target through GameCommandContext and must not silently skip missing targets.")
}

$playerResultCommandsRequireTargets =
    $addOrRemoveAbilityText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveAbility))") -and
    $addOrRemoveItemText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveItem))") -and
    $addOrRemoveManaText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveMana))") -and
    $healOrDamagePlayerText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(HealOrDamagePlayer))") -and
    $revivePlayerText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(RevivePlayer))") -and
    -not $revivePlayerText.Contains("target?.Revive")
if (-not $playerResultCommandsRequireTargets) {
    [void]$violations.Add("Player-result commands must use the required command target resolver and must not treat missing targets as successful no-ops.")
}

$addOrRemoveAbilityRejectsInvalidCode =
    $addOrRemoveAbilityText.Contains("EnsureValidFormalGasAbilityCode()") -and
    $addOrRemoveAbilityText.Contains("if (m_formalGasAbilityCode <= 0)") -and
    $addOrRemoveAbilityText.Contains("throw new InvalidOperationException") -and
    -not $addOrRemoveAbilityText.Contains("if (formalGasAbilityCode > 0)") -and
    -not [regex]::IsMatch(
        $addOrRemoveAbilityText,
        "case\s+EAction\.Add:[\s\S]*?if\s*\(\s*formalGasAbilityCode\s*>\s*0\s*\)[\s\S]*?case\s+EAction\.Remove:",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $addOrRemoveAbilityRejectsInvalidCode) {
    [void]$violations.Add("AddOrRemoveAbility must reject an invalid Formal GAS ability code instead of treating the reward command as a successful no-op.")
}

$addOrRemoveItemRejectsMissingRemoval =
    $addOrRemoveItemText.Contains("if (!GameManager.InventorySystem.RemoveFromBag(ownerHandle, m_item, m_quantity, EItemTransferType.Command))") -and
    $addOrRemoveItemText.Contains("throw new InvalidOperationException")
if (-not $addOrRemoveItemRejectsMissingRemoval) {
    [void]$violations.Add("AddOrRemoveItem remove commands must expose failed inventory removal instead of reporting command success.")
}

$commandListActionLockRequiresTarget =
    $executeCommandListText.Contains("m_disabledActions == EActionFlags.None") -and
    $executeCommandListText.Contains("ResolveRequiredActorOrCurrentControlledCharacter(nameof(ExecuteCommandList))") -and
    $executeCommandListText.Contains("actionLockTarget?.DisableActions(m_disabledActions);") -and
    $executeCommandListText.Contains("actionLockTarget?.EnableActions(m_disabledActions);")
if (-not $commandListActionLockRequiresTarget) {
    [void]$violations.Add("ExecuteCommandList must require a command target when it applies an action lock; otherwise the list can run without the promised lock.")
}

$commandListRejectsMissingCommands =
    $executeCommandListText.Contains("EnsureCommandsConfigured();") -and
    $executeCommandListText.Contains("throw new InvalidOperationException") -and
    $executeCommandListText.Contains("if (m_commands == null)") -and
    $executeCommandListText.Contains("CreateMissingCommandException(i)")
if (-not $commandListRejectsMissingCommands) {
    [void]$violations.Add("ExecuteCommandList must reject a missing command array or null child command instead of treating a configured command list as a successful no-op.")
}

$configuredTargetCommandsRejectMissingTargets =
    $destroyEntityText.Contains("throw new InvalidOperationException") -and
    $destroyEntityText.Contains("m_toDestroy.Destroy(context);") -and
    -not $destroyEntityText.Contains("m_toDestroy?.Destroy") -and
    $toggleControllerText.Contains("throw new InvalidOperationException") -and
    $toggleControllerText.Contains("m_character.StartController();") -and
    $toggleControllerText.Contains("m_character.StopController();") -and
    -not $toggleControllerText.Contains("m_character?.StartController") -and
    -not $toggleControllerText.Contains("m_character?.StopController") -and
    $moveCharacterBaseText.Contains("throw new InvalidOperationException") -and
    $moveCharacterBaseText.Contains("await target.MoveTo(targetPosition).Task;") -and
    -not ($moveCharacterBaseText -match "if\s*\(\s*!target\s*\)\s*\{\s*return\s*;") -and
    $moveCameraText.Contains("throw new InvalidOperationException") -and
    $moveCameraText.Contains("return m_cameraMovementStrategy.MoveCameraAsync();") -and
    -not $moveCameraText.Contains(": Task.CompletedTask") -and
    $executeCommandHandlerText.Contains("throw new InvalidOperationException") -and
    $executeCommandHandlerText.Contains("return m_commandHandler.Execute(context);") -and
    -not $executeCommandHandlerText.Contains(": Task.CompletedTask") -and
    $commandHandlerText.Contains("throw new InvalidOperationException") -and
    $commandHandlerText.Contains("return m_command.Execute(context);") -and
    $playDialogueSequenceText.Contains("throw new InvalidOperationException") -and
    $playDialogueSequenceText.Contains("return GameManager.DialogueSystem.PlayNow(m_dialogueSequence.ToDialogueTree(m_speaker, context));") -and
    -not $playDialogueSequenceText.Contains(": Task.CompletedTask")
if (-not $configuredTargetCommandsRejectMissingTargets) {
    [void]$violations.Add("Commands with explicit configured result targets, strategies, or command assets must reject missing configuration instead of treating it as a successful no-op.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    HasFireAndReport = $hasFireAndReport
    QuestCompletionReturnsTask = $questCompletionReturnsTask
    JournalCompletionAwaitsTask = $journalCompletionAwaitsTask
    QuestInteractionAwaitsCompletion = $questInteractionAwaitsCompletion
    EventEntrancesUseFireAndReport = $eventEntrancesUseFireAndReport
    EntityInteractionReports = $entityInteractionReports
    WaitCommandUsesPlayerLoopDelay = $waitCommandUsesPlayerLoopDelay
    CommandTriggerFrameDelayUsesPlayerLoop = $commandTriggerFrameDelayUsesPlayerLoop
    CommandContextKeepsNonThrowingFallback = $commandContextKeepsNonThrowingFallback
    CommandContextHasRequiredTargetResolver = $commandContextHasRequiredTargetResolver
    MovePlayerMatchesReferencePlayerShortcut = $movePlayerMatchesReferencePlayerShortcut
    AddExperienceUsesCommandContextTarget = $addExperienceUsesCommandContextTarget
    PlayerResultCommandsRequireTargets = $playerResultCommandsRequireTargets
    AddOrRemoveAbilityRejectsInvalidCode = $addOrRemoveAbilityRejectsInvalidCode
    AddOrRemoveItemRejectsMissingRemoval = $addOrRemoveItemRejectsMissingRemoval
    CommandListActionLockRequiresTarget = $commandListActionLockRequiresTarget
    CommandListRejectsMissingCommands = $commandListRejectsMissingCommands
    ConfiguredTargetCommandsRejectMissingTargets = $configuredTargetCommandsRejectMissingTargets
    RawCommandTaskDropCount = $rawCommandTaskDrops.Count
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Command runtime static gate passed."
    }
    else {
        Write-Host "Command runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
