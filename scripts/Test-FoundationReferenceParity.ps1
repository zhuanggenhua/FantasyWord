[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$ReferenceCoreRoot = "C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core",
    [string]$BrandName = "FantasyWord",
    [switch]$AsJson
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

$runtimeSourceRoot = Join-Path $ReferenceCoreRoot "Runtime\Scripts"
$editorSourceRoot = Join-Path $ReferenceCoreRoot "Editor\Scripts"
$runtimeTargetRoot = Join-Path $ProjectRoot "Assets\Scripts\GameCore\Runtime"
$editorTargetRoot = Join-Path $ProjectRoot "Assets\Editor\GameCore"

$allowedExtraRuntimePaths = @(
    "AssemblyInfo.cs",
    "Animation\AnimationStateMessageContracts.cs",
    "Animation\DamageScreenFlash.cs",
    "Audio\AudioChannel.FallbackPoolRuntime.cs",
    "Audio\AudioChannel.PlaybackRuntime.cs",
    "Audio\AudioChannelFallbackPlayer.cs",
    "Combat\CombatStatSnapshot.cs",
    "Database\DatabaseRegistry.Editor.cs",
    "Combat\FormalAttributeCatalog.cs",
    "Combat\FormalGameplayAttributeSet.cs",
    "Combat\Abilities\AbilityPermissionSettings.cs",
    "Controllers\IPlayerInputTarget.cs",
    "Combat\Weapons\WeaponExecutionRuntime.cs",
    "Combat\Weapons\WeaponExecutionSettings.cs",
    "Combat\Weapons\WeaponHitWindowRuntime.cs",
    "Combat\Abilities\IActionInterruptReceiver.cs",
    "Controllers\AIController.BehaviourRuntime.cs",
    "Controllers\PlayerController.InteractionRuntime.cs",
    "Controllers\PlayerController.NavigationRuntime.cs",
    "Entities\Characters\CharacterBase.ActionStateRuntime.cs",
    "Entities\Characters\CharacterBase.Abilities.cs",
    "Entities\Characters\CharacterBase.Contracts.cs",
    "Entities\Characters\CharacterBase.GASRuntime.cs",
    "Entities\Characters\CharacterBase.Persistence.cs",
    "Entities\Characters\CharacterBase.Resources.cs",
    "Entities\Characters\CharacterBase.StateApi.cs",
    "Diagnostics\RuntimeLogOverlay.cs",
    "Loot\ItemPickable.cs",
    "Loot\MoneyPickable.cs",
    "Loot\PickableItem.cs",
    "Miscellaneous\MovementZone.cs",
    "Diagnostics\RuntimeLogOverlayBootstrap.cs",
    "Diagnostics\FormalSceneSingletonConflictDiagnostics.cs",
    "Events\GameRuntimeEvents.cs",
    "Events\GameRuntimeEvents.Lifecycle.cs",
    "Events\GameRuntimeEvents.Presentation.cs",
    "Events\GameRuntimeEvents.Progression.cs",
    "Events\GameRuntimeEvents.Progression.Inventory.cs",
    "Events\GameRuntimeEvents.Progression.Quests.cs",
    "Events\GameRuntimeEvents.Ui.cs",
    "Game\GameConfig.Contracts.cs",
    "Game\GameConfig.Persistence.cs",
    "Game\GameConfig.Terms.cs",
    "Game\GameManager.LifecycleRuntime.cs",
    "Game\GameManager.SystemRegistryRuntime.cs",
    "Game\Systems\InputSystem.Contracts.cs",
    "Game\Systems\MapSystem.Contracts.cs",
    "Game\Systems\PersistenceSystem.Contracts.cs",
    "Game\Systems\PersistenceSystem.InstantiationRuntime.cs",
    "Game\Systems\SaveSystem.Contracts.cs",
    "Game\Systems\SaveFileStorageRuntime.cs",
    "Interactions\IInteractionReceiver.cs",
    "Physics\IMovableCollisionReceiver.cs",
    "Persistence\Persistable.Contracts.cs",
    "Persistence\Persistable.DataBlocks.cs",
    "Presentation\GameplayFeedbackSet.cs",
    "Resources\Generated\FWRes.g.cs",
    "Resources\Generated\FWScene.g.cs",
    "Resources\Generated\FWText.g.cs",
    "Entities\Characters\CharacterBase.AttributeBootstrapBuffer.cs",
    "Entities\Characters\CharacterBase.AbilitySetRuntime.cs",
    "Entities\Characters\CharacterBase.TemporalEffectRuntime.cs",
    "Entities\Characters\HeroEquippedAbilityLoadout.cs",
    "Entities\Characters\HeroEquippedItemLoadout.cs",
    "Entities\Characters\HeroEquipmentSlotChange.cs",
    "Entities\Movable.MotionRuntime.cs",
    "Entities\Projectile.CollisionRuntime.cs",
    "Entities\Projectile.ExplosionRuntime.cs",
    "Entities\Projectile.Persistence.cs",
    "UI\MenuPanels\UIKitDeathPanel.cs",
    "UI\MenuPanels\UIKitMenuOpenData.cs",
    "UI\MenuPanels\UIKitMenuPanelBase.cs",
    "UI\MenuPanels\UIKitMenuPanelTypeReference.cs",
    "UI\HUD\Dialogue\IDialogueHudEventReceiver.cs",
    "UI\UIPointerUtility.cs",
    "UI\InputActionReleaseGate.cs",
    "UI\UIManager.MenuRuntime.cs",
    "UI\UIManager.MenuRegistrationRuntime.cs",
    "UI\UIManager.MenuRequestRoutingRuntime.cs",
    "UI\UIManager.MenuStackRuntime.cs",
    "UI\Menus\Abilities\IAbilityMenuEventReceiver.cs",
    "UI\UIKitSmoke\UIKitSmokePanelBase.cs",
    "UI\UIKitSmoke\UIKitSmokePrimaryPanel.cs",
    "UI\UIKitSmoke\UIKitSmokeSecondaryPanel.cs",
    "UI\UITipsItem.cs",
    "UI\UITipsService.cs"
)
$allowedExtraEditorPaths = @(
    "Bridge\BridgePollerRecovery.cs",
    "Bridge\FormalSceneInputRootAutomation.cs",
    "Bridge\UIKitSmoke\UIKitSmokeValidator.cs",
    "EditorWindows\ContentBrowserWindow.cs",
    "Generated\FWSceneMenu.g.cs",
    "Generated\SceneMenuRegistry.cs",
    "PropertyDrawers\UIKitMenuPanelTypeReferencePropertyDrawer.cs",
    "Utils\FormalDataAssetCache.cs"
)

$allowedPatchedRuntimePaths = @(
    "Animation\CameraShake.cs",
    "Animation\EquipmentSpriteLibraryUpdater.cs",
    "Animation\FollowTargetDirection.cs",
    "Animation\StateMessageDispatcher.cs",
    "Animation\Strategies\AAnimationStrategy.cs",
    "Animation\Strategies\BidirectionalAnimationStrategy.cs",
    "Animation\Strategies\IAnimationStrategy.cs",
    "Audio\AudioChannel.cs",
    "Audio\AudioRegion.cs",
    "Combat\CombatSolver.cs",
    "Combat\DamageDescriptor.cs",
    "Combat\DamageSolver.cs",
    "Combat\ObservableStats.cs",
    "Combat\Stats.cs",
    "Commands\AddExperience.cs",
    "Commands\AddOrRemoveAbility.cs",
    "Commands\AddOrRemoveMana.cs",
    "Commands\ApplyEffectsToPlayer.cs",
    "Commands\CloseMenus.cs",
    "Commands\CompleteTask.cs",
    "Commands\ExecuteCommandList.cs",
    "Commands\HealOrDamagePlayer.cs",
    "Commands\MoveCamera.cs",
    "Commands\MovePlayer.cs",
    "Commands\OpenCraftMenu.cs",
    "Commands\OpenMenu.cs",
    "Commands\OpenShopMenu.cs",
    "Commands\PlayDialogueLine.cs",
    "Commands\PlayDialogueSequence.cs",
    "Commands\RevivePlayer.cs",
    "Commands\ToggleController.cs",
    "Combat\Abilities\AbilityBase.cs",
    "Combat\Abilities\Active\ActiveAbilityBase.cs",
    "Combat\Abilities\Active\MeleeAttackAbility.cs",
    "Combat\Abilities\Active\SelfCastAbility.cs",
    "Combat\EffectDispatcher.cs",
    "Combat\Effects\AEffect.cs",
    "Combat\Effects\Immediate\ImmediateDamageEffect.cs",
    "Combat\Effects\Immediate\ImmediateHealEffect.cs",
    "Combat\Effects\Immediate\ImmediateRestoreManaEffect.cs",
    "Combat\Effects\Temporal\ATemporalEffect.cs",
    "Combat\Effects\Temporal\ITemporalEffect.cs",
    "Combat\Effects\Temporal\TemporalControlEffect.cs",
    "Combat\Effects\Temporal\TemporalDamageEffect.cs",
    "Combat\Effects\Temporal\TemporalHealEffect.cs",
    "Combat\Effects\Temporal\TemporalRestoreManaEffect.cs",
    "Combat\Effects\Temporal\TemporalSpeedModifierEffect.cs",
    "Combat\Effects\Temporal\TemporalStatModifierEffect.cs",
    "Combat\PerTargetCooldown.cs",
    "Commands\PlayAudioClip.cs",
    "Controllers\AIController.cs",
    "Database\DatabaseRegistry.cs",
    "Database\Abilities\AbilitySheet.cs",
    "Database\Abilities\Active\ActiveAbilitySheet.cs",
    "Database\Audio\AudioClipResolver.cs",
    "Database\Characters\CharacterSheet.cs",
    "Database\Characters\HeroSheet.cs",
    "Database\Characters\MonsterSheet.cs",
    "Database\Crafting\CraftingStation.cs",
    "Database\Crafting\Recipe.cs",
    "Database\Dialogues\DialogueSequence.cs",
    "Database\Inns\Inn.cs",
    "Database\Items\Equipment.cs",
    "Database\Items\Item.cs",
    "Database\Items\ItemEffects\AItemEffect.cs",
    "Database\Items\ItemEffects\ItemEquipOrUnequip.cs",
    "Database\Items\ItemEffects\ItemHealEffect.cs",
    "Database\Items\ItemEffects\ItemRestoreManaEffect.cs",
    "Database\Quest\Quest.cs",
    "Database\Quest\Tasks\KillMonsterTask.cs",
    "Database\Quest\Tasks\ItemTask.cs",
    "Database\Quest\Tasks\TalkToNPCTask.cs",
    "Database\Save\PrefabReference.cs",
    "Database\Save\SaveFile.cs",
    "Database\Shops\Shop.cs",
    "Database\UI\NavigationCursorStyle.cs",
    "Controllers\PlayerController.cs",
    "Dialogue\DialogueChannel.cs",
    "Dialogue\DialogueNode.cs",
    "Dialogue\DialogueTree.cs",
    "Dialogue\DialogueUtils.cs",
    "Entities\Chest.cs",
    "Entities\Entity.cs",
    "Entities\Projectile.cs",
    "Entities\Characters\Character.cs",
    "Entities\Characters\CharacterBase.cs",
    "Entities\Characters\Hero.cs",
    "Entities\Characters\Monster.cs",
    "Entities\Characters\NPC.cs",
    "Game\GameConfig.cs",
    "Game\GameManager.cs",
    "Entities\Movable.cs",
    "Conditional\Conditions\IsAbilityUnlocked.cs",
    "Conditional\Conditions\IsGameFlagSet.cs",
    "Conditional\Conditions\IsItemInInventory.cs",
    "Conditional\Conditions\IsQuestInState.cs",
    "Conditional\Conditions\IsQuestTaskActive.cs",
    "Conditional\Conditions\IsQuestTaskInState.cs",
    "Database\Quest\Tasks\GameFlagTask.cs",
    "Game\Systems\AudioSystem.cs",
    "Game\Systems\DialogueSystem.cs",
    "Game\Systems\GameFlagSystem.cs",
    "Game\Systems\GameStateSystem.cs",
    "Game\Systems\InputSystem.cs",
    "Game\Systems\InventorySystem.cs",
    "Game\Systems\JournalSystem.cs",
    "Game\Systems\MapSystem.cs",
    "Game\Systems\PersistenceSystem.cs",
    "Game\Systems\PlayerSystem.cs",
    "Game\Systems\SaveSystem.cs",
    "Game\Systems\TransitionSystem.cs",
    "Game\Systems\UISystem.cs",
    "Interactions\IInteractionTarget.cs",
    "Interactions\InnInteraction.cs",
    "Interactions\CraftInteraction.cs",
    "Interactions\QuestInteraction.cs",
    "Interactions\ShopInteraction.cs",
    "Maps\Checkpoint.cs",
    "Maps\CheckpointUtil.cs",
    "Maps\ICheckpoint.cs",
    "Maps\MapInfo.cs",
    "Maps\PersistableCheckpoint.cs",
    "Maps\Teleporter.cs",
    "Miscellaneous\CommandTrigger.cs",
    "Physics\CollisionDispatcher.cs",
    "Persistence\Persistable.cs",
    "Persistence\PersistableReference.cs",
    "Quest\QuestProgress.cs",
    "Loot\ChestLoot.cs",
    "Spawners\AMonsterSpawner.cs",
    "UI\UIControllerButton.cs",
    "UI\FloatingTexts\CombatTextDisplay.cs",
    "UI\FloatingTexts\FloatingText.cs",
    "UI\FloatingTexts\FloatingTextPool.cs",
    "UI\HUD\Abilities\UIHUDAbilityMessage.cs",
    "UI\Effects\UIEffectListEntry.cs",
    "UI\Effects\UIEffectList.cs",
    "UI\HUD\Abilities\UIHUDAbilityBar.cs",
    "UI\HUD\Abilities\UIHUDAbilityBarEntry.cs",
    "UI\HUD\Dialogue\UIDialogue.cs",
    "UI\HUD\Dialogue\UIDialogueMessageBox.cs",
    "UI\HUD\Dialogue\UIDialogueOption.cs",
    "UI\HUD\EventLog\UIEventLog.cs",
    "UI\HUD\Effects\UIHUDEffectBar.cs",
    "UI\HUD\ItemDetails\UIItemDetails.cs",
    "UI\HUD\Stats\UIStatBar.cs",
    "UI\Menus\Abilities\UIAbilities.cs",
    "UI\Menus\Abilities\UIAbilityBar.cs",
    "UI\Menus\Abilities\UIAbilityBarEntry.cs",
    "UI\Menus\Abilities\UIAbilityCategory.cs",
    "UI\Menus\Abilities\UIAbilityListEntry.cs",
    "UI\Menus\Character\UICharacter.cs",
    "UI\Menus\Craft\UICraft.cs",
    "UI\Menus\Craft\UIRecipeEntry.cs",
    "UI\Menus\Inventory\UIInventory.cs",
    "UI\Menus\Inventory\UIInventoryBag.cs",
    "UI\Menus\Inventory\UIInventoryBagCategory.cs",
    "UI\Menus\Inventory\UIInventoryBagSlot.cs",
    "UI\Menus\Inventory\UIInventoryEquipmentSlot.cs",
    "UI\Menus\Inventory\UIInventoryStats.cs",
    "UI\Menus\Journal\UIJournal.cs",
    "UI\Menus\Journal\UIJournalQuestEntry.cs",
    "UI\Menus\Journal\UIJournalQuestDescription.cs",
    "UI\Menus\Save\UISave.cs",
    "UI\Menus\Save\UISaveFile.cs",
    "UI\Menus\Shop\UIShop.cs",
    "UI\Menus\Shop\UIShopEntry.cs",
    "UI\Menus\UIGameMenu.cs",
    "UI\Menus\UIGameMenuEntry.cs",
    "UI\Menus\UIMainMenu.cs",
    "UI\UICharacterInfo.cs",
    "UI\UIControllerButtonManager.cs",
    "UI\UIManager.cs",
    "UI\UINavigationCursor.cs",
    "UI\UINavigationCursorTarget.cs",
    "UI\UINavigationTarget.cs",
    "UI\UIPlayerControllerFeedback.cs",
    "UI\Generic\UIStat.cs",
    "UI\Menus\Character\UICharacterStat.cs",
    "UI\Menus\Settings\UISettings.cs"
)

$allowedPatchedEditorPaths = @(
    "Database\DatabaseEntryProcessor.cs",
    "Database\DatabaseRegistryExtensions.cs",
    "EditorWindows\DatabaseWindow.cs",
    "Editors\DatabaseEntryEditor.cs",
    "Editors\DatabaseRegistryEditor.cs",
    "Editors\HeroSheetEditor.cs",
    "Editors\MonsterSheetEditor.cs",
    "Editors\QuestEditor.cs",
    "Persistence\PersistableProcessor.cs",
    "Persistence\PersistanceUtil.cs",
    "Playtest\EditorPlayModeOverride.cs",
    "PropertyDrawers\PersistableCheckpointPropertyDrawer.cs",
    "PropertyDrawers\PersistableReferencePropertyDrawer.cs",
    "PropertyDrawers\StatsPropertyDrawer.cs",
    "Utils\SceneUtil.cs"
)
$excludedRuntimeReferencePaths = @(
    "UI\Menus\AUIMenu.cs",
    "UI\Menus\IUIMenu.cs",
    "UI\Menus\UIMenuManager.cs",
    "UI\Menus\Death\UIDeath.cs",
    "Animation\IAnimationMessageReceiver.cs",
    "Game\Systems\NotificationSystem.cs",
    "Pooling\InstancePool.cs",
    "Maps\GameObjectCheckpoint.cs",
    "Miscellaneous\CoroutineHelpers.cs"
)
$excludedEditorReferencePaths = @(
    "Overlays\SceneSelectorOverlay.cs",
    "Utils\AssetLoader.cs"
)

function Get-MappedRuntimeRelativePath {
    param([string]$RelativePath)

    switch -Regex ($RelativePath) {
        '^Checkpoints\\' { return ($RelativePath -replace '^Checkpoints\\', 'Maps\') }
        '^Save\\DataBlock\.cs$' { return 'Persistence\DataBlock.cs' }
        '^Save\\Persistable\.cs$' { return 'Persistence\Persistable.cs' }
        '^Save\\PersistableReference\.cs$' { return 'Persistence\PersistableReference.cs' }
        '^Save\\IDataBlockHandler\.cs$' { return 'Persistence\IDataBlockHandler.cs' }
        '^Save\\DatabaseEntryReference\.cs$' { return 'Database\DatabaseEntryReference.cs' }
        '^Database\\Game\\GameConfig\.cs$' { return 'Game\GameConfig.cs' }
        default { return $RelativePath }
    }
}

function Get-NamespaceForRelativePath {
    param(
        [string]$RelativePath,
        [string]$NamespaceRoot
    )

    return $NamespaceRoot
}

function Update-Branding {
    param(
        [string]$Content,
        [string]$Brand
    )

    $updated = $Content
    $updated = $updated.Replace("Window/Mythril2D/", "Window/$Brand/")
    $updated = $updated.Replace("Mythril2D Scene Selector", "$Brand Scene Selector")
    $updated = $updated.Replace("Mythril2DShowWelcomeWindowOnImport", "${Brand}ShowWelcomeWindowOnImport")
    $updated = $updated.Replace("Mythril2D Persistence System", "$Brand Persistence System")
    $updated = $updated.Replace("Mythril2D built-in documentation", "$Brand built-in documentation")
    $updated = $updated.Replace("Mythril2D documentation folder", "$Brand documentation folder")
    return $updated
}

function Convert-ReferenceContent {
    param(
        [string]$Content,
        [string]$RelativePath,
        [string]$NamespaceRoot,
        [string]$Brand
    )

    $namespace = Get-NamespaceForRelativePath -RelativePath $RelativePath -NamespaceRoot $NamespaceRoot
    $updated = [regex]::Replace($Content, 'namespace\s+Gyvr\.Mythril2D', "namespace $namespace")
    $updated = $updated.Replace("using Gyvr.Mythril2D;", "")
    $updated = $updated.Replace("AssetMenuIndexer.Mythril2D_", "AssetMenuIndexer.${Brand}_")
    $updated = $updated.Replace("AssetMenuIndexer.Mythril2D", "AssetMenuIndexer.$Brand")
    $updated = Update-Branding -Content $updated -Brand $Brand

    if ($RelativePath -eq "Database\AssetMenuIndexer.cs") {
        $updated = $updated.Replace('public const string Mythril2D = "Mythril2D/";', "public const string ${Brand} = `"$Brand/`";")
        $updated = $updated.Replace("public const string Mythril2D_Abilities", "public const string ${Brand}_Abilities")
        $updated = $updated.Replace("public const string Mythril2D_Animation", "public const string ${Brand}_Animation")
        $updated = $updated.Replace("public const string Mythril2D_Audio", "public const string ${Brand}_Audio")
        $updated = $updated.Replace("public const string Mythril2D_Characters", "public const string ${Brand}_Characters")
        $updated = $updated.Replace("public const string Mythril2D_Dialogues", "public const string ${Brand}_Dialogues")
        $updated = $updated.Replace("public const string Mythril2D_Game", "public const string ${Brand}_Game")
        $updated = $updated.Replace("public const string Mythril2D_Inns", "public const string ${Brand}_Inns")
        $updated = $updated.Replace("public const string Mythril2D_Items", "public const string ${Brand}_Items")
        $updated = $updated.Replace("public const string Mythril2D_Crafting", "public const string ${Brand}_Crafting")
        $updated = $updated.Replace("public const string Mythril2D_Quests", "public const string ${Brand}_Quests")
        $updated = $updated.Replace("public const string Mythril2D_Quests_Tasks", "public const string ${Brand}_Quests_Tasks")
        $updated = $updated.Replace("public const string Mythril2D_Save", "public const string ${Brand}_Save")
        $updated = $updated.Replace("public const string Mythril2D_Shops", "public const string ${Brand}_Shops")
        $updated = $updated.Replace("public const string Mythril2D_UI", "public const string ${Brand}_UI")
        $updated = $updated.Replace("public const string Mythril2D_Utils", "public const string ${Brand}_Utils")
        $updated = $updated.Replace("= Mythril2D + ", "= $Brand + ")
        $updated = $updated.Replace("= Mythril2D_Quests + ", "= ${Brand}_Quests + ")
    }

    return $updated
}

function Normalize-Text {
    param([string]$Content)

    if ($null -eq $Content) {
        return ""
    }

    $normalized = $Content -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    return $normalized.TrimEnd("`n")
}

function Compare-Tree {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot,
        [string]$NamespaceRoot,
        [bool]$UseRuntimeMappings,
        [string[]]$AllowedExtraPaths,
        [string[]]$AllowedPatchedPaths,
        [string[]]$ExcludedRelativePaths = @()
    )

    $missing = New-Object System.Collections.Generic.List[string]
    $mismatch = New-Object System.Collections.Generic.List[string]
    $allowedPatched = New-Object System.Collections.Generic.List[string]
    $unexpectedMismatch = New-Object System.Collections.Generic.List[string]
    $allowedExtra = New-Object System.Collections.Generic.List[string]
    $unexpectedExtra = New-Object System.Collections.Generic.List[string]
    $expectedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $allowedExtras = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $allowedPatchedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $excludedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($path in $AllowedExtraPaths) {
        [void]$allowedExtras.Add($path)
    }

    foreach ($path in $AllowedPatchedPaths) {
        [void]$allowedPatchedSet.Add($path)
    }

    foreach ($path in $ExcludedRelativePaths) {
        [void]$excludedSet.Add($path)
    }

    Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.cs | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceRoot.Length + 1)
        if ($UseRuntimeMappings) {
            $relativePath = Get-MappedRuntimeRelativePath -RelativePath $relativePath
        }

        if ($excludedSet.Contains($relativePath)) {
            return
        }

        [void]$expectedPaths.Add($relativePath)

        $targetPath = Join-Path $TargetRoot $relativePath
        if (-not (Test-Path -LiteralPath $targetPath)) {
            [void]$missing.Add($relativePath)
            return
        }

        $expected = Convert-ReferenceContent -Content (Get-Content -LiteralPath $_.FullName -Raw) -RelativePath $relativePath -NamespaceRoot $NamespaceRoot -Brand $BrandName
        $actual = Get-Content -LiteralPath $targetPath -Raw
        if ((Normalize-Text -Content $expected) -ne (Normalize-Text -Content $actual)) {
            [void]$mismatch.Add($relativePath)
            if ($allowedPatchedSet.Contains($relativePath)) {
                [void]$allowedPatched.Add($relativePath)
            }
            else {
                [void]$unexpectedMismatch.Add($relativePath)
            }
        }
    }

    Get-ChildItem -Path $TargetRoot -Recurse -File -Filter *.cs | ForEach-Object {
        $relativePath = $_.FullName.Substring($TargetRoot.Length + 1)
        if ($expectedPaths.Contains($relativePath)) {
            return
        }

        if ($allowedExtras.Contains($relativePath)) {
            [void]$allowedExtra.Add($relativePath)
        }
        else {
            [void]$unexpectedExtra.Add($relativePath)
        }
    }

    return [ordered]@{
        missing = @($missing)
        mismatched = @($mismatch)
        allowedPatched = @($allowedPatched)
        unexpectedMismatch = @($unexpectedMismatch)
        allowedExtra = @($allowedExtra)
        unexpectedExtra = @($unexpectedExtra)
    }
}

$runtime = Compare-Tree -SourceRoot $runtimeSourceRoot -TargetRoot $runtimeTargetRoot -NamespaceRoot "$BrandName.GameCore" -UseRuntimeMappings $true -AllowedExtraPaths $allowedExtraRuntimePaths -AllowedPatchedPaths $allowedPatchedRuntimePaths -ExcludedRelativePaths $excludedRuntimeReferencePaths
$editor = Compare-Tree -SourceRoot $editorSourceRoot -TargetRoot $editorTargetRoot -NamespaceRoot "$BrandName.GameCore" -UseRuntimeMappings $false -AllowedExtraPaths $allowedExtraEditorPaths -AllowedPatchedPaths $allowedPatchedEditorPaths -ExcludedRelativePaths $excludedEditorReferencePaths

$report = [ordered]@{
    projectRoot = $ProjectRoot
    referenceCoreRoot = $ReferenceCoreRoot
    runtimeMissingCount = $runtime.missing.Count
    runtimeMismatchCount = $runtime.mismatched.Count
    runtimeAllowedPatchedCount = $runtime.allowedPatched.Count
    runtimeUnexpectedMismatchCount = $runtime.unexpectedMismatch.Count
    runtimeAllowedExtraCount = $runtime.allowedExtra.Count
    runtimeUnexpectedExtraCount = $runtime.unexpectedExtra.Count
    editorMissingCount = $editor.missing.Count
    editorMismatchCount = $editor.mismatched.Count
    editorAllowedPatchedCount = $editor.allowedPatched.Count
    editorUnexpectedMismatchCount = $editor.unexpectedMismatch.Count
    editorAllowedExtraCount = $editor.allowedExtra.Count
    editorUnexpectedExtraCount = $editor.unexpectedExtra.Count
    runtimeMissing = $runtime.missing
    runtimeMismatched = $runtime.mismatched
    runtimeAllowedPatched = $runtime.allowedPatched
    runtimeUnexpectedMismatch = $runtime.unexpectedMismatch
    runtimeAllowedExtra = $runtime.allowedExtra
    runtimeUnexpectedExtra = $runtime.unexpectedExtra
    editorMissing = $editor.missing
    editorMismatched = $editor.mismatched
    editorAllowedPatched = $editor.allowedPatched
    editorUnexpectedMismatch = $editor.unexpectedMismatch
    editorAllowedExtra = $editor.allowedExtra
    editorUnexpectedExtra = $editor.unexpectedExtra
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "Foundation reference parity"
Write-Host "ProjectRoot:" $ProjectRoot
Write-Host "ReferenceCoreRoot:" $ReferenceCoreRoot
Write-Host "Runtime missing:" $report.runtimeMissingCount
Write-Host "Runtime mismatched:" $report.runtimeMismatchCount
Write-Host "Runtime allowed patched:" $report.runtimeAllowedPatchedCount
Write-Host "Runtime unexpected mismatch:" $report.runtimeUnexpectedMismatchCount
Write-Host "Runtime allowed extra:" $report.runtimeAllowedExtraCount
Write-Host "Runtime unexpected extra:" $report.runtimeUnexpectedExtraCount
Write-Host "Editor missing:" $report.editorMissingCount
Write-Host "Editor mismatched:" $report.editorMismatchCount
Write-Host "Editor allowed patched:" $report.editorAllowedPatchedCount
Write-Host "Editor unexpected mismatch:" $report.editorUnexpectedMismatchCount
Write-Host "Editor allowed extra:" $report.editorAllowedExtraCount
Write-Host "Editor unexpected extra:" $report.editorUnexpectedExtraCount

if ($report.runtimeMissingCount -gt 0) {
    Write-Host "Runtime missing paths:"
    $report.runtimeMissing | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeMismatchCount -gt 0) {
    Write-Host "Runtime mismatched paths:"
    $report.runtimeMismatched | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeAllowedPatchedCount -gt 0) {
    Write-Host "Runtime allowed patched paths:"
    $report.runtimeAllowedPatched | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeUnexpectedMismatchCount -gt 0) {
    Write-Host "Runtime unexpected mismatch paths:"
    $report.runtimeUnexpectedMismatch | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeAllowedExtraCount -gt 0) {
    Write-Host "Runtime allowed extra paths:"
    $report.runtimeAllowedExtra | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeUnexpectedExtraCount -gt 0) {
    Write-Host "Runtime unexpected extra paths:"
    $report.runtimeUnexpectedExtra | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorMissingCount -gt 0) {
    Write-Host "Editor missing paths:"
    $report.editorMissing | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorMismatchCount -gt 0) {
    Write-Host "Editor mismatched paths:"
    $report.editorMismatched | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorAllowedPatchedCount -gt 0) {
    Write-Host "Editor allowed patched paths:"
    $report.editorAllowedPatched | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorUnexpectedMismatchCount -gt 0) {
    Write-Host "Editor unexpected mismatch paths:"
    $report.editorUnexpectedMismatch | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorAllowedExtraCount -gt 0) {
    Write-Host "Editor allowed extra paths:"
    $report.editorAllowedExtra | ForEach-Object { Write-Host "  $_" }
}

if ($report.editorUnexpectedExtraCount -gt 0) {
    Write-Host "Editor unexpected extra paths:"
    $report.editorUnexpectedExtra | ForEach-Object { Write-Host "  $_" }
}

if ($report.runtimeMissingCount -gt 0 -or
    $report.runtimeUnexpectedMismatchCount -gt 0 -or
    $report.runtimeUnexpectedExtraCount -gt 0 -or
    $report.editorMissingCount -gt 0 -or
    $report.editorUnexpectedMismatchCount -gt 0 -or
    $report.editorUnexpectedExtraCount -gt 0) {
    exit 2
}
