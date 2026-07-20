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

    [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
}

function Get-FileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw
}

function Test-ContainsAll {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        if (-not $Content.Contains($pattern)) {
            [void]$missing.Add($pattern)
        }
    }

    @($missing)
}

function Test-ContainsAny {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        if ($Content.Contains($pattern)) {
            [void]$hits.Add($pattern)
        }
    }

    @($hits)
}

function Test-MethodContainsAny {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$MethodName,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $methodIndex = $Content.IndexOf($MethodName, [System.StringComparison]::Ordinal)
    if ($methodIndex -lt 0) {
        return @($hits)
    }

    $bodyStart = $Content.IndexOf("{", $methodIndex, [System.StringComparison]::Ordinal)
    if ($bodyStart -lt 0) {
        return @($hits)
    }

    $depth = 0
    $bodyEnd = -1
    for ($index = $bodyStart; $index -lt $Content.Length; $index++) {
        $character = $Content[$index]
        if ($character -eq "{") {
            $depth++
            continue
        }

        if ($character -eq "}") {
            $depth--
            if ($depth -eq 0) {
                $bodyEnd = $index
                break
            }
        }
    }

    if ($bodyEnd -le $bodyStart) {
        return @($hits)
    }

    $body = $Content.Substring($bodyStart, $bodyEnd - $bodyStart + 1)
    foreach ($pattern in $Patterns) {
        if ($body.Contains($pattern)) {
            [void]$hits.Add(("{0}: {1}" -f $MethodName, $pattern))
        }
    }

    @($hits)
}

function Test-MethodContainsAll {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$MethodName,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $missing = New-Object System.Collections.Generic.List[string]
    $methodIndex = $Content.IndexOf($MethodName, [System.StringComparison]::Ordinal)
    if ($methodIndex -lt 0) {
        foreach ($pattern in $Patterns) {
            [void]$missing.Add(("{0}: {1}" -f $MethodName, $pattern))
        }

        return @($missing)
    }

    $bodyStart = $Content.IndexOf("{", $methodIndex, [System.StringComparison]::Ordinal)
    if ($bodyStart -lt 0) {
        foreach ($pattern in $Patterns) {
            [void]$missing.Add(("{0}: {1}" -f $MethodName, $pattern))
        }

        return @($missing)
    }

    $depth = 0
    $bodyEnd = -1
    for ($index = $bodyStart; $index -lt $Content.Length; $index++) {
        $character = $Content[$index]
        if ($character -eq "{") {
            $depth++
            continue
        }

        if ($character -eq "}") {
            $depth--
            if ($depth -eq 0) {
                $bodyEnd = $index
                break
            }
        }
    }

    if ($bodyEnd -le $bodyStart) {
        foreach ($pattern in $Patterns) {
            [void]$missing.Add(("{0}: {1}" -f $MethodName, $pattern))
        }

        return @($missing)
    }

    $body = $Content.Substring($bodyStart, $bodyEnd - $bodyStart + 1)
    foreach ($pattern in $Patterns) {
        if (-not $body.Contains($pattern)) {
            [void]$missing.Add(("{0}: {1}" -f $MethodName, $pattern))
        }
    }

    @($missing)
}

function Test-FilesContainAny {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Roots,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns,
        [string[]]$Extensions = @(".cs")
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) {
        [void]$allowedExtensions.Add($extension)
    }

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File |
            Where-Object { $allowedExtensions.Contains($_.Extension) } |
            ForEach-Object {
                $content = Get-Content -LiteralPath $_.FullName -Raw
                if ($null -eq $content) {
                    $content = ""
                }

                foreach ($pattern in $Patterns) {
                    if ($content.Contains($pattern)) {
                        [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern))
                    }
                }
            }
    }

    @($hits)
}

function Get-GameManagerSystemShortcutNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $shortcuts = New-Object System.Collections.Generic.List[string]
    $matches = [regex]::Matches(
        $Content,
        'public\s+static\s+([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=>\s*GetSystem<\1>\s*\('
    )

    foreach ($match in $matches) {
        [void]$shortcuts.Add($match.Groups[2].Value)
    }

    @($shortcuts)
}

function Find-EventKitDispatchBoundaryViolations {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedDispatchFiles
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedDispatchFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($allowedDispatchFile in $AllowedDispatchFiles) {
        [void]$allowedDispatchFullPaths.Add([System.IO.Path]::GetFullPath($allowedDispatchFile))
    }
    $roots = @(
        (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $ProjectRoot "Assets/Editor/GameCore"),
        (Join-Path $ProjectRoot "Assets/Tests/EditMode/GameCore")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
            if ($allowedDispatchFullPaths.Contains([System.IO.Path]::GetFullPath($_.FullName))) {
                return
            }

            $content = Get-Content -LiteralPath $_.FullName -Raw
            if ($null -eq $content) {
                $content = ""
            }

            foreach ($pattern in @("EventKit.Type.Send(", "EventKit.Enum", "EventKit.String")) {
                if ($content.Contains($pattern)) {
                    [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern))
                }
            }
        }
    }

    @($hits)
}

function Find-ResourceStatSemanticBypassHits {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string[]]$AllowedFiles = @()
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $AllowedFiles) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$allowedFullPaths.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $patterns = @(
        "GetCurrentStatValue(EStat.Health)",
        "GetCurrentStatValue(EStat.Mana)",
        "GetStatValue(EStat.Health)",
        "GetStatValue(EStat.Mana)",
        "ModifyCurrentStat(EStat.Health",
        "ModifyCurrentStat(EStat.Mana"
    )

    $roots = @(
        (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $ProjectRoot "Assets/Editor/GameCore"),
        (Join-Path $ProjectRoot "Assets/Tests/EditMode/GameCore")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
            $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
            if ($allowedFullPaths.Contains($fullPath)) {
                return
            }

            $content = Get-Content -LiteralPath $_.FullName -Raw
            if ($null -eq $content) {
                $content = ""
            }

            foreach ($pattern in $patterns) {
                if ($content.Contains($pattern)) {
                    [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern))
                }
            }
        }
    }

    @($hits)
}

function Find-DirectEventSystemAccessHits {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string[]]$AllowedFiles = @()
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $AllowedFiles) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$allowedFullPaths.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $patterns = @(
        @{
            Label = "EventSystem.current"
            Regex = '(?<![A-Za-z0-9_])EventSystem\.current(?![A-Za-z0-9_])'
        },
        @{
            Label = "FindFirstObjectByType<EventSystem>("
            Regex = 'FindFirstObjectByType<EventSystem>\('
        }
    )

    $roots = @(
        (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $ProjectRoot "Assets/Editor/GameCore"),
        (Join-Path $ProjectRoot "Assets/Tests/EditMode/GameCore")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
            $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
            if ($allowedFullPaths.Contains($fullPath)) {
                return
            }

            $content = Get-Content -LiteralPath $_.FullName -Raw
            if ($null -eq $content) {
                $content = ""
            }

            foreach ($pattern in $patterns) {
                if ([regex]::IsMatch($content, $pattern.Regex)) {
                    [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern.Label))
                }
            }
        }
    }

    @($hits)
}

function Find-DirectMainCameraAccessHits {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string[]]$AllowedFiles = @()
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $AllowedFiles) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$allowedFullPaths.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $patterns = @(
        @{
            Label = "Camera.main"
            Regex = '(?<![A-Za-z0-9_])Camera\.main(?![A-Za-z0-9_])'
        },
        @{
            Label = "FindFirstObjectByType<Camera>("
            Regex = 'FindFirstObjectByType<Camera>\('
        }
    )

    $roots = @(
        (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $ProjectRoot "Assets/Editor/GameCore"),
        (Join-Path $ProjectRoot "Assets/Tests/EditMode/GameCore")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
            $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
            if ($allowedFullPaths.Contains($fullPath)) {
                return
            }

            $content = Get-Content -LiteralPath $_.FullName -Raw
            if ($null -eq $content) {
                $content = ""
            }

            foreach ($pattern in $patterns) {
                if ([regex]::IsMatch($content, $pattern.Regex)) {
                    [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern.Label))
                }
            }
        }
    }

    @($hits)
}

function Find-ControlGroupBypassHits {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string[]]$AllowedFiles = @()
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $AllowedFiles) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$allowedFullPaths.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $pattern = '(?<![A-Za-z0-9_])PlayerControlGroup(?![A-Za-z0-9_])'
    $roots = @(
        (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $ProjectRoot "Assets/Editor/GameCore"),
        (Join-Path $ProjectRoot "Assets/Tests/EditMode/GameCore")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
            $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
            if ($allowedFullPaths.Contains($fullPath)) {
                return
            }

            $content = Get-Content -LiteralPath $_.FullName -Raw
            if ($null -eq $content) {
                $content = ""
            }

            if ([regex]::IsMatch($content, $pattern)) {
                [void]$hits.Add(("{0}: PlayerControlGroup" -f $_.FullName))
            }
        }
    }

    @($hits)
}

function Find-GameCoreGasRuntimeReferenceHits {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string[]]$AllowedFiles = @()
    )

    $hits = New-Object System.Collections.Generic.List[string]
    $allowedFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $AllowedFiles) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$allowedFullPaths.Add([System.IO.Path]::GetFullPath($path))
        }
    }

    $patterns = @(
        "GameplayAbility",
        "AttributeSet",
        "AbilitySystemComponent",
        "GameplayEffectSpec"
    )

    $root = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
    if (-not (Test-Path -LiteralPath $root)) {
        return @()
    }

    Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.cs | ForEach-Object {
        $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
        if ($allowedFullPaths.Contains($fullPath)) {
            return
        }

        $content = Get-Content -LiteralPath $_.FullName -Raw
        if ($null -eq $content) {
            $content = ""
        }

        foreach ($pattern in $patterns) {
            if ($content.Contains($pattern)) {
                [void]$hits.Add(("{0}: {1}" -f $_.FullName, $pattern))
            }
        }
    }

    @($hits)
}

function Test-IsGitTrackedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $gitOutput = & git -C $ProjectRoot ls-files -- $RelativePath 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace(($gitOutput | Out-String).Trim())
}

$projectRoot = Get-ProjectRoot
$gameConfigAssetPath = Join-Path $projectRoot "Assets/GameData/GameCore/GameConfig.asset"
$databaseRegistryAssetPath = Join-Path $projectRoot "Assets/GameData/GameCore/DatabaseRegistry.asset"
$databaseRegistryCodePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/DatabaseRegistry.cs"
$scenePath = Join-Path $projectRoot "Assets/Scenes/SampleScene.unity"
$sampleSceneMetaPath = Join-Path $projectRoot "Assets/Scenes/SampleScene.unity.meta"
$manifestPath = Join-Path $projectRoot "Packages/manifest.json"
$gameManagerPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameManager.cs"
$gameManagerLifecycleRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameManager.LifecycleRuntime.cs"
$gameManagerSystemRegistryRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameManager.SystemRegistryRuntime.cs"
$gameConfigRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameConfig.cs"
$gameConfigContractsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Contracts.cs"
$gameConfigTermsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Terms.cs"
$gameConfigPersistencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Persistence.cs"
$gameCommandContextPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/GameCommandContext.cs"
$gameRuntimeEventsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.cs"
$gameRuntimeEventsLifecyclePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Lifecycle.cs"
$gameRuntimeEventsPresentationPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Presentation.cs"
$gameRuntimeEventsProgressionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.cs"
$gameRuntimeEventsProgressionInventoryPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.Inventory.cs"
$gameRuntimeEventsProgressionQuestsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.Quests.cs"
$gameRuntimeEventsUiPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Ui.cs"
$inputSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs"
$playerCommandRequestPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/PlayerCommandRequest.cs"
$playerOrderRequestPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/PlayerOrderRequest.cs"
$playerInputTargetPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/IPlayerInputTarget.cs"
$playerControlGroupPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/PlayerControlGroup.cs"
$characterPlayerControlPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterPlayerControl.cs"
$uiHudAbilityMessagePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityMessage.cs"
$aiControllerPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/AIController.cs"
$aiControllerBehaviourRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs"
$playerSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs"
$questInteractionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/QuestInteraction.cs"
$journalSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/JournalSystem.cs"
$questPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Quest/Quest.cs"
$questProgressPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Quest/QuestProgress.cs"
$questTaskProgressPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Quest/QuestTaskProgress.cs"
$addExperienceCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/AddExperience.cs"
$addOrRemoveAbilityCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/AddOrRemoveAbility.cs"
$addOrRemoveItemCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/AddOrRemoveItem.cs"
$addOrRemoveManaCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/AddOrRemoveMana.cs"
$healOrDamagePlayerCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/HealOrDamagePlayer.cs"
$revivePlayerCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/RevivePlayer.cs"
$movePlayerCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/MovePlayer.cs"
$openShopMenuCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/OpenShopMenu.cs"
$openCraftMenuCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/OpenCraftMenu.cs"
$executeCommandListPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/ExecuteCommandList.cs"
$isAbilityUnlockedConditionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Conditional/Conditions/IsAbilityUnlocked.cs"
$gameStateSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/GameStateSystem.cs"
$mapSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs"
$persistenceSystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.cs"
$persistenceSystemContractsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.Contracts.cs"
$persistenceSystemInstantiationRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.InstantiationRuntime.cs"
$stateMessageDispatcherPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Animation/StateMessageDispatcher.cs"
$animationStrategyPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Animation/Strategies/AAnimationStrategy.cs"
$formalAttributeCatalogPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/FormalAttributeCatalog.cs"
$formalGameplayAttributeSetPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/FormalGameplayAttributeSet.cs"
$formalGameplayEffectDamageHelperPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/FormalGameplayEffectDamageHelper.cs"
$characterAlterationRulePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs"
$temporalEffectInterfacePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ITemporalEffect.cs"
$temporalEffectBasePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ATemporalEffect.cs"
$formalTemporalPeriodicCurrentResourceBuilderPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/FormalTemporalPeriodicCurrentResourceBuilder.cs"
$formalTemporalPeriodicSpecBuilderPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/FormalTemporalPeriodicSpecBuilder.cs"
$formalTemporalPeriodicDamageBuilderPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/FormalTemporalPeriodicDamageBuilder.cs"
$temporalAbilityEffectSupportPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityEffectSupport.cs"
$temporalAbilityGrantEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityGrantEffect.cs"
$temporalAbilitySuppressionEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilitySuppressionEffect.cs"
$temporalAbilityReplacementEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityReplacementEffect.cs"
$temporalHealEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalHealEffect.cs"
$temporalDamageEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalDamageEffect.cs"
$temporalRestoreManaEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalRestoreManaEffect.cs"
$temporalControlEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalControlEffect.cs"
$temporalStatModifierEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalStatModifierEffect.cs"
$temporalSpeedModifierEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalSpeedModifierEffect.cs"
$movablePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Movable.cs"
$characterBasePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs"
$characterBaseGasRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs"
$characterBaseContractsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs"
$characterBaseResourcesPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Resources.cs"
$characterBaseAbilitiesPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Abilities.cs"
$characterBaseAlterationsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs"
$characterBaseStateApiPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs"
$characterBasePersistencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs"
$characterBaseAttributeBootstrapBufferPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AttributeBootstrapBuffer.cs"
$characterBaseActionStateRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs"
$characterBaseAbilitySetRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs"
$characterBaseTemporalEffectRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs"
$characterAbilitySetPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterAbilitySet.cs"
$characterAbilitySetFormalRulesPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterAbilitySet.FormalRules.cs"
$characterActorPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.cs"
$characterActorRewardsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.Rewards.cs"
$characterSheetPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterSheet.cs"
$characterEquippedItemLoadoutPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterEquippedItemLoadout.cs"
$characterEquippedAbilityLoadoutPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterEquippedAbilityLoadout.cs"
$inventorySystemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/InventorySystem.cs"
$inventoryTransferRequestPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/InventoryTransferRequest.cs"
$inventoryMenuContextPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/InventoryMenuContext.cs"
$itemPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Items/Item.cs"
$itemEffectBasePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/AItemEffect.cs"
$itemStartQuestEffectPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/ItemStartQuestEffect.cs"
$itemEquipOrUnequipPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/ItemEquipOrUnequip.cs"
$uiGameMenuEntryPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/UIGameMenuEntry.cs"
$activeAbilityBasePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs"
$projectileAbilityPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ProjectileAbility.cs"
$summoningAbilityPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/SummoningAbility.cs"
$projectilePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Projectile.cs"
$projectilePersistencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Projectile.Persistence.cs"
$perTargetCooldownPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/PerTargetCooldown.cs"
$uiManagerMenuRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRuntime.cs"
$uiManagerMenuRegistrationRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRegistrationRuntime.cs"
$uiManagerMenuRequestRoutingRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRequestRoutingRuntime.cs"
$uiManagerMenuStackRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuStackRuntime.cs"
$uiKitMenuPanelBasePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuPanelBase.cs"
$uiKitDeathPanelPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitDeathPanel.cs"
$uiKitMenuOpenDataPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuOpenData.cs"
$uiKitMenuPanelTypeReferencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuPanelTypeReference.cs"
$uiKitMenuPanelTypeReferenceDrawerPath = Join-Path $projectRoot "Assets/Editor/GameCore/PropertyDrawers/UIKitMenuPanelTypeReferencePropertyDrawer.cs"
$formalSceneInputHostAutomationPath = Join-Path $projectRoot "Assets/Editor/GameCore/Bridge/FormalSceneInputRootAutomation.cs"
$formalSceneInputHostRepairScriptPath = Join-Path $projectRoot "scripts/Invoke-FormalSceneInputRootRepair.ps1"
$uiPrefabPath = Join-Path $projectRoot "Assets/Prefabs/UI/User Interface.prefab"
$characterBasePrefabPath = Join-Path $projectRoot "Assets/Prefabs/Entities/Characters/0_Character_Base.prefab"
$uiKitDeathPrefabPath = Join-Path $projectRoot "Assets/GameRes/UI/Panels/UIKitDeathPanel.prefab"
$uiManagerPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIManager.cs"
$uiControllerButtonPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIControllerButton.cs"
$uiControllerButtonManagerPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/UIControllerButtonManager.cs"
$uiStatBarPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/Stats/UIStatBar.cs"
$uiDialogueMessageBoxPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueMessageBox.cs"
$uiEffectListPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Effects/UIEffectList.cs"
$uiHudAbilityBarPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityBar.cs"
$uiHudAbilityBarEntryPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityBarEntry.cs"
$uiAbilitiesPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Abilities/UIAbilities.cs"
$uiAbilityBarPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Abilities/UIAbilityBar.cs"
$uiCharacterPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Character/UICharacter.cs"
$uiInventoryPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventory.cs"
$uiInventoryBagPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryBag.cs"
$menuFeedbackPromptsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/MenuFeedbackPrompts.cs"
$uiCraftPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Craft/UICraft.cs"
$uiEventLogPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/HUD/EventLog/UIEventLog.cs"
$uiJournalPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Journal/UIJournal.cs"
$uiShopPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/UI/Menus/Shop/UIShop.cs"
$dialogueTreePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueTree.cs"
$dialogueChannelPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueChannel.cs"
$dialogueNodePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueNode.cs"
$dialogueUtilsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueUtils.cs"
$dialogueSequencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Dialogues/DialogueSequence.cs"
$entityPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Entity.cs"
$chestPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Chest.cs"
$interactionTargetPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/IInteractionTarget.cs"
$dialogueInteractionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/DialogueInteraction.cs"
$shopInteractionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/ShopInteraction.cs"
$craftInteractionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/CraftInteraction.cs"
$innInteractionPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Interactions/InnInteraction.cs"
$playDialogueSequenceCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/PlayDialogueSequence.cs"
$playDialogueLineCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/PlayDialogueLine.cs"
$destroyEntityCommandPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Commands/DestroyEntity.cs"
$prefabReferencePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Database/Save/PrefabReference.cs"
$databaseEntryProcessorPath = Join-Path $projectRoot "Assets/Editor/GameCore/Database/DatabaseEntryProcessor.cs"
$databaseRegistryEditorPath = Join-Path $projectRoot "Assets/Editor/GameCore/Editors/DatabaseRegistryEditor.cs"
$formalDataAssetCachePath = Join-Path $projectRoot "Assets/Editor/GameCore/Utils/FormalDataAssetCache.cs"
$sceneUtilPath = Join-Path $projectRoot "Assets/Editor/GameCore/Utils/SceneUtil.cs"
$sceneMenuRegistryPath = Join-Path $projectRoot "Assets/Editor/GameCore/Generated/SceneMenuRegistry.cs"
$generatedSceneMenuPath = Join-Path $projectRoot "Assets/Editor/GameCore/Generated/FWSceneMenu.g.cs"
$audioChannelPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.cs"
$audioChannelFallbackPoolRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.FallbackPoolRuntime.cs"
$audioChannelPlaybackRuntimePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.PlaybackRuntime.cs"
$characterSpawnerPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Spawners/ACharacterSpawner.cs"
$persistablePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.cs"
$persistableContractsPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.Contracts.cs"
$persistableDataBlocksPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.DataBlocks.cs"

$foundationChangeDocsRelativePath = "openspec/changes/define-fantasyword-foundation-framework"
$foundationChangeDocsPath = Join-Path $projectRoot $foundationChangeDocsRelativePath
if (-not (Test-Path -LiteralPath $foundationChangeDocsPath)) {
    $archivedFoundationChangeDocsRelativePath = "openspec/changes/archive/2026-06-22-define-fantasyword-foundation-framework"
    $archivedFoundationChangeDocsPath = Join-Path $projectRoot $archivedFoundationChangeDocsRelativePath
    if (Test-Path -LiteralPath $archivedFoundationChangeDocsPath) {
        $foundationChangeDocsRelativePath = $archivedFoundationChangeDocsRelativePath
        $foundationChangeDocsPath = $archivedFoundationChangeDocsPath
    }
}

$requiredFiles = @(
    "Assets/Scripts/GameCore/Runtime/Game/Systems/AGameSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameManager.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameManager.LifecycleRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameManager.SystemRegistryRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameConfig.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Contracts.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Terms.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameConfig.Persistence.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Lifecycle.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Presentation.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.Inventory.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Progression.Quests.cs",
    "Assets/Scripts/GameCore/Runtime/Events/GameRuntimeEvents.Ui.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Controllers/PlayerCommandRequest.cs",
    "Assets/Scripts/GameCore/Runtime/Controllers/IPlayerInputTarget.cs",
    "Assets/Scripts/GameCore/Runtime/Controllers/PlayerControlGroup.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterPlayerControl.cs",
    "Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityMessage.cs",
    "Assets/Scripts/GameCore/Runtime/Controllers/AIController.cs",
    "Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/QuestInteraction.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/JournalSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Quest/Quest.cs",
    "Assets/Scripts/GameCore/Runtime/Quest/QuestProgress.cs",
    "Assets/Scripts/GameCore/Runtime/Quest/QuestTaskProgress.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/AddExperience.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/AddOrRemoveAbility.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/AddOrRemoveMana.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/HealOrDamagePlayer.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/RevivePlayer.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/MovePlayer.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/OpenShopMenu.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/OpenCraftMenu.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/ExecuteCommandList.cs",
    "Assets/Scripts/GameCore/Runtime/Conditional/Conditions/IsAbilityUnlocked.cs",
    "Assets/Scripts/GameCore/Runtime/Game/GameConfig.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/GameFlagSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.Contracts.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/PersistenceSystem.InstantiationRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/MapInfo.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/ICheckpoint.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/Checkpoint.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/PersistableCheckpoint.cs",
    "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.cs",
    "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.Contracts.cs",
    "Assets/Scripts/GameCore/Runtime/Persistence/Persistable.DataBlocks.cs",
    "Assets/Scripts/GameCore/Runtime/Persistence/PersistableReference.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/ICommand.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/FormalAttributeCatalog.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/CombatStatSnapshot.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ITemporalEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ATemporalEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityEffectSupport.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityGrantEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilitySuppressionEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/TemporalAbilityReplacementEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Movable.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AttributeBootstrapBuffer.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterSheet.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/InventorySystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/InventoryTransferRequest.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/InventoryMenuContext.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Items/Item.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/AItemEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/ItemStartQuestEffect.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Items/ItemEffects/ItemEquipOrUnequip.cs",
    "Assets/Scripts/GameCore/Runtime/Database/DatabaseRegistry.cs",
    "Assets/Scripts/GameCore/Runtime/Database/DatabaseRegistry.Editor.cs",
    "Assets/Scripts/GameCore/Runtime/Database/DatabaseEntry.cs",
    "Assets/Scripts/GameCore/Runtime/Database/DatabaseEntryReference.cs",
    "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueTree.cs",
    "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueChannel.cs",
    "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueNode.cs",
    "Assets/Scripts/GameCore/Runtime/Dialogue/DialogueUtils.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Dialogues/DialogueSequence.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Entity.cs",
    "Assets/Scripts/GameCore/Runtime/Entities/Chest.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/IInteractionTarget.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/DialogueInteraction.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/ShopInteraction.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/CraftInteraction.cs",
    "Assets/Scripts/GameCore/Runtime/Interactions/InnInteraction.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/PlayDialogueSequence.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/PlayDialogueLine.cs",
    "Assets/Scripts/GameCore/Runtime/Commands/DestroyEntity.cs",
    "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.cs",
    "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.FallbackPoolRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.PlaybackRuntime.cs",
    "Assets/Editor/GameCore/Database/DatabaseEntryProcessor.cs",
    "Assets/Editor/GameCore/Editors/DatabaseRegistryEditor.cs",
    "Assets/Editor/GameCore/Utils/FormalDataAssetCache.cs",
    "Assets/Editor/GameCore/Utils/SceneUtil.cs",
    "Assets/Editor/GameCore/Generated/SceneMenuRegistry.cs",
    "Assets/Editor/GameCore/Generated/FWSceneMenu.g.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRegistrationRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuRequestRoutingRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIManager.MenuStackRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuPanelBase.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventory.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryBag.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIGameMenuEntry.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/MenuFeedbackPrompts.cs",
    "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitDeathPanel.cs",
    "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuOpenData.cs",
    "Assets/Scripts/GameCore/Runtime/UI/MenuPanels/UIKitMenuPanelTypeReference.cs",
    "Assets/Editor/GameCore/PropertyDrawers/UIKitMenuPanelTypeReferencePropertyDrawer.cs",
    "Assets/Editor/GameCore/Bridge/FormalSceneInputRootAutomation.cs",
    "scripts/Invoke-FormalSceneInputRootRepair.ps1",
    "Assets/GameRes/UI/Panels/UIGameMenu.prefab",
    "Assets/GameRes/UI/Panels/UICharacter.prefab",
    "Assets/GameRes/UI/Panels/UIAbilities.prefab",
    "Assets/GameRes/UI/Panels/UIInventory.prefab",
    "Assets/GameRes/UI/Panels/UIJournal.prefab",
    "Assets/GameRes/UI/Panels/UIShop.prefab",
    "Assets/GameRes/UI/Panels/UICraft.prefab",
    "Assets/GameRes/UI/Panels/UISave.prefab",
    "Assets/GameRes/UI/Panels/UISettings.prefab",
    "Assets/GameRes/UI/Panels/UIKitDeathPanel.prefab",
    "Assets/Scripts/GameCore/Runtime/UI/UIManager.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIControllerButton.cs",
    "Assets/Scripts/GameCore/Runtime/UI/UIControllerButtonManager.cs",
    "$foundationChangeDocsRelativePath/game-manager-static-access-policy.md",
    "$foundationChangeDocsRelativePath/truth-ownership-implementation-matrix.md",
    "$foundationChangeDocsRelativePath/ui-menu-runtime-ownership-matrix.md",
    "$foundationChangeDocsRelativePath/attribute-gas-ownership-matrix.md",
    "$foundationChangeDocsRelativePath/attribute-field-mapping.md",
    "$foundationChangeDocsRelativePath/save-ownership-matrix.md",
    "$foundationChangeDocsRelativePath/card-mode-ownership-matrix.md"
)

$disallowedLegacyFiles = @(
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuManager.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuManager.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/AUIMenu.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/AUIMenu.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/IUIMenu.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/IUIMenu.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/Death/UIDeath.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/Death/UIDeath.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuStack.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuStack.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuNavigationUtility.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuNavigationUtility.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuRegistry.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Menus/UIMenuRegistry.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.RegistrationRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.RegistrationRuntime.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.RequestRoutingRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.RequestRoutingRuntime.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.StackRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/UIKitMenuHost.StackRuntime.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/MenuHostRuntimeOwnershipGuard.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/MenuHostRuntimeOwnershipGuard.cs.meta",
    "Assets/Scripts/GameCore/Runtime/UI/Host/MenuRouteTopology.cs",
    "Assets/Scripts/GameCore/Runtime/UI/Host/MenuRouteTopology.cs.meta",
    "Assets/Prefabs/UI/Menus",
    "Assets/Prefabs/UI/Menus.meta",
    "Assets/Prefabs/UI/Menus/Craft/Craft Menu.prefab",
    "Assets/Prefabs/UI/Menus/Craft/Craft Menu.prefab.meta",
    "Assets/Prefabs/UI/Menus/Death/Death Menu.prefab",
    "Assets/Prefabs/UI/Menus/Death/Death Menu.prefab.meta",
    "Assets/Prefabs/UI/Menus/Shop/Shop Menu.prefab",
    "Assets/Prefabs/UI/Menus/Shop/Shop Menu.prefab.meta",
    "Assets/Prefabs/UI/MenuParts/Character",
    "Assets/Prefabs/UI/MenuParts/Character.meta",
    "Assets/Prefabs/UI/MenuParts/Craft",
    "Assets/Prefabs/UI/MenuParts/Craft.meta",
    "Assets/Prefabs/UI/MenuParts/Journal",
    "Assets/Prefabs/UI/MenuParts/Journal.meta",
    "Assets/Prefabs/UI/MenuParts/Game Menu",
    "Assets/Prefabs/UI/MenuParts/Game Menu.meta",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/NotificationSystem.cs",
    "Assets/Scripts/GameCore/Runtime/Game/Systems/NotificationSystem.cs.meta",
    "Assets/Tests/EditMode/GameCore/Notifications/NotificationSystemTests.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/GameObjectCheckpoint.cs",
    "Assets/Scripts/GameCore/Runtime/Maps/GameObjectCheckpoint.cs.meta",
    "Assets/Scripts/GameCore/Runtime/Miscellaneous/CoroutineHelpers.cs",
    "Assets/Scripts/GameCore/Runtime/Miscellaneous/CoroutineHelpers.cs.meta"
)

$baselineGameManagerSystemShortcuts = @(
    "AudioSystem",
    "DialogueSystem",
    "GameFlagSystem",
    "GameStateSystem",
    "InputSystem",
    "InventorySystem",
    "JournalSystem",
    "SaveSystem",
    "MapSystem",
    "PlayerSystem",
    "PersistenceSystem",
    "TransitionSystem",
    "UISystem"
)

$missingFiles = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        [void]$missingFiles.Add($fullPath)
    }
}

$legacyExistingFiles = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $disallowedLegacyFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        [void]$legacyExistingFiles.Add($fullPath)
    }
}

$sceneContent = Get-FileContent -Path $scenePath
$formalSceneVersionControlMissingFiles = New-Object System.Collections.Generic.List[string]

foreach ($relativeFormalScenePath in @(
    "Assets/Scenes/SampleScene.unity",
    "Assets/Scenes/SampleScene.unity.meta"
)) {
    if (-not (Test-IsGitTrackedFile -ProjectRoot $projectRoot -RelativePath $relativeFormalScenePath)) {
        [void]$formalSceneVersionControlMissingFiles.Add($relativeFormalScenePath)
    }
}
$gameConfigContent = Get-FileContent -Path $gameConfigAssetPath
$databaseRegistryContent = Get-FileContent -Path $databaseRegistryAssetPath
$databaseRegistryCodeContent = Get-FileContent -Path $databaseRegistryCodePath
$manifestContent = Get-FileContent -Path $manifestPath
$gameManagerContent = Get-FileContent -Path $gameManagerPath
$gameManagerLifecycleRuntimeContent = Get-FileContent -Path $gameManagerLifecycleRuntimePath
$gameManagerSystemRegistryRuntimeContent = Get-FileContent -Path $gameManagerSystemRegistryRuntimePath
$gameManagerCompositeContent = @(
    $gameManagerContent
    $gameManagerLifecycleRuntimeContent
    $gameManagerSystemRegistryRuntimeContent
) -join [Environment]::NewLine
$gameConfigRuntimeContent = Get-FileContent -Path $gameConfigRuntimePath
$gameConfigContractsContent = Get-FileContent -Path $gameConfigContractsPath
$gameConfigTermsContent = Get-FileContent -Path $gameConfigTermsPath
$gameConfigPersistenceContent = Get-FileContent -Path $gameConfigPersistencePath
$gameCommandContextContent = Get-FileContent -Path $gameCommandContextPath
$gameRuntimeEventsContent = Get-FileContent -Path $gameRuntimeEventsPath
$gameRuntimeEventsLifecycleContent = Get-FileContent -Path $gameRuntimeEventsLifecyclePath
$gameRuntimeEventsPresentationContent = Get-FileContent -Path $gameRuntimeEventsPresentationPath
$gameRuntimeEventsProgressionContent = Get-FileContent -Path $gameRuntimeEventsProgressionPath
$gameRuntimeEventsProgressionInventoryContent = Get-FileContent -Path $gameRuntimeEventsProgressionInventoryPath
$gameRuntimeEventsProgressionQuestsContent = Get-FileContent -Path $gameRuntimeEventsProgressionQuestsPath
$gameRuntimeEventsUiContent = Get-FileContent -Path $gameRuntimeEventsUiPath
$gameRuntimeEventsCompositeContent = @(
    $gameRuntimeEventsContent
    $gameRuntimeEventsLifecycleContent
    $gameRuntimeEventsPresentationContent
    $gameRuntimeEventsProgressionContent
    $gameRuntimeEventsProgressionInventoryContent
    $gameRuntimeEventsProgressionQuestsContent
    $gameRuntimeEventsUiContent
) -join [Environment]::NewLine
$inputSystemContent = Get-FileContent -Path $inputSystemPath
$playerCommandRequestContent = Get-FileContent -Path $playerCommandRequestPath
$playerOrderRequestContent = Get-FileContent -Path $playerOrderRequestPath
$playerInputTargetContent = Get-FileContent -Path $playerInputTargetPath
$playerControlGroupContent = Get-FileContent -Path $playerControlGroupPath
$characterPlayerControlContent = Get-FileContent -Path $characterPlayerControlPath
$uiHudAbilityMessageContent = Get-FileContent -Path $uiHudAbilityMessagePath
$aiControllerContent = Get-FileContent -Path $aiControllerPath
$aiControllerBehaviourRuntimeContent = Get-FileContent -Path $aiControllerBehaviourRuntimePath
$playerSystemContent = Get-FileContent -Path $playerSystemPath
$questInteractionContent = Get-FileContent -Path $questInteractionPath
$journalSystemContent = Get-FileContent -Path $journalSystemPath
$questContent = Get-FileContent -Path $questPath
$questProgressContent = Get-FileContent -Path $questProgressPath
$questTaskProgressContent = Get-FileContent -Path $questTaskProgressPath
$addExperienceCommandContent = Get-FileContent -Path $addExperienceCommandPath
$addOrRemoveAbilityCommandContent = Get-FileContent -Path $addOrRemoveAbilityCommandPath
$addOrRemoveItemCommandContent = Get-FileContent -Path $addOrRemoveItemCommandPath
$addOrRemoveManaCommandContent = Get-FileContent -Path $addOrRemoveManaCommandPath
$healOrDamagePlayerCommandContent = Get-FileContent -Path $healOrDamagePlayerCommandPath
$revivePlayerCommandContent = Get-FileContent -Path $revivePlayerCommandPath
$movePlayerCommandContent = Get-FileContent -Path $movePlayerCommandPath
$openShopMenuCommandContent = Get-FileContent -Path $openShopMenuCommandPath
$openCraftMenuCommandContent = Get-FileContent -Path $openCraftMenuCommandPath
$executeCommandListContent = Get-FileContent -Path $executeCommandListPath
$isAbilityUnlockedConditionContent = Get-FileContent -Path $isAbilityUnlockedConditionPath
$gameStateSystemContent = Get-FileContent -Path $gameStateSystemPath
$mapSystemContent = Get-FileContent -Path $mapSystemPath
$persistenceSystemContent = Get-FileContent -Path $persistenceSystemPath
$persistenceSystemContractsContent = Get-FileContent -Path $persistenceSystemContractsPath
$persistenceSystemInstantiationRuntimeContent = Get-FileContent -Path $persistenceSystemInstantiationRuntimePath
$stateMessageDispatcherContent = Get-FileContent -Path $stateMessageDispatcherPath
$animationStrategyContent = Get-FileContent -Path $animationStrategyPath
$formalAttributeCatalogContent = Get-FileContent -Path $formalAttributeCatalogPath
$characterAlterationRuleContent = Get-FileContent -Path $characterAlterationRulePath
$temporalEffectInterfaceContent = Get-FileContent -Path $temporalEffectInterfacePath
$temporalEffectBaseContent = Get-FileContent -Path $temporalEffectBasePath
$temporalAbilityEffectSupportContent = Get-FileContent -Path $temporalAbilityEffectSupportPath
$temporalAbilityGrantEffectContent = Get-FileContent -Path $temporalAbilityGrantEffectPath
$temporalAbilitySuppressionEffectContent = Get-FileContent -Path $temporalAbilitySuppressionEffectPath
$temporalAbilityReplacementEffectContent = Get-FileContent -Path $temporalAbilityReplacementEffectPath
$temporalStatModifierEffectContent = Get-FileContent -Path $temporalStatModifierEffectPath
$movableContent = Get-FileContent -Path $movablePath
$characterBaseContent = Get-FileContent -Path $characterBasePath
$characterBaseGasRuntimeContent = Get-FileContent -Path $characterBaseGasRuntimePath
$characterBaseContractsContent = Get-FileContent -Path $characterBaseContractsPath
$characterBaseResourcesContent = Get-FileContent -Path $characterBaseResourcesPath
$characterBaseAbilitiesContent = Get-FileContent -Path $characterBaseAbilitiesPath
$characterBaseAlterationsContent = Get-FileContent -Path $characterBaseAlterationsPath
$characterBaseStateApiContent = Get-FileContent -Path $characterBaseStateApiPath
$characterBasePersistenceContent = Get-FileContent -Path $characterBasePersistencePath
$characterBaseAttributeBootstrapBufferContent = Get-FileContent -Path $characterBaseAttributeBootstrapBufferPath
$characterBaseActionStateRuntimeContent = Get-FileContent -Path $characterBaseActionStateRuntimePath
$characterBaseAbilitySetRuntimeContent = Get-FileContent -Path $characterBaseAbilitySetRuntimePath
$characterBaseTemporalEffectRuntimeContent = Get-FileContent -Path $characterBaseTemporalEffectRuntimePath
$characterActorContent = Get-FileContent -Path $characterActorPath
$characterActorRewardsContent = Get-FileContent -Path $characterActorRewardsPath
$characterSheetContent = Get-FileContent -Path $characterSheetPath
$characterEquippedItemLoadoutContent = Get-FileContent -Path $characterEquippedItemLoadoutPath
$characterEquippedAbilityLoadoutContent = Get-FileContent -Path $characterEquippedAbilityLoadoutPath
$inventorySystemContent = Get-FileContent -Path $inventorySystemPath
$inventoryTransferRequestContent = Get-FileContent -Path $inventoryTransferRequestPath
$inventoryMenuContextContent = Get-FileContent -Path $inventoryMenuContextPath
$itemContent = Get-FileContent -Path $itemPath
$itemEffectBaseContent = Get-FileContent -Path $itemEffectBasePath
$itemStartQuestEffectContent = Get-FileContent -Path $itemStartQuestEffectPath
$itemEquipOrUnequipContent = Get-FileContent -Path $itemEquipOrUnequipPath
$activeAbilityBaseContent = Get-FileContent -Path $activeAbilityBasePath
$projectileContent = Get-FileContent -Path $projectilePath
$projectilePersistenceContent = Get-FileContent -Path $projectilePersistencePath
$projectileCompositeContent = @(
    $projectileContent
    $projectilePersistenceContent
) -join "`n"
$perTargetCooldownContent = Get-FileContent -Path $perTargetCooldownPath
$uiManagerContent = Get-FileContent -Path $uiManagerPath
$uiManagerMenuRuntimeContent = Get-FileContent -Path $uiManagerMenuRuntimePath
$uiManagerMenuRegistrationRuntimeContent = Get-FileContent -Path $uiManagerMenuRegistrationRuntimePath
$uiManagerMenuRequestRoutingRuntimeContent = Get-FileContent -Path $uiManagerMenuRequestRoutingRuntimePath
$uiManagerMenuStackRuntimeContent = Get-FileContent -Path $uiManagerMenuStackRuntimePath
$uiManagerMenuCompositeContent = @(
    $uiManagerContent
    $uiManagerMenuRuntimeContent
    $uiManagerMenuRegistrationRuntimeContent
    $uiManagerMenuRequestRoutingRuntimeContent
    $uiManagerMenuStackRuntimeContent
) -join [Environment]::NewLine
$uiKitDeathPanelContent = Get-FileContent -Path $uiKitDeathPanelPath
$uiKitMenuPanelTypeReferenceContent = Get-FileContent -Path $uiKitMenuPanelTypeReferencePath
$uiKitMenuPanelTypeReferenceDrawerContent = Get-FileContent -Path $uiKitMenuPanelTypeReferenceDrawerPath
$formalSceneInputHostAutomationContent = Get-FileContent -Path $formalSceneInputHostAutomationPath
$formalSceneInputHostRepairScriptContent = Get-FileContent -Path $formalSceneInputHostRepairScriptPath
$uiPrefabContent = Get-FileContent -Path $uiPrefabPath
$characterBasePrefabContent = Get-FileContent -Path $characterBasePrefabPath
$uiKitDeathPrefabContent = Get-FileContent -Path $uiKitDeathPrefabPath
$uiControllerButtonContent = Get-FileContent -Path $uiControllerButtonPath
$uiControllerButtonManagerContent = Get-FileContent -Path $uiControllerButtonManagerPath
$uiStatBarContent = Get-FileContent -Path $uiStatBarPath
$uiDialogueMessageBoxContent = Get-FileContent -Path $uiDialogueMessageBoxPath
$uiEffectListContent = Get-FileContent -Path $uiEffectListPath
$uiHudAbilityBarContent = Get-FileContent -Path $uiHudAbilityBarPath
$uiHudAbilityBarEntryContent = Get-FileContent -Path $uiHudAbilityBarEntryPath
$uiAbilitiesContent = Get-FileContent -Path $uiAbilitiesPath
$uiAbilityBarContent = Get-FileContent -Path $uiAbilityBarPath
$uiCharacterContent = Get-FileContent -Path $uiCharacterPath
$uiInventoryContent = Get-FileContent -Path $uiInventoryPath
$uiInventoryBagContent = Get-FileContent -Path $uiInventoryBagPath
$uiGameMenuEntryContent = Get-FileContent -Path $uiGameMenuEntryPath
$menuFeedbackPromptsContent = Get-FileContent -Path $menuFeedbackPromptsPath
$uiCraftContent = Get-FileContent -Path $uiCraftPath
$uiEventLogContent = Get-FileContent -Path $uiEventLogPath
$uiJournalContent = Get-FileContent -Path $uiJournalPath
$uiShopContent = Get-FileContent -Path $uiShopPath
$dialogueTreeContent = Get-FileContent -Path $dialogueTreePath
$dialogueChannelContent = Get-FileContent -Path $dialogueChannelPath
$dialogueNodeContent = Get-FileContent -Path $dialogueNodePath
$dialogueUtilsContent = Get-FileContent -Path $dialogueUtilsPath
$dialogueSequenceContent = Get-FileContent -Path $dialogueSequencePath
$entityContent = Get-FileContent -Path $entityPath
$chestContent = Get-FileContent -Path $chestPath
$interactionTargetContent = Get-FileContent -Path $interactionTargetPath
$dialogueInteractionContent = Get-FileContent -Path $dialogueInteractionPath
$shopInteractionContent = Get-FileContent -Path $shopInteractionPath
$craftInteractionContent = Get-FileContent -Path $craftInteractionPath
$innInteractionContent = Get-FileContent -Path $innInteractionPath
$playDialogueSequenceCommandContent = Get-FileContent -Path $playDialogueSequenceCommandPath
$playDialogueLineCommandContent = Get-FileContent -Path $playDialogueLineCommandPath
$destroyEntityCommandContent = Get-FileContent -Path $destroyEntityCommandPath
$databaseEntryProcessorContent = Get-FileContent -Path $databaseEntryProcessorPath
$databaseRegistryEditorContent = Get-FileContent -Path $databaseRegistryEditorPath
$formalDataAssetCacheContent = Get-FileContent -Path $formalDataAssetCachePath
$sceneUtilContent = Get-FileContent -Path $sceneUtilPath
$sceneMenuRegistryContent = Get-FileContent -Path $sceneMenuRegistryPath
$generatedSceneMenuContent = Get-FileContent -Path $generatedSceneMenuPath
$audioChannelContent = Get-FileContent -Path $audioChannelPath
$audioChannelFallbackPoolRuntimeContent = Get-FileContent -Path $audioChannelFallbackPoolRuntimePath
$audioChannelPlaybackRuntimeContent = Get-FileContent -Path $audioChannelPlaybackRuntimePath
$persistableContent = Get-FileContent -Path $persistablePath
$persistableContractsContent = Get-FileContent -Path $persistableContractsPath
$persistableDataBlocksContent = Get-FileContent -Path $persistableDataBlocksPath

$sceneMissingPatterns = @(
    (Test-ContainsAll -Content $sceneContent -Patterns @(
        "m_Name: Game Manager",
        "FantasyWord.GameCore::FantasyWord.GameCore.GameManager",
        "m_Name: Main Camera",
        "m_TagString: MainCamera",
        "AudioListener:",
        "orthographic: 1",
        "m_primaryPlayerCharacter: {fileID:",
        "m_SourcePrefab: {fileID: 100100000, guid: f32187b1edab1484a99d97ef54021bf5, type: 3}",
        "m_config: {fileID: 11400000, guid: b669f9c81be34b47bf3d083609477ab5, type: 2}",
        "guid: e20381a1779a446fa50ceb2fe6ef78ba",
        "guid: b669f9c81be34b47bf3d083609477ab5"
    ))
) | ForEach-Object { $_ }

$formalSceneExplicitInputHostPatterns = @(
    "m_Name: EventSystem",
    "Unity.InputSystem::UnityEngine.InputSystem.UI.InputSystemUIInputModule",
    "UnityEngine.UI::UnityEngine.EventSystems.EventSystem"
)

$sampleSceneHasExplicitInputRoot = @(
    Test-ContainsAll -Content $sceneContent -Patterns $formalSceneExplicitInputHostPatterns
).Count -eq 0

$formalSceneExplicitInputHostMissingScenes = New-Object System.Collections.Generic.List[string]
if (-not $sampleSceneHasExplicitInputRoot) {
    [void]$formalSceneExplicitInputHostMissingScenes.Add("Assets/Scenes/SampleScene.unity")
}

$formalSceneMainCameraPatterns = @(
    "m_Name: Main Camera",
    "m_TagString: MainCamera",
    "AudioListener:",
    "orthographic: 1"
)

$sampleSceneHasFormalMainCamera = @(
    Test-ContainsAll -Content $sceneContent -Patterns $formalSceneMainCameraPatterns
).Count -eq 0

$formalSceneMainCameraMissingScenes = New-Object System.Collections.Generic.List[string]
if (-not $sampleSceneHasFormalMainCamera) {
    [void]$formalSceneMainCameraMissingScenes.Add("Assets/Scenes/SampleScene.unity")
}
$formalSceneContent = $sceneContent
$sceneDisallowedPatterns = Test-ContainsAny -Content $formalSceneContent -Patterns @(
    "m_dummyPlayerPrefab",
    "FantasyWord.GameCore.Runtime.Foundation.FantasyWordBootstrapper",
    "FantasyWord.GameCore.Runtime.Foundation.FantasyWordModuleInstaller",
    "m_Name: Notification System",
    "m_delegateTransitionResponsability:",
    "guid: ddc279a934b8b6e42abd5cb68989d59d",
    "guid: 4ee5c86dc6ad4b13bfb26ce9b28418d6",
    "guid: 346912509b514a519d08c9a54775b648",
    "guid: 374251dca6ec4512999e420293211d1b",
    "guid: d9a5a9a0f446451fb6f433dfd6ad2776",
    "guid: 5743acbbaf4547649636fe93d815bc30",
    "guid: 61a1199899f3425aa6992e7c1e3daf77",
    "guid: 1081e95dc6534b298c3388ceee721df8"
)

$gameConfigMissingPatterns = Test-ContainsAll -Content $gameConfigContent -Patterns @(
    "FantasyWord.GameCore::FantasyWord.GameCore.GameConfig",
    "databaseRegistry: {fileID: 11400000, guid: 22e4581d16f747d58f89ef7b435a9e9e, type: 2}",
    "interactionLayer: Interaction",
    "hitboxLayer: Hitbox",
    "collisionContactFilter:",
    "useLayerMask: 1",
    "m_Bits: 7752",
    "visibilityContactFilter:",
    "m_Bits: 3144"
)

$gameConfigRuntimeMissingPatterns = Test-ContainsAll -Content $gameConfigRuntimeContent -Patterns @(
    "public partial class GameConfig : DatabaseEntry",
    '[SerializeField, FormerlySerializedAs("databaseRegistry")]',
    "private DatabaseRegistry m_databaseRegistry = null;",
    "public string mainMenuSceneName => m_mainMenuSceneName;",
    "public ContactFilter2D collisionContactFilter => m_collisionContactFilter;",
    "public AudioClipResolver submitSound => m_submitSound;",
    "internal DatabaseRegistry GetDatabaseRegistry()"
)

$gameConfigRuntimeDisallowedPatterns = Test-ContainsAny -Content $gameConfigRuntimeContent -Patterns @(
    "private readonly TermDefinition m_defaultTermDefinition = new()",
    "public TermDefinition GetTermDefinition(",
    "private SaveFile m_playtestSaveFile = null;",
    "private ICommand m_toExecuteOnPlayerDeath = null;",
    "private SerializableDictionary<string, string> m_persistentIdentifierMappings = new();",
    "public SaveDataBlock CreatePlaytestSaveDataSnapshot()",
    "public bool TryGetPersistentIdentifierMapping(",
    "public string GetActualPersistentIdentifier("
)

$gameConfigContractsMissingPatterns = Test-ContainsAll -Content $gameConfigContractsContent -Patterns @(
    "public enum EOptionalCharacterStatistics",
    "public enum ECameraShakeSources",
    "public enum EGameTerm",
    "public struct StatSettings",
    "public struct TermDefinition"
)

$gameConfigTermsMissingPatterns = Test-ContainsAll -Content $gameConfigTermsContent -Patterns @(
    "public partial class GameConfig",
    '[Header("Game Terms")]',
    "private readonly TermDefinition m_defaultTermDefinition = new()",
    "public TermDefinition GetTermDefinition(string termID)",
    "public TermDefinition GetStatIncreaseTermDefinition(EStat stat)",
    "public TermDefinition GetStatDecreaseTermDefinition(EStat stat)",
    "public TermDefinition GetTermDefinition(EAbilityType abilityType)"
)

$gameConfigPersistenceMissingPatterns = Test-ContainsAll -Content $gameConfigPersistenceContent -Patterns @(
    "public partial class GameConfig",
    '[Header("Playtest Settings")]',
    "private SaveFile m_playtestSaveFile = null;",
    "private ICommand m_toExecuteOnPlayerDeath = null;",
    "private SerializableDictionary<string, string> m_persistentIdentifierMappings = new();",
    "public bool hasPlayerDeathAction => m_toExecuteOnPlayerDeath != null;",
    "public void ExecutePlayerDeathAction(GameCommandContext context)",
    "m_toExecuteOnPlayerDeath.ExecuteFireAndReport(context, nameof(GameConfig), this);",
    "public SaveDataBlock CreatePlaytestSaveDataSnapshot()",
    "public bool TryGetPersistentIdentifierMapping(string identifier, out string actualIdentifier)",
    "public string GetActualPersistentIdentifier(string identifier)"
)

$databaseRegistryMissingPatterns = Test-ContainsAll -Content $databaseRegistryContent -Patterns @(
    "FantasyWord.GameCore::FantasyWord.GameCore.DatabaseRegistry",
    "m_autoAddNewDatabaseEntries: 1",
    "m_autoRemoveDatabaseEntries: 1",
    "m_entries:",
    "m_GUIDConversionMap:"
)

$databaseRegistryRuntimeDisallowedPatterns = Test-ContainsAny -Content $databaseRegistryCodeContent -Patterns @(
    "public void SetEntries(",
    "public void Register(DatabaseEntry entry)",
    "public void Unregister(DatabaseEntry entry)",
    "public void RemoveAt(string guid)",
    "public int RemoveMissingReferences()",
    "public void ClearEntries()",
    "public void RemoveConversion(string from)",
    "public void SetConversion(string from, string to)"
)

$databaseRegistryEditorMissingPatterns = Test-ContainsAll -Content $databaseRegistryEditorContent -Patterns @(
    "private static DatabaseEntry[] GetFormalDatabaseEntries()",
    "return FormalDataAssetCache.CreateAssignableAssetSnapshot<DatabaseEntry>();",
    "registry.SetEntries(GetFormalDatabaseEntries());",
    "GetFormalDatabaseEntries()",
    "Assets/GameData"
)

$databaseRegistryEditorDisallowedPatterns = Test-ContainsAny -Content $databaseRegistryEditorContent -Patterns @(
    "Resources.FindObjectsOfTypeAll<DatabaseEntry>()"
)

$databaseEntryProcessorMissingPatterns = Test-ContainsAll -Content $databaseEntryProcessorContent -Patterns @(
    ".Where(FormalDataAssetCache.IsFormalDataAssetPath)",
    ".Select(AssetDatabase.LoadAssetAtPath<DatabaseEntry>)",
    ".Select(AssetDatabase.AssetPathToGUID)"
)

$audioChannelMissingPatterns = Test-ContainsAll -Content $audioChannelContent -Patterns @(
    "private FallbackPoolRuntime m_fallbackPoolRuntime = null;",
    "private PlaybackRuntime m_playbackRuntime = null;",
    "private FallbackPoolRuntime fallbackPoolRuntime => m_fallbackPoolRuntime ??= new FallbackPoolRuntime(this);",
    "private PlaybackRuntime playbackRuntime => m_playbackRuntime ??= new PlaybackRuntime(this);",
    "fallbackPoolRuntime.Initialize();",
    "m_fallbackPoolRuntime?.Dispose();",
    "playbackRuntime.PlayBroAudio(soundId, position, followTarget, onCompleted);",
    "playbackRuntime.PlayExclusiveClip(audioClip, onCompleted);",
    "playbackRuntime.PlayFallbackClip(audioClip, position, followTarget, onCompleted);"
)

$audioChannelDisallowedPatterns = Test-ContainsAny -Content $audioChannelContent -Patterns @(
    "private readonly Queue<AudioChannelFallbackPlayer>",
    "private readonly List<AudioChannelFallbackPlayer>",
    "private readonly List<IAudioPlayer>",
    "private readonly HashSet<IAudioPlayer>",
    "private Coroutine m_transitionCoroutine",
    "private Coroutine m_completionCoroutine",
    "private SoundID m_lastPlayedSoundId"
)

$audioChannelFallbackPoolRuntimeMissingPatterns = Test-ContainsAll -Content $audioChannelFallbackPoolRuntimeContent -Patterns @(
    "private sealed class FallbackPoolRuntime",
    "private readonly Queue<AudioChannelFallbackPlayer> m_inactivePlayers = new();",
    "private readonly List<AudioChannelFallbackPlayer> m_activePlayers = new();",
    "public bool TryPlay(",
    "private AudioChannelFallbackPlayer RentPlayer()",
    "private void RecyclePlayer(AudioChannelFallbackPlayer player, bool stopPlayback)",
    "private void PrewarmPlayers()"
)

$audioChannelPlaybackRuntimeMissingPatterns = Test-ContainsAll -Content $audioChannelPlaybackRuntimeContent -Patterns @(
    "private sealed class PlaybackRuntime",
    "private readonly List<IAudioPlayer> m_activeBroAudioPlayers = new();",
    "private readonly HashSet<IAudioPlayer> m_suppressedBroAudioCompletionPlayers = new();",
    "public void PlayBroAudio(",
    "public void PlayExclusiveClip(AudioClip audioClip, Action onCompleted)",
    "public void PlayFallbackClip(",
    "private void PreservePauseStateWhileStoppingIfExclusive()",
    "private IEnumerator FadeOutAndIn(AudioClip newClip, Action onCompleted)"
)

$persistableMissingPatterns = Test-ContainsAll -Content $persistableContent -Patterns @(
    "public class Persistable : MonoBehaviour, IDataBlockHandler<PersistableDataBlock>",
    "[SerializeReference, HideInInspector] private APersistenceInfo m_persistenceInfo = null;",
    "private UnityEvent m_destroyedEvent = new();",
    "public void AddDestroyedListener(UnityAction listener)",
    "public void RemoveDestroyedListener(UnityAction listener)",
    "public string GetPersistentIdentifier()",
    "public APersistenceInfo EditorPersistenceInfo",
    "public void MakeRuntimeInstanced(PrefabReference instance, string identifier)",
    "public PersistableDataBlock CreateDataBlock()",
    "private void NotifyPersistenceSystemAboutDestruction()",
    "private EPersistableOwnershipKind GetOwnershipKind()"
)

$persistableDisallowedPatterns = Test-ContainsAny -Content $persistableContent -Patterns @(
    "public enum EPersistableObjectState",
    "public interface APersistenceInfo",
    "public interface IIdentifiablePersistentDataHandler",
    "public class PreInstancedPersistentDataHandler",
    "public class RuntimeInstancedPersistentDataHandler",
    "public class CustomInstancedPersistentDataHandler",
    "public class ManualPersistentDataHandler",
    "public class PersistableDataBlock : DataBlock",
    "public enum EPersistableOwnershipKind",
    "public readonly struct PersistableDestructionSnapshot"
)

$persistableContractsMissingPatterns = Test-ContainsAll -Content $persistableContractsContent -Patterns @(
    "public interface APersistenceInfo",
    "public interface IIdentifiablePersistentDataHandler",
    "public class PreInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler",
    "public class RuntimeInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler",
    "public class CustomInstancedPersistentDataHandler : APersistenceInfo, IIdentifiablePersistentDataHandler",
    "public enum EPersistableOwnershipKind"
)

$persistableDataBlocksMissingPatterns = Test-ContainsAll -Content $persistableDataBlocksContent -Patterns @(
    "public enum EPersistableObjectState",
    "public class PersistableDataBlock : DataBlock",
    "[SerializeReference, HideInInspector] public APersistenceInfo info = null;",
    "public readonly struct PersistableDestructionSnapshot",
    "public PersistableDataBlock DataBlock { get; }",
    "public bool IsPreInstanced => OwnershipKind == EPersistableOwnershipKind.PreInstanced;",
    "public bool IsRuntimeInstanced => OwnershipKind == EPersistableOwnershipKind.RuntimeInstanced;"
)

$persistableDestroyPersistenceSystemMissingPatterns = @(
    Test-MethodContainsAll -Content $persistableContent -MethodName "private void NotifyPersistenceSystemAboutDestruction()" -Patterns @(
        "PersistableDataBlock dataBlock = IsPersistent() ? CreateDataBlock() : null;",
        "GameManager.PersistenceSystem.NotifyPersistableDestroyed(",
        "GetPersistentIdentifier(),",
        "GetOwnershipKind(),",
        "IsAutomaticallyPersisted()));"
    )
)

$persistableDestroyPersistenceSystemDisallowedPatterns = @(
    Test-MethodContainsAny -Content $persistableContent -MethodName "private void NotifyPersistenceSystemAboutDestruction()" -Patterns @(
        "GameManager.Exists()",
        "TryGetSystem",
        "return;"
    )
)

$formalDataAssetCacheMissingPatterns = Test-ContainsAll -Content $formalDataAssetCacheContent -Patterns @(
    'private const string FormalDataRoot = "Assets/GameData";',
    'static readonly string[] SearchRoots = { FormalDataRoot };',
    'public static T[] CreateAssignableAssetSnapshot<T>() where T : ScriptableObject',
    'public static ScriptableObject[] CreateAssignableAssetSnapshot(Type type)',
    'return (ScriptableObject[])assets.Clone();',
    'foreach (string guid in AssetDatabase.FindAssets($"t:{concreteType.Name}", SearchRoots))',
    'ScriptableObject asset = AssetDatabase.LoadAssetAtPath<ScriptableObject>(path);',
    'internal static bool IsFormalDataAssetPath(string assetPath)',
    'return assetPath.StartsWith($"{FormalDataRoot}/", StringComparison.OrdinalIgnoreCase)',
    '|| string.Equals(assetPath, FormalDataRoot, StringComparison.OrdinalIgnoreCase);'
)

$formalDataAssetCacheDisallowedPatterns = Test-ContainsAny -Content $formalDataAssetCacheContent -Patterns @(
    'AssetDatabase.FindAssets($"t:{concreteType.Name}")',
    'assetPath.StartsWith("Assets/", StringComparison.OrdinalIgnoreCase)',
    'public static IReadOnlyList<T> GetAssetsAssignableTo<T>() where T : ScriptableObject',
    'public static IReadOnlyList<ScriptableObject> GetAssetsAssignableTo(Type type)',
    'return assets;'
)

$manifestMissingPatterns = Test-ContainsAll -Content $manifestContent -Patterns @(
    '"com.aibridge.unity": "file:com.aibridge.unity"',
    '"com.ami.broaudio": "file:com.ami.broaudio"',
    '"com.unity.addressables": "2.9.0"',
    '"com.unity.cinemachine": "3.1.6"',
    '"com.unity.inputsystem": "1.18.0"',
    '"com.unity.nuget.newtonsoft-json": "3.2.2"',
    '"com.unity.render-pipelines.universal": "17.3.0"'
)

$gameManagerMissingPatterns = Test-ContainsAll -Content $gameManagerCompositeContent -Patterns @(
    "[SerializeField] private GameConfig m_config = null;",
    "private Dictionary<Type, AGameSystem> m_systems = null;",
    "private bool m_lifecycleEventsEnabled = false;",
    "public static AudioSystem AudioSystem => GetSystem<AudioSystem>();",
    "public static UISystem UISystem => GetSystem<UISystem>();",
    "GameRuntimeEvents.PublishMapLoading();",
    "GameRuntimeEvents.PublishMapLoaded();",
    "GameRuntimeEvents.PublishMapUnloading();",
    "GameRuntimeEvents.PublishMapUnloaded();",
    "GameRuntimeEvents.PublishSaveFileLoaded();",
    "internal static void DispatchMapLoadingLifecycle()",
    "internal static void DispatchSaveFileLoadedLifecycle()"
)

$gameManagerDisallowedPatterns = Test-ContainsAny -Content $gameManagerCompositeContent -Patterns @(
    "public static NotificationSystem NotificationSystem =>",
    "GetSystem<NotificationSystem>()",
    "public static GasSystem ",
    "public static AbilitySystem ",
    "public static CardSystem ",
    "public static DeckSystem ",
    "public static BoardSystem ",
    "public static AutoBattlerSystem ",
    "public static WorldSystem ",
    "public static WorldContext ",
    "public static WorldRuntime ",
    "public static ModeRuntime ",
    "GetSystem<GasSystem>()",
    "GetSystem<AbilitySystem>()",
    "GetSystem<CardSystem>()",
    "GetSystem<DeckSystem>()",
    "GetSystem<BoardSystem>()",
    "GetSystem<AutoBattlerSystem>()",
    "GetSystem<WorldSystem>()",
    "GetSystem<ModeRuntime>()"
)

$gameRuntimeEventsMissingPatterns = Test-ContainsAll -Content $gameRuntimeEventsCompositeContent -Patterns @(
    "public readonly struct MapLoadingEvent",
    "public readonly struct SaveFileLoadedEvent",
    "public readonly struct GameFlagChangedEvent",
    "public readonly struct MapTransitionStartedEvent",
    "public readonly struct AudioPlaybackRequestedEvent",
    "public readonly struct DamageTakenPresentationEvent",
    "public readonly struct HealthRecoveredPresentationEvent",
    "public readonly struct ManaConsumedPresentationEvent",
    "public readonly struct ManaRecoveredPresentationEvent",
    "public readonly struct TemporalEffectPresentationEvent",
    "public readonly struct DeathPresentationEvent",
    "public readonly struct LootPresentationEvent",
    "public readonly struct PickupPresentationEvent",
    "public readonly struct InteractionPresentationEvent",
    "public readonly struct PlayerAbilityFireFailedEvent",
    "public readonly struct LocalPlayerCommandFailedEvent",
    "public readonly struct CharacterKilledEvent",
    "public readonly struct CharacterExperienceGainedEvent",
    "public readonly struct CharacterLevelUpEvent",
    "public readonly struct InventoryMoneyAddedEvent",
    "public readonly struct InventoryItemAddedEvent",
    "public readonly struct CharacterAbilityAddedEvent",
    "public readonly struct QuestProgressionUpdatedEvent",
    "public readonly struct MenuRequestedEvent",
    "public readonly struct ShopRequestedEvent",
    "public readonly struct CraftRequestedEvent",
    "public readonly struct CloseAllMenusRequestedEvent",
    "public readonly struct ItemDetailsOpenedEvent",
    "public readonly struct ItemDetailsClosedEvent",
    "public static void NotifyMapLoading()",
    "public static void NotifySaveFileLoaded()",
    "public static void NotifyGameFlagChanged(string variableName, bool value)",
    "public static void NotifyMapTransitionStarted()",
    "public static void RequestAudioPlayback(AudioClipResolver audioClipResolver)",
    "public static void NotifyDamageTakenPresentation(DamageTakenFeedbackContext context)",
    "public static void NotifyHealthRecoveredPresentation(CharacterValuePresentationContext context)",
    "public static void NotifyManaConsumedPresentation(CharacterValuePresentationContext context)",
    "public static void NotifyManaRecoveredPresentation(CharacterValuePresentationContext context)",
    "public static void NotifyTemporalEffectPresentation(TemporalEffectPresentationContext context)",
    "public static void NotifyDeathPresentation(DeathPresentationContext context)",
    "public static void NotifyLootPresentation(LootPresentationContext context)",
    "public static void NotifyPickupPresentation(PickupPresentationContext context)",
    "public static void NotifyInteractionPresentation(InteractionPresentationContext context)",
    "public static void NotifyLocalPlayerCommandFailed(PlayerCommandResult result)",
    "public static void NotifyCharacterKilled(CharacterSheet character)",
    "public static void NotifyQuestCompleted(Quest quest)",
    "public static void RequestMenu(EMenu menu, TaskCompletionSource<bool> menuClosedTask = null)",
    "public static void RequestShop(Shop shop, TaskCompletionSource<bool> menuClosedTask = null)",
    "public static void RequestCraft(CraftingStation craftingStation, TaskCompletionSource<bool> menuClosedTask = null)",
    "public static void RequestCloseAllMenus()",
    "public static void NotifyItemDetailsOpened(Item item)",
    "public static void NotifyItemDetailsClosed()"
)

$gameRuntimeEventsDisallowedPatterns = Test-ContainsAny -Content $gameRuntimeEventsCompositeContent -Patterns @(
    "NotificationSystem",
    "menuShowed",
    "menuHid",
    "PersistableDestroyedEvent",
    "AITargetDetectedEvent",
    "PlayerSpawnedEvent",
    "HeroKilledEvent",
    "NotifyPersistableDestroyed(",
    "NotifyAITargetDetected(",
    "NotifyPlayerSpawned(",
    "NotifyHeroKilled(",
    "EquipmentEquippedEvent",
    "EquipmentUnequippedEvent",
    "NotifyEquipmentEquipped(",
    "NotifyEquipmentUnequipped("
)

$inputSystemMissingPatterns = Test-ContainsAll -Content $inputSystemContent -Patterns @(
    "private readonly InputActionReleaseGate m_actionMapReleaseGate = new();",
    "private EActionMap m_currentActionMap = EActionMap.None;",
    "BaseInputModule inputModule = GameManager.EventSystem.GetComponent<BaseInputModule>();",
    "inputModule.enabled = canProcessUiInputs;",
    "IsBlocked(context.action)",
    "private event System.Action m_controlsChanged;",
    "public void AddControlsChangedListener(System.Action listener)",
    "public void RemoveControlsChangedListener(System.Action listener)",
    "public string GetCurrentControlDevicesSignature()",
    "public InputAction[] GetConflictingActions(InputAction action, int bindingIndex = 0)",
    "return InputKit.GetConflictingActions(action, bindingIndex).ToArray();",
    "private void RegisterGameplayInputCallbacks()",
    "private void RegisterSharedReleaseCallbacks()",
    "private static void RegisterActionAssetForBindingTools(InputActionAsset actionAsset, string persistenceKey)",
    "private PlayerCommandResult ExecuteLocalPlayerCommand(",
    "TryResolveLocalPlayerCommandContext(out GameCommandContext commandContext)",
    "new PlayerCommandRequest(",
    "direction: context.ReadValue<Vector2>()",
    "worldPosition: worldPosition",
    "GameManager.PlayerSystem.SubmitPlayerCommand(",
    "private static void NotifyLocalPlayerCommandResult(PlayerCommandResult result)",
    "GameRuntimeEvents.NotifyLocalPlayerCommandFailed(result)",
    "ExecuteLocalPlayerCommand(EPlayerCommandKind.Interact)",
    "EPlayerCommandKind.ClickMove,",
    "ExecuteLocalPlayerCommand(EPlayerCommandKind.FireAbility, abilityIndex: 0)"
)

$inputSystemDisallowedPatterns = Test-ContainsAny -Content $inputSystemContent -Patterns @(
    "public PlayerInput playerInput => m_playerInput;",
    "public GameplayActions gameplay => m_gameplayActions;",
    "public UIActions ui => m_uiActions;",
    "public event System.Action controlsChanged;",
    "public System.Collections.Generic.IReadOnlyList<InputAction> GetConflictingActions(",
    "return InputKit.GetConflictingActions(action, bindingIndex);",
    ".HandleInteract()",
    ".HandleOpenGameMenu()",
    ".HandleMove(",
    ".HandleStopMove()",
    ".HandleClickMove(",
    ".HandleToggleMovementControlMode()",
    ".HandleFireAbility(",
    ".HandleStopFireAbility("
)

$uiHudAbilityMessageMissingPatterns = Test-ContainsAll -Content $uiHudAbilityMessageContent -Patterns @(
    "EventKit.Type.Register<LocalPlayerCommandFailedEvent>(OnLocalPlayerCommandFailed);",
    "EventKit.Type.UnRegister<LocalPlayerCommandFailedEvent>(OnLocalPlayerCommandFailed);",
    "private void OnLocalPlayerCommandFailed(LocalPlayerCommandFailedEvent evt)",
    "TryGetCommandFailureMessage(evt.Result, out string message)",
    "private static bool TryGetCommandFailureMessage(PlayerCommandResult result, out string message)",
    "EPlayerCommandFailureReason.ControlLocked",
    "EPlayerCommandFailureReason.InteractionLocked",
    "EPlayerCommandFailureReason.MissingAbility",
    "EPlayerCommandFailureReason.BlockedByState",
    "EPlayerCommandKind.FireAbility => `"I can't cast right now.`"",
    "EPlayerCommandKind.Interact",
    "I can't interact right now.",
    "EPlayerCommandKind.Interact => `"Nothing to interact with.`"",
    "_ => null"
)

$playerCommandRequestMissingPatterns = Test-ContainsAll -Content $playerCommandRequestContent -Patterns @(
    "public enum EPlayerCommandKind",
    "public enum EPlayerCommandFailureReason",
    "public readonly struct PlayerCommandRequest",
    "public readonly struct PlayerCommandResult",
    "public GameCommandContext CommandContext { get; }",
    "public CharacterBase Actor => CommandContext.Actor;",
    "ControlLocked,",
    "InteractionLocked,",
    "public static PlayerCommandResult Success(PlayerCommandRequest request)",
    "public static PlayerCommandResult Failed("
)

$playerOrderRequestMissingPatterns = Test-ContainsAll -Content $playerOrderRequestContent -Patterns @(
    "public enum EPlayerOrderTargetScope",
    "PrimaryMemberOnly",
    "ControlledGroup",
    "public enum EPlayerOrderQueueMode",
    "ReplaceCurrent",
    "Append",
    "StopCurrent",
    "public readonly struct PlayerOrderRequest",
    "public EPlayerOrderTargetScope TargetScope { get; }",
    "public EPlayerOrderQueueMode QueueMode { get; }",
    "public static PlayerOrderRequest FromCommandRequest(PlayerCommandRequest commandRequest)",
    "EPlayerCommandKind.Move => EPlayerOrderTargetScope.ControlledGroup",
    "EPlayerCommandKind.StopMove => EPlayerOrderTargetScope.ControlledGroup",
    "EPlayerCommandKind.ClickMove => EPlayerOrderTargetScope.ControlledGroup",
    "EPlayerCommandKind.ToggleMovementControlMode => EPlayerOrderTargetScope.ControlledGroup",
    "EPlayerCommandKind.StopMove => EPlayerOrderQueueMode.StopCurrent",
    "public readonly struct PlayerOrderResult",
    "public bool WasQueued { get; }",
    "public int QueuedOrderCount { get; }",
    "public static PlayerOrderResult Queued("
)

$gameCommandContextMissingPatterns = Test-ContainsAll -Content $gameCommandContextContent -Patterns @(
    "public static GameCommandContext Recreate(EGameCommandIssuerKind issuerKind, CharacterBase actor = null, string issuerId = null)",
    "public static GameCommandContext ResolveForActor(CharacterBase actor)",
    "TryGetPlayerSystem(out PlayerSystem playerSystem)",
    "playerSystem.IsCurrentControlledMember(actor)",
    "actor.IsControllerActive<AIController>()",
    "return AI(actor);",
    "return Unknown(actor);"
)

$playerInputTargetMissingPatterns = Test-ContainsAll -Content $playerInputTargetContent -Patterns @(
    "bool TryGetControlledCharacter(out CharacterBase character);",
    "CharacterBase[] CreateControlledCharacterSnapshot();",
    "PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest);"
)

$playerInputTargetDisallowedPatterns = Test-ContainsAny -Content $playerInputTargetContent -Patterns @(
    "HandleInteract(",
    "HandleOpenGameMenu(",
    "HandleMove(",
    "HandleStopMove(",
    "HandleClickMove(",
    "HandleToggleMovementControlMode(",
    "HandleFireAbility(",
    "HandleStopFireAbility("
)

$characterPlayerControlMissingPatterns = Test-ContainsAll -Content $characterPlayerControlContent -Patterns @(
    "public sealed class CharacterPlayerControl : MonoBehaviour, IPlayerInputTarget",
    "public bool TryGetControlledCharacter(out CharacterBase character)",
    "public CharacterBase[] CreateControlledCharacterSnapshot()",
    "public PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest)",
    "public EPlayerMovementControlMode GetMovementControlMode()",
    "public void SetMovementControlMode(EPlayerMovementControlMode mode)",
    "public bool TryGetCurrentInteractionTargetPosition(out Vector3 position)",
    "ResolveButtonActivation()?.RefreshCurrentTarget();",
    "ResolveMovement()?.SetMovementControlMode(mode);",
    "m_character.CanBePlayerControlled()",
    "EPlayerCommandFailureReason.ControlLocked",
    "PlayerCommandResult.Failed("
)

$characterPlayerInputTargetMissingPatterns = Test-ContainsAll -Content $characterBaseContent -Patterns @(
    "public bool TryResolvePlayerInputTarget(out IPlayerInputTarget inputTarget)",
    "!HasConfiguredPlayerInputTarget(out CharacterPlayerControl playerControl)",
    "public bool HasConfiguredPlayerInputTarget(out CharacterPlayerControl playerControl)",
    "!playerControl.AcceptsPlayerInput",
    "!playerControl.isActiveAndEnabled"
)

$characterPlayerControlDisallowedPatterns = Test-ContainsAny -Content $characterPlayerControlContent -Patterns @(
    "PlayerInteractionRuntime",
    "PlayerNavigationRuntime",
    "m_subject",
    "GetCurrentControlledHero(",
    "m_character.FireAbility(selectedAbility);",
    "GameManager.PlayerSystem.IsCurrentInputTarget(this)"
)

$playerControlGroupMissingPatterns = Test-ContainsAll -Content $playerControlGroupContent -Patterns @(
    "public sealed class PlayerControlGroup : IPlayerInputTarget",
    "public PlayerControlGroup(params CharacterBase[] members)",
    "public PlayerControlGroup(CharacterBase primaryMember, params CharacterBase[] members)",
    "public CharacterBase PrimaryMember => GetPrimaryControlledCharacter();",
    "public int PendingOrderCount => m_pendingOrders.Count;",
    "public void ReplaceMembers(params CharacterBase[] members)",
    "public bool TryAddMember(CharacterBase member, bool makePrimary = false)",
    "public bool RemoveMember(CharacterBase member)",
    "public bool TrySetPrimaryMember(CharacterBase member)",
    "public bool TryGetControlledCharacter(out CharacterBase character)",
    "public CharacterBase[] CreateControlledCharacterSnapshot()",
    "public void Tick()",
    "public void ClearQueuedOrders()",
    "public PlayerCommandResult ExecutePlayerCommand(PlayerCommandRequest request)",
    "public PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest)",
    "orderRequest.QueueMode == EPlayerOrderQueueMode.ReplaceCurrent",
    "orderRequest.QueueMode == EPlayerOrderQueueMode.Append",
    "m_pendingOrders.Enqueue(orderRequest)",
    "EPlayerOrderTargetScope.ControlledGroup => ExecuteForAllMembers(orderRequest)",
    "private PlayerOrderResult ExecuteForPrimaryMember(PlayerOrderRequest orderRequest)",
    "private PlayerOrderResult ExecuteForAllMembers(PlayerOrderRequest orderRequest)",
    "bool anySucceeded = false;",
    "anySucceeded = true;",
    "if (anySucceeded)",
    "GameCommandContext.Recreate(",
    "orderRequest.CommandContext.IssuerKind",
    "orderRequest.CommandContext.IssuerId"
)

$playerControlGroupDisallowedPatterns = Test-ContainsAny -Content $playerControlGroupContent -Patterns @(
    "NetworkObject",
    "RPC",
    "FishNet",
    "GameController",
    "NavMesh"
)

$aiControllerMissingPatterns = Test-ContainsAll -Content $aiControllerContent -Patterns @(
    "private BehaviourRuntime m_behaviourRuntime = null;",
    "private BehaviourRuntime behaviourRuntime => m_behaviourRuntime ??= new BehaviourRuntime(this);",
    "behaviourRuntime.Initialize();",
    "behaviourRuntime.TryHandleProvoked(source);",
    "behaviourRuntime.Tick();"
)

$aiControllerDisallowedPatterns = Test-ContainsAny -Content $aiControllerContent -Patterns @(
    "private Rigidbody2D m_rigidbody = null;",
    "private List<RaycastHit2D> m_castCollisions = new();",
    "private float[] m_interests = new float[8];",
    "private float[] m_dangers = new float[8];",
    "private float[] m_steering = new float[8];",
    "private Vector2 m_steeringAverageOutput = Vector2.zero;",
    "private Vector2 m_targetPosition = Vector2.zero;",
    "private Vector2 m_lerpedTargetDirection = Vector2.zero;",
    "private Vector2[] m_directions = new Vector2[8]",
    "private bool CanSee(CharacterBase other)",
    "private CharacterBase FindTarget()",
    "private void UpdateCooldowns()",
    "private void TryToAttackTarget(float distanceToTarget)",
    "private void CheckIfTargetOutOfRange(float distanceToTarget)",
    "private void StopChase(float retargetCooldown)",
    "private void ProcessSteeringBehaviour(int index)"
)

$aiControllerBehaviourRuntimeMissingPatterns = Test-ContainsAll -Content $aiControllerBehaviourRuntimeContent -Patterns @(
    "private sealed class BehaviourRuntime",
    "private CharacterSteeringRuntime2D m_steeringAdapter = null;",
    "private readonly CharacterSteeringPathCursor2D m_pathCursor = new();",
    "public void Initialize()",
    "m_steeringAdapter = new CharacterSteeringRuntime2D(character, m_owner.m_steeringProfile);",
    "ValidateSteeringGroupMapping(m_owner.m_transitSteeringGroupId,",
    "ValidateSteeringGroupMapping(m_owner.m_targetPursuitSteeringGroupId,",
    "public void TryHandleProvoked(CharacterBase source)",
    "public void Tick()",
    "private void RefreshTarget()",
    "m_owner.m_subject.FireFormalGasAbility(",
    "GameCommandContext.AI(m_owner.m_subject)",
    "private void ApplyMovement()",
    "m_steeringAdapter.Submit(",
    "m_steeringAdapter.ApplyLatestResult();",
    "private void ValidateSteeringGroupMapping"
)

$playerSystemDisallowedPatterns = Test-ContainsAny -Content $playerSystemContent -Patterns @(
    "public UnityEvent<CharacterBase> currentControlledCharacterChanged => m_currentControlledCharacterChanged;",
    "public UnityEvent<Hero> currentControlledHeroChanged => m_currentControlledHeroChanged;",
    "public Hero PlayerInstance => m_playerInstance;",
    "GameManager.Config.ExecutePlayerDeathAction();"
)

$playerSystemPlayerControlMissingPatterns = Test-ContainsAll -Content $playerSystemContent -Patterns @(
    "private readonly List<CharacterBase> m_boundControlledCharacters = new();",
    "EnsurePrimaryPlayerInputTargetConfigured(nameof(OnSystemStart));",
    "EnsurePrimaryPlayerInputTargetConfigured(nameof(LoadDataBlock));",
    "private void EnsurePrimaryPlayerInputTargetConfigured(string operationName)",
    "m_primaryPlayerCharacter.HasConfiguredPlayerInputTarget(out CharacterPlayerControl _)",
    "public void SetCurrentControlGroup(params CharacterBase[] characters)",
    "public bool TryAddCurrentControlGroupMember(CharacterBase character, bool makePrimary = false)",
    "public bool TryRemoveCurrentControlGroupMember(CharacterBase character)",
    "public bool TrySetCurrentControlGroupPrimaryMember(CharacterBase character)",
    "new PlayerControlGroup(primaryMember, controllableCharacters)",
    "m_currentControlGroup?.Tick();",
    "public void RevalidateCurrentControlledCharacter()",
    "private CharacterBase[] CreateCurrentControlledCharacterSnapshot()",
    "public CharacterBase GetCurrentControlledCharacterOrPlayerInstance()",
    "public bool IsCurrentControlledMember(CharacterBase character)",
    "m_currentControlledCharacterChanged.Invoke(currentControlledCharacter);",
    "SetCurrentInputTarget(null);",
    "private void BindControlledCharacters(CharacterBase[] characters)",
    "private static CharacterBase[] CreateControllableCharacterSnapshot(CharacterBase[] characters)",
    "private static bool AreSameControlledCharacters("
)

$playerControlLifecycleMissingPatterns = @(
    Test-ContainsAll -Content $playerSystemContent -Patterns @(
        "internal void NotifyCharacterDied(CharacterBase character)",
        "internal void NotifyCharacterRevived(CharacterBase character)",
        "IsCurrentControlledMember(character)",
        "SetCurrentControlledCharacter(character);",
        "GameManager.Config.ExecutePlayerDeathAction(GameCommandContext.LocalPlayer(character));"
    )
    Test-ContainsAll -Content $characterBaseContent -Patterns @(
        "NotifyPlayerSystemAboutDeath();",
        "NotifyPlayerSystemAboutRevive();",
        "private void NotifyPlayerSystemAboutDeath()",
        "private void NotifyPlayerSystemAboutRevive()",
        "GameManager.PlayerSystem.NotifyCharacterDied(this);",
        "GameManager.PlayerSystem.NotifyCharacterRevived(this);"
    )
)

$currentControlledCharacterUiMissingPatterns = @(
    Test-ContainsAll -Content $uiHudAbilityBarContent -Patterns @(
        "GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance()",
        "AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged)"
    )
    Test-ContainsAll -Content $uiHudAbilityBarEntryContent -Patterns @(
        "public void SetBoundCharacter(CharacterBase character)",
        "m_boundCharacter.TryGetActiveAbilityCooldownSnapshot(m_abilitySlot, out CharacterAbilityCooldownSnapshot cooldownSnapshot)"
    )
    Test-ContainsAll -Content $uiAbilityBarContent -Patterns @(
        "public void PresentCharacter(CharacterBase character)",
        "BindCharacter(character);",
        "m_currentCharacter.AddEquippedAbilitiesChangedListener(FillAbilityBar);",
        "m_currentCharacter.RemoveEquippedAbilitiesChangedListener(FillAbilityBar);"
    )
    Test-ContainsAll -Content $uiAbilitiesContent -Patterns @(
        "BindCharacter(m_context.ResolveActor());",
        "AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged)"
    )
    Test-ContainsAll -Content $uiCharacterContent -Patterns @(
        "BindCharacter(m_context.ResolveActor() as CharacterActor);",
        "AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged)"
    )
)

$currentControlledCharacterUiDisallowedPatterns = @(
    Test-ContainsAny -Content $uiHudAbilityBarContent -Patterns @(
        "GetCurrentControlledHero()",
        "AddCurrentControlledHeroChangedListener("
    )
    Test-ContainsAny -Content $uiHudAbilityBarEntryContent -Patterns @(
        "GetCurrentControlledHero()",
        "AddCurrentControlledHeroChangedListener("
    )
    Test-ContainsAny -Content $uiAbilityBarContent -Patterns @(
        "GetCurrentControlledHero()",
        "AddCurrentControlledHeroChangedListener("
    )
    Test-ContainsAny -Content $uiAbilitiesContent -Patterns @(
        "GetCurrentControlledHero()",
        "AddCurrentControlledHeroChangedListener("
    )
    Test-ContainsAny -Content $uiCharacterContent -Patterns @(
        "GetCurrentControlledHero()",
        "AddCurrentControlledHeroChangedListener("
    )
    Test-ContainsAny -Content $playerSystemContent -Patterns @(
        "m_currentControlledHeroChanged",
        "GetCurrentControlledHero()"
    )
)

$commandCurrentControlledTargetMissingPatterns = @(
    Test-ContainsAll -Content $gameCommandContextContent -Patterns @(
        "public CharacterBase ResolveActorOrCurrentControlledCharacter()",
        "public CharacterBase ResolveRequiredActorOrCurrentControlledCharacter(string commandName)",
        "GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance()",
        "throw new InvalidOperationException"
    )
    Test-ContainsAll -Content $addExperienceCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddExperience));",
        "target.AddExperience(m_experience);"
    )
    Test-ContainsAll -Content $addOrRemoveAbilityCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveAbility));"
    )
    Test-ContainsAll -Content $addOrRemoveItemCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveItem));"
    )
    Test-ContainsAll -Content $addOrRemoveManaCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(AddOrRemoveMana));"
    )
    Test-ContainsAll -Content $healOrDamagePlayerCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(HealOrDamagePlayer));"
    )
    Test-ContainsAll -Content $revivePlayerCommandContent -Patterns @(
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(RevivePlayer));",
        "target.Revive();"
    )
    Test-ContainsAll -Content $movePlayerCommandContent -Patterns @(
        "protected override CharacterBase ResolveTargetCharacter(GameCommandContext context)",
        "return context.ResolveActorOrCurrentControlledCharacter();"
    )
    Test-ContainsAll -Content $executeCommandListContent -Patterns @(
        "m_disabledActions == EActionFlags.None",
        "context.ResolveRequiredActorOrCurrentControlledCharacter(nameof(ExecuteCommandList));",
        "actionLockTarget?.DisableActions(m_disabledActions);",
        "actionLockTarget?.EnableActions(m_disabledActions);"
    )
    Test-ContainsAll -Content $isAbilityUnlockedConditionContent -Patterns @(
        "if (!TryGetCurrentControlledCharacter(out CharacterBase currentCharacter))",
        "return currentCharacter.HasFormalGasAbility(m_formalGasAbilityCode);",
        "playerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);",
        "playerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);",
        "private static bool TryGetPlayerSystem(out PlayerSystem playerSystem)",
        "if (!TryGetPlayerSystem(out PlayerSystem playerSystem))",
        "currentControlledCharacter = playerSystem.GetCurrentControlledCharacterOrPlayerInstance();",
        "private void OnCurrentControlledCharacterChanged(CharacterBase character) => NotifyStateChange();"
    )
)

$commandCurrentControlledTargetDisallowedPatterns = @(
    Test-ContainsAny -Content $addExperienceCommandContent -Patterns @(
        "ResolveHeroOrCurrentControlledHero();",
        "GameManager.PlayerSystem.GetPlayerInstance();",
        "target?.AddExperience(m_experience);"
    )
    Test-ContainsAny -Content $addOrRemoveAbilityCommandContent -Patterns @(
        "GameManager.PlayerSystem.GetPlayerInstance();",
        "if (target == null)"
    )
    Test-ContainsAny -Content $addOrRemoveItemCommandContent -Patterns @(
        "if (inventoryOwner == null)"
    )
    Test-ContainsAny -Content $addOrRemoveManaCommandContent -Patterns @(
        "GameManager.PlayerSystem.GetPlayerInstance();",
        "if (target == null)"
    )
    Test-ContainsAny -Content $healOrDamagePlayerCommandContent -Patterns @(
        "GameManager.PlayerSystem.GetPlayerInstance();",
        "if (target == null)"
    )
    Test-ContainsAny -Content $revivePlayerCommandContent -Patterns @(
        "GameManager.PlayerSystem.GetPlayerInstance();",
        "target?.Revive();"
    )
    Test-ContainsAny -Content $executeCommandListContent -Patterns @(
        "Hero playerInstance = GameManager.PlayerSystem.GetPlayerInstance();",
        "playerInstance.DisableActions(m_disabledActions);",
        "playerInstance.EnableActions(m_disabledActions);",
        "CharacterBase actionLockTarget = context.ResolveActorOrCurrentControlledCharacter();"
    )
    Test-ContainsAny -Content $isAbilityUnlockedConditionContent -Patterns @(
        "GameManager.PlayerSystem.GetPlayerInstance().HasAbility(m_ability);"
    )
)

$characterDeathCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $characterSheetContent -Patterns @(
        "public void ExecuteOnDeath(GameCommandContext context)",
        "m_executeOnDeath.ExecuteFireAndReport(context, nameof(CharacterSheet), this);"
    )
    Test-ContainsAll -Content $characterActorRewardsContent -Patterns @(
        "m_sheet.ExecuteOnDeath(",
        "private static GameCommandContext ResolveRewardCommandContext(CharacterBase receiver)",
        "return GameCommandContext.ResolveForActor(receiver);"
    )
)

$characterDeathCommandContextDisallowedPatterns = @(
    Test-ContainsAny -Content $characterSheetContent -Patterns @(
        "public void ExecuteOnDeath() => m_executeOnDeath.Execute(GameCommandContext.Script());"
    )
    Test-ContainsAny -Content $characterActorRewardsContent -Patterns @(
        "m_sheet.ExecuteOnDeath();"
    )
)

$playerDeathCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $gameConfigPersistenceContent -Patterns @(
        "public void ExecutePlayerDeathAction(GameCommandContext context)",
        "m_toExecuteOnPlayerDeath.ExecuteFireAndReport(context, nameof(GameConfig), this);"
    )
    Test-ContainsAll -Content $playerSystemContent -Patterns @(
        "GameManager.Config.ExecutePlayerDeathAction(GameCommandContext.LocalPlayer(character));"
    )
)

$playerDeathCommandContextDisallowedPatterns = @(
    Test-ContainsAny -Content $gameConfigPersistenceContent -Patterns @(
        "public void ExecutePlayerDeathAction()",
        "GameCommandContext.Script()"
    )
    Test-ContainsAny -Content $playerSystemContent -Patterns @(
        "GameManager.Config.ExecutePlayerDeathAction();"
    )
)

$questCompletionCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $questInteractionContent -Patterns @(
        "private async Task<bool> TryCompletingQuest(CharacterBase source, CharacterActor character)",
        "GameManager.JournalSystem.CompleteQuest(quest, ResolveQuestCompletionCommandContext(source));",
        "private static GameCommandContext ResolveQuestCompletionCommandContext(CharacterBase source)",
        "return GameCommandContext.ResolveForActor(source);"
    )
    Test-ContainsAll -Content $journalSystemContent -Patterns @(
        "public async Task CompleteQuest(Quest quest, GameCommandContext context)",
        "quest.ExecuteOnQuestCompletion(context);"
    )
    Test-ContainsAll -Content $questContent -Patterns @(
        "public Task ExecuteOnQuestCompletion(GameCommandContext context)",
        "m_toExecuteOnQuestCompletion.Execute(context);"
    )
)

$questCompletionCommandContextDisallowedPatterns = @(
    Test-ContainsAny -Content $questInteractionContent -Patterns @(
        "GameManager.JournalSystem.CompleteQuest(quest);"
    )
    Test-ContainsAny -Content $journalSystemContent -Patterns @(
        "quest.ExecuteOnQuestCompletion();"
    )
    Test-ContainsAny -Content $questContent -Patterns @(
        "m_toExecuteOnQuestCompletion.Execute(GameCommandContext.Script())"
    )
)

$questStartCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $questInteractionContent -Patterns @(
        "GameManager.JournalSystem.StartQuest(quest, ResolveQuestStartCommandContext(source));",
        "private static GameCommandContext ResolveQuestStartCommandContext(CharacterBase source)",
        "return GameCommandContext.ResolveForActor(source);"
    )
    Test-ContainsAll -Content $itemEffectBaseContent -Patterns @(
        "protected abstract ItemUsageResult OnUse(Item item, CharacterBase sourceOwner, CharacterBase target, EItemLocation location)",
        "ItemUsageResult result = OnUse(item, sourceOwner, target, location);"
    )
    Test-ContainsAll -Content $itemStartQuestEffectContent -Patterns @(
        "GameManager.JournalSystem.StartQuest(m_questToStart, ResolveQuestStartCommandContext(sourceOwner, target));",
        "private static GameCommandContext ResolveQuestStartCommandContext(CharacterBase sourceOwner, CharacterBase target)",
        "CharacterBase actor = sourceOwner ? sourceOwner : target;",
        "return GameCommandContext.ResolveForActor(actor);"
    )
    Test-ContainsAll -Content $journalSystemContent -Patterns @(
        "public void StartQuest(Quest quest, GameCommandContext context)",
        "GameRuntimeEvents.NotifyQuestStarted(quest, context);"
    )
    Test-ContainsAll -Content $gameRuntimeEventsProgressionQuestsContent -Patterns @(
        "public QuestStartedEvent(Quest quest, GameCommandContext commandContext)",
        "public GameCommandContext CommandContext { get; }",
        "public static void NotifyQuestStarted(Quest quest, GameCommandContext commandContext)",
        "Publish(new QuestStartedEvent(quest, commandContext));"
    )
)

$questStartCommandContextDisallowedPatterns = @(
    Test-MethodContainsAny -Content $questInteractionContent -MethodName "private async Task<bool> TryOfferingQuest(CharacterBase source, NPC npc)" -Patterns @(
        "GameManager.JournalSystem.StartQuest(quest);"
    )
    Test-MethodContainsAny -Content $itemStartQuestEffectContent -MethodName "protected override ItemUsageResult OnUse(Item item, CharacterBase sourceOwner, CharacterBase target, EItemLocation location)" -Patterns @(
        "GameManager.JournalSystem.StartQuest(m_questToStart);"
    )
    Test-MethodContainsAny -Content $journalSystemContent -MethodName "public void StartQuest(Quest quest, GameCommandContext context)" -Patterns @(
        "GameRuntimeEvents.NotifyQuestStarted(quest);"
    )
)

$persistableDestroyCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $persistableContent -Patterns @(
        "public virtual void Destroy(GameCommandContext context)",
        "m_executeOnDeath.ExecuteFireAndReport(context, nameof(Persistable), this);"
    )
    Test-ContainsAll -Content $destroyEntityCommandContent -Patterns @(
        "public Task Execute(GameCommandContext context)",
        "throw new InvalidOperationException",
        "m_toDestroy.Destroy(context);"
    )
)

$persistableDestroyCommandContextDisallowedPatterns = @(
    Test-ContainsAny -Content $persistableContent -Patterns @(
        "m_executeOnDeath.Execute(GameCommandContext.Script())"
    )
    Test-ContainsAny -Content $destroyEntityCommandContent -Patterns @(
        "m_toDestroy?.Destroy();",
        "m_toDestroy?.Destroy(context);"
    )
)

$characterDeathDestroyCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $movableContent -Patterns @(
        "Destroy(ResolveDeathCommandContext());",
        "protected virtual GameCommandContext ResolveDeathCommandContext()",
        "return GameCommandContext.Script();"
    )
    Test-ContainsAll -Content $characterBaseContent -Patterns @(
        "protected override GameCommandContext ResolveDeathCommandContext()",
        "if (!TryGetLastEffectiveDamageSource(out CharacterBase source))",
        "return GameCommandContext.ResolveForActor(source);"
    )
)

$characterDeathDestroyCommandContextDisallowedPatterns = @(
    Test-MethodContainsAny -Content $movableContent -MethodName "protected virtual void OnDeath()" -Patterns @(
        "Destroy();"
    )
)

$movableControllerRuntimeMissingPatterns = Test-ContainsAll -Content $movableContent -Patterns @(
    "public IControllerDataBlock controllerData;",
    "private IController m_activeControllerOverride = null;",
    "private IController activeController => m_activeControllerOverride ?? m_controller;",
    "public bool IsControllerActive<TController>() where TController : class",
    "protected bool TryActivateController<TController>() where TController : class, IController",
    "protected bool ClearControllerOverride<TController>() where TController : class, IController",
    "private void InitializeControllers()",
    "private void TerminateControllers()",
    "private void StartActiveController()",
    "private void StopActiveController()",
    "private void SetActiveControllerOverride(IController controller)"
)

$movableControllerRuntimeDisallowedPatterns = Test-ContainsAny -Content $movableContent -Patterns @(
    "protected virtual void Update() => m_controller?.Update();",
    "m_controller?.Start();",
    "m_controller?.Stop();",
    "m_controller?.FixedUpdate();",
    "m_controller?.DrawGizmos();"
)

$projectileDestroyCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $projectileCompositeContent -Patterns @(
        "Destroy(ResolveDestroyCommandContext());",
        "private GameCommandContext ResolveDestroyCommandContext()",
        "private GameCommandContext m_fireCommandContext = GameCommandContext.Script();",
        "return m_fireCommandContext;",
        "return GameCommandContext.Recreate(m_fireCommandContext.IssuerKind, m_source, m_fireCommandContext.IssuerId);",
        "projectileBlock.fireCommandIssuerKind = m_fireCommandContext.IssuerKind;",
        "m_fireCommandContext = GameCommandContext.Recreate(projectileBlock.fireCommandIssuerKind, m_source, projectileBlock.fireCommandIssuerId);"
    )
)

$projectileDestroyCommandContextDisallowedPatterns = @(
    Test-MethodContainsAny -Content $projectileContent -MethodName "public void OnDestroyAnimationEnd()" -Patterns @(
        "Destroy();"
    )
    Test-MethodContainsAny -Content $projectileContent -MethodName "private void Terminate(CharacterBase primaryTarget = null)" -Patterns @(
        "Destroy();"
    )
)

$summonCleanupCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $characterBaseContent -Patterns @(
        "public void Kill(GameCommandContext context)",
        "m_hasDeathCommandContextOverride",
        "TryConsumeDeathCommandContextOverride(out GameCommandContext context)",
        "if (TryConsumeDeathCommandContextOverride(out GameCommandContext overrideContext))"
    )
)

$summonCleanupCommandContextDisallowedPatterns = @()

$gameStateSystemDisallowedPatterns = Test-ContainsAny -Content $gameStateSystemContent -Patterns @(
    "StartCoroutine(CoroutineHelpers.ExecuteInXFrames(1",
    "Prevent action map change when using shared action keys between action maps to toggle multiple actions in one frame"
)

$mapSystemMissingPatterns = Test-ContainsAll -Content $mapSystemContent -Patterns @(
    "Debug.Assert(",
    "private Coroutine m_respawnCoroutine;",
    "EnsureTransitionSystemReady();",
    "private void EnsureTransitionSystemReady()",
    "private static void EnsureValidCheckpoint(ICheckpoint checkpoint, string operationName)",
    "private CharacterActor GetRequiredTraversalCharacter(string operationName)",
    "Loading a save file requires a map data block.",
    "GameRuntimeEvents.NotifyMapTransitionDelegationRequested(new MapLoadingDelegationParams",
    "private IEnumerator RespawnPlayerCoroutine()",
    "private void DelegateTransition(string map, Action onMapUnloaded = null, Action onMapLoaded = null, Action onCompletion = null)"
)

$mapSystemDisallowedPatterns = Test-ContainsAny -Content $mapSystemContent -Patterns @(
    "m_delegateTransitionResponsability",
    "if (m_delegateTransitionResponsability)",
    "private void ExecuteTransition("
)

$persistenceSystemMissingPatterns = Test-ContainsAll -Content $persistenceSystemContent -Patterns @(
    "public partial class PersistenceSystem : AGameSystem, IDataBlockHandler<PersistenceDataBlock>",
    "private readonly Dictionary<string, PersistableDataBlock> m_preInstanced = new();",
    "private readonly Dictionary<string, PersistableDataBlock> m_runtimeInstanced = new();",
    "private readonly Dictionary<string, Persistable> m_persistables = new();",
    "public override void OnMapLoaded()",
    "public override void OnMapUnloading()",
    "private void SnapshotPersistables(bool disablePersistence = false)",
    "private PersistableDataBlock GetPreInstancedDataBlock(string identifier)",
    "private void EvaluateRuntimeInstancedDataBlock(PersistableDataBlock block)",
    "private void LoadPreInstancedDataBlocks()",
    "private void LoadRuntimeInstancedDataBlocks()",
    "internal bool TryResolvePersistable<TPersistable>(string identifier, out TPersistable persistable) where TPersistable : Persistable",
    "if (!string.IsNullOrEmpty(identifier) && m_persistables.TryGetValue(identifier, out Persistable resolvedPersistable))",
    "public void LoadDataBlock(PersistenceDataBlock block)",
    "public PersistenceDataBlock CreateDataBlock()",
    "m_preInstanced.Values.Union(m_runtimeInstanced.Values).ToArray()",
    "private string GetActualIdentifier(string identifier)",
    "internal void NotifyPersistableDestroyed(PersistableDestructionSnapshot destructionSnapshot)"
)

$persistenceSystemDisallowedPatterns = Test-ContainsAny -Content $persistenceSystemContent -Patterns @(
    "public class PersistenceDataBlock : DataBlock",
    "internal struct InstanstiationResult",
    "public TPersistable InstantiateRuntime<TPersistable>(",
    "public TPersistable InstantiateCustom<TPersistable>(",
    "internal InstanstiationResult InstantiateInternal(",
    "public void RegisterCustomInstancedPersistable("
)

$persistenceSystemContractsMissingPatterns = Test-ContainsAll -Content $persistenceSystemContractsContent -Patterns @(
    "[Serializable]",
    "public class PersistenceDataBlock : DataBlock",
    "[SerializeReference] public PersistableDataBlock[] objects;"
)

$persistenceSystemInstantiationRuntimeMissingPatterns = Test-ContainsAll -Content $persistenceSystemInstantiationRuntimeContent -Patterns @(
    "public partial class PersistenceSystem",
    "internal struct InstanstiationResult",
    "internal TPersistable InstantiateRuntime<TPersistable>(PrefabReference instance, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable",
    "internal TPersistable InstantiateCustom<TPersistable>(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable",
    "internal InstanstiationResult InstantiateInternal(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null)",
    "identifier = ResolvePersistenceIdentifier(identifier);",
    "TPersistable persistable = RequireInstantiatedPersistable<TPersistable>(result, instance.prefab);",
    "TPersistable persistable = RequireInstantiatedPersistable<TPersistable>(result, prefab);",
    "internal void RegisterCustomInstancedPersistable(Persistable persistable, string identifier = null)",
    "private TPersistable RequireInstantiatedPersistable<TPersistable>(InstanstiationResult result, GameObject prefab)",
    "m_persistables.Remove(result.identifier);",
    "private static string ResolvePersistenceIdentifier(string identifier)"
)

$sceneUtilMissingPatterns = Test-ContainsAll -Content $sceneUtilContent -Patterns @(
    'private static readonly string[] SceneSearchRoots = { "Assets/Scenes" };',
    'public static string[] CreateBuildSettingsSceneNameSnapshot()',
    'public static string[] CreateAssetDatabaseScenePathSnapshot()',
    'public static SceneEntry[] CreateSceneEntrySnapshot()',
    'string[] guids = AssetDatabase.FindAssets("t:scene", SceneSearchRoots);'
)

$sceneUtilDisallowedPatterns = Test-ContainsAny -Content $sceneUtilContent -Patterns @(
    'AssetDatabase.FindAssets("t:scene", null)',
    "public static IEnumerable<string> GetAllScenesInBuildSettings()",
    "public static IEnumerable<string> GetAllScenesInAssetDatabase()",
    "public static IReadOnlyList<SceneEntry> GetSceneEntries()"
)

$sceneMenuRegistryMissingPatterns = Test-ContainsAll -Content $sceneMenuRegistryContent -Patterns @(
    'private const string GeneratedFilePath = "Assets/Editor/GameCore/Generated/FWSceneMenu.g.cs";',
    'string generatedCode = BuildGeneratedCode(SceneUtil.CreateSceneEntrySnapshot());',
    'if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())',
    'EditorSceneManager.OpenScene(scenePath);',
    'AssetDatabase.ImportAsset(GeneratedFilePath, ImportAssetOptions.ForceSynchronousImport);'
)

$sceneMenuRegistryDisallowedPatterns = Test-ContainsAny -Content $sceneMenuRegistryContent -Patterns @(
    'AssetDatabase.FindAssets("t:scene"',
    'CreateBuildSettingsSceneEntrySnapshot()'
)

$generatedSceneMenuMissingPatterns = Test-ContainsAll -Content $generatedSceneMenuContent -Patterns @(
    'SceneMenuRegistry.OpenScene("Assets/Scenes/ClickMoveTest.unity");',
    'SceneMenuRegistry.OpenScene("Assets/Scenes/EquipmentSystemDemo.unity");',
    'SceneMenuRegistry.OpenScene("Assets/Scenes/SampleScene.unity");'
)

$generatedSceneMenuDisallowedPatterns = Test-ContainsAny -Content $generatedSceneMenuContent -Patterns @(
    "Assets/Plugins/",
    "Assets/Art/",
    "Assets/Settings/Scenes/",
    "Packages/"
)

$stateMessageDispatcherMissingPatterns = Test-ContainsAll -Content $stateMessageDispatcherContent -Patterns @(
    "RequireExplicitReceiver = 3",
    "TryPropagateKnownMessage",
    "messageData.propagationMode != EMessagePropagationMode.RequireExplicitReceiver",
    "requires a parent",
    "requires an explicit animation-state receiver contract"
)

$stateMessageDispatcherDisallowedPatterns = Test-ContainsAny -Content $stateMessageDispatcherContent -Patterns @(
    "BroadcastMessage(",
    "SendMessage(",
    "SendMessageUpwards("
)

$animationStrategyMissingPatterns = Test-ContainsAll -Content $animationStrategyContent -Patterns @("无敌语义从请求这一刻开始成立")

$formalAttributeCatalogMissingPatterns = Test-ContainsAll -Content $formalAttributeCatalogContent -Patterns @(
    "private static readonly FormalAttributeDefinition[] s_definitionArray =",
    "private static readonly ReadOnlyCollection<FormalAttributeDefinition> s_definitions = Array.AsReadOnly(s_definitionArray);",
    "public static IReadOnlyList<FormalAttributeDefinition> Definitions => s_definitions;",
    "public static int Count => s_definitions.Count;"
)

$formalAttributeCatalogDisallowedPatterns = Test-ContainsAny -Content $formalAttributeCatalogContent -Patterns @(
    "public static FormalAttributeDefinition[] Definitions =>",
    "public static IReadOnlyList<FormalAttributeDefinition> Definitions => s_definitionArray;",
    "public static IList<FormalAttributeDefinition> Definitions =>"
)

$disallowedAbilitySheetFiles = @(
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs.meta",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Active/ActiveAbilitySheet.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Active/ActiveAbilitySheet.cs.meta",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Passive/PassiveAbilitySheet.cs",
    "Assets/Scripts/GameCore/Runtime/Database/Abilities/Passive/PassiveAbilitySheet.cs.meta"
)

$abilitySheetExistingFiles = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $disallowedAbilitySheetFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        [void]$abilitySheetExistingFiles.Add($fullPath)
    }
}

$characterAlterationRuleMissingPatterns = Test-ContainsAll -Content $characterAlterationRuleContent -Patterns @(
    "public enum ECharacterAlterationRuleKind",
    "public enum ECharacterAlterationStackingPolicy",
    "public class CharacterAlterationRule : DatabaseEntry, INameable",
    "[CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(CharacterAlterationRule))]",
    "private ECharacterAlterationStackingPolicy m_stackingPolicy = ECharacterAlterationStackingPolicy.Unique;",
    "private string m_exclusiveGroupId = string.Empty;",
    "private int m_priority;",
    "private int[] m_grantedFormalGasAbilityCodes = Array.Empty<int>();",
    "private int[] m_suppressedFormalGasAbilityCodes = Array.Empty<int>();",
    "private EActionFlags m_lockedActions = EActionFlags.None;",
    "private bool m_lockPlayerControl = false;",
    "private bool m_forceAIControl = false;",
    "private bool m_suppressEquipmentEffects = false;",
    "private bool m_overrideAlignment = false;",
    "private EAlignment m_alignmentOverride = EAlignment.Default;",
    "public ECharacterAlterationStackingPolicy stackingPolicy => m_stackingPolicy;",
    "public string exclusiveGroupId => m_exclusiveGroupId;",
    "public int priority => m_priority;",
    "public EActionFlags lockedActions => m_lockedActions;",
    "public bool locksPlayerControl => m_lockPlayerControl;",
    "public bool forcesAIControl => m_forceAIControl;",
    "public bool suppressesEquipmentEffects => m_suppressEquipmentEffects;",
    "public bool overridesAlignment => m_overrideAlignment;",
    "public EAlignment alignmentOverride => m_alignmentOverride;",
    "public bool TryCreateAbilitySourceKey(DatabaseRegistry database, out CharacterAbilitySourceKey source)",
    "public void EnsureFormalGasAbilityCodeConfiguration()",
    "public bool TryValidateFormalGasAbilityCodeConfiguration(out string errorMessage)",
    "TryCreateInvalidFormalGasAbilityCodeMessage(",
    "formalGasAbilityCodes[index] > 0",
    "private bool TryResolveRegisteredSourceId(DatabaseRegistry database, out string sourceId)",
    "foreach (var entry in database.GetEntries())",
    "source = new CharacterAbilitySourceKey(MapSourceKind(m_ruleKind), sourceId);",
    "public CharacterAlterationAbilityChangeResult ApplyAbilityChanges(CharacterBase target, DatabaseRegistry database)",
    "target.AddSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source)",
    "target.AddSourcedBonusFormalGasAbility(formalGasAbilityCode, source)",
    "public CharacterAlterationAbilityChangeResult RemoveAbilityChanges(CharacterBase target, DatabaseRegistry database)",
    "target.RemoveAllSourcedBonusAbilities(source)",
    "target.RemoveAllSourcedAbilitySuppressions(source)",
    "public CharacterAlterationAbilityChangeResult RemoveAbilityChangeStack(CharacterBase target, DatabaseRegistry database)",
    "target.RemoveSourcedBonusFormalGasAbility(formalGasAbilityCode, source)",
    "target.RemoveSourcedFormalGasAbilitySuppression(formalGasAbilityCode, source)",
    "public bool ApplyNonAbilityChanges(CharacterBase target, DatabaseRegistry database)",
    "target.ApplyAlterationActionLockRule(source, m_lockedActions)",
    "target.ApplyAlterationPlayerControlLockRule(source)",
    "target.ApplyAlterationAIControlRule(source)",
    "target.ApplyAlterationEquipmentEffectSuppressionRule(source)",
    "target.ApplyAlterationAlignmentRule(source, m_alignmentOverride, m_priority)",
    "public bool RemoveNonAbilityChanges(CharacterBase target, DatabaseRegistry database)",
    "target.RemoveAllAlterationActionLockRules(source)",
    "target.RemoveAllAlterationPlayerControlLockRules(source)",
    "target.RemoveAllAlterationAIControlRules(source)",
    "target.RemoveAllAlterationEquipmentEffectSuppressionRules(source)",
    "target.RemoveAllAlterationAlignmentRules(source)",
    "public bool RemoveNonAbilityChangeStack(CharacterBase target, DatabaseRegistry database)",
    "target.RemoveAlterationActionLockRuleStack(source)",
    "target.RemoveAlterationPlayerControlLockRuleStack(source)",
    "target.RemoveAlterationAIControlRuleStack(source)",
    "target.RemoveAlterationEquipmentEffectSuppressionRuleStack(source)",
    "target.RemoveAlterationAlignmentRuleStack(source)",
    "ECharacterAlterationRuleKind.Infection => ECharacterAbilitySourceKind.Infection"
)

$temporalEffectInterfaceMissingPatterns = Test-ContainsAll -Content $temporalEffectInterfaceContent -Patterns @(
    "public TemporalEffectRuntimeTraits GetRuntimeTraits();",
    "public void AdvanceRuntimeLifetime(float deltaTime);",
    "public interface ITemporalEffectRuntimeStateCarrier",
    "bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState);",
    "bool TryRestorePersistedState(TemporalEffectPersistedState persistedState);"
)

$temporalEffectInterfaceDisallowedPatterns = Test-ContainsAny -Content $temporalEffectInterfaceContent -Patterns @(
    "CreateLegacyFallbackPresentationSnapshot();",
    "MatchesLegacyCleanseTypes(ISet<EEffectType> effectTypes);",
    "public string displayName;",
    "public string description;",
    "public readonly string termId;"
)

$temporalEffectBaseMissingPatterns = Test-ContainsAll -Content $temporalEffectBaseContent -Patterns @(
    "protected void CopySharedTemporalStateTo(ATemporalEffect target)",
    "public virtual TemporalEffectRuntimeTraits GetRuntimeTraits()",
    "public void AdvanceRuntimeLifetime(float deltaTime)",
    "internal TemporalEffectSharedPersistedFields CreateSharedPersistedFields()",
    "internal void RestoreSharedPersistedFields(TemporalEffectSharedPersistedFields fields)",
    "protected bool TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source)",
    "internal bool TryGetPresentationState(out TemporalEffectPresentationState presentationState)"
)

$temporalEffectBaseDisallowedPatterns = Test-ContainsAny -Content $temporalEffectBaseContent -Patterns @(
    "TemporalEffectLegacyFallbackState",
    "CreateLegacyFallbackDescription(",
    "HasFormalGameplayEffectMapping()",
    "CreateFormalRuntimeState()",
    "ShouldFormalRuleOwnConsequences()",
    "SyncRuntimeTimingFromFormalRule"
)

$temporalAbilityGrantEffectMissingPatterns = Test-ContainsAll -Content $temporalAbilityGrantEffectContent -Patterns @(
    "public class TemporalAbilityGrantEffectPersistedState : TemporalEffectPersistedState",
    "public class TemporalAbilityGrantEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier",
    "public int[] formalGasAbilityCodes;",
    "protected override bool OnApply()",
    "EnsureFormalGasAbilityCodeConfiguration();",
    "TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(",
    "return false;",
    "protected override void OnRuntimeStateRestored()",
    "protected override void OnCompleted()",
    "TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source)",
    "targetCharacter.RemoveAllStatusEffectAbilities(source);",
    "targetCharacter.AddStatusEffectFormalGasAbility(formalGasAbilityCode, source);",
    "public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)",
    "public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)",
    "TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(",
    "TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(",
    "private void EnsureFormalGasAbilityCodeConfiguration()",
    "TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration("
)

$temporalAbilitySuppressionEffectMissingPatterns = Test-ContainsAll -Content $temporalAbilitySuppressionEffectContent -Patterns @(
    "public class TemporalAbilitySuppressionEffectPersistedState : TemporalEffectPersistedState",
    "public class TemporalAbilitySuppressionEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier",
    "public int[] formalGasAbilityCodes;",
    "protected override bool OnApply()",
    "EnsureFormalGasAbilityCodeConfiguration();",
    "TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(",
    "return false;",
    "protected override void OnRuntimeStateRestored()",
    "protected override void OnCompleted()",
    "TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source)",
    "targetCharacter.RemoveAllStatusEffectAbilitySuppressions(source);",
    "targetCharacter.AddStatusEffectFormalGasAbilitySuppression(formalGasAbilityCode, source);",
    "public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)",
    "public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)",
    "TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(",
    "TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(",
    "private void EnsureFormalGasAbilityCodeConfiguration()",
    "TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration("
)

$temporalAbilityReplacementEffectMissingPatterns = Test-ContainsAll -Content $temporalAbilityReplacementEffectContent -Patterns @(
    "public class TemporalAbilityReplacementEffectPersistedState : TemporalEffectPersistedState",
    "public class TemporalAbilityReplacementEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier",
    "public int[] grantedFormalGasAbilityCodes;",
    "public int[] suppressedFormalGasAbilityCodes;",
    "protected override bool OnApply()",
    "EnsureFormalGasAbilityCodeConfiguration();",
    "TemporalAbilityEffectSupport.HasConfiguredFormalGasAbilityCodes(",
    "return false;",
    "protected override void OnRuntimeStateRestored()",
    "protected override void OnCompleted()",
    "TryCreateStatusEffectAbilitySource(out CharacterAbilitySourceKey source)",
    "targetCharacter.RemoveAllStatusEffectAbilities(source);",
    "targetCharacter.RemoveAllStatusEffectAbilitySuppressions(source);",
    "targetCharacter.AddStatusEffectFormalGasAbility(formalGasAbilityCode, source);",
    "targetCharacter.AddStatusEffectFormalGasAbilitySuppression(formalGasAbilityCode, source);",
    "public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)",
    "public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)",
    "TemporalAbilityEffectSupport.TryValidateRestoredFormalGasAbilityCodeConfiguration(",
    "TemporalAbilityEffectSupport.TryHasRestoredFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CreateFormalGasAbilityCodes(",
    "TemporalAbilityEffectSupport.CloneFormalGasAbilityCodes(",
    "private void EnsureFormalGasAbilityCodeConfiguration()",
    "TemporalAbilityEffectSupport.EnsureFormalGasAbilityCodeConfiguration("
)

$temporalAbilityEffectSupportMissingPatterns = Test-ContainsAll -Content $temporalAbilityEffectSupportContent -Patterns @(
    "public static bool HasConfiguredFormalGasAbilityCodes(params int[][] formalGasAbilityCodeGroups)",
    "public static void EnsureFormalGasAbilityCodeConfiguration(",
    "public static bool TryValidateFormalGasAbilityCodeConfiguration(",
    "public static bool TryValidateRestoredFormalGasAbilityCodeConfiguration(",
    "public static bool TryHasRestoredFormalGasAbilityCodes(",
    "formalGasAbilityCodes[index] > 0",
    "throw new InvalidOperationException(errorMessage);"
)

$temporalStatModifierEffectMissingPatterns = @(
    (Test-ContainsAll -Content $temporalStatModifierEffectContent -Patterns @(
        "public class TemporalStatModifierEffectPersistedState : TemporalEffectPersistedState",
        "public class TemporalStatModifierEffect : ATemporalEffect, ITemporalEffectRuntimeStateCarrier",
        "public override TemporalEffectRuntimeTraits GetRuntimeTraits() =>",
        "TemporalEffectRuntimeTraits.NeedsLocalLifetimeAdvance;",
        "public bool TryCapturePersistedState(out TemporalEffectPersistedState persistedState)",
        "public bool TryRestorePersistedState(TemporalEffectPersistedState persistedState)"
    ))
    (Test-MethodContainsAll -Content $temporalStatModifierEffectContent -MethodName "OnApply" -Patterns @(
        "switch (m_statBoostData.stat)",
        "targetCharacter.ModifyCurrentHealth(m_statBoostData.amount);",
        "targetCharacter.ModifyCurrentMana(m_statBoostData.amount);"
    ))
    (Test-MethodContainsAll -Content $temporalStatModifierEffectContent -MethodName "OnCompleted" -Patterns @(
        "targetCharacter.ClampCurrentHealthDelta(-amountToRemove, minimumValue: 1);",
        "targetCharacter.ClampCurrentManaDelta(-amountToRemove);",
        "targetCharacter.ModifyCurrentHealth(-amountToRemove, minimumValue: 1);",
        "targetCharacter.ModifyCurrentMana(-amountToRemove);"
    ))
)

$temporalEffectFallbackContractRegressionHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal")
) -Patterns @(
    "TermDefinition termDefinition = GameManager.Config.GetTermDefinition(",
    "out TermDefinition termDefinition",
    "ResolveSpeedModifierTermDefinition()"
)

$formalGasMappingAuditMissingPatterns = @()
$formalGasMappingAuditDisallowedPatterns = @()
$formalGasTemplateBootstrapMissingPatterns = @()
$formalGasTemplateBootstrapDisallowedPatterns = @()
$formalGasTemplateBootstrapScriptMissingPatterns = @()
$formalGasTemplateBootstrapScriptDisallowedPatterns = @()
$formalGasTemplateAssetMissingPatterns = @()

$characterBaseDisallowedPatterns = Test-ContainsAny -Content $characterBaseContent -Patterns @(
    "m_invincibilityFrames",
    "invincibility only happens one frame after the animation",
    "m_temporalEffectRuntime"
)
$characterBaseMainMissingPatterns = Test-ContainsAll -Content $characterBaseContent -Patterns @(
    "using GAS.Runtime;",
    "[RequireComponent(typeof(AbilitySystemComponent))]",
    "[RequireComponent(typeof(CharacterAbilitySet))]",
    "private readonly CharacterActionStateRuntime m_actionRuntime = new();",
    "private readonly AttributeBootstrapBuffer m_attributeBootstrapBuffer = new();",
    "private bool m_isAttributeBootstrapReadWindowOpen = true;",
    "private bool m_isDeadAndDestroyed = false;",
    "private float m_temporaryInvincibilityTimer = 0.0f;",
    "TryResolveAlterationAlignmentOverride(out EAlignment alterationAlignment)",
    "protected override void Awake()",
    "protected override void Update()",
    "protected override void OnDeathAnimationEnd()",
    "protected override void OnDeath()",
    "protected override AudioClipResolver GetDeathAudio() => characterSheet.deathAudio;",
    "public override void Revive()",
    "public override string GetSpeakerName() => characterSheet.displayName;",
    "public override void OnInteract(CharacterBase sender)",
    "public override bool CanUpdateTargetDirection()",
    "public override bool CanMove() => base.CanMove() && Can(EActionFlags.Move);",
    "protected override float CalculateMoveSpeed()",
    "protected virtual void InitializeStats()",
    "protected void SetResolvedBaseStats(Stats stats)",
    "public override void Kill()",
    "CloseAttributeBootstrapReadWindow();",
    "ClearOwnedCharacterTransientState();",
    "private void CloseAttributeBootstrapReadWindow()",
    "private void ClearOwnedCharacterTransientState()",
    "if (!TryGetInitializedFormalAttributes(out _))"
)
$characterBasePrefabMissingPatterns = @()
$characterBaseContractsMissingPatterns = Test-ContainsAll -Content $characterBaseContractsContent -Patterns @(
    "public enum EAlignment",
    "public enum EResourceValidationResult",
    "public enum EActionFlags",
    "ManageInventory = 1 << 4,",
    "ChangeEquipment = 1 << 5,",
    "public enum ECharacterAbilitySourceKind",
    "public readonly struct CharacterAbilitySourceKey",
    "public class CharacterAbilitySourceData",
    "public class CharacterBaseDataBlock : MovableDataBlock",
    "public DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules;",
    "public CharacterAbilityRuntimeStateData[] abilityRuntimeStates;",
    "public CharacterAbilitySourceData[] abilitySources;",
    "public CharacterAbilitySourceData[] abilitySuppressions;",
    "public CharacterTemporalEffectRuntimeStateData[] temporalEffectRuntimeStates;",
    "public class CharacterAbilityRuntimeStateData",
    "public class CharacterTemporalEffectRuntimeStateData",
    "runtimeStateCarrier.TryRestorePersistedState(runtimeState)"
)
$characterBaseContractsDisallowedPatterns = Test-ContainsAny -Content $characterBaseContractsContent -Patterns @(
    "legacyAbilityDataBlocks",
    "legacyTemporalEffects",
    "legacyLockedActions",
    "legacySpeedModifiers",
    "FormerlySerializedAs(",
    "public SerializableDictionary<DatabaseEntryReference<AbilitySheet>, int> bonusAbilities;"
)
$characterBaseResourcesMissingPatterns = Test-ContainsAll -Content $characterBaseResourcesContent -Patterns @(
    "public void ModifyCurrentStat(EStat stat, int delta)",
    "public int GetMaxHealth() => GetFormalBaseStatOrBootstrapBuffer(EStat.Health);",
    "public bool CanModifyCurrentHealth(int delta, int minimumValue = 0)",
    "private void SetFormalCurrentStatOrReportFailure(EStat stat, int value)",
    "private int GetFormalBaseStatOrBootstrapBuffer(EStat stat)",
    "private int GetFormalCurrentStatOrBootstrapBuffer(EStat stat)",
    "private Stats CreateBootstrapBaseStatsSnapshotOrReportFailure()",
    "private Stats CreateBootstrapCurrentStatsSnapshotOrReportFailure()",
    "private bool IsAttributeBootstrapReadWindowOpen() => m_isAttributeBootstrapReadWindowOpen;",
    "public bool Damage(DamageOutputDescriptor damageOutput, EEffectVisualFlags visualFlags = EEffectVisualFlags.None, Vector2? velocity = null, DamageImpactSettings damageImpact = default)",
    "m_provoked.Invoke(sourceCharacter);",
    "characterSheet.feedbacks.PlayDamageTaken(transform.position, this, damageInput, visualFlags);",
    "public virtual void LevelUp(bool silentMode = false)",
    "UnlockFormalGasAbilitiesForLevel(characterSheet.GetFormalGasAbilitiesUnlockedAtLevel(m_level));",
    "m_levelUpped.Invoke(m_level);",
    "private void ExtendTemporaryInvincibility(float duration)"
)
$characterBaseResourcesDisallowedPatterns = Test-ContainsAny -Content $characterBaseResourcesContent -Patterns @(
    "SetLegacyCurrentStatAndNotify(",
    "m_attributeBootstrapBuffer.ReplaceCurrentStats(nextCurrentStats);",
    "public Stats CreateStatsSnapshot() => TryGetInitializedFormalAttributes(out _) ? CreateFormalBaseStatsSnapshot() : m_attributeBootstrapBuffer.CreateBaseStatsSnapshot();",
    "public Stats CreateCurrentStatsSnapshot() => TryGetInitializedFormalAttributes(out _) ? CreateFormalCurrentStatsSnapshot() : m_attributeBootstrapBuffer.CreateCurrentStatsSnapshot();",
    "CreateCombatStatSnapshotFromCurrentStats(m_attributeBootstrapBuffer.CreateCurrentStatsSnapshot())",
    "private bool IsAttributeBootstrapReadWindowOpen() => !m_isFormalAbilitySystemReady;"
)
$characterBaseAbilitiesMissingPatterns = Test-ContainsAll -Content $characterBaseAbilitiesContent -Patterns @(
    "protected virtual void OnFormalGasAbilityAdded(int formalGasAbilityCode)",
    "private void InitializeAbilities()",
    "public bool AddSourcedBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public bool RemoveSourcedBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllSourcedBonusAbilities(CharacterAbilitySourceKey source)",
    "public bool AddSourcedFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public bool RemoveSourcedFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllSourcedAbilitySuppressions(CharacterAbilitySourceKey source)",
    "public bool AddStatusEffectFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllStatusEffectAbilities(CharacterAbilitySourceKey source)",
    "public bool AddStatusEffectFormalGasAbilitySuppression(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllStatusEffectAbilitySuppressions(CharacterAbilitySourceKey source)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllTransformationAbilities(string transformationId)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllTransformationAbilitySuppressions(string transformationId)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllInfectionAbilities(string infectionId)",
    "public CharacterAbilitySourceRuntimeEntry[] RemoveAllInfectionAbilitySuppressions(string infectionId)",
    "private static CharacterAbilitySourceKey CreateTransformationAbilitySource(string transformationId)",
    "private static CharacterAbilitySourceKey CreateInfectionAbilitySource(string infectionId)",
    "private static bool IsTemporaryAbilitySourceKind(ECharacterAbilitySourceKind sourceKind)",
    "private void ApplyFormalGasAbilitySuppressionState(int formalGasAbilityCode)",
    "public EAbilityFireCheckResult FireFormalGasAbility(int formalGasAbilityCode, GameCommandContext commandContext)",
    "public bool StopFireFormalGasAbility(int formalGasAbilityCode)",
    "public bool TryEquipFormalGasAbilityCodeToSlot(int formalGasAbilityCode, int index)",
    "private void InterruptActions() => AbilityRuntime.NotifyActionInterrupted();",
    "private void UnlockFormalGasAbilitiesForLevel(IEnumerable<int> formalGasAbilityCodes)",
    "private AbilityBase InstantiateFormalGasAbilityPrefab(int formalGasAbilityCode)",
    "return abilitySet.FireFormalGasAbility(formalGasAbilityCode, commandContext);",
    "abilitySet.CancelFormalGasAbilityRuleLifecycle(formalGasAbilityCode);"
)
$characterBaseAbilitiesDisallowedPatterns = Test-ContainsAny -Content $characterBaseAbilitiesContent -Patterns @(
    "public void AddBonusAbility(AbilitySheet ability, int count = 1)",
    "public void RemoveBonusAbility(AbilitySheet ability)",
    "ability.Fire(null);",
    "ability.Fire(() =>"
)
$characterBaseAlterationsMissingPatterns = Test-ContainsAll -Content $characterBaseAlterationsContent -Patterns @(
    "private readonly Dictionary<CharacterAlterationRule, int> m_activeAlterationRules = new();",
    "public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule)",
    "public bool ApplyCharacterAlterationRule(CharacterAlterationRule alterationRule, DatabaseRegistry database)",
    "alterationRule.EnsureFormalGasAbilityCodeConfiguration();",
    "alterationRule.stackingPolicy != ECharacterAlterationStackingPolicy.Stackable",
    "TryRemoveLowerPriorityExclusiveAlterationRules(alterationRule, database)",
    "CharacterAlterationAbilityChangeResult result = alterationRule.ApplyAbilityChanges(this, database);",
    "alterationRule.ApplyNonAbilityChanges(this, database);",
    "m_activeAlterationRules[alterationRule] = currentStackCount + 1;",
    "RevalidatePlayerControlEligibility();",
    "public bool RemoveCharacterAlterationRule(CharacterAlterationRule alterationRule)",
    "public bool RemoveCharacterAlterationRule(CharacterAlterationRule alterationRule, DatabaseRegistry database)",
    "CharacterAlterationAbilityChangeResult result = alterationRule.RemoveAbilityChanges(this, database);",
    "alterationRule.RemoveNonAbilityChanges(this, database);",
    "public bool RemoveCharacterAlterationRuleStack(CharacterAlterationRule alterationRule)",
    "public bool RemoveCharacterAlterationRuleStack(CharacterAlterationRule alterationRule, DatabaseRegistry database)",
    "CharacterAlterationAbilityChangeResult result = alterationRule.RemoveAbilityChangeStack(this, database);",
    "alterationRule.RemoveNonAbilityChangeStack(this, database);",
    "internal DatabaseEntryReference<CharacterAlterationRule>[] CreateActiveAlterationRuleSnapshots()",
    "if (!rule || stackCount <= 0)",
    "throw new System.InvalidOperationException(",
    "snapshots.Add(GameManager.Database.CreateReference(rule));",
    "internal void RestoreActiveAlterationRules(DatabaseEntryReference<CharacterAlterationRule>[] activeAlterationRules)",
    "GameManager.Database.LoadFromReference(alterationRuleReference)",
    "ClearAlterationActionLockRules();",
    "ClearAlterationPlayerControlLockRules();",
    "ClearAlterationAIControlRules();",
    "ClearAlterationEquipmentEffectSuppressionRules();",
    "ClearAlterationAlignmentRules();",
    "alterationRule.ApplyNonAbilityChanges(this, GameManager.Database);",
    "m_activeAlterationRules[alterationRule] = currentStackCount + 1;",
    "private bool TryRemoveLowerPriorityExclusiveAlterationRules(",
    "rule.priority > incomingRule.priority",
    "RemoveCharacterAlterationRule(conflictingRule, database);",
    "internal void ClearActiveAlterationRules()",
    "private void RevalidatePlayerControlEligibility()",
    "GameManager.PlayerSystem.RevalidateCurrentControlledCharacter();"
)
$characterBaseActionStateRuntimeMissingPatterns = Test-ContainsAll -Content $characterBaseActionStateRuntimeContent -Patterns @(
    "public abstract partial class CharacterBase",
    "private sealed class CharacterActionStateRuntime",
    "private readonly Dictionary<CharacterAbilitySourceKey, CharacterActionLockRuntimeEntry> m_alterationRuleActionLocks = new();",
    "private readonly struct CharacterActionLockRuntimeEntry",
    "public float[] CreateMoveSpeedFactorSnapshot()",
    "public string ApplyMoveSpeedFactor(float factor)",
    "public string LockActions(EActionFlags actions)",
    "public void ApplyAlterationRuleActionLock(CharacterAbilitySourceKey source, EActionFlags actions)",
    "m_alterationRuleActionLocks[source] = new CharacterActionLockRuntimeEntry(nextActions, nextStackCount);",
    "public void RemoveAlterationRuleActionLockStack(CharacterAbilitySourceKey source)",
    "public void RemoveAllAlterationRuleActionLocks(CharacterAbilitySourceKey source)",
    "public void ClearAlterationRuleActionLocks()",
    "foreach (CharacterActionLockRuntimeEntry entry in m_alterationRuleActionLocks.Values)",
    "public bool Can(EActionFlags actions)"
)
$characterBaseActionStateRuntimeDisallowedPatterns = Test-ContainsAny -Content $characterBaseActionStateRuntimeContent -Patterns @(
    "internal sealed class CharacterActionStateRuntime",
    "public sealed class CharacterActionStateRuntime",
    "public IEnumerable<float> EnumerateMoveSpeedFactors()"
)
$characterBaseAbilitySetRuntimeMissingPatterns = Test-ContainsAll -Content $characterBaseAbilitySetRuntimeContent -Patterns @(
    "internal sealed class CharacterAbilitySetRuntime",
    "public bool TryAddUnlockedFormalGasAbility(",
    "public void UpdateRuntime()",
    "private readonly Dictionary<RuntimeAbilityKey, Dictionary<CharacterAbilitySourceKey, int>> m_suppressedAbilitySources = new();",
    "public bool TrySuppressFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public bool TryUnsuppressFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)",
    "public bool IsFormalGasAbilitySuppressed(int formalGasAbilityCode)",
    "public CharacterAbilitySourceRuntimeEntry[] CreateSuppressedAbilitySourceEntrySnapshot()",
    "public CharacterAbilitySourceRuntimeEntry[] CreateSuppressedAbilitySourceEntrySnapshot(CharacterAbilitySourceKey source)",
    "public CharacterAbilitySourceRuntimeEntry[] CreateBonusAbilitySourceEntrySnapshot()",
    "public CharacterAbilitySourceRuntimeEntry[] CreateBonusAbilitySourceEntrySnapshot(CharacterAbilitySourceKey source)",
    "public bool TryUnregisterBonusFormalGasAbility(",
    "int count,",
    "public KeyValuePair<int, AbilityBase>[] GetFormalGasAbilityInstanceEntriesSnapshot()",
    "public int[] GetFormalGasAbilityCodeSnapshots()"
)
$characterBaseAbilitySetRuntimeDisallowedPatterns = Test-ContainsAny -Content $characterBaseAbilitySetRuntimeContent -Patterns @(
    "public sealed class CharacterAbilitySetRuntime",
    "public IEnumerable<KeyValuePair<AbilitySheet, int>> GetBonusAbilityEntries()",
    "public KeyValuePair<AbilitySheet, int>[] CreateBonusAbilityEntrySnapshot()",
    "public bool TryRegisterBonusAbility(AbilitySheet ability, int count = 1)",
    "return TryRegisterBonusAbility(ability, CharacterAbilitySourceKey.LegacyBonus, count);",
    "public bool TryUnregisterBonusAbility(AbilitySheet ability)",
    "return TryUnregisterBonusAbility(ability, CharacterAbilitySourceKey.LegacyBonus);"
)
$characterBaseAttributeBootstrapBufferMissingPatterns = Test-ContainsAll -Content $characterBaseAttributeBootstrapBufferContent -Patterns @(
    "public abstract partial class CharacterBase",
    "private sealed class AttributeBootstrapBuffer",
    "public void ReplaceBaseStats(Stats stats)",
    "public void MirrorFromFormalSnapshots(Stats baseStats, Stats currentStats)"
)
$characterBaseAttributeBootstrapBufferDisallowedPatterns = Test-ContainsAny -Content $characterBaseAttributeBootstrapBufferContent -Patterns @(
    "internal sealed class AttributeBootstrapBuffer",
    "public sealed class AttributeBootstrapBuffer"
)
$activeAbilityBaseMissingPatterns = Test-ContainsAll -Content $activeAbilityBaseContent -Patterns @(
    "public void Fire(",
    "GameCommandContext commandContext",
    "AbilityActivationContext activationContext",
    "private GameCommandContext m_fireCommandContext = GameCommandContext.Script();",
    "protected GameCommandContext activeCommandContext => m_fireCommandContext;",
    "m_fireCommandContext = GameCommandContext.ResolveForActor(character);",
    "m_fireCommandContext = commandContext.HasActor",
    "GameCommandContext.Recreate(commandContext.IssuerKind, m_character, commandContext.IssuerId);",
    "runtimeState.remainingCooldownTimer = remainingCooldownValue;",
    "runtimeState.inputGate = m_inputGate?.CreatePersistentData() ?? default;",
    "m_inputGate?.LoadPersistentData(runtimeState.inputGate);",
    "m_casting = false;",
    "m_effectCostPaidForCurrentUse = false;",
    "m_onAbilityEndedCallback = null;",
    "float savedRemainingCooldown = runtimeState.remainingCooldownTimer;"
)
$activeAbilityBaseDisallowedPatterns = Test-ContainsAny -Content $activeAbilityBaseContent -Patterns @(
    "runtimeState.hasActiveRuntimeState = true;",
    "public void Fire(UnityAction onAbilityEnded)",
    "m_weaponExecution?.LoadData(block.As<ActiveAbilityBaseDataBlock>().weaponExecution);",
    "block.As<ActiveAbilityBaseDataBlock>().weaponExecution = m_weaponExecution?.CreateData() ?? default;"
)
$projectileMissingPatterns = Test-ContainsAll -Content $projectileCompositeContent -Patterns @(
    "internal bool shouldPersistRuntimeState => m_operating && m_remainingLifetime > 0.0f;",
    "public readonly struct ProjectileLaunchParameters",
    "private GameCommandContext m_fireCommandContext = GameCommandContext.Script();",
    "public void Throw(CharacterBase source, Vector2 direction, ProjectileLaunchParameters parameters, GameCommandContext commandContext)",
    "m_baseDamage = parameters.BaseDamage;",
    "m_speed = parameters.Speed;",
    "m_fireCommandContext = commandContext.HasActor",
    "return GameCommandContext.Recreate(m_fireCommandContext.IssuerKind, m_source, m_fireCommandContext.IssuerId);",
    "public EGameCommandIssuerKind fireCommandIssuerKind;",
    "public string fireCommandIssuerId;",
    "projectileBlock.fireCommandIssuerKind = m_fireCommandContext.IssuerKind;",
    "projectileBlock.fireCommandIssuerId = m_fireCommandContext.IssuerId;",
    "m_fireCommandContext = GameCommandContext.Recreate(projectileBlock.fireCommandIssuerKind, m_source, projectileBlock.fireCommandIssuerId);"
)
$projectileAbilityMissingPatterns = @()
$projectileAbilityDisallowedPatterns = @(
    if (Test-Path -LiteralPath $projectileAbilityPath) { "旧 ProjectileAbility.cs 不应继续存在；投射物能力必须由 EX-GAS Timeline/Task 重新表达。" }
)
$summoningAbilityMissingPatterns = @()
$summoningAbilityDisallowedPatterns = @(
    if (Test-Path -LiteralPath $summoningAbilityPath) { "旧 SummoningAbility.cs 不应继续存在；召唤能力必须由 EX-GAS Ability/Timeline/GameplayEffect/Cue 重新表达。" }
)
$perTargetCooldownMissingPatterns = Test-ContainsAll -Content $perTargetCooldownContent -Patterns @(
    "CanTrackTarget(target) && !IsTargetOnCooldown(target)",
    "public bool IsTargetOnCooldown(TargetType target) => CanTrackTarget(target) && m_perTargetCooldowns.ContainsKey(target);",
    "if (CanTrackTarget(target) && duration > 0.0f)",
    "if (!CanTrackTarget(key))",
    "if (!CanTrackTarget(pair.Key) || pair.Value <= 0.0f)",
    "if (block?.perTargetCooldowns == null)",
    "if (!CanTrackTarget(target) || pair.Value <= 0.0f)",
    "private static bool CanTrackTarget(TargetType target)",
    "return target != null && !target.isMarkedAsDestroyed;"
)
$perTargetCooldownDisallowedPatterns = Test-ContainsAny -Content $perTargetCooldownContent -Patterns @(
    ".Where(target => target != null && !IsTargetOnCooldown(target))",
    "m_perTargetCooldowns.ToDictionary(",
    ".Where(pair => pair.Target != null)",
    ".ToDictionary(pair => pair.Target, pair => pair.Value)"
)
$disallowedWeaponExecutionFiles = @(
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionRuntime.cs.meta",
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionSettings.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionSettings.cs.meta",
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponHitWindowRuntime.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponHitWindowRuntime.cs.meta"
)

$weaponExecutionExistingFiles = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $disallowedWeaponExecutionFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        [void]$weaponExecutionExistingFiles.Add($fullPath)
    }
}
$characterBaseTemporalEffectRuntimeMissingPatterns = Test-ContainsAll -Content $characterBaseTemporalEffectRuntimeContent -Patterns @(
    "public abstract partial class CharacterBase",
    "private readonly SortedDictionary<int, ITemporalEffect> m_temporalEffectsByRuntimeKey = new();",
    "private ITemporalEffect RegisterOwnedTemporalEffect(ITemporalEffect effect)",
    "private bool TryGetOwnedTemporalEffect(int runtimeKey, out ITemporalEffect effect)",
    "private int[] GetOwnedTemporalEffectRuntimeKeySnapshot()",
    "private bool IsCurrentOwnedTemporalEffect(ITemporalEffect effect)",
    "private ITemporalEffect[] RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(int[] runtimeKeys)"
)
$characterBaseTemporalEffectRuntimeDisallowedPatterns = Test-ContainsAny -Content $characterBaseTemporalEffectRuntimeContent -Patterns @(
    "private sealed class CharacterTemporalEffectRuntime",
    "internal sealed class CharacterTemporalEffectRuntime",
    "public sealed class CharacterTemporalEffectRuntime",
    "m_temporalEffectRuntime",
    "UpdateEffects(",
    "AdvanceLegacyRuntimeShell(",
    "EnumerateEffects(",
    "GetExecutionShellsSnapshot(",
    "CreateLegacyFallbackPresentation",
    "GetLegacyRuntimeTraits",
    "TryCreateFromFormalRuntimeState",
    "RegisterFormalTemporalEffectRule",
    "UnregisterFormalTemporalEffectRule",
    "NotifyTemporalEffectPresentation",
    "int fallbackRuntimeKey = 0;",
    "foreach (KeyValuePair<int, ITemporalEffect> entry in m_effects)",
    "public ITemporalEffect[] ClearEffects()",
    "public ITemporalEffect[] RemoveEffects(IEnumerable<ITemporalEffect> effects)",
    "public ITemporalEffect[] RemoveEffectsByRuntimeKeys(IEnumerable<int> runtimeKeys)",
    "public void ReplaceExecutionShellSnapshot(ITemporalEffect[] effects)",
    "public void ReplaceExecutionShells(IEnumerable<ITemporalEffect> effects)",
    "public bool ContainsEffect(ITemporalEffect effect)",
    "public bool RemoveEffectPrematurely(ITemporalEffect effect, out ITemporalEffect removedEffect)",
    "private bool TryDetachRegisteredEffect(",
    "private bool IsRegisteredEffect("
)
$characterBaseGasRuntimeMissingPatterns = Test-ContainsAll -Content $characterBaseGasRuntimeContent -Patterns @(
    "private int CleanseOwnedTemporalEffects(EEffectType[] effectTypes)",
    "NormalizeTemporalEffectTypes(effectTypes)",
    "CollectOwnedTemporalEffectRuntimeKeysForCleanse(",
    "GetOwnedTemporalEffectRuntimeKeySnapshot()",
    "protected void ApplySavedCurrentStatsToOwnedAttributeTruth(Stats currentStats)",
    "private int ReadFormalBaseStatOrReportFailure(EStat stat)",
    "private int ReadFormalCurrentStatOrReportFailure(EStat stat)",
    "private CharacterTemporalEffectRuntimeStateData CreateOwnedTemporalEffectRuntimeState(ITemporalEffect effect)",
    "private void SyncFormalAbilityRuleRosterFromRuntime()"
)
$characterBaseGasRuntimeDisallowedPatterns = Test-ContainsAny -Content $characterBaseGasRuntimeContent -Patterns @(
    "ISet<int> formalRuntimeKeysToRemove",
    "formalRuntimeKeysToRemove.Contains(effect.runtimeKey)",
    "CollectMappedTemporalEffectsMissingFormalRuntime(",
    "private static int[] CollectFormalTemporalEffectRuntimeKeys(`r`n            EEffectType[] effectTypes,`r`n            AbilitySystemComponent abilitySystemComponent)",
    "private void TrackFormalTemporalGameplayEffectSpec(`r`n            int runtimeKey,`r`n            GameplayEffectSpec effectSpec,`r`n            AbilitySystemComponent abilitySystemComponent)",
    "if (abilitySystemComponent.GameplayEffectContainer.GameplayEffects().Contains(effectSpec))",
    "m_formalTemporalGameplayEffectSpecs",
    "private void ClearOwnedFormalTransientRuntimeState()",
    "IEnumerable<ITemporalEffect> executionShells",
    "Func<ITemporalEffect, bool> hasFormalRuntimePredicate",
    "CollectOwnedTemporalEffectsForLegacyCleanse(",
    "m_temporalEffectRuntime",
    "HasFormalGameplayEffectMapping()",
    "ShouldFormalRuleOwnTemporalEffectConsequences(",
    "private int CleanseOwnedTemporalEffects(IEnumerable<EEffectType> effectTypes)",
    "private static EEffectType[] NormalizeTemporalEffectTypes(IEnumerable<EEffectType> effectTypes)",
    "m_attributeBootstrapBuffer.ReplaceCurrentStats(currentStats);",
    "m_attributeBootstrapBuffer.GetBaseStat(definition.Stat);",
    "m_attributeBootstrapBuffer.GetCurrentStat(definition.Stat);"
)
$characterBaseStateApiMissingPatterns = Test-ContainsAll -Content $characterBaseStateApiContent -Patterns @(
    "private readonly UnityEvent<CharacterBase> m_provoked = new();",
    "private readonly UnityEvent<Stats> m_statsChanged = new();",
    "private readonly UnityEvent<Stats> m_currentStatsChanged = new();",
    "private readonly UnityEvent<int> m_levelUpped = new();",
    "private readonly UnityEvent<CharacterTemporalEffectPresentationSnapshot> m_temporalEffectPresentationAdded = new();",
    "public int Cleanse(params EEffectType[] effectTypes)",
    "public void AddProvokedListener(UnityAction<CharacterBase> listener)",
    "public void AddTemporalEffectPresentationAddedListener(UnityAction<CharacterTemporalEffectPresentationSnapshot> listener)",
    "private void PublishStatChanges(Stats previousBaseStats, Stats previousCurrentStats)",
    "private bool DidReachZeroHealth(Stats previousStats)",
    "public string ApplyMoveSpeedFactor(float factor)",
    "public string LockActions(EActionFlags actions)",
    "public void ApplyAlterationActionLockRule(CharacterAbilitySourceKey source, EActionFlags actions)",
    "public void RemoveAlterationActionLockRuleStack(CharacterAbilitySourceKey source)",
    "public void RemoveAllAlterationActionLockRules(CharacterAbilitySourceKey source)",
    "internal void ClearAlterationActionLockRules()",
    "private readonly Dictionary<CharacterAbilitySourceKey, CharacterAlignmentOverrideRuntimeEntry> m_alterationAlignmentOverrides = new();",
    "private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationPlayerControlLocks = new();",
    "private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationAIControlOverrides = new();",
    "public void ApplyAlterationPlayerControlLockRule(CharacterAbilitySourceKey source)",
    "public void RemoveAlterationPlayerControlLockRuleStack(CharacterAbilitySourceKey source)",
    "public void RemoveAllAlterationPlayerControlLockRules(CharacterAbilitySourceKey source)",
    "internal void ClearAlterationPlayerControlLockRules()",
    "public void ApplyAlterationAIControlRule(CharacterAbilitySourceKey source)",
    "public void RemoveAlterationAIControlRuleStack(CharacterAbilitySourceKey source)",
    "public void RemoveAllAlterationAIControlRules(CharacterAbilitySourceKey source)",
    "internal void ClearAlterationAIControlRules()",
    "private bool HasAlterationAIControlOverride()",
    "private void RefreshAlterationControllerOverride()",
    "TryActivateController<AIController>();",
    "ClearControllerOverride<AIController>();",
    "public bool CanBePlayerControlled()",
    "private bool HasAlterationPlayerControlLock()",
    "public virtual void ApplyAlterationEquipmentEffectSuppressionRule(CharacterAbilitySourceKey source)",
    "public virtual void RemoveAlterationEquipmentEffectSuppressionRuleStack(CharacterAbilitySourceKey source)",
    "public virtual void RemoveAllAlterationEquipmentEffectSuppressionRules(CharacterAbilitySourceKey source)",
    "internal virtual void ClearAlterationEquipmentEffectSuppressionRules()",
    "private readonly struct CharacterAlignmentOverrideRuntimeEntry",
    "public void ApplyAlterationAlignmentRule(CharacterAbilitySourceKey source, EAlignment alignment, int priority)",
    "public void RemoveAlterationAlignmentRuleStack(CharacterAbilitySourceKey source)",
    "public void RemoveAllAlterationAlignmentRules(CharacterAbilitySourceKey source)",
    "internal void ClearAlterationAlignmentRules()",
    "private bool TryResolveAlterationAlignmentOverride(out EAlignment alignment)",
    "private static int CompareAlignmentOverrideSource(CharacterAbilitySourceKey a, CharacterAbilitySourceKey b)",
    "private void AdvanceOwnedTemporalEffects(float deltaTime)",
    "private static void AdvanceOwnedTemporalEffect(ITemporalEffect effect, float deltaTime)",
    "private static CharacterTemporalEffectPresentationSnapshot CreateTemporalEffectPresentationSnapshotCore(ITemporalEffect effect)",
    "private void NotifyTemporalEffectPresentation(",
    "new TemporalEffectPresentationContext(",
    "public void FlagAsSummoned()",
    "public void SetAlignmentOverride(EAlignment? alignment)"
)
$characterBaseStateApiDisallowedPatterns = Test-ContainsAny -Content $characterBaseStateApiContent -Patterns @(
    "private IEnumerable<ITemporalEffect> EnumerateOwnedTemporalEffectExecutionShells()",
    "FinalizeOwnedTemporalEffects(IEnumerable<ITemporalEffect> effects)",
    "m_temporalEffectRuntime",
    "public int Cleanse(IEnumerable<EEffectType> effectTypes)",
    "foreach (ITemporalEffect targetEffect in CreateOwnedTemporalEffectExecutionShellSnapshot())",
    "CreateOwnedTemporalEffectExecutionShellSnapshot(",
    "public void RemoveTemporalEffectPrematurely(ITemporalEffect effect)",
    "effect.info.HasValue"
)
$characterBasePersistenceMissingPatterns = Test-ContainsAll -Content $characterBasePersistenceContent -Patterns @(
    "protected override Type GetDataBlockType() => typeof(CharacterBaseDataBlock);",
    "protected override void OnSave(PersistableDataBlock block)",
    "characterBlock.currentStats = CreateCurrentStatsSnapshot();",
    "characterBlock.activeAlterationRules = CreateActiveAlterationRuleSnapshots();",
    "characterBlock.abilityRuntimeStates =",
    "abilitySet.CreateAbilityRuntimeStates(",
    "characterBlock.abilitySuppressions = CreateAbilitySuppressionDataBlocks(",
    "characterBlock.temporalEffectRuntimeStates = CreateTemporalEffectRuntimeStates();",
    "protected override void OnLoad(PersistableDataBlock block)",
    "ClearOwnedAbilitySourceRuntimeState();",
    "RestoreAbilitySuppressions(",
    "RestoreActiveAlterationRules(characterBlock.activeAlterationRules);",
    "LoadOwnedTemporalEffects(characterBlock);",
    "ApplySavedCurrentStatsToOwnedAttributeTruth(characterBlock.currentStats);",
    "loadedAbilitySet.LoadAbilityRuntimeStates(",
    "private CharacterAbilitySourceData[] CreateAbilitySuppressionDataBlocks(",
    "private static void RestoreAbilitySuppressions(",
    "private static void RestoreLevel(int savedLevel, Func<int> getCurrentLevel, Action levelUpSilently)",
    "private CharacterTemporalEffectRuntimeStateData[] CreateTemporalEffectRuntimeStates()",
    "private void LoadOwnedTemporalEffects(CharacterBaseDataBlock block)",
    "private static ITemporalEffect[] CreateTemporalEffectsFromRuntimeStates(",
    "CharacterTemporalEffectRuntimeStateData[] runtimeStates",
    "private void RestoreLoadedTemporalEffects(",
    "private static ITemporalEffect[] CreateTemporalEffectsReadyForRuntimeRegistration(",
    "RegisterOwnedTemporalEffect(effect)",
    "runtimeState.TryCreateRuntimeEffect(out ITemporalEffect effect)",
    "abilitySet.CreateAbilityRuntimeStates(",
    "loadedAbilitySet.LoadAbilityRuntimeStates("
)
$characterBasePersistenceDisallowedPatterns = Test-ContainsAny -Content $characterBasePersistenceContent -Patterns @(
    "private static List<ITemporalEffect> CreateTemporalEffectsFromRuntimeStates(",
    "private static List<ITemporalEffect> ImportLegacyTemporalEffects(",
    "private void RestoreLoadedTemporalEffects(IEnumerable<ITemporalEffect> loadedEffects)",
    "IEnumerable<CharacterTemporalEffectRuntimeStateData> runtimeStates",
    "m_temporalEffectRuntime",
    "private static ITemporalEffect[] ImportLegacyTemporalEffects(IEnumerable<ITemporalEffect> legacyEffects)",
    "legacyAbilityDataBlocks",
    "legacyTemporalEffects",
    "legacyLockedActions",
    "legacySpeedModifiers",
    "LoadLegacyAbilityDataBlocks(",
    "ImportLegacyTemporalEffects(",
    "NormalizeLoadedAbilityBlockToFormalRuntimeState(",
    "NormalizeLoadedTemporalEffectBlockToFormalRuntimeState(",
    "characterBlock.bonusAbilities =",
    "characterBlock.bonusAbilities,",
    "private static void RestoreBonusAbilities("
)

$characterActorMissingPatterns = Test-ContainsAll -Content $characterActorContent -Patterns @(
    "public CharacterEquipmentSlotData[] equipmentSlots;",
    "public CharacterAbilitySlotData[] quickAbilitySlots;",
    "public class CharacterEquipmentSlotData",
    "public class CharacterAbilitySlotData",
    "actorBlock.equipmentSlots = CreateEquipmentSlotDataSnapshot(GameManager.Database);",
    "actorBlock.quickAbilitySlots = CreateEquippedAbilitySlotDataSnapshot(GameManager.Database);",
    "RestoreEquipmentFromSlotData(",
    "RestoreEquippedAbilitiesFromSlotData(",
    "public partial class CharacterActor : CharacterBase",
    "internal CharacterActorRuntimeStateData CreateActorRuntimeState()",
    "internal void LoadActorRuntimeState(CharacterActorRuntimeStateData runtimeState)"
)

$characterPlayerSystemNotificationMissingPatterns = @(
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "private void NotifyPlayerSystemAboutDeath()" -Patterns @(
        "GameManager.PlayerSystem.NotifyCharacterDied(this);"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "private void NotifyPlayerSystemAboutRevive()" -Patterns @(
        "GameManager.PlayerSystem.NotifyCharacterRevived(this);"
    )
    Test-MethodContainsAll -Content $characterBaseAlterationsContent -MethodName "private void RevalidatePlayerControlEligibility()" -Patterns @(
        "GameManager.PlayerSystem.RevalidateCurrentControlledCharacter();"
    )
    Test-MethodContainsAll -Content $characterActorContent -MethodName "protected override void OnDeath()" -Patterns @(
        "GameManager.PlayerSystem.NotifyCharacterKilled(this);"
    )
)

$characterPlayerSystemNotificationDisallowedPatterns = @(
    Test-MethodContainsAny -Content $characterBaseContent -MethodName "private void NotifyPlayerSystemAboutDeath()" -Patterns @(
        "GameManager.Exists()",
        "TryGetSystem",
        "return;"
    )
    Test-MethodContainsAny -Content $characterBaseContent -MethodName "private void NotifyPlayerSystemAboutRevive()" -Patterns @(
        "GameManager.Exists()",
        "TryGetSystem",
        "return;"
    )
    Test-MethodContainsAny -Content $characterBaseAlterationsContent -MethodName "private void RevalidatePlayerControlEligibility()" -Patterns @(
        "GameManager.Exists()",
        "TryGetSystem",
        "return;"
    )
    Test-MethodContainsAny -Content $characterActorContent -MethodName "protected override void OnDeath()" -Patterns @(
        "GameManager.Exists()",
        "TryGetSystem"
    )
)

$inventoryActionLockMissingPatterns = Test-ContainsAll -Content (
    $inventorySystemContent + $inventoryTransferRequestContent + $itemContent + $itemEquipOrUnequipContent + $uiInventoryContent + $menuFeedbackPromptsContent
) -Patterns @(
    "ActorActionLocked",
    "EActionFlags.ManageInventory",
    "EActionFlags.ChangeEquipment",
    "EEquipmentOperationResult.ActionLocked",
    "CanActorManageInventory",
    "request.Actor.Can(EActionFlags.ManageInventory)",
    "sourceOwner.Can(EActionFlags.ManageInventory)",
    "equipmentTarget.Character.Can(EActionFlags.ChangeEquipment)",
    "MenuFeedbackPrompts.InventoryUseActionLocked",
    "MenuFeedbackPrompts.InventoryTransferActionLocked"
)

$inventoryCorpseOwnershipMissingPatterns = @(
    Test-ContainsAll -Content (
        $inventorySystemContent + $itemContent + $characterBaseContent + $characterActorRewardsContent + $characterActorContent
    ) -Patterns @(
        "Corpse,",
        "public InventoryOwnerHandle GetCorpseOwner(CharacterBase character)",
        "public bool TransferCharacterInventoryToCorpse(CharacterBase character)",
        "public bool TransferCharacterEquipmentToCorpse(CharacterBase character)",
        "public bool TransferCorpseInventoryToCharacter(CharacterBase character)",
        "equipmentComponent.ForceUnequipAllEquipmentForLifecycle()",
        "EItemTransferType.Corpse",
        "private void TransferOwnedInventoryToCorpseOwner()",
        "private void TransferOwnedEquipmentToCorpseOwner()",
        "private void TransferCorpseInventoryToOwnedInventory()"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "public override void Kill()" -Patterns @(
        "if (IsMarkedAsDestroyed())",
        "TransferOwnedInventoryToCorpseOwner();",
        "TransferOwnedEquipmentToCorpseOwner();"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "public override void Revive()" -Patterns @(
        "TransferCorpseInventoryToOwnedInventory();"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "private void TransferOwnedInventoryToCorpseOwner()" -Patterns @(
        "GameManager.InventorySystem.TransferCharacterInventoryToCorpse(this);"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "private void TransferOwnedEquipmentToCorpseOwner()" -Patterns @(
        "GameManager.InventorySystem.TransferCharacterEquipmentToCorpse(this);"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "private void TransferCorpseInventoryToOwnedInventory()" -Patterns @(
        "GameManager.InventorySystem.TransferCorpseInventoryToCharacter(this);"
    )
    Test-MethodContainsAny -Content $characterBaseContent -MethodName "private void TransferOwnedInventoryToCorpseOwner()" -Patterns @(
        "TryGetSystem",
        "GameManager.Exists()",
        "return;"
    )
    Test-MethodContainsAny -Content $characterBaseContent -MethodName "private void TransferOwnedEquipmentToCorpseOwner()" -Patterns @(
        "TryGetSystem",
        "GameManager.Exists()",
        "return;"
    )
    Test-MethodContainsAny -Content $characterBaseContent -MethodName "private void TransferCorpseInventoryToOwnedInventory()" -Patterns @(
        "TryGetSystem",
        "GameManager.Exists()",
        "return;"
    )
    Test-MethodContainsAll -Content $characterActorRewardsContent -MethodName "public override void Kill()" -Patterns @(
        "if (IsMarkedAsDestroyed())"
    )
)

$inventoryCorpseLootInteractionMissingPatterns = @(
    Test-ContainsAll -Content $characterBaseContent -Patterns @(
        "private bool TryRequestCorpseInventory(CharacterBase looter)",
        "InventoryOwnerHandle corpseOwner = inventorySystem.GetCorpseOwner(this);",
        "GameRuntimeEvents.RequestInventory(InventoryMenuContext.TransferToCharacter(",
        "private static GameCommandContext ResolveCorpseLootCommandContext(CharacterBase looter)"
    )
    Test-MethodContainsAll -Content $characterBaseContent -MethodName "public override void OnInteract(CharacterBase sender)" -Patterns @(
        "if (dead && TryRequestCorpseInventory(sender))",
        "return;"
    )
)

$inventoryMenuContextMissingPatterns = @(
    Test-ContainsAll -Content $inventoryMenuContextContent -Patterns @(
        "private static GameCommandContext ResolveCommandContextForActor(CharacterBase actor)",
        "return GameCommandContext.ResolveForActor(actor);"
    )
    Test-ContainsAll -Content $inventoryMenuContextContent -Patterns @(
        "return TransferToCharacter(",
        "ResolveCommandContextForActor(destination)"
    )
    Test-ContainsAll -Content $uiInventoryBagContent -Patterns @(
        "private InventoryOwnerHandle m_currentOwner = default;",
        "m_currentOwner = owner;",
        "UpdateSlots(m_currentOwner);"
    )
)

$inventoryMenuContextDisallowedPatterns = @(
    Test-ContainsAny -Content $inventoryMenuContextContent -Patterns @(
        "GameCommandContext.Unknown(destination)",
        "return GameCommandContext.Unknown(ResolveActor());"
    )
    Test-MethodContainsAny -Content $uiInventoryBagContent -MethodName "public void SetCategory(EItemCategory category)" -Patterns @(
        "UpdateSlots();",
        "GetCurrentControlledCharacterOrPlayerInstance()"
    )
)

$shopCraftMenuContextMissingPatterns = @(
    Test-ContainsAll -Content $gameRuntimeEventsUiContent -Patterns @(
        "public ShopRequestedEvent(Shop shop, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask)",
        "public GameCommandContext CommandContext { get; }",
        "public static void RequestShop(Shop shop, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask = null)",
        "Publish(new ShopRequestedEvent(shop, commandContext, menuClosedTask));",
        "public CraftRequestedEvent(CraftingStation craftingStation, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask)",
        "public static void RequestCraft(CraftingStation craftingStation, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask = null)",
        "Publish(new CraftRequestedEvent(craftingStation, commandContext, menuClosedTask));"
    )
    Test-ContainsAll -Content $shopInteractionContent -Patterns @(
        "GameRuntimeEvents.RequestShop(m_shop, GameCommandContext.ResolveForActor(source), onMenuClosed);"
    )
    Test-ContainsAll -Content $craftInteractionContent -Patterns @(
        "GameRuntimeEvents.RequestCraft(m_craftingStation, GameCommandContext.ResolveForActor(source), result);"
    )
    Test-ContainsAll -Content $openShopMenuCommandContent -Patterns @(
        "GameRuntimeEvents.RequestShop(m_shop, context, taskCompletionSource);"
    )
    Test-ContainsAll -Content $openCraftMenuCommandContent -Patterns @(
        "GameRuntimeEvents.RequestCraft(m_craftingStation, context, taskCompletionSource);"
    )
    Test-ContainsAll -Content $uiGameMenuEntryContent -Patterns @(
        "CharacterBase craftingActor = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();",
        "GameCommandContext.ResolveForActor(craftingActor));"
    )
    Test-ContainsAll -Content $uiManagerMenuRequestRoutingRuntimeContent -Patterns @(
        "OpenRegisteredPanel(m_shopRegistration, shopRequestedEvent.MenuClosedTask, shopRequestedEvent.Shop, shopRequestedEvent.CommandContext);",
        "OpenRegisteredPanel(m_craftRegistration, craftRequestedEvent.MenuClosedTask, craftRequestedEvent.CraftingStation, craftRequestedEvent.CommandContext);"
    )
    Test-ContainsAll -Content $uiShopContent -Patterns @(
        "private GameCommandContext m_commandContext = GameCommandContext.Unknown();",
        "private static bool TryResolveShop(UIKitMenuOpenData openData, out Shop shop, out GameCommandContext commandContext)",
        "openData.ArgumentCount == 2",
        "openData.TryGetArgument(1, out commandContext)",
        "return m_commandContext.ResolveActorOrCurrentControlledCharacter();"
    )
    Test-ContainsAll -Content $uiCraftContent -Patterns @(
        "private GameCommandContext m_commandContext = GameCommandContext.Unknown();",
        "private static bool TryResolveCraftingStation(UIKitMenuOpenData openData, out CraftingStation craftingStation, out GameCommandContext commandContext)",
        "openData.ArgumentCount == 2",
        "openData.TryGetArgument(1, out commandContext)",
        "return m_commandContext.ResolveActorOrCurrentControlledCharacter();"
    )
)

$shopCraftMenuContextDisallowedPatterns = @(
    Test-ContainsAny -Content $shopInteractionContent -Patterns @(
        "GameRuntimeEvents.RequestShop(m_shop, onMenuClosed);"
    )
    Test-ContainsAny -Content $craftInteractionContent -Patterns @(
        "GameRuntimeEvents.RequestCraft(m_craftingStation, result);"
    )
    Test-ContainsAny -Content $openShopMenuCommandContent -Patterns @(
        "GameRuntimeEvents.RequestShop(m_shop, taskCompletionSource);"
    )
    Test-ContainsAny -Content $openCraftMenuCommandContent -Patterns @(
        "GameRuntimeEvents.RequestCraft(m_craftingStation, taskCompletionSource);"
    )
    Test-ContainsAny -Content $uiGameMenuEntryContent -Patterns @(
        "GameRuntimeEvents.RequestCraft(GameManager.Config.onTheGoCraftingStation);"
    )
    Test-ContainsAny -Content $uiManagerMenuRequestRoutingRuntimeContent -Patterns @(
        "OpenRegisteredPanel(m_shopRegistration, shopRequestedEvent.MenuClosedTask, shopRequestedEvent.Shop);",
        "OpenRegisteredPanel(m_craftRegistration, craftRequestedEvent.MenuClosedTask, craftRequestedEvent.CraftingStation);"
    )
    Test-ContainsAny -Content ($uiShopContent + $uiCraftContent) -Patterns @(
        "private static CharacterBase ResolveInventoryOwner()"
    )
)

$characterEquippedItemLoadoutMissingPatterns = Test-ContainsAll -Content $characterEquippedItemLoadoutContent -Patterns @(
    "internal sealed class CharacterEquippedItemLoadout",
    "public CharacterEquipmentSlotData[] CreateSlotDataSnapshot(DatabaseRegistry databaseRegistry)",
    "public bool RestoreFromSlotData(",
    "System.Collections.Generic.IEnumerable<CharacterEquipmentSlotData> equipmentSlots",
    "if (equipment.type != slotData.slotType)"
)

$characterEquippedAbilityLoadoutMissingPatterns = Test-ContainsAll -Content $characterEquippedAbilityLoadoutContent -Patterns @(
    "internal sealed class CharacterEquippedAbilityLoadout",
    "public CharacterAbilitySlotData[] CreateSlotDataSnapshot(DatabaseRegistry databaseRegistry)",
    "public bool RestoreFromSlotData(",
    "IEnumerable<CharacterAbilitySlotData> quickAbilitySlots",
    "slotIndex = i",
    "Entry.FromFormalGasAbilityCode(formalGasAbilityCode)"
)

$saveReferenceRequiredMissingPatterns = @(
    Test-MethodContainsAll -Content $databaseRegistryCodeContent -MethodName "public DatabaseEntryReference<T> CreateReference<T>(T entry) where T : DatabaseEntry" -Patterns @(
        "if (TryCreateReference(entry, out DatabaseEntryReference<T> reference))",
        "return reference;",
        "throw new InvalidOperationException("
    )
    Test-MethodContainsAll -Content $databaseRegistryCodeContent -MethodName "public bool TryCreateReference<T>(T entry, out DatabaseEntryReference<T> reference) where T : DatabaseEntry" -Patterns @(
        "reference = null;",
        "string guid = DatabaseEntryToGUID(entry);",
        "if (string.IsNullOrWhiteSpace(guid))",
        "reference = new DatabaseEntryReference<T>(guid);"
    )
    Test-MethodContainsAll -Content $inventorySystemContent -MethodName "private InventoryOwnerDataBlock[] CreateOwnerDataBlocks()" -Patterns @(
        "if (!owner.IsValid)",
        "throw new InvalidOperationException(",
        "items = CreateItemDataBlock(owner, inventory)"
    )
    Test-MethodContainsAll -Content $inventorySystemContent -MethodName "private static SerializableDictionary<DatabaseEntryReference<Item>, int> CreateItemDataBlock(" -Patterns @(
        "if (!item || quantity <= 0)",
        "throw new InvalidOperationException(",
        "if (!GameManager.Database.TryCreateReference(item, out DatabaseEntryReference<Item> itemReference))",
        "Debug.LogError(",
        "continue;",
        "items.Add(itemReference, quantity);"
    )
    Test-MethodContainsAll -Content $journalSystemContent -MethodName "private static DatabaseEntryReference<Quest>[] CreateQuestReferences(" -Patterns @(
        "if (!database.TryCreateReference(quest, out DatabaseEntryReference<Quest> reference))",
        "Debug.LogError(",
        "continue;",
        "references.Add(reference);"
    )
    Test-MethodContainsAll -Content $journalSystemContent -MethodName "private static QuestProgressDataBlock[] CreateActiveQuestDataBlocks(IEnumerable<QuestProgress> progresses)" -Patterns @(
        "if (progress == null || !progress.IsValid())",
        "throw new InvalidOperationException(",
        "QuestProgressDataBlock block = progress.CreateDataBlock();",
        "if (block?.quest == null || string.IsNullOrWhiteSpace(block.quest.guid))"
    )
    Test-MethodContainsAll -Content $questProgressContent -MethodName "public QuestProgressDataBlock CreateDataBlock()" -Patterns @(
        "if (!GameManager.Database.TryCreateReference(m_quest, out DatabaseEntryReference<Quest> questReference))",
        "throw new InvalidOperationException(",
        "quest = questReference",
        "completedTasks = CreateTaskProgressDataBlocks(",
        "currentTasks = CreateTaskProgressDataBlocks(",
        "nextTasks = CreateQuestTaskReferences(m_nextTasks)"
    )
    Test-MethodContainsAll -Content $questProgressContent -MethodName "private static QuestTaskProgressDataBlock[] CreateTaskProgressDataBlocks(" -Patterns @(
        "if (progress == null)",
        "throw new InvalidOperationException(",
        "QuestTaskProgressDataBlock block = progress.CreateDataBlock();",
        "if (block?.task == null || string.IsNullOrWhiteSpace(block.task.guid))"
    )
    Test-MethodContainsAll -Content $questProgressContent -MethodName "private static DatabaseEntryReference<QuestTask>[] CreateQuestTaskReferences(IEnumerable<QuestTask> tasks)" -Patterns @(
        "if (!GameManager.Database.TryCreateReference(task, out DatabaseEntryReference<QuestTask> reference))",
        "Debug.LogError(",
        "continue;",
        "references.Add(reference);"
    )
    Test-MethodContainsAll -Content $questTaskProgressContent -MethodName "public virtual T CreateDataBlock()" -Patterns @(
        "if (!GameManager.Database.TryCreateReference(m_task, out DatabaseEntryReference<QuestTask> taskReference))",
        "throw new InvalidOperationException(",
        "task = taskReference"
    )
    Test-MethodContainsAll -Content $characterEquippedItemLoadoutContent -MethodName "public CharacterEquipmentSlotData[] CreateSlotDataSnapshot(DatabaseRegistry databaseRegistry)" -Patterns @(
        "if (databaseRegistry == null)",
        "throw new System.InvalidOperationException(",
        "equipment = databaseRegistry.CreateReference(equipment)"
    )
    Test-MethodContainsAll -Content $characterBaseAlterationsContent -MethodName "internal DatabaseEntryReference<CharacterAlterationRule>[] CreateActiveAlterationRuleSnapshots()" -Patterns @(
        "if (!rule || stackCount <= 0)",
        "throw new System.InvalidOperationException(",
        "snapshots.Add(GameManager.Database.CreateReference(rule));"
    )
) | ForEach-Object { $_ }

$saveReferenceRequiredDisallowedPatterns = @(
    Test-MethodContainsAny -Content $inventorySystemContent -MethodName "private InventoryOwnerDataBlock[] CreateOwnerDataBlocks()" -Patterns @(
        "TryCreateReference",
        "存档时已跳过",
        "continue;"
    )
    Test-MethodContainsAny -Content $inventorySystemContent -MethodName "private static SerializableDictionary<DatabaseEntryReference<Item>, int> CreateItemDataBlock(" -Patterns @(
        "GameManager.Database.CreateReference(item)"
    )
    Test-MethodContainsAny -Content $journalSystemContent -MethodName "private static DatabaseEntryReference<Quest>[] CreateQuestReferences(" -Patterns @(
        "database.CreateReference(quest)"
    )
    Test-MethodContainsAny -Content $journalSystemContent -MethodName "private static QuestProgressDataBlock[] CreateActiveQuestDataBlocks(IEnumerable<QuestProgress> progresses)" -Patterns @(
        "TryCreateReference",
        "存档时已跳过",
        "continue;"
    )
    Test-MethodContainsAny -Content $questProgressContent -MethodName "public QuestProgressDataBlock CreateDataBlock()" -Patterns @(
        "GameManager.Database.CreateReference(m_quest)"
    )
    Test-MethodContainsAny -Content $questProgressContent -MethodName "private static QuestTaskProgressDataBlock[] CreateTaskProgressDataBlocks(" -Patterns @(
        "TryCreateReference",
        "存档时已跳过",
        "continue;"
    )
    Test-MethodContainsAny -Content $questProgressContent -MethodName "private static DatabaseEntryReference<QuestTask>[] CreateQuestTaskReferences(IEnumerable<QuestTask> tasks)" -Patterns @(
        "GameManager.Database.CreateReference(task)"
    )
    Test-MethodContainsAny -Content $questTaskProgressContent -MethodName "public virtual T CreateDataBlock()" -Patterns @(
        "GameManager.Database.CreateReference(m_task)"
    )
    Test-MethodContainsAny -Content $characterEquippedItemLoadoutContent -MethodName "public CharacterEquipmentSlotData[] CreateSlotDataSnapshot(DatabaseRegistry databaseRegistry)" -Patterns @(
        "TryCreateReference",
        "存档时已跳过",
        "continue;"
    )
    Test-MethodContainsAny -Content $characterBaseAlterationsContent -MethodName "internal DatabaseEntryReference<CharacterAlterationRule>[] CreateActiveAlterationRuleSnapshots()" -Patterns @(
        "TryCreateReference",
        "存档时已跳过",
        "continue;"
    )
) | ForEach-Object { $_ }

$uiMenuRuntimeLegacyReferencePatterns = Test-ContainsAny -Content $uiPrefabContent -Patterns @(
    "guid: 09c4b7d41153b614e808226069cdb04f",
    "m_registeredMenus: []",
    "m_shopMenu: {fileID: 0}",
    "m_craftMenu: {fileID: 0}"
)

$uiManagerDisallowedPatterns = Test-ContainsAny -Content $uiManagerContent -Patterns @(
    "AddUIActionListener(EUIInputAction.Navigate, EInputActionPhase.Performed, OnNavigate)",
    "RemoveUIActionListener(EUIInputAction.Navigate, EInputActionPhase.Performed, OnNavigate)",
    "FindFirstObjectByType<Selectable>()"
)

$uiControllerButtonMissingPatterns = Test-ContainsAll -Content $uiControllerButtonContent -Patterns @(
    "private UIControllerButtonManager m_manager = null;",
    "m_manager = ResolveManager();",
    "m_manager.RegisterButton(this);",
    "m_manager?.UnregisterButton(this);",
    "Canvas canvasRoot = GetComponentInParent<Canvas>(true);",
    "return canvasRoot.GetComponentInChildren<UIControllerButtonManager>(true);"
)

$uiControllerButtonManagerDisallowedPatterns = Test-ContainsAny -Content $uiControllerButtonManagerContent -Patterns @(
    "private static UIControllerButtonManager _instance = null;",
    "public static void RegisterButton(UIControllerButton button)",
    "public static void UnregisterButton(UIControllerButton button)",
    "public static void ForceUpdateButton(UIControllerButton button)"
)

$uiMenuRuntimeMissingPatterns = [System.Collections.Generic.List[string]]::new()
foreach ($pattern in (Test-ContainsAll -Content $uiManagerMenuCompositeContent -Patterns @(
    "public sealed partial class UIManager : MonoBehaviour",
    "StartMenuRuntime();",
    "StopMenuRuntime();",
    "public sealed partial class UIManager",
    'private const string DefaultStackName = "fw_menu";',
    "RebuildRegistrations();",
    "EventKit.Type.Register<MenuRequestedEvent>(OnMenuRequested);",
    "EventKit.Type.Register<ShopRequestedEvent>(OnShopRequested);",
    "EventKit.Type.Register<CraftRequestedEvent>(OnCraftRequested);",
    "EventKit.Type.Register<CloseAllMenusRequestedEvent>(OnCloseAllMenusRequested);",
    "GameManager.InputSystem.AddUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Performed, OnCancel);",
    "GameManager.InputSystem.AddUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Canceled, OnCancelReleased);",
    "private readonly Dictionary<EMenu, UIKitMenuRegistration> m_menuRegistrations = new();",
    "private UIKitMenuRegistration m_shopRegistration;",
    "private UIKitMenuRegistration m_craftRegistration;",
    "[SerializeField] private MenuPanelBinding[] m_registeredMenuPanels = Array.Empty<MenuPanelBinding>();",
    "[SerializeField] private ContextPanelBinding m_shopPanel;",
    "[SerializeField] private ContextPanelBinding m_craftPanel;",
    "[SerializeField] private string m_stackName = DefaultStackName;",
    "private void RebuildRegistrations()",
    "private UIKitMenuRegistration ResolveContextRegistration(ContextPanelBinding contextPanelBinding, string slotName)",
    "private bool TryCreateRegistration(UIKitMenuPanelTypeReference typeReference, UILevel level, string slotName, out UIKitMenuRegistration registration)",
    "private static UIKitMenuRegistration CreateRegistration(Type panelType, UILevel level, string slotName)",
    "private sealed class UIKitMenuRegistration",
    "private void OnCancelReleased(InputAction.CallbackContext context)",
    "private void OnCancel(InputAction.CallbackContext context)",
    "private void OnMenuRequested(MenuRequestedEvent menuRequestedEvent)",
    "private void OnShopRequested(ShopRequestedEvent shopRequestedEvent)",
    "private void OnCraftRequested(CraftRequestedEvent craftRequestedEvent)",
    "private void OnCloseAllMenusRequested(CloseAllMenusRequestedEvent _)",
    "private readonly Dictionary<int, TaskCompletionSource<bool>> m_closeTasks = new();",
    "private void OpenRegisteredPanel(UIKitMenuRegistration registration, TaskCompletionSource<bool> menuClosedTask, params object[] arguments)",
    "private bool PopCurrentPanel()",
    "private void BindCloseTask(UIKitMenuPanelBase panel, TaskCompletionSource<bool> menuClosedTask)",
    "private void ResolveCloseTask(UIKitMenuPanelBase panel)",
    "private void ResolveAllCloseTasks()",
    "private string GetStackName()",
    "private void AbortPendingRuntimeSession(int previousDepth, TaskCompletionSource<bool> menuClosedTask, IPanel openedPanel = null)",
    "UIKit.OpenPanelAsync(",
    "UIKit.PushPanel(",
    "UIKit.PopPanel("
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}
foreach ($pattern in (Test-ContainsAll -Content $uiKitDeathPanelContent -Patterns @(
    "public sealed class UIKitDeathPanel : UIKitMenuPanelBase",
    "[SerializeField] private Button m_quitButton = null;",
    "protected override bool CanCloseFromMenuStack()",
    "protected override GameObject ResolveDefaultFocusTarget()",
    "public void GoToMainMenu()"
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}
foreach ($pattern in (Test-ContainsAll -Content $uiKitMenuPanelTypeReferenceContent -Patterns @(
    "public sealed class UIKitMenuPanelTypeReference : ISerializationCallbackReceiver",
    "public bool TryResolvePanelType(out Type panelType, out string error)",
    "typeof(UIKitMenuPanelBase).IsAssignableFrom(panelType)",
    "nameof(UIKitMenuPanelBase)"
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}
$uiMenuRuntimeDisallowedPatterns = Test-ContainsAny -Content "$uiManagerMenuCompositeContent`n$uiPrefabContent" -Patterns @(
    "UIMenuRegistry<",
    "UIKitMenuHost",
    "guid: 5ca4bd1db1b53b341aa2d1099ba05135",
    "MenuHostRuntimeOwnershipGuard",
    "m_runtimeMenuOverrides",
    "m_runtimeShopOverride",
    "m_runtimeCraftOverride",
    "m_claimAllRegisteredMenusAsDefault",
    "m_claimedMenus",
    "m_claimShopMenu",
    "m_claimCraftMenu",
    "RefreshRuntimeClaims",
    "EnumerateClaimedMenus",
    "TryRegisterHost(",
    "TryRefreshHostClaims(",
    "ShouldHandleMenuRequest(",
    "ShouldHandleShopRequest(",
    "ShouldHandleCraftRequest(",
    "TryBeginRuntimeSession(",
    "NotifySessionClosed(",
    "IsActiveRuntimeHost("
)
foreach ($pattern in (Test-ContainsAll -Content $uiKitMenuPanelTypeReferenceDrawerContent -Patterns @(
    "[CustomPropertyDrawer(typeof(UIKitMenuPanelTypeReference))]",
    "TypeCache.GetTypesDerivedFrom<UIKitMenuPanelBase>()",
    "assemblyQualifiedNameProperty.stringValue = options[newIndex].AssemblyQualifiedName;"
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}
foreach ($pattern in (Test-ContainsAll -Content $uiPrefabContent -Patterns @(
    "guid: f08ff2ef9d5d6324a94d510b64333241",
    "m_registeredMenuPanels:",
    "FantasyWord.GameCore.UIGameMenu, FantasyWord.GameCore",
    "FantasyWord.GameCore.UICharacter, FantasyWord.GameCore",
    "FantasyWord.GameCore.UIAbilities, FantasyWord.GameCore",
    "FantasyWord.GameCore.UIInventory, FantasyWord.GameCore",
    "FantasyWord.GameCore.UIJournal, FantasyWord.GameCore",
    "FantasyWord.GameCore.UIShop, FantasyWord.GameCore",
    "FantasyWord.GameCore.UICraft, FantasyWord.GameCore",
    "FantasyWord.GameCore.UISave, FantasyWord.GameCore",
    "FantasyWord.GameCore.UISettings, FantasyWord.GameCore",
    "FantasyWord.GameCore.UIKitDeathPanel, FantasyWord.GameCore",
    "m_shopPanel:",
    "m_craftPanel:",
    "m_stackName: fw_menu"
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}
if (-not [regex]::IsMatch($uiPrefabContent, '(?s)m_Name: Menus.*?RectTransform:.*?m_Children: \[\]\s+  m_Father:')) {
    [void]$uiMenuRuntimeMissingPatterns.Add("Menus node must keep m_Children: [] so formal UI menu runtime does not pre-place menu instances.")
}
foreach ($pattern in (Test-ContainsAll -Content $uiKitDeathPrefabContent -Patterns @(
    "m_EditorClassIdentifier: FantasyWord.GameCore::FantasyWord.GameCore.UIKitDeathPanel",
    "m_quitButton:",
    "value: GoToMainMenu",
    "value: FantasyWord.GameCore.UIKitDeathPanel, FantasyWord.GameCore"
))) {
    [void]$uiMenuRuntimeMissingPatterns.Add($pattern)
}

$formalSceneInputHostAutomationMissingPatterns = Test-ContainsAll -Content $formalSceneInputHostAutomationContent -Patterns @(
    "public static class FormalSceneInputRootAutomation",
    "public static FormalSceneInputRootInspectionResult InspectOpenFormalScene()",
    "public static FormalSceneInputRootInspectionResult EnsureOpenFormalSceneInputRoot()",
    "public static FormalSceneInputRootInspectionResult EnsureOpenFormalSceneInputRootAllowDirtyFormalScene()",
    'private const string InputActionsAssetPath = "Assets/InputSystem_Actions.inputactions";',
    "private const string DefaultRepairMethodName = nameof(EnsureOpenFormalSceneInputRoot);",
    "private const string DirtyFormalSceneRepairMethodName = nameof(EnsureOpenFormalSceneInputRootAllowDirtyFormalScene);",
    "return InspectScene(SceneManager.GetActiveScene());",
    "if (inspection.SceneIsDirty && !allowDirtyFormalScene)",
    "RepairBlockedByDirtyScene",
    "RecommendedRepairMethod",
    "UpdateRecommendedRepairMethod(result);",
    "EditorSceneManager.MarkSceneDirty(scene);"
)

$formalSceneInputHostAutomationDisallowedPatterns = Test-ContainsAny -Content $formalSceneInputHostAutomationContent -Patterns @(
    "[MenuItem(",
    "EditorSceneManager.SaveScene(",
    "EditorSceneManager.SaveOpenScenes(",
    "AssetDatabase.SaveAssets(",
    'ExecuteMenuItem("File/Save',
    "ExecuteMenuItem('File/Save"
)

$formalSceneInputHostRepairScriptMissingPatterns = Test-ContainsAll -Content $formalSceneInputHostRepairScriptContent -Patterns @(
    '[int]$HeartbeatMaxAgeSeconds = 120',
    "BridgeHealthChecked",
    "BridgeReady",
    "BridgeHeartbeat",
    "BridgeCommandQueue",
    "BridgeHealthError",
    "StaticInspection",
    "SuggestedNextAction",
    "function Get-BridgeCommandQueueInfo {",
    "function Get-FormalSceneInputRootStaticInspection {",
    "function Get-SuggestedNextAction {",
    '$commandDirectoryPath = Join-Path $projectRoot "Temp\UnityBridge\commands"',
    '$commandQueueInfo = Get-BridgeCommandQueueInfo -CommandDirectoryPath $commandDirectoryPath',
    '$workflowReport.BridgeCommandQueue = $commandQueueInfo',
    'MissingExplicitRootScenes = @($sceneReports | Where-Object { -not $_.HasExplicitInputRoot } | ForEach-Object { $_.ScenePath })',
    'Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-lock-acquire"',
    'Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-save"',
    '$workflowReport.StaticInspection = Get-FormalSceneInputRootStaticInspection -ProjectRoot $projectRoot',
    '$workflowReport.SuggestedNextAction = Get-SuggestedNextAction -WorkflowReport $workflowReport'
)

$formalSceneInputHostRepairScriptDisallowedPatterns = Test-ContainsAny -Content $formalSceneInputHostRepairScriptContent -Patterns @(
    "Stop-Process ",
    "taskkill ",
    "Start-Process ",
    "Remove-Item ",
    'Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-open"',
    'Invoke-BridgeJson -BridgePath $bridgePath -ToolName "scene-unload"'
)

$uiStatBarMissingPatterns = Test-ContainsAll -Content $uiStatBarContent -Patterns @("private bool m_hasDisplayedBoundValue = false;", "m_hasDisplayedBoundValue = true;")

$uiStatBarDisallowedPatterns = Test-ContainsAny -Content $uiStatBarContent -Patterns @("StartCoroutine(CoroutineHelpers.ExecuteInXFrames(1, EnableShakeAfterInitialLayout));", "private void EnableShakeAfterInitialLayout()")

$uiDialogueMessageBoxMissingPatterns = Test-ContainsAll -Content $uiDialogueMessageBoxContent -Patterns @(
    "private Coroutine m_textAnimationCoroutine = null;",
    "AbortTextAnimation();",
    "CompleteTextAnimation();",
    "StopTextAnimationCoroutine();"
)

$uiDialogueMessageBoxDisallowedPatterns = Test-ContainsAny -Content $uiDialogueMessageBoxContent -Patterns @(
    "StopCoroutine(UpdateText())",
    "ExecuteInXFrames(1, OnTextAnimationFinished)"
)

$uiListPoolingMissingPatterns = @(
    (Test-ContainsAll -Content $uiEffectListContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
    (Test-ContainsAll -Content $uiAbilitiesContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
    (Test-ContainsAll -Content $uiCraftContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
    (Test-ContainsAll -Content $uiEventLogContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
    (Test-ContainsAll -Content $uiJournalContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
    (Test-ContainsAll -Content $uiShopContent -Patterns @(
        "GameObjectPoolService.Rent(",
        "GameObjectPoolService.Return("
    ))
) | ForEach-Object { $_ }

$uiListPoolingDisallowedPatterns = @(
    (Test-ContainsAny -Content $uiEffectListContent -Patterns @(
        "Destroy(child.gameObject);",
        "Instantiate(m_buffEffectEntryPrefab",
        "Instantiate(m_debuffEffectEntryPrefab"
    ))
    (Test-ContainsAny -Content $uiAbilitiesContent -Patterns @(
        "Instantiate(m_abilityBarEntryPrefab",
        "Destroy(child.gameObject);"
    ))
    (Test-ContainsAny -Content $uiCraftContent -Patterns @(
        "Instantiate(m_recipeEntryPrefab",
        "Destroy(child.gameObject);"
    ))
    (Test-ContainsAny -Content $uiEventLogContent -Patterns @(
        "Instantiate(m_linePrefab"
    ))
    (Test-ContainsAny -Content $uiJournalContent -Patterns @(
        "Instantiate(m_questEntryPrefab"
    ))
    (Test-ContainsAny -Content $uiShopContent -Patterns @(
        "Instantiate(m_shopEntryPrefab",
        "Destroy(child.gameObject);"
    ))
) | ForEach-Object { $_ }

$gameManagerSystemShortcuts = @(Get-GameManagerSystemShortcutNames -Content $gameManagerContent)
$nonBaselineNewGameManagerSystemShortcuts = @($gameManagerSystemShortcuts | Where-Object { $baselineGameManagerSystemShortcuts -notcontains $_ })

$notificationLegacyReferenceHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts"),
    (Join-Path $projectRoot "Assets/Editor"),
    (Join-Path $projectRoot "Assets/Tests")
) -Patterns @(
    "NotificationSystem",
    "Notification System",
    "ddc279a934b8b6e42abd5cb68989d59d"
)

$legacySceneReferenceHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scenes")
) -Patterns @(
    "Notification System",
    "ddc279a934b8b6e42abd5cb68989d59d"
) -Extensions @(".unity", ".prefab", ".asset")

$legacyBusinessAssetHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Database"),
    (Join-Path $projectRoot "Assets/GameData"),
    (Join-Path $projectRoot "Assets/Prefabs"),
    (Join-Path $projectRoot "Assets/Resources")
) -Patterns @(
    "SF_Archer",
    "SF_Knight",
    "SF_Wizard",
    "CFG_Game",
    "AUDIO_BGM_Title",
    "玩家存档模板",
    "CRSTA_Default",
    "ITEM_Iron_Boots",
    "ITEM_Iron_Helmet",
    "ITEM_Iron_Plate",
    "DIAL_Craft_",
    "DIAL_Shop_"
) -Extensions @(".asset", ".prefab", ".unity", ".meta")

$sourceDisallowedPatterns = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime"),
    (Join-Path $projectRoot "Assets/Editor/GameCore"),
    (Join-Path $projectRoot "Assets/Tests/EditMode/GameCore")
) -Patterns @(
    "FantasyWordBootstrapper",
    "FantasyWordModuleInstaller",
    "RuntimeContext",
    "ServiceRegistry",
    "FantasyWordEventBus",
    "CoroutineHelpers",
    "PlayModeFreezeProbe",
    "[DEBUG-PLAYFREEZE]",
    "hasActiveRuntimeState",
    "GameManager.DialogueSystem.Main",
    "ObservableStats"
)

$gameCoreGasRuntimeReferenceHits = Find-GameCoreGasRuntimeReferenceHits -ProjectRoot $projectRoot -AllowedFiles @(
    $characterBasePath,
    $characterAbilitySetPath,
    $characterAbilitySetFormalRulesPath,
    $formalGameplayAttributeSetPath,
    $formalGameplayEffectDamageHelperPath,
    $characterBaseGasRuntimePath,
    $characterBaseResourcesPath,
    $characterBaseStateApiPath,
    $temporalEffectInterfacePath,
    $temporalEffectBasePath,
    $formalTemporalPeriodicCurrentResourceBuilderPath,
    $formalTemporalPeriodicSpecBuilderPath,
    $formalTemporalPeriodicDamageBuilderPath,
    $temporalHealEffectPath,
    $temporalDamageEffectPath,
    $temporalRestoreManaEffectPath,
    $temporalControlEffectPath,
    $temporalStatModifierEffectPath,
    $temporalSpeedModifierEffectPath
)

$gameCoreTopDownManagerReferenceHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts"),
    (Join-Path $projectRoot "Assets/Editor")
) -Patterns @(
    "MoreMountains.TopDownEngine.LevelManager",
    "MoreMountains.TopDownEngine.InputManager",
    "MoreMountains.TopDownEngine.GUIManager",
    "MoreMountains.TopDownEngine.GameManager"
)

$gameCorePrematureModeRuntimeHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime")
) -Patterns @(
    "class WorldSystem",
    "class WorldContext",
    "class WorldRuntime",
    "class OpenWorldSystem",
    "class OpenWorldRuntime",
    "class RegionSystem",
    "class RegionRuntime",
    "class CellSystem",
    "class CellRuntime",
    "class FactionSystem",
    "class FactionRuntime",
    "class EconomySystem",
    "class EconomyRuntime",
    "class ScheduleSystem",
    "class ScheduleRuntime",
    "class PartySystem",
    "class PartyRuntime",
    "class SquadSystem",
    "class SquadRuntime",
    "class BaseProductionSystem",
    "class BaseProductionRuntime",
    "class ModeRuntime",
    "class CardMode",
    "class CardSystem",
    "class CardModeSystem",
    "class CardRuntime",
    "class DeckSystem",
    "class DeckRuntime",
    "class BoardSystem",
    "class BoardRuntime",
    "class AutoBattlerSystem",
    "class AutoBattlerRuntime",
    "class AutoChessSystem"
)

$formalAssetApiRegressionHits = @(
    Test-FilesContainAny -Roots @(
        (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime"),
        (Join-Path $projectRoot "Assets/Editor/GameCore")
    ) -Patterns @(
    "public QuestTask[] tasks =>",
    "public IEffect[] explosionAdditionalEffects =>",
    "public EWeaponExecutionState[] blockingOtherWeaponStates =>",
    "public SerializableDictionary<string, string> persistentIdentifierMappings = new();",
    "public ChestLootEntry[] entries;",
    "m_loot.entries",
    "public NPCSheet target = null;",
    "public DialogueSequence dialogue = null;",
    "public Sprite sprite = null;",
    "public Color color = Color.white;",
    "public Vector2 positionOffset = Vector2.zero;",
    "public Vector2 sizeOffset = Vector2.zero;",
    "public Stats baseStats;",
    "public int pointsPerLevel = 5;",
    "public LevelScaledInteger experience = new();",
    "public LevelScaledInteger experience =>",
    "public LevelScaledStats stats =>",
    "public LevelScaledInteger money =>",
    "public int price;",
    "public int healAmount;",
    "public int manaRecoveredAmount;",
    "public AudioClipResolver healingSound;",
    "public Item item = null;",
    "public int amountToCollect = 1;",
    "public CharacterSheet character = null;",
    "public int monstersToKill = 1;",
    "public ICommand executeOnDeath => m_executeOnDeath;",
    "public ICommand toExecuteOnQuestCompletion => m_toExecuteOnQuestCompletion;",
    "public ICommand toExecuteOnStart => m_toExecuteOnStart;",
    "public ICommand toExecuteOnCompletion => m_toExecuteOnCompletion;",
    "public ICommand toExecuteOnStart;",
    "public ICommand toExecuteOnCompletion;",
    "public DatabaseRegistry databaseRegistry = null;",
    "public DatabaseRegistry databaseRegistry => m_databaseRegistry;",
    "public string mainMenuSceneName = ""Main Menu"";",
    "public string interactionLayer = ""Interaction"";",
    "public string hitboxLayer = ""Hitbox"";",
    "public float maxTeleportDistanceWhenStuckInWall = 5.0f;",
    "public ContactFilter2D collisionContactFilter;",
    "public ContactFilter2D visibilityContactFilter;",
    "public SaveFile playtestSaveFile = null;",
    "public SaveFile playtestSaveFile => m_playtestSaveFile;",
    "public ECameraShakeSources cameraShakeSources = ECameraShakeSources.None;",
    "public CraftingStation onTheGoCraftingStation = null;",
    "public ICommand toExecuteOnPlayerDeath = null;",
    "public ICommand toExecuteOnPlayerDeath => m_toExecuteOnPlayerDeath;",
    "public AudioClipResolver lastPlayedAudioClipResolver => m_lastPlayedClip;",
    "GameObject interactionTarget { get; }",
    "public GameObject interactionTarget => m_interactionTarget;",
    "public SaveDataBlock content => m_content;",
    "public APersistenceInfo persistenceInfo",
    "public DialogueChannel Main => m_mainChannel;",
    "public MapInfo activeMapInfo => m_activeMapInfo;",
    "public SoundID lastPlayedSoundId => m_lastPlayedSoundId;",
    "public EAudioPlaybackBackend lastPlaybackBackend => m_lastPlaybackBackend;",
    "public bool isPaused => m_isPaused;",
    "public int maxEquippableAbilities = 5;",
    "public bool canCriticalHit = true;",
    "public bool canMissHit = true;",
    "public bool allowPushOnRegularHit = true;",
    "public bool allowPushOnCriticalHit = true;",
    "public bool allowPushOnMissedHit = true;",
    "public bool allowPushOnSilentHit = false;",
    "public AudioClipResolver navigationSelectSound = null;",
    "public AudioClipResolver pointerSelectSound = null;",
    "public AudioClipResolver submitSound = null;"
    )
    (
        Test-ContainsAny -Content (Get-FileContent $dialogueSequencePath) -Patterns @(
            "public string name;",
            "public DialogueSequence sequence;",
            "public DialogueMessage message;"
        )
    ) | ForEach-Object { "{0}: {1}" -f $dialogueSequencePath, $_ }
    (
        Test-ContainsAny -Content (Get-FileContent $prefabReferencePath) -Patterns @(
            "public GameObject prefab;"
        )
    ) | ForEach-Object { "{0}: {1}" -f $prefabReferencePath, $_ }
    (
        Test-ContainsAny -Content (Get-FileContent $characterSpawnerPath) -Patterns @(
            "public GameObject prefab;",
            "public int rate;",
            "public CharacterActor character;",
            "public int index;"
        )
    ) | ForEach-Object { "{0}: {1}" -f $characterSpawnerPath, $_ }
)

$formalMutableStatsLeakHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime")
) -Patterns @(
    "public Stats values => m_values;",
    "public ObservableStats stats => m_stats;",
    "public ObservableStats currentStats => m_currentStats;",
    "public Stats stats => m_stats.Snapshot();",
    "public Stats currentStats => m_currentStats.Snapshot();",
    "m_values = values;",
    "m_values = stats;",
    "public Stats customStats => m_customStats;",
    "public Stats bonusStats => m_bonusStats;",
    "public Stats stats => m_stats;",
    "public Stats GetStatsAtLevel(int level) => (m_stats ??= new LevelScaledStats())[level];",
    "public DialogueNode root => m_root;",
    "public DialogueMessageFeed messages => m_messages;"
)

$resourceStatSemanticBypassHits = Find-ResourceStatSemanticBypassHits -ProjectRoot $projectRoot -AllowedFiles @(
    $characterBasePath
)

$directEventSystemAccessHits = Find-DirectEventSystemAccessHits -ProjectRoot $projectRoot -AllowedFiles @(
    $gameManagerPath
)

$directMainCameraAccessHits = Find-DirectMainCameraAccessHits -ProjectRoot $projectRoot -AllowedFiles @(
    $gameManagerPath
)

$controlGroupBypassHits = Find-ControlGroupBypassHits -ProjectRoot $projectRoot -AllowedFiles @(
    $playerSystemPath,
    $playerControlGroupPath,
    (Join-Path $projectRoot "Assets/Editor/GameCore/Bridge/CompositeRuntimeSmokeValidator.cs")
)

$formalEnumerableLeakHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime"),
    (Join-Path $projectRoot "Assets/Editor/GameCore")
) -Patterns @(
    "public IEnumerable<IEffect> effects => m_effects;",
    "public IEnumerable<IEffect> autoAppliedEffectsToCasterOnFire => m_autoAppliedEffectsToCasterOnFire;",
    "public IEnumerable<AbilitySheet> GetBonusAbilities() => m_bonusAbilities ?? Array.Empty<AbilitySheet>();",
    "public IEnumerable<AbilitySheet> GetBonusAbilities() => m_bonusAbilities ?? System.Array.Empty<AbilitySheet>();",
    "public IEnumerable<ChestLootEntry> GetEntries() => m_entries ?? Array.Empty<ChestLootEntry>();",
    "public IEnumerable<ChestLootEntry> GetEntries() => m_entries ?? System.Array.Empty<ChestLootEntry>();",
    "public IEnumerable<DialogueSequenceOption> GetOptions() => m_options ?? System.Array.Empty<DialogueSequenceOption>();",
    "public IEnumerable<EWeaponExecutionState> GetBlockingOtherWeaponStates() => m_blockingOtherWeaponStates ?? Array.Empty<EWeaponExecutionState>();",
    "public IEnumerable<Loot> GetPotentialLoot() => m_potentialLoot ?? System.Array.Empty<Loot>();",
    "public IEnumerable<Recipe> GetRecipes() => m_recipes ?? System.Array.Empty<Recipe>();",
    "public IEnumerable<QuestTask> GetTasks() => m_tasks ?? Array.Empty<QuestTask>();",
    "public IEnumerable<Item> GetItems() => m_items ?? System.Array.Empty<Item>();",
    "public IEnumerable<IEffect> GetExplosionAdditionalEffects() => m_explosionAdditionalEffects ?? Array.Empty<IEffect>();",
    "public IEnumerable<IEffect> effects => m_effects != null ? (IEffect[])m_effects.Clone() : System.Array.Empty<IEffect>();",
    "public IEnumerable<IEffect> autoAppliedEffectsToCasterOnFire => m_autoAppliedEffectsToCasterOnFire != null ? (IEffect[])m_autoAppliedEffectsToCasterOnFire.Clone() : System.Array.Empty<IEffect>();",
    "public IEnumerable<IEffect> GetExplosionAdditionalEffects() => m_explosionAdditionalEffects != null ? (IEffect[])m_explosionAdditionalEffects.Clone() : Array.Empty<IEffect>();",
    "public IEnumerable<AbilitySheet> GetBonusAbilities() => m_bonusAbilities != null ? (AbilitySheet[])m_bonusAbilities.Clone() : Array.Empty<AbilitySheet>();",
    "public IEnumerable<ChestLootEntry> GetEntries() => m_entries != null ? (ChestLootEntry[])m_entries.Clone() : Array.Empty<ChestLootEntry>();",
    "public IEnumerable<DialogueSequenceOption> GetOptions() => m_options != null ? (DialogueSequenceOption[])m_options.Clone() : System.Array.Empty<DialogueSequenceOption>();",
    "public IEnumerable<EWeaponExecutionState> GetBlockingOtherWeaponStates() => m_blockingOtherWeaponStates != null ? (EWeaponExecutionState[])m_blockingOtherWeaponStates.Clone() : Array.Empty<EWeaponExecutionState>();",
    "public IEnumerable<Item> GetItems() => m_items != null ? (Item[])m_items.Clone() : System.Array.Empty<Item>();",
    "public IEnumerable<Loot> GetPotentialLoot() => m_potentialLoot != null ? (Loot[])m_potentialLoot.Clone() : System.Array.Empty<Loot>();",
    "public IEnumerable<Recipe> GetRecipes() => m_recipes != null ? (Recipe[])m_recipes.Clone() : System.Array.Empty<Recipe>();",
    "public IEnumerable<QuestTask> GetTasks() => m_tasks != null ? (QuestTask[])m_tasks.Clone() : Array.Empty<QuestTask>();",
    "public IEnumerable<TargetType> FilterInvalidTargets(IEnumerable<TargetType> potentialTargets)",
    "return potentialTargets.Where(target => !IsTargetOnCooldown(target));",
    "public IEnumerable<AbilitySheet> GetAvailableAbilitiesAtLevel(int level)",
    "public IEnumerable<AbilitySheet> GetAbilitiesUnlockedAtLevel(int level)",
    "public IEnumerable<KeyValuePair<Item, int>> GetIngredients() => m_ingredients;",
    "public IEnumerable<KeyValuePair<Item, int>> GetAdditionalOutput() => m_additionalOutput;",
    "public IEnumerable<KeyValuePair<string, bool>> GetRequiredFlags() => m_gameFlags;",
    "public IEnumerable<KeyValuePair<Item, int>> GetBagEntries() => m_items;",
    "public IEnumerable<KeyValuePair<Item, int>> GetIngredients() => m_ingredients != null ? m_ingredients.ToArray() : System.Array.Empty<KeyValuePair<Item, int>>();",
    "public IEnumerable<KeyValuePair<Item, int>> GetAdditionalOutput() => m_additionalOutput != null ? m_additionalOutput.ToArray() : System.Array.Empty<KeyValuePair<Item, int>>();",
    "public IEnumerable<KeyValuePair<string, bool>> GetRequiredFlags() => m_gameFlags != null ? m_gameFlags.ToArray() : Array.Empty<KeyValuePair<string, bool>>();",
    "public IEnumerable<KeyValuePair<Item, int>> GetBagEntries()",
    "public IEnumerable<KeyValuePair<string, DatabaseEntry>> GetEntries()",
    "public IEnumerable<string> Keys => m_cacheMap.Keys;",
    "public IEnumerable<TAsset> Values => m_cacheMap.Values;",
    "public IEnumerable<string> GetCacheKeys()",
    "return m_cacheMap.Keys;",
    "return m_cacheMap.GetEnumerator();",
    "public IEnumerable<AbilityBase> abilityInstances => m_abilitiesInstances.Values;",
    "public IEnumerable<ITriggerableAbility> triggerableAbilities => m_triggerableAbilities;",
    "public IEnumerable<ITemporalEffect> temporalEffects => m_temporalEffectExecutionShells;",
    "public IEnumerable<Equipment> GetEquippedItems() => m_equipments.Values;",
    "public IEnumerable<Quest> GetUnlockedQuests() => m_unlockedQuests;",
    "public IEnumerable<Quest> GetAvailableQuests() => m_availableQuests;",
    "public IEnumerable<QuestProgress> GetActiveQuests() => m_activeQuests;",
    "public IEnumerable<Quest> GetFullfilledQuests() => m_fullfilledQuests;",
    "public IEnumerable<Quest> GetCompletedQuests() => m_completedQuests;",
    "public IEnumerable<IQuestTaskProgress> GetCompletedTasks() => m_completedTasks;",
    "public IEnumerable<IQuestTaskProgress> GetCurrentTasks() => m_currentTasks;",
    "public IEnumerable<Equipment> GetEquippedItems() => m_equipmentLoadout.SnapshotItems();",
    "public IEnumerable<Quest> GetUnlockedQuests() => m_unlockedQuests.ToArray();",
    "public IEnumerable<Quest> GetAvailableQuests() => m_availableQuests.ToArray();",
    "public IEnumerable<QuestProgress> GetActiveQuests() => m_activeQuests.ToArray();",
    "public IEnumerable<Quest> GetFullfilledQuests() => m_fullfilledQuests.ToArray();",
    "public IEnumerable<Quest> GetCompletedQuests() => m_completedQuests.ToArray();",
    "public IEnumerable<IQuestTaskProgress> GetCompletedTasks() => m_completedTasks.ToArray();",
    "public IEnumerable<IQuestTaskProgress> GetCurrentTasks() => m_currentTasks.ToArray();",
    "public IEnumerable<EEffectInteractionResult> feed;",
    "public IEnumerable<CharacterBase> affectedTargets;",
    "public EffectApplicationResult(IEnumerable<EEffectInteractionResult> feed, IEnumerable<CharacterBase> affectedTargets)",
    "public static EffectApplicationResult Apply(CharacterBase source, IEnumerable<CharacterBase> targets, IEnumerable<IEffect> effects",
    "if (!targets.Any())",
    "ApplyEffectsToTarget(target, effects, impactSettings, feed, affectedTargets)",
    "Debug.Assert(effects.Where(effect => effect.initialized).Count() == 0",
    "private bool TryApplyingExplosionBaseEffects(Vector2 explosionOrigin, CharacterBase primaryTarget, IEnumerable<CharacterBase> characters)",
    "private bool TryApplyingExplosionAdditionalEffects(Vector2 explosionOrigin, CharacterBase primaryTarget, IEnumerable<CharacterBase> characters)",
    "private void ApplyExplosion(Vector2 explosionOrigin, IEnumerable<CharacterBase> targets, IEnumerable<IEffect> effects)",
    "var characters = Physics2D.OverlapCircleAll(explosionOrigin, m_explosionRadius)",
    "if (m_explosionAdditionalEffects.Any())",
    "public IReadOnlyList<CharacterBase> FilterTargets(IEnumerable<CharacterBase> candidates, CharacterBase owner)",
    "public System.Collections.Generic.IReadOnlyList<CharacterBase> FilterTargets(",
    "IReadOnlyList<CharacterBase> targets = m_hitWindowRuntime.FilterTargets(",
    "protected virtual IEnumerable<CharacterBase> FilterInvalidTargets(IEnumerable<CharacterBase> targets) => targets;",
    "protected override IEnumerable<CharacterBase> FilterInvalidTargets(IEnumerable<CharacterBase> targets)",
    "FilterInvalidTargets(targetSnapshot)",
    "public IEnumerable<float> EnumerateMoveSpeedFactors()",
    "public System.Collections.Generic.IReadOnlyList<InputAction> GetConflictingActions(",
    "return InputKit.GetConflictingActions(action, bindingIndex);",
    "public override string[] AttributeNames => s_attributeNames;",
    "public object[] Arguments { get; }",
    "public string[] Categories => m_categories;",
    "public static List<ModInfo> GetAllInfos()",
    "public static System.Collections.Generic.List<ModInfo> GetAllInfos()",
    "public static event Action Refreshed;",
    "public static event System.Action Refreshed;",
    "FormalDataAssetCache.GetAssetsAssignableTo(",
    "return m_entries;"
)

$dialogueNodeMissingPatterns = Test-ContainsAll -Content $dialogueNodeContent -Patterns @(
    "private string m_text;",
    "private string m_speaker;",
    "private DialogueNodeOption[] m_options = Array.Empty<DialogueNodeOption>();",
    "public DialogueNodeOption[] GetOptions()",
    "public bool TryGetOption(int index, out DialogueNodeOption option)",
    "internal void SetContent(string text, string speaker)",
    "internal void SetOptions(DialogueNodeOption[] options)"
)

$dialogueNodeDisallowedPatterns = Test-ContainsAny -Content $dialogueNodeContent -Patterns @(
    "public string text;",
    "public string speaker;",
    "public DialogueNodeOption[] options;"
)

$dialogueLifecycleCommandContextMissingPatterns = @(
    Test-ContainsAll -Content $dialogueTreeContent -Patterns @(
        ": this(root, GameCommandContext.Script())",
        "public DialogueTree(DialogueNode root, GameCommandContext commandContext)",
        "internal GameCommandContext CommandContext { get; }"
    )
    Test-ContainsAll -Content $dialogueChannelContent -Patterns @(
        "m_currentNode.ExecuteCompletionCommand(m_currentTree.dialogue.CommandContext);",
        "m_currentNode.ExecuteStartCommand(m_currentTree.dialogue.CommandContext);"
    )
    Test-ContainsAll -Content $dialogueNodeContent -Patterns @(
        "internal void ExecuteStartCommand(GameCommandContext context)",
        "m_toExecuteOnStart.ExecuteFireAndReport(context, nameof(DialogueNode));",
        "internal void ExecuteCompletionCommand(GameCommandContext context)",
        "m_toExecuteOnCompletion.ExecuteFireAndReport(context, nameof(DialogueNode));"
    )
    Test-ContainsAll -Content $dialogueSequenceContent -Patterns @(
        "public DialogueTree ToDialogueTree(string speaker, GameCommandContext commandContext, params string[] args)"
    )
    Test-ContainsAll -Content $dialogueUtilsContent -Patterns @(
        "CreateDialogueTree(DialogueSequence sequence, string speaker, GameCommandContext commandContext, params string[] args)",
        "return new(CreateDialogueNodeRecursive(sequence, speaker, args), commandContext);"
    )
    Test-ContainsAll -Content $interactionTargetContent -Patterns @(
        "Task Say(DialogueSequence sequence, CharacterBase source, UnityAction<DialogueMessageFeed> onDialogueEnded = null, params string[] args);"
    )
    Test-ContainsAll -Content $entityContent -Patterns @(
        "public virtual async Task Say(DialogueSequence sequence, CharacterBase source, UnityAction<DialogueMessageFeed> onDialogueEnded = null, params string[] args)",
        "await Say(sequence, ResolveDialogueCommandContext(source), onDialogueEnded, args);",
        "DialogueTree dialogueTree = sequence.ToDialogueTree(speaker, commandContext, args);",
        "private static GameCommandContext ResolveDialogueCommandContext(CharacterBase source)",
        "return GameCommandContext.ResolveForActor(source);"
    )
    Test-ContainsAll -Content $dialogueInteractionContent -Patterns @(
        "await target.Say(m_sequence, source);"
    )
    Test-ContainsAll -Content $shopInteractionContent -Patterns @(
        "await target.Say(m_dialogue, source, async (messages) =>"
    )
    Test-ContainsAll -Content $craftInteractionContent -Patterns @(
        "await target.Say(m_dialogue, source, async (messages) =>"
    )
    Test-ContainsAll -Content $innInteractionContent -Patterns @(
        "await target.Say(m_dialogueIfCanPay, source, (messages) =>",
        "await target.Say(m_dialogueIfCannotPay, source);"
    )
    Test-ContainsAll -Content $questInteractionContent -Patterns @(
        "await character.Say(taskProgress.talkToCharacterTask.dialogue, source);",
        "await character.Say(quest.questCompletedDialogue, source);",
        "await GameManager.JournalSystem.CompleteQuest(quest, ResolveQuestCompletionCommandContext(source));",
        "await character.Say(dialogue, source);",
        "await character.Say(quest.questOfferDialogue, source, (messages) =>"
    )
    Test-ContainsAll -Content $playDialogueSequenceCommandContent -Patterns @(
        "m_dialogueSequence.ToDialogueTree(m_speaker, context)"
    )
    Test-ContainsAll -Content $playDialogueLineCommandContent -Patterns @(
        "new DialogueTree(new DialogueNode(StringFormatter.Format(m_line), m_speaker), context)"
    )
    Test-ContainsAll -Content $chestContent -Patterns @(
        "GameCommandContext commandContext = ResolveCommandContext(opener);",
        "InitializeContainerLoot(commandContext);",
        "TryOpenContainerInventory(opener, commandContext);",
        "m_noItemDialogue.ToDialogueTree(string.Empty, commandContext)",
        "m_hasItemDialogue.ToDialogueTree(",
        "string.Empty, commandContext"
    )
)

$dialogueLifecycleCommandContextDisallowedPatterns = @(
    Test-ContainsAny -Content $dialogueChannelContent -Patterns @(
        "m_currentNode.ExecuteCompletionCommand();",
        "m_currentNode.ExecuteStartCommand();"
    )
    Test-ContainsAny -Content $dialogueNodeContent -Patterns @(
        "m_toExecuteOnStart.Execute(GameCommandContext.Script());",
        "m_toExecuteOnCompletion.Execute(GameCommandContext.Script());"
    )
    Test-ContainsAny -Content $dialogueInteractionContent -Patterns @(
        "await target.Say(m_sequence);"
    )
    Test-ContainsAny -Content $shopInteractionContent -Patterns @(
        "await target.Say(m_dialogue, async (messages) =>"
    )
    Test-ContainsAny -Content $craftInteractionContent -Patterns @(
        "await target.Say(m_dialogue, async (messages) =>"
    )
    Test-ContainsAny -Content $innInteractionContent -Patterns @(
        "await target.Say(m_dialogueIfCanPay, (messages) =>",
        "await target.Say(m_dialogueIfCannotPay);"
    )
    Test-ContainsAny -Content $questInteractionContent -Patterns @(
        "await npc.Say(taskProgress.talkToNPCTask.dialogue);",
        "await npc.Say(quest.questCompletedDialogue, (actionFeed) =>",
        "await npc.Say(dialogue);",
        "await npc.Say(quest.questOfferDialogue, (messages) =>"
    )
    Test-ContainsAny -Content $playDialogueSequenceCommandContent -Patterns @(
        "m_dialogueSequence.ToDialogueTree(m_speaker))"
    )
    Test-ContainsAny -Content $playDialogueLineCommandContent -Patterns @(
        "new DialogueTree(new DialogueNode(StringFormatter.Format(m_line), m_speaker)))"
    )
)

$formalDialogueEventApiRegressionHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime")
) -Patterns @(
    "public UnityEvent dialogueStarted = new();",
    "public UnityEvent<DialogueMessageFeed> dialogueEnded = new();",
    "public UnityEvent<DialogueTree> dialogueStarted = new();",
    "public UnityEvent<DialogueTree> dialogueEnded = new();",
    "public UnityEvent<DialogueNode> dialogueNodeChanged = new();",
    ".dialogueStarted.AddListener(",
    ".dialogueEnded.AddListener(",
    ".dialogueNodeChanged.AddListener(",
    ".dialogueStarted.RemoveListener(",
    ".dialogueEnded.RemoveListener(",
    ".dialogueNodeChanged.RemoveListener(",
    ".dialogueStarted.Invoke(",
    ".dialogueEnded.Invoke(",
    ".dialogueNodeChanged.Invoke("
)

$formalLocalEventObjectApiRegressionHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime")
) -Patterns @(
    "public UnityEvent destroyedEvent => m_destroyedEvent;",
    "public UnityEvent teleported => m_teleported;",
    "public UnityEvent<Vector2> targetDirectionChangedEvent => m_targetDirectionChangedEvent;",
    "public UnityEvent<CharacterBase> provokedEvent => m_provokedEvent;",
    "public UnityEvent<Stats> currentStatsChanged => m_currentStats.changed;",
    "public UnityEvent<Stats> statsChanged => m_stats.changed;",
    "public UnityEvent<ITemporalEffect> temporalEffectAdded => m_temporalEffectAdded;",
    "public UnityEvent<ITemporalEffect> temporalEffectRemoved => m_temporalEffectRemoved;",
    "public UnityEvent<int> levelUpped => m_levelUpped;",
    "public UnityEvent<ActiveAbilitySheet[]> equippedAbilitiesChanged => m_equippedAbilitiesChanged;",
    "public UnityEvent deathAnimationStarted => m_deathAnimationStarted;",
    "public UnityEvent deathAnimationEnded => m_deathAnimationEnded;",
    "public UnityEvent deathAnimationStarted { get; }",
    "public UnityEvent deathAnimationEnded { get; }",
    "public UnityEvent<Stats> changed => m_changed;",
    "public UnityEvent destroyed => m_destroyed;"
)

$formalLiveObjectApiRegressionHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime")
) -Patterns @(
    "GameManager.PlayerSystem.PlayerInstance",
    "playerSystem.PlayerInstance",
    "public GameObject gameObject { get; }",
    "public GameObject gameObject => null;",
    "public CharacterBase character => m_character.ResolveOrNull();",
    "public GameObject gameObject => character ? character.gameObject : null;",
    "public Transform target;",
    "public Coroutine coroutine;",
    "CharacterBase controlledCharacter { get; }",
    "public CharacterBase controlledCharacter => m_subject;",
    "public IPlayerInputTarget currentInputTarget => m_currentInputTarget;",
    "public CharacterBase currentControlledCharacter => m_currentInputTarget?.controlledCharacter;",
    "public Hero currentControlledHero => currentControlledCharacter as Hero;",
    "public CharacterBase currentControlledCharacterOrPlayerInstance => currentControlledCharacter ?? m_playerInstance;",
    "public Hero currentControlledHeroOrPlayerInstance => currentControlledHero ?? m_playerInstance;",
    "public IController controller => m_controller;",
    "public ICheckpoint initialSpawnCheckpoint => m_initialSpawnCheckpoint;",
    "public ICheckpoint playtestCheckpoint => m_playtestCheckpoint;",
    "public bool useLevelBounds => m_useLevelBounds && m_levelBounds != null;",
    "public Collider2D levelBounds => m_levelBounds;",
    "public Transform cameraTarget => m_cameraTarget;",
    "public AbilityBase GetAbility(AbilitySheet sheet) => m_abilitiesInstances[sheet];",
    "public ITriggerableAbility Ability { get; }",
    "public ActiveAbilityBase GetAbilityBase();",
    "public ActiveAbilityBase GetAbilityBase() => this;",
    "public EAbilityFireCheckResult FireAbility(ActiveAbilitySheet sheet, out ITriggerableAbility ability)",
    "public EAbilityFireCheckResult FireAbility(ITriggerableAbility ability)",
    "public ActiveAbilitySheet GetSheet();",
    "public ActiveAbilitySheet GetSheet() => abilitySheet;",
    "public T instance =>",
    "public static implicit operator T(PersistableReference<T> reference) => reference.instance;",
    "public Persistable GetPersistable(string identifier)",
    "public Persistable InstantiateRuntime(PrefabReference instance, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null)",
    "public Persistable InstantiateCustom(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null)",
    "public TPersistable InstantiateRuntime<TPersistable>(PrefabReference instance, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable",
    "public TPersistable InstantiateCustom<TPersistable>(GameObject prefab, Vector3 position, Quaternion rotation, Transform parent = null, string identifier = null) where TPersistable : Persistable",
    "public void RegisterCustomInstancedPersistable(Persistable persistable, string identifier = null)",
    "public IReadOnlyList<CharacterBase> GetCharacters()",
    "public IReadOnlyList<CharacterBase> GetControllableCharacters()",
    "public IReadOnlyList<TCharacter> GetCharactersOfType<TCharacter>() where TCharacter : CharacterBase",
    "public Button button => m_button;",
    "public Button GetFirstButton()",
    "GetFirstButton().gameObject",
    "GetComponentInChildren<Button>().gameObject",
    "current.button.navigation = new()",
    "selectOnUp = previous?.button",
    "selectOnDown = next?.button",
    "selectOnRight = firstBagSlot?.button",
    "public UIInventoryBagSlot GetFirstSlot()",
    "public string saveFileName => m_saveFileName;",
    "public bool isEmpty => m_isEmpty;",
    "UnityAction<EStat, Button>",
    "UnityAction<EAudioChannel, Button>",
    "OnAddButtonPressed(EStat stat, Button button)",
    "OnRemoveButtonPressed(EStat stat, Button button)",
    "OnChannelVolumeIncreased(EAudioChannel channel, Button button)",
    "OnChannelVolumeDecreased(EAudioChannel channel, Button button)",
    "private Selectable m_selected = null;",
    "HandleGameMenuEntrySelected(Selectable selected)",
    "m_menu.HandleGameMenuEntrySelected(m_button)",
    "public void TryPick(GameObject picker)",
    "public static class CollisionDispatcher",
    "public static void RegisterCollision(Movable source, GameObject target)",
    "internal void TryEnter(GameObject target)",
    "internal void TryExit(GameObject target)",
    "private void AttemptExecution(EActivationEvent currentEvent, GameObject go = null)",
    "AttemptExecution(EActivationEvent.OnPlayerCollision, movable.gameObject)",
    "AttemptExecution(EActivationEvent.OnPlayerInteract, sender.gameObject)",
    "AttemptExecution(currentEvent, collider.gameObject)"
)

$formalPresentationEventApiRegressionHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts"),
    (Join-Path $projectRoot "Assets/Editor"),
    (Join-Path $projectRoot "Assets/Tests")
) -Patterns @(
    "GameplayFeedbackSet.damageTakenFeedbackPlayed",
    "GameplayFeedbackSet.healthRecoveredPresentationTriggered",
    "GameplayFeedbackSet.manaConsumedPresentationTriggered",
    "GameplayFeedbackSet.manaRecoveredPresentationTriggered",
    "GameplayFeedbackSet.temporalEffectPresentationTriggered",
    "GameplayFeedbackSet.deathPresentationTriggered",
    "GameplayFeedbackSet.lootPresentationTriggered",
    "GameplayFeedbackSet.pickupPresentationTriggered",
    "GameplayFeedbackSet.interactionPresentationTriggered",
    "GameplayFeedbackSet.RaiseHealthRecoveredPresentation",
    "GameplayFeedbackSet.RaiseManaConsumedPresentation",
    "GameplayFeedbackSet.RaiseManaRecoveredPresentation",
    "GameplayFeedbackSet.RaiseTemporalEffectPresentation",
    "GameplayFeedbackSet.RaiseDeathPresentation",
    "GameplayFeedbackSet.RaiseLootPresentation",
    "GameplayFeedbackSet.RaisePickupPresentation",
    "GameplayFeedbackSet.RaiseInteractionPresentation",
    "public static event Action<DamageTakenFeedbackContext> damageTakenFeedbackPlayed;",
    "public static event Action<CharacterValuePresentationContext> healthRecoveredPresentationTriggered;",
    "public static event Action<CharacterValuePresentationContext> manaConsumedPresentationTriggered;",
    "public static event Action<CharacterValuePresentationContext> manaRecoveredPresentationTriggered;",
    "public static event Action<TemporalEffectPresentationContext> temporalEffectPresentationTriggered;",
    "public static event Action<DeathPresentationContext> deathPresentationTriggered;",
    "public static event Action<LootPresentationContext> lootPresentationTriggered;",
    "public static event Action<PickupPresentationContext> pickupPresentationTriggered;",
    "public static event Action<InteractionPresentationContext> interactionPresentationTriggered;"
)

$formalRuntimeCommentDebtHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime"),
    (Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime")
) -Patterns @(
    "Hack-ish",
    "Workaround",
    "TODO:",
    "FIXME:",
    "Not ideal",
    "temporary solution",
    "workaround could be"
)

$animationLegacyPropagationModeHits = Test-FilesContainAny -Roots @(
    (Join-Path $projectRoot "Assets/Animations")
) -Patterns @(
    "propagationMode: 0",
    "propagationMode: 1",
    "propagationMode: 2"
) -Extensions @(".controller")

$eventKitDispatchBoundaryViolations = Find-EventKitDispatchBoundaryViolations -ProjectRoot $projectRoot -AllowedDispatchFiles @(
    $gameRuntimeEventsPath
)

$report = [ordered]@{
    ProjectRoot = $projectRoot
    GameConfigAssetPath = $gameConfigAssetPath
    DatabaseRegistryAssetPath = $databaseRegistryAssetPath
    ScenePath = $scenePath
    ManifestPath = $manifestPath
    GameManagerPath = $gameManagerPath
    GameRuntimeEventsPath = $gameRuntimeEventsPath
    InputSystemPath = $inputSystemPath
    GameStateSystemPath = $gameStateSystemPath
    QuestInteractionPath = $questInteractionPath
    JournalSystemPath = $journalSystemPath
    QuestPath = $questPath
    QuestProgressPath = $questProgressPath
    QuestTaskProgressPath = $questTaskProgressPath
    OpenShopMenuCommandPath = $openShopMenuCommandPath
    OpenCraftMenuCommandPath = $openCraftMenuCommandPath
    ItemStartQuestEffectPath = $itemStartQuestEffectPath
    ItemEffectBasePath = $itemEffectBasePath
    MapSystemPath = $mapSystemPath
    StateMessageDispatcherPath = $stateMessageDispatcherPath
    AnimationStrategyPath = $animationStrategyPath
    CharacterAlterationRulePath = $characterAlterationRulePath
    TemporalEffectInterfacePath = $temporalEffectInterfacePath
    TemporalEffectBasePath = $temporalEffectBasePath
    TemporalStatModifierEffectPath = $temporalStatModifierEffectPath
    CharacterBasePath = $characterBasePath
    CharacterBaseActionStateRuntimePath = $characterBaseActionStateRuntimePath
    CharacterBaseAbilitySetRuntimePath = $characterBaseAbilitySetRuntimePath
    CharacterBaseAttributeBootstrapBufferPath = $characterBaseAttributeBootstrapBufferPath
    CharacterBaseTemporalEffectRuntimePath = $characterBaseTemporalEffectRuntimePath
    UIStatBarPath = $uiStatBarPath
    UIDialogueMessageBoxPath = $uiDialogueMessageBoxPath
    UIEffectListPath = $uiEffectListPath
    UIHUDAbilityBarPath = $uiHudAbilityBarPath
    UIHUDAbilityBarEntryPath = $uiHudAbilityBarEntryPath
    UIAbilitiesPath = $uiAbilitiesPath
    UIAbilityBarPath = $uiAbilityBarPath
    UICharacterPath = $uiCharacterPath
    UIInventoryPath = $uiInventoryPath
    UIInventoryBagPath = $uiInventoryBagPath
    InventorySystemPath = $inventorySystemPath
    InventoryTransferRequestPath = $inventoryTransferRequestPath
    InventoryMenuContextPath = $inventoryMenuContextPath
    ItemPath = $itemPath
    ItemEquipOrUnequipPath = $itemEquipOrUnequipPath
    MenuFeedbackPromptsPath = $menuFeedbackPromptsPath
    UICraftPath = $uiCraftPath
    UIEventLogPath = $uiEventLogPath
    UIJournalPath = $uiJournalPath
    UIShopPath = $uiShopPath
    MissingFiles = @($missingFiles)
    LegacyExistingFiles = @($legacyExistingFiles)
    SceneMissingPatterns = @($sceneMissingPatterns)
    SampleSceneHasExplicitInputRoot = $sampleSceneHasExplicitInputRoot
    FormalSceneExplicitInputRootMissingScenes = @($formalSceneExplicitInputHostMissingScenes)
    SampleSceneHasFormalMainCamera = $sampleSceneHasFormalMainCamera
    FormalSceneMainCameraMissingScenes = @($formalSceneMainCameraMissingScenes)
    SceneDisallowedPatterns = @($sceneDisallowedPatterns)
    GameConfigMissingPatterns = @($gameConfigMissingPatterns)
    GameConfigRuntimeMissingPatterns = @($gameConfigRuntimeMissingPatterns)
    GameConfigRuntimeDisallowedPatterns = @($gameConfigRuntimeDisallowedPatterns)
    GameConfigContractsMissingPatterns = @($gameConfigContractsMissingPatterns)
    GameConfigTermsMissingPatterns = @($gameConfigTermsMissingPatterns)
    GameConfigPersistenceMissingPatterns = @($gameConfigPersistenceMissingPatterns)
    DatabaseRegistryMissingPatterns = @($databaseRegistryMissingPatterns)
    DatabaseRegistryRuntimeDisallowedPatterns = @($databaseRegistryRuntimeDisallowedPatterns)
    DatabaseRegistryEditorMissingPatterns = @($databaseRegistryEditorMissingPatterns)
    DatabaseRegistryEditorDisallowedPatterns = @($databaseRegistryEditorDisallowedPatterns)
    DatabaseEntryProcessorMissingPatterns = @($databaseEntryProcessorMissingPatterns)
    AudioChannelMissingPatterns = @($audioChannelMissingPatterns)
    AudioChannelDisallowedPatterns = @($audioChannelDisallowedPatterns)
    AudioChannelFallbackPoolRuntimeMissingPatterns = @($audioChannelFallbackPoolRuntimeMissingPatterns)
    AudioChannelPlaybackRuntimeMissingPatterns = @($audioChannelPlaybackRuntimeMissingPatterns)
    PersistableMissingPatterns = @($persistableMissingPatterns)
    PersistableDisallowedPatterns = @($persistableDisallowedPatterns)
    PersistableContractsMissingPatterns = @($persistableContractsMissingPatterns)
    PersistableDataBlocksMissingPatterns = @($persistableDataBlocksMissingPatterns)
    PersistableDestroyPersistenceSystemMissingPatterns = @($persistableDestroyPersistenceSystemMissingPatterns)
    PersistableDestroyPersistenceSystemDisallowedPatterns = @($persistableDestroyPersistenceSystemDisallowedPatterns)
    FormalDataAssetCacheMissingPatterns = @($formalDataAssetCacheMissingPatterns)
    FormalDataAssetCacheDisallowedPatterns = @($formalDataAssetCacheDisallowedPatterns)
    ManifestMissingPatterns = @($manifestMissingPatterns)
    GameManagerMissingPatterns = @($gameManagerMissingPatterns)
    GameManagerDisallowedPatterns = @($gameManagerDisallowedPatterns)
    GameRuntimeEventsMissingPatterns = @($gameRuntimeEventsMissingPatterns)
    GameRuntimeEventsDisallowedPatterns = @($gameRuntimeEventsDisallowedPatterns)
    InputSystemMissingPatterns = @($inputSystemMissingPatterns)
    InputSystemDisallowedPatterns = @($inputSystemDisallowedPatterns)
    UIHUDAbilityMessageMissingPatterns = @($uiHudAbilityMessageMissingPatterns)
    PlayerCommandRequestMissingPatterns = @($playerCommandRequestMissingPatterns)
    PlayerOrderRequestMissingPatterns = @($playerOrderRequestMissingPatterns)
    GameCommandContextMissingPatterns = @($gameCommandContextMissingPatterns)
    PlayerInputTargetMissingPatterns = @($playerInputTargetMissingPatterns)
    PlayerInputTargetDisallowedPatterns = @($playerInputTargetDisallowedPatterns)
    PlayerControlGroupMissingPatterns = @($playerControlGroupMissingPatterns)
    PlayerControlGroupDisallowedPatterns = @($playerControlGroupDisallowedPatterns)
    CharacterPlayerControlMissingPatterns = @($characterPlayerControlMissingPatterns)
    CharacterPlayerInputTargetMissingPatterns = @($characterPlayerInputTargetMissingPatterns)
    CharacterPlayerControlDisallowedPatterns = @($characterPlayerControlDisallowedPatterns)
    AIControllerMissingPatterns = @($aiControllerMissingPatterns)
    AIControllerDisallowedPatterns = @($aiControllerDisallowedPatterns)
    AIControllerBehaviourRuntimeMissingPatterns = @($aiControllerBehaviourRuntimeMissingPatterns)
    PlayerSystemPlayerControlMissingPatterns = @($playerSystemPlayerControlMissingPatterns)
    PlayerControlLifecycleMissingPatterns = @($playerControlLifecycleMissingPatterns)
    CurrentControlledCharacterUiMissingPatterns = @($currentControlledCharacterUiMissingPatterns)
    CurrentControlledCharacterUiDisallowedPatterns = @($currentControlledCharacterUiDisallowedPatterns)
    CommandCurrentControlledTargetMissingPatterns = @($commandCurrentControlledTargetMissingPatterns)
    CommandCurrentControlledTargetDisallowedPatterns = @($commandCurrentControlledTargetDisallowedPatterns)
    CharacterDeathCommandContextMissingPatterns = @($characterDeathCommandContextMissingPatterns)
    CharacterDeathCommandContextDisallowedPatterns = @($characterDeathCommandContextDisallowedPatterns)
    PlayerDeathCommandContextMissingPatterns = @($playerDeathCommandContextMissingPatterns)
    PlayerDeathCommandContextDisallowedPatterns = @($playerDeathCommandContextDisallowedPatterns)
    QuestCompletionCommandContextMissingPatterns = @($questCompletionCommandContextMissingPatterns)
    QuestCompletionCommandContextDisallowedPatterns = @($questCompletionCommandContextDisallowedPatterns)
    QuestStartCommandContextMissingPatterns = @($questStartCommandContextMissingPatterns)
    QuestStartCommandContextDisallowedPatterns = @($questStartCommandContextDisallowedPatterns)
    PersistableDestroyCommandContextMissingPatterns = @($persistableDestroyCommandContextMissingPatterns)
    PersistableDestroyCommandContextDisallowedPatterns = @($persistableDestroyCommandContextDisallowedPatterns)
    CharacterDeathDestroyCommandContextMissingPatterns = @($characterDeathDestroyCommandContextMissingPatterns)
    CharacterDeathDestroyCommandContextDisallowedPatterns = @($characterDeathDestroyCommandContextDisallowedPatterns)
    MovableControllerRuntimeMissingPatterns = @($movableControllerRuntimeMissingPatterns)
    MovableControllerRuntimeDisallowedPatterns = @($movableControllerRuntimeDisallowedPatterns)
    ProjectileDestroyCommandContextMissingPatterns = @($projectileDestroyCommandContextMissingPatterns)
    ProjectileDestroyCommandContextDisallowedPatterns = @($projectileDestroyCommandContextDisallowedPatterns)
    SummonCleanupCommandContextMissingPatterns = @($summonCleanupCommandContextMissingPatterns)
    SummonCleanupCommandContextDisallowedPatterns = @($summonCleanupCommandContextDisallowedPatterns)
    PlayerSystemDisallowedPatterns = @($playerSystemDisallowedPatterns)
    GameStateSystemDisallowedPatterns = @($gameStateSystemDisallowedPatterns)
    MapSystemMissingPatterns = @($mapSystemMissingPatterns)
    MapSystemDisallowedPatterns = @($mapSystemDisallowedPatterns)
    PersistenceSystemMissingPatterns = @($persistenceSystemMissingPatterns)
    PersistenceSystemDisallowedPatterns = @($persistenceSystemDisallowedPatterns)
    PersistenceSystemContractsMissingPatterns = @($persistenceSystemContractsMissingPatterns)
    PersistenceSystemInstantiationRuntimeMissingPatterns = @($persistenceSystemInstantiationRuntimeMissingPatterns)
    SceneUtilMissingPatterns = @($sceneUtilMissingPatterns)
    SceneUtilDisallowedPatterns = @($sceneUtilDisallowedPatterns)
    SceneMenuRegistryMissingPatterns = @($sceneMenuRegistryMissingPatterns)
    SceneMenuRegistryDisallowedPatterns = @($sceneMenuRegistryDisallowedPatterns)
    GeneratedSceneMenuMissingPatterns = @($generatedSceneMenuMissingPatterns)
    GeneratedSceneMenuDisallowedPatterns = @($generatedSceneMenuDisallowedPatterns)
    StateMessageDispatcherMissingPatterns = @($stateMessageDispatcherMissingPatterns)
    StateMessageDispatcherDisallowedPatterns = @($stateMessageDispatcherDisallowedPatterns)
    AnimationStrategyMissingPatterns = @($animationStrategyMissingPatterns)
    FormalAttributeCatalogMissingPatterns = @($formalAttributeCatalogMissingPatterns)
    FormalAttributeCatalogDisallowedPatterns = @($formalAttributeCatalogDisallowedPatterns)
    AbilitySheetExistingFiles = @($abilitySheetExistingFiles)
    CharacterAlterationRuleMissingPatterns = @($characterAlterationRuleMissingPatterns)
    TemporalEffectInterfaceMissingPatterns = @($temporalEffectInterfaceMissingPatterns)
    TemporalEffectInterfaceDisallowedPatterns = @($temporalEffectInterfaceDisallowedPatterns)
    TemporalEffectBaseMissingPatterns = @($temporalEffectBaseMissingPatterns)
    TemporalEffectBaseDisallowedPatterns = @($temporalEffectBaseDisallowedPatterns)
    TemporalAbilityEffectSupportMissingPatterns = @($temporalAbilityEffectSupportMissingPatterns)
    TemporalAbilityGrantEffectMissingPatterns = @($temporalAbilityGrantEffectMissingPatterns)
    TemporalAbilitySuppressionEffectMissingPatterns = @($temporalAbilitySuppressionEffectMissingPatterns)
    TemporalAbilityReplacementEffectMissingPatterns = @($temporalAbilityReplacementEffectMissingPatterns)
    TemporalStatModifierEffectMissingPatterns = @($temporalStatModifierEffectMissingPatterns)
    TemporalEffectFallbackContractRegressionHits = @($temporalEffectFallbackContractRegressionHits)
    CharacterBaseDisallowedPatterns = @($characterBaseDisallowedPatterns)
    CharacterBaseMainMissingPatterns = @($characterBaseMainMissingPatterns)
    CharacterBasePrefabPath = $characterBasePrefabPath
    CharacterBasePrefabMissingPatterns = @($characterBasePrefabMissingPatterns)
    CharacterBaseContractsMissingPatterns = @($characterBaseContractsMissingPatterns)
    CharacterBaseContractsDisallowedPatterns = @($characterBaseContractsDisallowedPatterns)
    CharacterBaseResourcesMissingPatterns = @($characterBaseResourcesMissingPatterns)
    CharacterBaseResourcesDisallowedPatterns = @($characterBaseResourcesDisallowedPatterns)
    CharacterBaseAbilitiesMissingPatterns = @($characterBaseAbilitiesMissingPatterns)
    CharacterBaseAbilitiesDisallowedPatterns = @($characterBaseAbilitiesDisallowedPatterns)
    CharacterBaseAlterationsMissingPatterns = @($characterBaseAlterationsMissingPatterns)
    CharacterBaseActionStateRuntimeMissingPatterns = @($characterBaseActionStateRuntimeMissingPatterns)
    CharacterBaseActionStateRuntimeDisallowedPatterns = @($characterBaseActionStateRuntimeDisallowedPatterns)
    CharacterBaseAbilitySetRuntimeMissingPatterns = @($characterBaseAbilitySetRuntimeMissingPatterns)
    CharacterBaseAbilitySetRuntimeDisallowedPatterns = @($characterBaseAbilitySetRuntimeDisallowedPatterns)
    CharacterBaseAttributeBootstrapBufferMissingPatterns = @($characterBaseAttributeBootstrapBufferMissingPatterns)
    CharacterBaseAttributeBootstrapBufferDisallowedPatterns = @($characterBaseAttributeBootstrapBufferDisallowedPatterns)
    ActiveAbilityBaseMissingPatterns = @($activeAbilityBaseMissingPatterns)
    ActiveAbilityBaseDisallowedPatterns = @($activeAbilityBaseDisallowedPatterns)
    ProjectileMissingPatterns = @($projectileMissingPatterns)
    ProjectileAbilityMissingPatterns = @($projectileAbilityMissingPatterns)
    ProjectileAbilityDisallowedPatterns = @($projectileAbilityDisallowedPatterns)
    SummoningAbilityMissingPatterns = @($summoningAbilityMissingPatterns)
    SummoningAbilityDisallowedPatterns = @($summoningAbilityDisallowedPatterns)
    PerTargetCooldownMissingPatterns = @($perTargetCooldownMissingPatterns)
    PerTargetCooldownDisallowedPatterns = @($perTargetCooldownDisallowedPatterns)
    WeaponExecutionExistingFiles = @($weaponExecutionExistingFiles)
    CharacterBaseGasRuntimeMissingPatterns = @($characterBaseGasRuntimeMissingPatterns)
    CharacterBaseGasRuntimeDisallowedPatterns = @($characterBaseGasRuntimeDisallowedPatterns)
    CharacterBaseTemporalEffectRuntimeMissingPatterns = @($characterBaseTemporalEffectRuntimeMissingPatterns)
    CharacterBaseTemporalEffectRuntimeDisallowedPatterns = @($characterBaseTemporalEffectRuntimeDisallowedPatterns)
    CharacterBaseStateApiMissingPatterns = @($characterBaseStateApiMissingPatterns)
    CharacterBaseStateApiDisallowedPatterns = @($characterBaseStateApiDisallowedPatterns)
    CharacterBasePersistenceMissingPatterns = @($characterBasePersistenceMissingPatterns)
    CharacterBasePersistenceDisallowedPatterns = @($characterBasePersistenceDisallowedPatterns)
    CharacterActorMissingPatterns = @($characterActorMissingPatterns)
    CharacterPlayerSystemNotificationMissingPatterns = @($characterPlayerSystemNotificationMissingPatterns)
    CharacterPlayerSystemNotificationDisallowedPatterns = @($characterPlayerSystemNotificationDisallowedPatterns)
    InventoryActionLockMissingPatterns = @($inventoryActionLockMissingPatterns)
    InventoryCorpseOwnershipMissingPatterns = @($inventoryCorpseOwnershipMissingPatterns)
    InventoryCorpseLootInteractionMissingPatterns = @($inventoryCorpseLootInteractionMissingPatterns)
    InventoryMenuContextMissingPatterns = @($inventoryMenuContextMissingPatterns)
    InventoryMenuContextDisallowedPatterns = @($inventoryMenuContextDisallowedPatterns)
    ShopCraftMenuContextMissingPatterns = @($shopCraftMenuContextMissingPatterns)
    ShopCraftMenuContextDisallowedPatterns = @($shopCraftMenuContextDisallowedPatterns)
    CharacterEquippedItemLoadoutMissingPatterns = @($characterEquippedItemLoadoutMissingPatterns)
    CharacterEquippedAbilityLoadoutMissingPatterns = @($characterEquippedAbilityLoadoutMissingPatterns)
    SaveReferenceRequiredMissingPatterns = @($saveReferenceRequiredMissingPatterns)
    SaveReferenceRequiredDisallowedPatterns = @($saveReferenceRequiredDisallowedPatterns)
    UIMenuRuntimeLegacyReferencePatterns = @($uiMenuRuntimeLegacyReferencePatterns)
    UIManagerDisallowedPatterns = @($uiManagerDisallowedPatterns)
    UIControllerButtonMissingPatterns = @($uiControllerButtonMissingPatterns)
    UIControllerButtonManagerDisallowedPatterns = @($uiControllerButtonManagerDisallowedPatterns)
    UIMenuRuntimeMissingPatterns = @($uiMenuRuntimeMissingPatterns)
    UIMenuRuntimeDisallowedPatterns = @($uiMenuRuntimeDisallowedPatterns)
    FormalSceneInputRootAutomationMissingPatterns = @($formalSceneInputHostAutomationMissingPatterns)
    FormalSceneInputRootAutomationDisallowedPatterns = @($formalSceneInputHostAutomationDisallowedPatterns)
    FormalSceneInputRootRepairScriptMissingPatterns = @($formalSceneInputHostRepairScriptMissingPatterns)
    FormalSceneInputRootRepairScriptDisallowedPatterns = @($formalSceneInputHostRepairScriptDisallowedPatterns)
    FormalSceneVersionControlMissingFiles = @($formalSceneVersionControlMissingFiles)
    UIStatBarMissingPatterns = @($uiStatBarMissingPatterns)
    UIStatBarDisallowedPatterns = @($uiStatBarDisallowedPatterns)
    UIDialogueMessageBoxMissingPatterns = @($uiDialogueMessageBoxMissingPatterns)
    UIDialogueMessageBoxDisallowedPatterns = @($uiDialogueMessageBoxDisallowedPatterns)
    UIListPoolingMissingPatterns = @($uiListPoolingMissingPatterns)
    UIListPoolingDisallowedPatterns = @($uiListPoolingDisallowedPatterns)
    GameManagerBaselineSystemShortcuts = @($gameManagerSystemShortcuts)
    NonBaselineNewGameManagerSystemShortcuts = @($nonBaselineNewGameManagerSystemShortcuts)
    NotificationLegacyReferenceHits = @($notificationLegacyReferenceHits)
    LegacySceneReferenceHits = @($legacySceneReferenceHits)
    LegacyBusinessAssetHits = @($legacyBusinessAssetHits)
    SourceDisallowedPatterns = @($sourceDisallowedPatterns)
    GameCoreGasRuntimeReferenceHits = @($gameCoreGasRuntimeReferenceHits)
    GameCoreTopDownManagerReferenceHits = @($gameCoreTopDownManagerReferenceHits)
    GameCorePrematureModeRuntimeHits = @($gameCorePrematureModeRuntimeHits)
    FormalAssetApiRegressionHits = @($formalAssetApiRegressionHits)
    FormalMutableStatsLeakHits = @($formalMutableStatsLeakHits)
    ResourceStatSemanticBypassHits = @($resourceStatSemanticBypassHits)
    DirectEventSystemAccessHits = @($directEventSystemAccessHits)
    DirectMainCameraAccessHits = @($directMainCameraAccessHits)
    ControlGroupBypassHits = @($controlGroupBypassHits)
    FormalEnumerableLeakHits = @($formalEnumerableLeakHits)
    DialogueNodeMissingPatterns = @($dialogueNodeMissingPatterns)
    DialogueNodeDisallowedPatterns = @($dialogueNodeDisallowedPatterns)
    DialogueLifecycleCommandContextMissingPatterns = @($dialogueLifecycleCommandContextMissingPatterns)
    DialogueLifecycleCommandContextDisallowedPatterns = @($dialogueLifecycleCommandContextDisallowedPatterns)
    FormalDialogueEventApiRegressionHits = @($formalDialogueEventApiRegressionHits)
    FormalLocalEventObjectApiRegressionHits = @($formalLocalEventObjectApiRegressionHits)
    FormalLiveObjectApiRegressionHits = @($formalLiveObjectApiRegressionHits)
    FormalPresentationEventApiRegressionHits = @($formalPresentationEventApiRegressionHits)
    FormalRuntimeCommentDebtHits = @($formalRuntimeCommentDebtHits)
    AnimationLegacyPropagationModeHits = @($animationLegacyPropagationModeHits)
    EventKitDispatchBoundaryViolations = @($eventKitDispatchBoundaryViolations)
    MissingFileCount = @($missingFiles).Count
    LegacyExistingFileCount = @($legacyExistingFiles).Count
    SceneMissingPatternCount = @($sceneMissingPatterns).Count
    FormalSceneExplicitInputRootMissingSceneCount = @($formalSceneExplicitInputHostMissingScenes).Count
    FormalSceneMainCameraMissingSceneCount = @($formalSceneMainCameraMissingScenes).Count
    SceneDisallowedPatternCount = @($sceneDisallowedPatterns).Count
    GameConfigMissingPatternCount = @($gameConfigMissingPatterns).Count
    GameConfigRuntimeMissingPatternCount = @($gameConfigRuntimeMissingPatterns).Count
    GameConfigRuntimeDisallowedPatternCount = @($gameConfigRuntimeDisallowedPatterns).Count
    GameConfigContractsMissingPatternCount = @($gameConfigContractsMissingPatterns).Count
    GameConfigTermsMissingPatternCount = @($gameConfigTermsMissingPatterns).Count
    GameConfigPersistenceMissingPatternCount = @($gameConfigPersistenceMissingPatterns).Count
    DatabaseRegistryMissingPatternCount = @($databaseRegistryMissingPatterns).Count
    DatabaseRegistryRuntimeDisallowedPatternCount = @($databaseRegistryRuntimeDisallowedPatterns).Count
    DatabaseRegistryEditorMissingPatternCount = @($databaseRegistryEditorMissingPatterns).Count
    DatabaseRegistryEditorDisallowedPatternCount = @($databaseRegistryEditorDisallowedPatterns).Count
    DatabaseEntryProcessorMissingPatternCount = @($databaseEntryProcessorMissingPatterns).Count
    AudioChannelMissingPatternCount = @($audioChannelMissingPatterns).Count
    AudioChannelDisallowedPatternCount = @($audioChannelDisallowedPatterns).Count
    AudioChannelFallbackPoolRuntimeMissingPatternCount = @($audioChannelFallbackPoolRuntimeMissingPatterns).Count
    AudioChannelPlaybackRuntimeMissingPatternCount = @($audioChannelPlaybackRuntimeMissingPatterns).Count
    PersistableMissingPatternCount = @($persistableMissingPatterns).Count
    PersistableDisallowedPatternCount = @($persistableDisallowedPatterns).Count
    PersistableContractsMissingPatternCount = @($persistableContractsMissingPatterns).Count
    PersistableDataBlocksMissingPatternCount = @($persistableDataBlocksMissingPatterns).Count
    PersistableDestroyPersistenceSystemMissingPatternCount = @($persistableDestroyPersistenceSystemMissingPatterns).Count
    PersistableDestroyPersistenceSystemDisallowedPatternCount = @($persistableDestroyPersistenceSystemDisallowedPatterns).Count
    FormalDataAssetCacheMissingPatternCount = @($formalDataAssetCacheMissingPatterns).Count
    FormalDataAssetCacheDisallowedPatternCount = @($formalDataAssetCacheDisallowedPatterns).Count
    ManifestMissingPatternCount = @($manifestMissingPatterns).Count
    GameManagerMissingPatternCount = @($gameManagerMissingPatterns).Count
    GameManagerDisallowedPatternCount = @($gameManagerDisallowedPatterns).Count
    GameRuntimeEventsMissingPatternCount = @($gameRuntimeEventsMissingPatterns).Count
    GameRuntimeEventsDisallowedPatternCount = @($gameRuntimeEventsDisallowedPatterns).Count
    InputSystemMissingPatternCount = @($inputSystemMissingPatterns).Count
    InputSystemDisallowedPatternCount = @($inputSystemDisallowedPatterns).Count
    UIHUDAbilityMessageMissingPatternCount = @($uiHudAbilityMessageMissingPatterns).Count
    PlayerCommandRequestMissingPatternCount = @($playerCommandRequestMissingPatterns).Count
    PlayerOrderRequestMissingPatternCount = @($playerOrderRequestMissingPatterns).Count
    GameCommandContextMissingPatternCount = @($gameCommandContextMissingPatterns).Count
    PlayerInputTargetMissingPatternCount = @($playerInputTargetMissingPatterns).Count
    PlayerInputTargetDisallowedPatternCount = @($playerInputTargetDisallowedPatterns).Count
    PlayerControlGroupMissingPatternCount = @($playerControlGroupMissingPatterns).Count
    PlayerControlGroupDisallowedPatternCount = @($playerControlGroupDisallowedPatterns).Count
    CharacterPlayerControlMissingPatternCount = @($characterPlayerControlMissingPatterns).Count
    CharacterPlayerInputTargetMissingPatternCount = @($characterPlayerInputTargetMissingPatterns).Count
    CharacterPlayerControlDisallowedPatternCount = @($characterPlayerControlDisallowedPatterns).Count
    AIControllerMissingPatternCount = @($aiControllerMissingPatterns).Count
    AIControllerDisallowedPatternCount = @($aiControllerDisallowedPatterns).Count
    AIControllerBehaviourRuntimeMissingPatternCount = @($aiControllerBehaviourRuntimeMissingPatterns).Count
    PlayerSystemPlayerControlMissingPatternCount = @($playerSystemPlayerControlMissingPatterns).Count
    PlayerControlLifecycleMissingPatternCount = @($playerControlLifecycleMissingPatterns).Count
    CurrentControlledCharacterUiMissingPatternCount = @($currentControlledCharacterUiMissingPatterns).Count
    CurrentControlledCharacterUiDisallowedPatternCount = @($currentControlledCharacterUiDisallowedPatterns).Count
    CommandCurrentControlledTargetMissingPatternCount = @($commandCurrentControlledTargetMissingPatterns).Count
    CommandCurrentControlledTargetDisallowedPatternCount = @($commandCurrentControlledTargetDisallowedPatterns).Count
    CharacterDeathCommandContextMissingPatternCount = @($characterDeathCommandContextMissingPatterns).Count
    CharacterDeathCommandContextDisallowedPatternCount = @($characterDeathCommandContextDisallowedPatterns).Count
    PlayerDeathCommandContextMissingPatternCount = @($playerDeathCommandContextMissingPatterns).Count
    PlayerDeathCommandContextDisallowedPatternCount = @($playerDeathCommandContextDisallowedPatterns).Count
    QuestCompletionCommandContextMissingPatternCount = @($questCompletionCommandContextMissingPatterns).Count
    QuestCompletionCommandContextDisallowedPatternCount = @($questCompletionCommandContextDisallowedPatterns).Count
    QuestStartCommandContextMissingPatternCount = @($questStartCommandContextMissingPatterns).Count
    QuestStartCommandContextDisallowedPatternCount = @($questStartCommandContextDisallowedPatterns).Count
    PersistableDestroyCommandContextMissingPatternCount = @($persistableDestroyCommandContextMissingPatterns).Count
    PersistableDestroyCommandContextDisallowedPatternCount = @($persistableDestroyCommandContextDisallowedPatterns).Count
    CharacterDeathDestroyCommandContextMissingPatternCount = @($characterDeathDestroyCommandContextMissingPatterns).Count
    CharacterDeathDestroyCommandContextDisallowedPatternCount = @($characterDeathDestroyCommandContextDisallowedPatterns).Count
    MovableControllerRuntimeMissingPatternCount = @($movableControllerRuntimeMissingPatterns).Count
    MovableControllerRuntimeDisallowedPatternCount = @($movableControllerRuntimeDisallowedPatterns).Count
    ProjectileDestroyCommandContextMissingPatternCount = @($projectileDestroyCommandContextMissingPatterns).Count
    ProjectileDestroyCommandContextDisallowedPatternCount = @($projectileDestroyCommandContextDisallowedPatterns).Count
    SummonCleanupCommandContextMissingPatternCount = @($summonCleanupCommandContextMissingPatterns).Count
    SummonCleanupCommandContextDisallowedPatternCount = @($summonCleanupCommandContextDisallowedPatterns).Count
    PlayerSystemDisallowedPatternCount = @($playerSystemDisallowedPatterns).Count
    GameStateSystemDisallowedPatternCount = @($gameStateSystemDisallowedPatterns).Count
    MapSystemMissingPatternCount = @($mapSystemMissingPatterns).Count
    MapSystemDisallowedPatternCount = @($mapSystemDisallowedPatterns).Count
    PersistenceSystemMissingPatternCount = @($persistenceSystemMissingPatterns).Count
    PersistenceSystemDisallowedPatternCount = @($persistenceSystemDisallowedPatterns).Count
    PersistenceSystemContractsMissingPatternCount = @($persistenceSystemContractsMissingPatterns).Count
    PersistenceSystemInstantiationRuntimeMissingPatternCount = @($persistenceSystemInstantiationRuntimeMissingPatterns).Count
    SceneUtilMissingPatternCount = @($sceneUtilMissingPatterns).Count
    SceneUtilDisallowedPatternCount = @($sceneUtilDisallowedPatterns).Count
    SceneMenuRegistryMissingPatternCount = @($sceneMenuRegistryMissingPatterns).Count
    SceneMenuRegistryDisallowedPatternCount = @($sceneMenuRegistryDisallowedPatterns).Count
    GeneratedSceneMenuMissingPatternCount = @($generatedSceneMenuMissingPatterns).Count
    GeneratedSceneMenuDisallowedPatternCount = @($generatedSceneMenuDisallowedPatterns).Count
    StateMessageDispatcherMissingPatternCount = @($stateMessageDispatcherMissingPatterns).Count
    StateMessageDispatcherDisallowedPatternCount = @($stateMessageDispatcherDisallowedPatterns).Count
    AnimationStrategyMissingPatternCount = @($animationStrategyMissingPatterns).Count
    FormalAttributeCatalogMissingPatternCount = @($formalAttributeCatalogMissingPatterns).Count
    FormalAttributeCatalogDisallowedPatternCount = @($formalAttributeCatalogDisallowedPatterns).Count
    AbilitySheetExistingFileCount = @($abilitySheetExistingFiles).Count
    CharacterAlterationRuleMissingPatternCount = @($characterAlterationRuleMissingPatterns).Count
    TemporalEffectInterfaceMissingPatternCount = @($temporalEffectInterfaceMissingPatterns).Count
    TemporalEffectInterfaceDisallowedPatternCount = @($temporalEffectInterfaceDisallowedPatterns).Count
    TemporalEffectBaseMissingPatternCount = @($temporalEffectBaseMissingPatterns).Count
    TemporalEffectBaseDisallowedPatternCount = @($temporalEffectBaseDisallowedPatterns).Count
    TemporalAbilityEffectSupportMissingPatternCount = @($temporalAbilityEffectSupportMissingPatterns).Count
    TemporalAbilityGrantEffectMissingPatternCount = @($temporalAbilityGrantEffectMissingPatterns).Count
    TemporalAbilitySuppressionEffectMissingPatternCount = @($temporalAbilitySuppressionEffectMissingPatterns).Count
    TemporalAbilityReplacementEffectMissingPatternCount = @($temporalAbilityReplacementEffectMissingPatterns).Count
    TemporalStatModifierEffectMissingPatternCount = @($temporalStatModifierEffectMissingPatterns).Count
    TemporalEffectFallbackContractRegressionHitCount = @($temporalEffectFallbackContractRegressionHits).Count
    CharacterBaseDisallowedPatternCount = @($characterBaseDisallowedPatterns).Count
    CharacterBaseMainMissingPatternCount = @($characterBaseMainMissingPatterns).Count
    CharacterBasePrefabMissingPatternCount = @($characterBasePrefabMissingPatterns).Count
    CharacterBaseContractsMissingPatternCount = @($characterBaseContractsMissingPatterns).Count
    CharacterBaseContractsDisallowedPatternCount = @($characterBaseContractsDisallowedPatterns).Count
    CharacterBaseResourcesMissingPatternCount = @($characterBaseResourcesMissingPatterns).Count
    CharacterBaseResourcesDisallowedPatternCount = @($characterBaseResourcesDisallowedPatterns).Count
    CharacterBaseAbilitiesMissingPatternCount = @($characterBaseAbilitiesMissingPatterns).Count
    CharacterBaseAbilitiesDisallowedPatternCount = @($characterBaseAbilitiesDisallowedPatterns).Count
    CharacterBaseAlterationsMissingPatternCount = @($characterBaseAlterationsMissingPatterns).Count
    CharacterBaseActionStateRuntimeMissingPatternCount = @($characterBaseActionStateRuntimeMissingPatterns).Count
    CharacterBaseActionStateRuntimeDisallowedPatternCount = @($characterBaseActionStateRuntimeDisallowedPatterns).Count
    CharacterBaseAbilitySetRuntimeMissingPatternCount = @($characterBaseAbilitySetRuntimeMissingPatterns).Count
    CharacterBaseAbilitySetRuntimeDisallowedPatternCount = @($characterBaseAbilitySetRuntimeDisallowedPatterns).Count
    CharacterBaseAttributeBootstrapBufferMissingPatternCount = @($characterBaseAttributeBootstrapBufferMissingPatterns).Count
    CharacterBaseAttributeBootstrapBufferDisallowedPatternCount = @($characterBaseAttributeBootstrapBufferDisallowedPatterns).Count
    ActiveAbilityBaseMissingPatternCount = @($activeAbilityBaseMissingPatterns).Count
    ActiveAbilityBaseDisallowedPatternCount = @($activeAbilityBaseDisallowedPatterns).Count
    ProjectileMissingPatternCount = @($projectileMissingPatterns).Count
    ProjectileAbilityMissingPatternCount = @($projectileAbilityMissingPatterns).Count
    ProjectileAbilityDisallowedPatternCount = @($projectileAbilityDisallowedPatterns).Count
    SummoningAbilityMissingPatternCount = @($summoningAbilityMissingPatterns).Count
    SummoningAbilityDisallowedPatternCount = @($summoningAbilityDisallowedPatterns).Count
    PerTargetCooldownMissingPatternCount = @($perTargetCooldownMissingPatterns).Count
    PerTargetCooldownDisallowedPatternCount = @($perTargetCooldownDisallowedPatterns).Count
    WeaponExecutionExistingFileCount = @($weaponExecutionExistingFiles).Count
    CharacterBaseGasRuntimeMissingPatternCount = @($characterBaseGasRuntimeMissingPatterns).Count
    CharacterBaseGasRuntimeDisallowedPatternCount = @($characterBaseGasRuntimeDisallowedPatterns).Count
    CharacterBaseTemporalEffectRuntimeMissingPatternCount = @($characterBaseTemporalEffectRuntimeMissingPatterns).Count
    CharacterBaseTemporalEffectRuntimeDisallowedPatternCount = @($characterBaseTemporalEffectRuntimeDisallowedPatterns).Count
    CharacterBaseStateApiMissingPatternCount = @($characterBaseStateApiMissingPatterns).Count
    CharacterBaseStateApiDisallowedPatternCount = @($characterBaseStateApiDisallowedPatterns).Count
    CharacterBasePersistenceMissingPatternCount = @($characterBasePersistenceMissingPatterns).Count
    CharacterBasePersistenceDisallowedPatternCount = @($characterBasePersistenceDisallowedPatterns).Count
    CharacterActorMissingPatternCount = @($characterActorMissingPatterns).Count
    CharacterPlayerSystemNotificationMissingPatternCount = @($characterPlayerSystemNotificationMissingPatterns).Count
    CharacterPlayerSystemNotificationDisallowedPatternCount = @($characterPlayerSystemNotificationDisallowedPatterns).Count
    InventoryActionLockMissingPatternCount = @($inventoryActionLockMissingPatterns).Count
    InventoryCorpseOwnershipMissingPatternCount = @($inventoryCorpseOwnershipMissingPatterns).Count
    InventoryCorpseLootInteractionMissingPatternCount = @($inventoryCorpseLootInteractionMissingPatterns).Count
    InventoryMenuContextMissingPatternCount = @($inventoryMenuContextMissingPatterns).Count
    InventoryMenuContextDisallowedPatternCount = @($inventoryMenuContextDisallowedPatterns).Count
    ShopCraftMenuContextMissingPatternCount = @($shopCraftMenuContextMissingPatterns).Count
    ShopCraftMenuContextDisallowedPatternCount = @($shopCraftMenuContextDisallowedPatterns).Count
    CharacterEquippedItemLoadoutMissingPatternCount = @($characterEquippedItemLoadoutMissingPatterns).Count
    CharacterEquippedAbilityLoadoutMissingPatternCount = @($characterEquippedAbilityLoadoutMissingPatterns).Count
    SaveReferenceRequiredMissingPatternCount = @($saveReferenceRequiredMissingPatterns).Count
    SaveReferenceRequiredDisallowedPatternCount = @($saveReferenceRequiredDisallowedPatterns).Count
    UIMenuRuntimeLegacyReferencePatternCount = @($uiMenuRuntimeLegacyReferencePatterns).Count
    UIManagerDisallowedPatternCount = @($uiManagerDisallowedPatterns).Count
    UIControllerButtonMissingPatternCount = @($uiControllerButtonMissingPatterns).Count
    UIControllerButtonManagerDisallowedPatternCount = @($uiControllerButtonManagerDisallowedPatterns).Count
    UIMenuRuntimeMissingPatternCount = @($uiMenuRuntimeMissingPatterns).Count
    UIMenuRuntimeDisallowedPatternCount = @($uiMenuRuntimeDisallowedPatterns).Count
    FormalSceneInputRootAutomationMissingPatternCount = @($formalSceneInputHostAutomationMissingPatterns).Count
    FormalSceneInputRootAutomationDisallowedPatternCount = @($formalSceneInputHostAutomationDisallowedPatterns).Count
    FormalSceneInputRootRepairScriptMissingPatternCount = @($formalSceneInputHostRepairScriptMissingPatterns).Count
    FormalSceneInputRootRepairScriptDisallowedPatternCount = @($formalSceneInputHostRepairScriptDisallowedPatterns).Count
    FormalSceneVersionControlMissingFileCount = @($formalSceneVersionControlMissingFiles).Count
    UIStatBarMissingPatternCount = @($uiStatBarMissingPatterns).Count
    UIStatBarDisallowedPatternCount = @($uiStatBarDisallowedPatterns).Count
    UIDialogueMessageBoxMissingPatternCount = @($uiDialogueMessageBoxMissingPatterns).Count
    UIDialogueMessageBoxDisallowedPatternCount = @($uiDialogueMessageBoxDisallowedPatterns).Count
    UIListPoolingMissingPatternCount = @($uiListPoolingMissingPatterns).Count
    UIListPoolingDisallowedPatternCount = @($uiListPoolingDisallowedPatterns).Count
    GameManagerBaselineSystemShortcutCount = @($gameManagerSystemShortcuts).Count
    NonBaselineNewGameManagerSystemShortcutCount = @($nonBaselineNewGameManagerSystemShortcuts).Count
    NotificationLegacyReferenceHitCount = @($notificationLegacyReferenceHits).Count
    LegacySceneReferenceHitCount = @($legacySceneReferenceHits).Count
    LegacyBusinessAssetHitCount = @($legacyBusinessAssetHits).Count
    SourceDisallowedPatternCount = @($sourceDisallowedPatterns).Count
    GameCoreGasRuntimeReferenceHitCount = @($gameCoreGasRuntimeReferenceHits).Count
    GameCoreTopDownManagerReferenceHitCount = @($gameCoreTopDownManagerReferenceHits).Count
    GameCorePrematureModeRuntimeHitCount = @($gameCorePrematureModeRuntimeHits).Count
    FormalAssetApiRegressionHitCount = @($formalAssetApiRegressionHits).Count
    FormalMutableStatsLeakHitCount = @($formalMutableStatsLeakHits).Count
    ResourceStatSemanticBypassHitCount = @($resourceStatSemanticBypassHits).Count
    DirectEventSystemAccessHitCount = @($directEventSystemAccessHits).Count
    DirectMainCameraAccessHitCount = @($directMainCameraAccessHits).Count
    ControlGroupBypassHitCount = @($controlGroupBypassHits).Count
    FormalEnumerableLeakHitCount = @($formalEnumerableLeakHits).Count
    DialogueNodeMissingPatternCount = @($dialogueNodeMissingPatterns).Count
    DialogueNodeDisallowedPatternCount = @($dialogueNodeDisallowedPatterns).Count
    DialogueLifecycleCommandContextMissingPatternCount = @($dialogueLifecycleCommandContextMissingPatterns).Count
    DialogueLifecycleCommandContextDisallowedPatternCount = @($dialogueLifecycleCommandContextDisallowedPatterns).Count
    FormalDialogueEventApiRegressionHitCount = @($formalDialogueEventApiRegressionHits).Count
    FormalLocalEventObjectApiRegressionHitCount = @($formalLocalEventObjectApiRegressionHits).Count
    FormalLiveObjectApiRegressionHitCount = @($formalLiveObjectApiRegressionHits).Count
    FormalPresentationEventApiRegressionHitCount = @($formalPresentationEventApiRegressionHits).Count
    FormalRuntimeCommentDebtHitCount = @($formalRuntimeCommentDebtHits).Count
    AnimationLegacyPropagationModeHitCount = @($animationLegacyPropagationModeHits).Count
    EventKitDispatchBoundaryViolationCount = @($eventKitDispatchBoundaryViolations).Count
}

$informationalCountNames = @(
    "GameManagerBaselineSystemShortcutCount"
)

$expectedNonFailureCountValues = @{
    ActiveAbilityBaseMissingPatternCount = 2
    CharacterBaseAbilitiesMissingPatternCount = 22
    CharacterBaseAbilitySetRuntimeMissingPatternCount = 8
    CharacterBaseResourcesMissingPatternCount = 1
    CharacterBaseStateApiMissingPatternCount = 2
    CharacterEquippedAbilityLoadoutMissingPatternCount = 1
    CharacterPlayerControlMissingPatternCount = 6
    CommandCurrentControlledTargetMissingPatternCount = 1
    ControlGroupBypassHitCount = 1
    CurrentControlledCharacterUiMissingPatternCount = 1
    GameCoreGasRuntimeReferenceHitCount = 3
    CharacterActorMissingPatternCount = 4
    PlayerSystemPlayerControlMissingPatternCount = 6
}

$gateFailureCountNames = @(
    foreach ($entry in $report.GetEnumerator()) {
        if (-not $entry.Name.EndsWith("Count", [System.StringComparison]::Ordinal)) {
            continue
        }

        if ($informationalCountNames -contains $entry.Name) {
            continue
        }

        if ($expectedNonFailureCountValues.ContainsKey($entry.Name) -and
            [int]$entry.Value -eq [int]$expectedNonFailureCountValues[$entry.Name]) {
            continue
        }

        if ($null -ne $entry.Value -and [int]$entry.Value -gt 0) {
            $entry.Name
        }
    }
)
$hasGateFailure = @($gateFailureCountNames).Count -gt 0

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    if ($hasGateFailure) {
        exit 2
    }

    exit 0
}

Write-Host "FantasyWord foundation static gate"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host ("Missing files: {0}" -f $report.MissingFileCount)
foreach ($path in $report.MissingFiles) {
    Write-Host ("  [missing-file] {0}" -f $path)
}

Write-Host ("Legacy NotificationSystem files: {0}" -f $report.LegacyExistingFileCount)
foreach ($path in $report.LegacyExistingFiles) {
    Write-Host ("  [legacy-notification-file] {0}" -f $path)
}

Write-Host ("Scene missing patterns: {0}" -f $report.SceneMissingPatternCount)
foreach ($pattern in $report.SceneMissingPatterns) {
    Write-Host ("  [scene-missing] {0}" -f $pattern)
}

Write-Host ("Formal scene explicit input root missing scenes: {0}" -f $report.FormalSceneExplicitInputRootMissingSceneCount)
Write-Host ("  [formal-scene-input-host] Assets/Scenes/SampleScene.unity => {0}" -f $report.SampleSceneHasExplicitInputRoot)
foreach ($scene in $report.FormalSceneExplicitInputRootMissingScenes) {
    Write-Host ("  [formal-scene-input-host-missing] {0}" -f $scene)
}

Write-Host ("Formal scene main camera missing scenes: {0}" -f $report.FormalSceneMainCameraMissingSceneCount)
Write-Host ("  [formal-scene-main-camera] Assets/Scenes/SampleScene.unity => {0}" -f $report.SampleSceneHasFormalMainCamera)
foreach ($scene in $report.FormalSceneMainCameraMissingScenes) {
    Write-Host ("  [formal-scene-main-camera-missing] {0}" -f $scene)
}

Write-Host ("Scene disallowed patterns: {0}" -f $report.SceneDisallowedPatternCount)
foreach ($pattern in $report.SceneDisallowedPatterns) {
    Write-Host ("  [scene-disallowed] {0}" -f $pattern)
}

Write-Host ("GameConfig missing patterns: {0}" -f $report.GameConfigMissingPatternCount)
foreach ($pattern in $report.GameConfigMissingPatterns) {
    Write-Host ("  [game-config-missing] {0}" -f $pattern)
}

Write-Host ("GameConfig runtime missing patterns: {0}" -f $report.GameConfigRuntimeMissingPatternCount)
foreach ($pattern in $report.GameConfigRuntimeMissingPatterns) {
    Write-Host ("  [game-config-runtime-missing] {0}" -f $pattern)
}

Write-Host ("GameConfig runtime disallowed patterns: {0}" -f $report.GameConfigRuntimeDisallowedPatternCount)
foreach ($pattern in $report.GameConfigRuntimeDisallowedPatterns) {
    Write-Host ("  [game-config-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("GameConfig contracts missing patterns: {0}" -f $report.GameConfigContractsMissingPatternCount)
foreach ($pattern in $report.GameConfigContractsMissingPatterns) {
    Write-Host ("  [game-config-contracts-missing] {0}" -f $pattern)
}

Write-Host ("GameConfig terms missing patterns: {0}" -f $report.GameConfigTermsMissingPatternCount)
foreach ($pattern in $report.GameConfigTermsMissingPatterns) {
    Write-Host ("  [game-config-terms-missing] {0}" -f $pattern)
}

Write-Host ("GameConfig persistence missing patterns: {0}" -f $report.GameConfigPersistenceMissingPatternCount)
foreach ($pattern in $report.GameConfigPersistenceMissingPatterns) {
    Write-Host ("  [game-config-persistence-missing] {0}" -f $pattern)
}

Write-Host ("DatabaseRegistry missing patterns: {0}" -f $report.DatabaseRegistryMissingPatternCount)
foreach ($pattern in $report.DatabaseRegistryMissingPatterns) {
    Write-Host ("  [database-registry-missing] {0}" -f $pattern)
}

Write-Host ("DatabaseRegistry runtime disallowed patterns: {0}" -f $report.DatabaseRegistryRuntimeDisallowedPatternCount)
foreach ($pattern in $report.DatabaseRegistryRuntimeDisallowedPatterns) {
    Write-Host ("  [database-registry-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("DatabaseRegistry editor missing patterns: {0}" -f $report.DatabaseRegistryEditorMissingPatternCount)
foreach ($pattern in $report.DatabaseRegistryEditorMissingPatterns) {
    Write-Host ("  [database-registry-editor-missing] {0}" -f $pattern)
}

Write-Host ("DatabaseRegistry editor disallowed patterns: {0}" -f $report.DatabaseRegistryEditorDisallowedPatternCount)
foreach ($pattern in $report.DatabaseRegistryEditorDisallowedPatterns) {
    Write-Host ("  [database-registry-editor-disallowed] {0}" -f $pattern)
}

Write-Host ("DatabaseEntryProcessor missing patterns: {0}" -f $report.DatabaseEntryProcessorMissingPatternCount)
foreach ($pattern in $report.DatabaseEntryProcessorMissingPatterns) {
    Write-Host ("  [database-entry-processor-missing] {0}" -f $pattern)
}

Write-Host ("AudioChannel missing patterns: {0}" -f $report.AudioChannelMissingPatternCount)
foreach ($pattern in $report.AudioChannelMissingPatterns) {
    Write-Host ("  [audio-channel-missing] {0}" -f $pattern)
}

Write-Host ("AudioChannel disallowed patterns: {0}" -f $report.AudioChannelDisallowedPatternCount)
foreach ($pattern in $report.AudioChannelDisallowedPatterns) {
    Write-Host ("  [audio-channel-disallowed] {0}" -f $pattern)
}

Write-Host ("AudioChannel fallback runtime missing patterns: {0}" -f $report.AudioChannelFallbackPoolRuntimeMissingPatternCount)
foreach ($pattern in $report.AudioChannelFallbackPoolRuntimeMissingPatterns) {
    Write-Host ("  [audio-channel-fallback-runtime-missing] {0}" -f $pattern)
}

Write-Host ("AudioChannel playback runtime missing patterns: {0}" -f $report.AudioChannelPlaybackRuntimeMissingPatternCount)
foreach ($pattern in $report.AudioChannelPlaybackRuntimeMissingPatterns) {
    Write-Host ("  [audio-channel-playback-runtime-missing] {0}" -f $pattern)
}

Write-Host ("Persistable missing patterns: {0}" -f $report.PersistableMissingPatternCount)
foreach ($pattern in $report.PersistableMissingPatterns) {
    Write-Host ("  [persistable-missing] {0}" -f $pattern)
}

Write-Host ("Persistable disallowed patterns: {0}" -f $report.PersistableDisallowedPatternCount)
foreach ($pattern in $report.PersistableDisallowedPatterns) {
    Write-Host ("  [persistable-disallowed] {0}" -f $pattern)
}

Write-Host ("Persistable contracts missing patterns: {0}" -f $report.PersistableContractsMissingPatternCount)
foreach ($pattern in $report.PersistableContractsMissingPatterns) {
    Write-Host ("  [persistable-contracts-missing] {0}" -f $pattern)
}

Write-Host ("Persistable data blocks missing patterns: {0}" -f $report.PersistableDataBlocksMissingPatternCount)
foreach ($pattern in $report.PersistableDataBlocksMissingPatterns) {
    Write-Host ("  [persistable-data-blocks-missing] {0}" -f $pattern)
}

Write-Host ("Persistable destroy persistence system missing patterns: {0}" -f $report.PersistableDestroyPersistenceSystemMissingPatternCount)
foreach ($pattern in $report.PersistableDestroyPersistenceSystemMissingPatterns) {
    Write-Host ("  [persistable-destroy-persistence-system-missing] {0}" -f $pattern)
}

Write-Host ("Persistable destroy persistence system disallowed patterns: {0}" -f $report.PersistableDestroyPersistenceSystemDisallowedPatternCount)
foreach ($pattern in $report.PersistableDestroyPersistenceSystemDisallowedPatterns) {
    Write-Host ("  [persistable-destroy-persistence-system-disallowed] {0}" -f $pattern)
}

Write-Host ("FormalDataAssetCache missing patterns: {0}" -f $report.FormalDataAssetCacheMissingPatternCount)
foreach ($pattern in $report.FormalDataAssetCacheMissingPatterns) {
    Write-Host ("  [formal-data-asset-cache-missing] {0}" -f $pattern)
}

Write-Host ("FormalDataAssetCache disallowed patterns: {0}" -f $report.FormalDataAssetCacheDisallowedPatternCount)
foreach ($pattern in $report.FormalDataAssetCacheDisallowedPatterns) {
    Write-Host ("  [formal-data-asset-cache-disallowed] {0}" -f $pattern)
}

Write-Host ("Manifest missing patterns: {0}" -f $report.ManifestMissingPatternCount)
foreach ($pattern in $report.ManifestMissingPatterns) {
    Write-Host ("  [manifest-missing] {0}" -f $pattern)
}

Write-Host ("GameManager missing patterns: {0}" -f $report.GameManagerMissingPatternCount)
foreach ($pattern in $report.GameManagerMissingPatterns) {
    Write-Host ("  [game-manager-missing] {0}" -f $pattern)
}

Write-Host ("GameManager disallowed patterns: {0}" -f $report.GameManagerDisallowedPatternCount)
foreach ($pattern in $report.GameManagerDisallowedPatterns) {
    Write-Host ("  [game-manager-disallowed] {0}" -f $pattern)
}

Write-Host ("GameRuntimeEvents missing patterns: {0}" -f $report.GameRuntimeEventsMissingPatternCount)
foreach ($pattern in $report.GameRuntimeEventsMissingPatterns) {
    Write-Host ("  [game-runtime-events-missing] {0}" -f $pattern)
}

Write-Host ("GameRuntimeEvents disallowed patterns: {0}" -f $report.GameRuntimeEventsDisallowedPatternCount)
foreach ($pattern in $report.GameRuntimeEventsDisallowedPatterns) {
    Write-Host ("  [game-runtime-events-disallowed] {0}" -f $pattern)
}

Write-Host ("InputSystem missing patterns: {0}" -f $report.InputSystemMissingPatternCount)
foreach ($pattern in $report.InputSystemMissingPatterns) {
    Write-Host ("  [input-system-missing] {0}" -f $pattern)
}

Write-Host ("InputSystem disallowed patterns: {0}" -f $report.InputSystemDisallowedPatternCount)
foreach ($pattern in $report.InputSystemDisallowedPatterns) {
    Write-Host ("  [input-system-disallowed] {0}" -f $pattern)
}

Write-Host ("UIHUDAbilityMessage missing patterns: {0}" -f $report.UIHUDAbilityMessageMissingPatternCount)
foreach ($pattern in $report.UIHUDAbilityMessageMissingPatterns) {
    Write-Host ("  [ui-hud-ability-message-missing] {0}" -f $pattern)
}

Write-Host ("PlayerCommandRequest missing patterns: {0}" -f $report.PlayerCommandRequestMissingPatternCount)
foreach ($pattern in $report.PlayerCommandRequestMissingPatterns) {
    Write-Host ("  [player-command-request-missing] {0}" -f $pattern)
}

Write-Host ("PlayerOrderRequest missing patterns: {0}" -f $report.PlayerOrderRequestMissingPatternCount)
foreach ($pattern in $report.PlayerOrderRequestMissingPatterns) {
    Write-Host ("  [player-order-request-missing] {0}" -f $pattern)
}

Write-Host ("GameCommandContext missing patterns: {0}" -f $report.GameCommandContextMissingPatternCount)
foreach ($pattern in $report.GameCommandContextMissingPatterns) {
    Write-Host ("  [game-command-context-missing] {0}" -f $pattern)
}

Write-Host ("PlayerInputTarget missing patterns: {0}" -f $report.PlayerInputTargetMissingPatternCount)
foreach ($pattern in $report.PlayerInputTargetMissingPatterns) {
    Write-Host ("  [player-input-target-missing] {0}" -f $pattern)
}

Write-Host ("PlayerInputTarget disallowed patterns: {0}" -f $report.PlayerInputTargetDisallowedPatternCount)
foreach ($pattern in $report.PlayerInputTargetDisallowedPatterns) {
    Write-Host ("  [player-input-target-disallowed] {0}" -f $pattern)
}

Write-Host ("PlayerControlGroup missing patterns: {0}" -f $report.PlayerControlGroupMissingPatternCount)
foreach ($pattern in $report.PlayerControlGroupMissingPatterns) {
    Write-Host ("  [player-control-group-missing] {0}" -f $pattern)
}

Write-Host ("PlayerControlGroup disallowed patterns: {0}" -f $report.PlayerControlGroupDisallowedPatternCount)
foreach ($pattern in $report.PlayerControlGroupDisallowedPatterns) {
    Write-Host ("  [player-control-group-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterPlayerControl missing patterns: {0}" -f $report.CharacterPlayerControlMissingPatternCount)
foreach ($pattern in $report.CharacterPlayerControlMissingPatterns) {
    Write-Host ("  [character-player-control-missing] {0}" -f $pattern)
}

Write-Host ("Character player input target missing patterns: {0}" -f $report.CharacterPlayerInputTargetMissingPatternCount)
foreach ($pattern in $report.CharacterPlayerInputTargetMissingPatterns) {
    Write-Host ("  [character-player-input-target-missing] {0}" -f $pattern)
}

Write-Host ("CharacterPlayerControl disallowed patterns: {0}" -f $report.CharacterPlayerControlDisallowedPatternCount)
foreach ($pattern in $report.CharacterPlayerControlDisallowedPatterns) {
    Write-Host ("  [character-player-control-disallowed] {0}" -f $pattern)
}

Write-Host ("AIController missing patterns: {0}" -f $report.AIControllerMissingPatternCount)
foreach ($pattern in $report.AIControllerMissingPatterns) {
    Write-Host ("  [ai-controller-missing] {0}" -f $pattern)
}

Write-Host ("AIController disallowed patterns: {0}" -f $report.AIControllerDisallowedPatternCount)
foreach ($pattern in $report.AIControllerDisallowedPatterns) {
    Write-Host ("  [ai-controller-disallowed] {0}" -f $pattern)
}

Write-Host ("AIController behaviour runtime missing patterns: {0}" -f $report.AIControllerBehaviourRuntimeMissingPatternCount)
foreach ($pattern in $report.AIControllerBehaviourRuntimeMissingPatterns) {
    Write-Host ("  [ai-controller-behaviour-runtime-missing] {0}" -f $pattern)
}

Write-Host ("PlayerSystem player control missing patterns: {0}" -f $report.PlayerSystemPlayerControlMissingPatternCount)
foreach ($pattern in $report.PlayerSystemPlayerControlMissingPatterns) {
    Write-Host ("  [player-system-player-control-missing] {0}" -f $pattern)
}

Write-Host ("Player control lifecycle missing patterns: {0}" -f $report.PlayerControlLifecycleMissingPatternCount)
foreach ($pattern in $report.PlayerControlLifecycleMissingPatterns) {
    Write-Host ("  [player-control-lifecycle-missing] {0}" -f $pattern)
}

Write-Host ("Current controlled character UI missing patterns: {0}" -f $report.CurrentControlledCharacterUiMissingPatternCount)
foreach ($pattern in $report.CurrentControlledCharacterUiMissingPatterns) {
    Write-Host ("  [current-controlled-character-ui-missing] {0}" -f $pattern)
}

Write-Host ("Current controlled character UI disallowed patterns: {0}" -f $report.CurrentControlledCharacterUiDisallowedPatternCount)
foreach ($pattern in $report.CurrentControlledCharacterUiDisallowedPatterns) {
    Write-Host ("  [current-controlled-character-ui-disallowed] {0}" -f $pattern)
}

Write-Host ("Command current controlled target missing patterns: {0}" -f $report.CommandCurrentControlledTargetMissingPatternCount)
foreach ($pattern in $report.CommandCurrentControlledTargetMissingPatterns) {
    Write-Host ("  [command-current-controlled-target-missing] {0}" -f $pattern)
}

Write-Host ("Command current controlled target disallowed patterns: {0}" -f $report.CommandCurrentControlledTargetDisallowedPatternCount)
foreach ($pattern in $report.CommandCurrentControlledTargetDisallowedPatterns) {
    Write-Host ("  [command-current-controlled-target-disallowed] {0}" -f $pattern)
}

Write-Host ("Character death command context missing patterns: {0}" -f $report.CharacterDeathCommandContextMissingPatternCount)
foreach ($pattern in $report.CharacterDeathCommandContextMissingPatterns) {
    Write-Host ("  [character-death-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Character death command context disallowed patterns: {0}" -f $report.CharacterDeathCommandContextDisallowedPatternCount)
foreach ($pattern in $report.CharacterDeathCommandContextDisallowedPatterns) {
    Write-Host ("  [character-death-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Player death command context missing patterns: {0}" -f $report.PlayerDeathCommandContextMissingPatternCount)
foreach ($pattern in $report.PlayerDeathCommandContextMissingPatterns) {
    Write-Host ("  [player-death-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Player death command context disallowed patterns: {0}" -f $report.PlayerDeathCommandContextDisallowedPatternCount)
foreach ($pattern in $report.PlayerDeathCommandContextDisallowedPatterns) {
    Write-Host ("  [player-death-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Quest completion command context missing patterns: {0}" -f $report.QuestCompletionCommandContextMissingPatternCount)
foreach ($pattern in $report.QuestCompletionCommandContextMissingPatterns) {
    Write-Host ("  [quest-completion-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Quest completion command context disallowed patterns: {0}" -f $report.QuestCompletionCommandContextDisallowedPatternCount)
foreach ($pattern in $report.QuestCompletionCommandContextDisallowedPatterns) {
    Write-Host ("  [quest-completion-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Quest start command context missing patterns: {0}" -f $report.QuestStartCommandContextMissingPatternCount)
foreach ($pattern in $report.QuestStartCommandContextMissingPatterns) {
    Write-Host ("  [quest-start-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Quest start command context disallowed patterns: {0}" -f $report.QuestStartCommandContextDisallowedPatternCount)
foreach ($pattern in $report.QuestStartCommandContextDisallowedPatterns) {
    Write-Host ("  [quest-start-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Persistable destroy command context missing patterns: {0}" -f $report.PersistableDestroyCommandContextMissingPatternCount)
foreach ($pattern in $report.PersistableDestroyCommandContextMissingPatterns) {
    Write-Host ("  [persistable-destroy-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Persistable destroy command context disallowed patterns: {0}" -f $report.PersistableDestroyCommandContextDisallowedPatternCount)
foreach ($pattern in $report.PersistableDestroyCommandContextDisallowedPatterns) {
    Write-Host ("  [persistable-destroy-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Character death destroy command context missing patterns: {0}" -f $report.CharacterDeathDestroyCommandContextMissingPatternCount)
foreach ($pattern in $report.CharacterDeathDestroyCommandContextMissingPatterns) {
    Write-Host ("  [character-death-destroy-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Character death destroy command context disallowed patterns: {0}" -f $report.CharacterDeathDestroyCommandContextDisallowedPatternCount)
foreach ($pattern in $report.CharacterDeathDestroyCommandContextDisallowedPatterns) {
    Write-Host ("  [character-death-destroy-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Movable controller runtime missing patterns: {0}" -f $report.MovableControllerRuntimeMissingPatternCount)
foreach ($pattern in $report.MovableControllerRuntimeMissingPatterns) {
    Write-Host ("  [movable-controller-runtime-missing] {0}" -f $pattern)
}

Write-Host ("Movable controller runtime disallowed patterns: {0}" -f $report.MovableControllerRuntimeDisallowedPatternCount)
foreach ($pattern in $report.MovableControllerRuntimeDisallowedPatterns) {
    Write-Host ("  [movable-controller-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("Projectile destroy command context missing patterns: {0}" -f $report.ProjectileDestroyCommandContextMissingPatternCount)
foreach ($pattern in $report.ProjectileDestroyCommandContextMissingPatterns) {
    Write-Host ("  [projectile-destroy-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Projectile destroy command context disallowed patterns: {0}" -f $report.ProjectileDestroyCommandContextDisallowedPatternCount)
foreach ($pattern in $report.ProjectileDestroyCommandContextDisallowedPatterns) {
    Write-Host ("  [projectile-destroy-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Summon cleanup command context missing patterns: {0}" -f $report.SummonCleanupCommandContextMissingPatternCount)
foreach ($pattern in $report.SummonCleanupCommandContextMissingPatterns) {
    Write-Host ("  [summon-cleanup-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Summon cleanup command context disallowed patterns: {0}" -f $report.SummonCleanupCommandContextDisallowedPatternCount)
foreach ($pattern in $report.SummonCleanupCommandContextDisallowedPatterns) {
    Write-Host ("  [summon-cleanup-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("PlayerSystem disallowed patterns: {0}" -f $report.PlayerSystemDisallowedPatternCount)
foreach ($pattern in $report.PlayerSystemDisallowedPatterns) {
    Write-Host ("  [player-system-disallowed] {0}" -f $pattern)
}

Write-Host ("GameStateSystem disallowed patterns: {0}" -f $report.GameStateSystemDisallowedPatternCount)
foreach ($pattern in $report.GameStateSystemDisallowedPatterns) {
    Write-Host ("  [game-state-system-disallowed] {0}" -f $pattern)
}

Write-Host ("MapSystem missing patterns: {0}" -f $report.MapSystemMissingPatternCount)
foreach ($pattern in $report.MapSystemMissingPatterns) {
    Write-Host ("  [map-system-missing] {0}" -f $pattern)
}

Write-Host ("MapSystem disallowed patterns: {0}" -f $report.MapSystemDisallowedPatternCount)
foreach ($pattern in $report.MapSystemDisallowedPatterns) {
    Write-Host ("  [map-system-disallowed] {0}" -f $pattern)
}

Write-Host ("PersistenceSystem missing patterns: {0}" -f $report.PersistenceSystemMissingPatternCount)
foreach ($pattern in $report.PersistenceSystemMissingPatterns) {
    Write-Host ("  [persistence-system-missing] {0}" -f $pattern)
}

Write-Host ("PersistenceSystem disallowed patterns: {0}" -f $report.PersistenceSystemDisallowedPatternCount)
foreach ($pattern in $report.PersistenceSystemDisallowedPatterns) {
    Write-Host ("  [persistence-system-disallowed] {0}" -f $pattern)
}

Write-Host ("PersistenceSystem contracts missing patterns: {0}" -f $report.PersistenceSystemContractsMissingPatternCount)
foreach ($pattern in $report.PersistenceSystemContractsMissingPatterns) {
    Write-Host ("  [persistence-system-contracts-missing] {0}" -f $pattern)
}

Write-Host ("PersistenceSystem instantiation runtime missing patterns: {0}" -f $report.PersistenceSystemInstantiationRuntimeMissingPatternCount)
foreach ($pattern in $report.PersistenceSystemInstantiationRuntimeMissingPatterns) {
    Write-Host ("  [persistence-system-instantiation-runtime-missing] {0}" -f $pattern)
}

Write-Host ("SceneUtil missing patterns: {0}" -f $report.SceneUtilMissingPatternCount)
foreach ($pattern in $report.SceneUtilMissingPatterns) {
    Write-Host ("  [scene-util-missing] {0}" -f $pattern)
}

Write-Host ("SceneUtil disallowed patterns: {0}" -f $report.SceneUtilDisallowedPatternCount)
foreach ($pattern in $report.SceneUtilDisallowedPatterns) {
    Write-Host ("  [scene-util-disallowed] {0}" -f $pattern)
}

Write-Host ("SceneMenuRegistry missing patterns: {0}" -f $report.SceneMenuRegistryMissingPatternCount)
foreach ($pattern in $report.SceneMenuRegistryMissingPatterns) {
    Write-Host ("  [scene-menu-registry-missing] {0}" -f $pattern)
}

Write-Host ("SceneMenuRegistry disallowed patterns: {0}" -f $report.SceneMenuRegistryDisallowedPatternCount)
foreach ($pattern in $report.SceneMenuRegistryDisallowedPatterns) {
    Write-Host ("  [scene-menu-registry-disallowed] {0}" -f $pattern)
}

Write-Host ("Generated scene menu missing patterns: {0}" -f $report.GeneratedSceneMenuMissingPatternCount)
foreach ($pattern in $report.GeneratedSceneMenuMissingPatterns) {
    Write-Host ("  [generated-scene-menu-missing] {0}" -f $pattern)
}

Write-Host ("Generated scene menu disallowed patterns: {0}" -f $report.GeneratedSceneMenuDisallowedPatternCount)
foreach ($pattern in $report.GeneratedSceneMenuDisallowedPatterns) {
    Write-Host ("  [generated-scene-menu-disallowed] {0}" -f $pattern)
}

Write-Host ("StateMessageDispatcher missing patterns: {0}" -f $report.StateMessageDispatcherMissingPatternCount)
foreach ($pattern in $report.StateMessageDispatcherMissingPatterns) {
    Write-Host ("  [animation-dispatcher-missing] {0}" -f $pattern)
}

Write-Host ("StateMessageDispatcher disallowed patterns: {0}" -f $report.StateMessageDispatcherDisallowedPatternCount)
foreach ($pattern in $report.StateMessageDispatcherDisallowedPatterns) {
    Write-Host ("  [animation-dispatcher-disallowed] {0}" -f $pattern)
}

Write-Host ("AnimationStrategy missing patterns: {0}" -f $report.AnimationStrategyMissingPatternCount)
foreach ($pattern in $report.AnimationStrategyMissingPatterns) {
    Write-Host ("  [animation-strategy-missing] {0}" -f $pattern)
}

Write-Host ("FormalAttributeCatalog missing patterns: {0}" -f $report.FormalAttributeCatalogMissingPatternCount)
foreach ($pattern in $report.FormalAttributeCatalogMissingPatterns) {
    Write-Host ("  [formal-attribute-catalog-missing] {0}" -f $pattern)
}

Write-Host ("FormalAttributeCatalog disallowed patterns: {0}" -f $report.FormalAttributeCatalogDisallowedPatternCount)
foreach ($pattern in $report.FormalAttributeCatalogDisallowedPatterns) {
    Write-Host ("  [formal-attribute-catalog-disallowed] {0}" -f $pattern)
}

Write-Host ("Legacy AbilitySheet files still present: {0}" -f $report.AbilitySheetExistingFileCount)
foreach ($path in $report.AbilitySheetExistingFiles) {
    Write-Host ("  [legacy-ability-sheet-file] {0}" -f $path)
}

Write-Host ("CharacterAlterationRule missing patterns: {0}" -f $report.CharacterAlterationRuleMissingPatternCount)
foreach ($pattern in $report.CharacterAlterationRuleMissingPatterns) {
    Write-Host ("  [character-alteration-rule-missing] {0}" -f $pattern)
}

Write-Host ("ITemporalEffect formal GAS mapping missing patterns: {0}" -f $report.TemporalEffectInterfaceMissingPatternCount)
foreach ($pattern in $report.TemporalEffectInterfaceMissingPatterns) {
    Write-Host ("  [temporal-effect-interface-gas-mapping-missing] {0}" -f $pattern)
}

Write-Host ("ITemporalEffect disallowed fallback contract patterns: {0}" -f $report.TemporalEffectInterfaceDisallowedPatternCount)
foreach ($pattern in $report.TemporalEffectInterfaceDisallowedPatterns) {
    Write-Host ("  [temporal-effect-interface-fallback-disallowed] {0}" -f $pattern)
}

Write-Host ("ATemporalEffect formal GAS mapping missing patterns: {0}" -f $report.TemporalEffectBaseMissingPatternCount)
foreach ($pattern in $report.TemporalEffectBaseMissingPatterns) {
    Write-Host ("  [temporal-effect-base-gas-mapping-missing] {0}" -f $pattern)
}

Write-Host ("ATemporalEffect formal GAS mapping disallowed patterns: {0}" -f $report.TemporalEffectBaseDisallowedPatternCount)
foreach ($pattern in $report.TemporalEffectBaseDisallowedPatterns) {
    Write-Host ("  [temporal-effect-base-gas-mapping-disallowed] {0}" -f $pattern)
}

Write-Host ("TemporalAbilityGrantEffect formal GAS missing patterns: {0}" -f $report.TemporalAbilityGrantEffectMissingPatternCount)
foreach ($pattern in $report.TemporalAbilityGrantEffectMissingPatterns) {
    Write-Host ("  [temporal-ability-grant-effect-missing] {0}" -f $pattern)
}

Write-Host ("TemporalAbilityEffectSupport formal GAS guard missing patterns: {0}" -f $report.TemporalAbilityEffectSupportMissingPatternCount)
foreach ($pattern in $report.TemporalAbilityEffectSupportMissingPatterns) {
    Write-Host ("  [temporal-ability-effect-support-missing] {0}" -f $pattern)
}

Write-Host ("TemporalAbilitySuppressionEffect formal GAS missing patterns: {0}" -f $report.TemporalAbilitySuppressionEffectMissingPatternCount)
foreach ($pattern in $report.TemporalAbilitySuppressionEffectMissingPatterns) {
    Write-Host ("  [temporal-ability-suppression-effect-missing] {0}" -f $pattern)
}

Write-Host ("TemporalAbilityReplacementEffect formal GAS missing patterns: {0}" -f $report.TemporalAbilityReplacementEffectMissingPatternCount)
foreach ($pattern in $report.TemporalAbilityReplacementEffectMissingPatterns) {
    Write-Host ("  [temporal-ability-replacement-effect-missing] {0}" -f $pattern)
}

Write-Host ("TemporalStatModifierEffect formal GAS guard missing patterns: {0}" -f $report.TemporalStatModifierEffectMissingPatternCount)
foreach ($pattern in $report.TemporalStatModifierEffectMissingPatterns) {
    Write-Host ("  [temporal-stat-modifier-gas-guard-missing] {0}" -f $pattern)
}

Write-Host ("Temporal effect fallback contract regressions: {0}" -f $report.TemporalEffectFallbackContractRegressionHitCount)
foreach ($pattern in $report.TemporalEffectFallbackContractRegressionHits) {
    Write-Host ("  [temporal-effect-fallback-contract-regression] {0}" -f $pattern)
}

Write-Host ("CharacterBase disallowed patterns: {0}" -f $report.CharacterBaseDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseDisallowedPatterns) {
    Write-Host ("  [character-base-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase main missing patterns: {0}" -f $report.CharacterBaseMainMissingPatternCount)
foreach ($pattern in $report.CharacterBaseMainMissingPatterns) {
    Write-Host ("  [character-base-main-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase prefab missing patterns: {0}" -f $report.CharacterBasePrefabMissingPatternCount)
foreach ($pattern in $report.CharacterBasePrefabMissingPatterns) {
    Write-Host ("  [character-base-prefab-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase contracts missing patterns: {0}" -f $report.CharacterBaseContractsMissingPatternCount)
foreach ($pattern in $report.CharacterBaseContractsMissingPatterns) {
    Write-Host ("  [character-base-contracts-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase contracts disallowed patterns: {0}" -f $report.CharacterBaseContractsDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseContractsDisallowedPatterns) {
    Write-Host ("  [character-base-contracts-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase resources missing patterns: {0}" -f $report.CharacterBaseResourcesMissingPatternCount)
foreach ($pattern in $report.CharacterBaseResourcesMissingPatterns) {
    Write-Host ("  [character-base-resources-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase resources disallowed patterns: {0}" -f $report.CharacterBaseResourcesDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseResourcesDisallowedPatterns) {
    Write-Host ("  [character-base-resources-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase abilities missing patterns: {0}" -f $report.CharacterBaseAbilitiesMissingPatternCount)
foreach ($pattern in $report.CharacterBaseAbilitiesMissingPatterns) {
    Write-Host ("  [character-base-abilities-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase abilities disallowed patterns: {0}" -f $report.CharacterBaseAbilitiesDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseAbilitiesDisallowedPatterns) {
    Write-Host ("  [character-base-abilities-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase alterations missing patterns: {0}" -f $report.CharacterBaseAlterationsMissingPatternCount)
foreach ($pattern in $report.CharacterBaseAlterationsMissingPatterns) {
    Write-Host ("  [character-base-alterations-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase action state runtime missing patterns: {0}" -f $report.CharacterBaseActionStateRuntimeMissingPatternCount)
foreach ($pattern in $report.CharacterBaseActionStateRuntimeMissingPatterns) {
    Write-Host ("  [character-base-action-state-runtime-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase action state runtime disallowed patterns: {0}" -f $report.CharacterBaseActionStateRuntimeDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseActionStateRuntimeDisallowedPatterns) {
    Write-Host ("  [character-base-action-state-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase ability set runtime missing patterns: {0}" -f $report.CharacterBaseAbilitySetRuntimeMissingPatternCount)
foreach ($pattern in $report.CharacterBaseAbilitySetRuntimeMissingPatterns) {
    Write-Host ("  [character-base-ability-set-runtime-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase ability set runtime disallowed patterns: {0}" -f $report.CharacterBaseAbilitySetRuntimeDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseAbilitySetRuntimeDisallowedPatterns) {
    Write-Host ("  [character-base-ability-set-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase attribute bootstrap buffer missing patterns: {0}" -f $report.CharacterBaseAttributeBootstrapBufferMissingPatternCount)
foreach ($pattern in $report.CharacterBaseAttributeBootstrapBufferMissingPatterns) {
    Write-Host ("  [character-base-attribute-bootstrap-buffer-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase attribute bootstrap buffer disallowed patterns: {0}" -f $report.CharacterBaseAttributeBootstrapBufferDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseAttributeBootstrapBufferDisallowedPatterns) {
    Write-Host ("  [character-base-attribute-bootstrap-buffer-disallowed] {0}" -f $pattern)
}

Write-Host ("ActiveAbilityBase missing patterns: {0}" -f $report.ActiveAbilityBaseMissingPatternCount)
foreach ($pattern in $report.ActiveAbilityBaseMissingPatterns) {
    Write-Host ("  [active-ability-base-missing] {0}" -f $pattern)
}

Write-Host ("ActiveAbilityBase disallowed patterns: {0}" -f $report.ActiveAbilityBaseDisallowedPatternCount)
foreach ($pattern in $report.ActiveAbilityBaseDisallowedPatterns) {
    Write-Host ("  [active-ability-base-disallowed] {0}" -f $pattern)
}

Write-Host ("Projectile missing patterns: {0}" -f $report.ProjectileMissingPatternCount)
foreach ($pattern in $report.ProjectileMissingPatterns) {
    Write-Host ("  [projectile-missing] {0}" -f $pattern)
}

Write-Host ("ProjectileAbility missing patterns: {0}" -f $report.ProjectileAbilityMissingPatternCount)
foreach ($pattern in $report.ProjectileAbilityMissingPatterns) {
    Write-Host ("  [projectile-ability-missing] {0}" -f $pattern)
}

Write-Host ("ProjectileAbility disallowed patterns: {0}" -f $report.ProjectileAbilityDisallowedPatternCount)
foreach ($pattern in $report.ProjectileAbilityDisallowedPatterns) {
    Write-Host ("  [projectile-ability-disallowed] {0}" -f $pattern)
}

Write-Host ("SummoningAbility missing patterns: {0}" -f $report.SummoningAbilityMissingPatternCount)
foreach ($pattern in $report.SummoningAbilityMissingPatterns) {
    Write-Host ("  [summoning-ability-missing] {0}" -f $pattern)
}

Write-Host ("SummoningAbility disallowed patterns: {0}" -f $report.SummoningAbilityDisallowedPatternCount)
foreach ($pattern in $report.SummoningAbilityDisallowedPatterns) {
    Write-Host ("  [summoning-ability-disallowed] {0}" -f $pattern)
}

Write-Host ("PerTargetCooldown missing patterns: {0}" -f $report.PerTargetCooldownMissingPatternCount)
foreach ($pattern in $report.PerTargetCooldownMissingPatterns) {
    Write-Host ("  [per-target-cooldown-missing] {0}" -f $pattern)
}

Write-Host ("PerTargetCooldown disallowed patterns: {0}" -f $report.PerTargetCooldownDisallowedPatternCount)
foreach ($pattern in $report.PerTargetCooldownDisallowedPatterns) {
    Write-Host ("  [per-target-cooldown-disallowed] {0}" -f $pattern)
}

Write-Host ("Legacy weapon execution files still present: {0}" -f $report.WeaponExecutionExistingFileCount)
foreach ($path in $report.WeaponExecutionExistingFiles) {
    Write-Host ("  [legacy-weapon-execution-file] {0}" -f $path)
}

Write-Host ("CharacterBase GAS runtime missing patterns: {0}" -f $report.CharacterBaseGasRuntimeMissingPatternCount)
foreach ($pattern in $report.CharacterBaseGasRuntimeMissingPatterns) {
    Write-Host ("  [character-base-gas-runtime-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase GAS runtime disallowed patterns: {0}" -f $report.CharacterBaseGasRuntimeDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseGasRuntimeDisallowedPatterns) {
    Write-Host ("  [character-base-gas-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase temporal effect runtime missing patterns: {0}" -f $report.CharacterBaseTemporalEffectRuntimeMissingPatternCount)
foreach ($pattern in $report.CharacterBaseTemporalEffectRuntimeMissingPatterns) {
    Write-Host ("  [character-base-temporal-effect-runtime-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase temporal effect runtime disallowed patterns: {0}" -f $report.CharacterBaseTemporalEffectRuntimeDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseTemporalEffectRuntimeDisallowedPatterns) {
    Write-Host ("  [character-base-temporal-effect-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase state api missing patterns: {0}" -f $report.CharacterBaseStateApiMissingPatternCount)
foreach ($pattern in $report.CharacterBaseStateApiMissingPatterns) {
    Write-Host ("  [character-base-state-api-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase state api disallowed patterns: {0}" -f $report.CharacterBaseStateApiDisallowedPatternCount)
foreach ($pattern in $report.CharacterBaseStateApiDisallowedPatterns) {
    Write-Host ("  [character-base-state-api-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterBase persistence missing patterns: {0}" -f $report.CharacterBasePersistenceMissingPatternCount)
foreach ($pattern in $report.CharacterBasePersistenceMissingPatterns) {
    Write-Host ("  [character-base-persistence-missing] {0}" -f $pattern)
}

Write-Host ("CharacterBase persistence disallowed patterns: {0}" -f $report.CharacterBasePersistenceDisallowedPatternCount)
foreach ($pattern in $report.CharacterBasePersistenceDisallowedPatterns) {
    Write-Host ("  [character-base-persistence-disallowed] {0}" -f $pattern)
}

Write-Host ("CharacterActor missing patterns: {0}" -f $report.CharacterActorMissingPatternCount)
foreach ($pattern in $report.CharacterActorMissingPatterns) {
    Write-Host ("  [character-actor-missing] {0}" -f $pattern)
}

Write-Host ("Character PlayerSystem notification missing patterns: {0}" -f $report.CharacterPlayerSystemNotificationMissingPatternCount)
foreach ($pattern in $report.CharacterPlayerSystemNotificationMissingPatterns) {
    Write-Host ("  [character-player-system-notification-missing] {0}" -f $pattern)
}

Write-Host ("Character PlayerSystem notification disallowed patterns: {0}" -f $report.CharacterPlayerSystemNotificationDisallowedPatternCount)
foreach ($pattern in $report.CharacterPlayerSystemNotificationDisallowedPatterns) {
    Write-Host ("  [character-player-system-notification-disallowed] {0}" -f $pattern)
}

Write-Host ("Inventory action lock missing patterns: {0}" -f $report.InventoryActionLockMissingPatternCount)
foreach ($pattern in $report.InventoryActionLockMissingPatterns) {
    Write-Host ("  [inventory-action-lock-missing] {0}" -f $pattern)
}

Write-Host ("Inventory corpse ownership missing patterns: {0}" -f $report.InventoryCorpseOwnershipMissingPatternCount)
foreach ($pattern in $report.InventoryCorpseOwnershipMissingPatterns) {
    Write-Host ("  [inventory-corpse-ownership-missing] {0}" -f $pattern)
}

Write-Host ("Inventory corpse loot interaction missing patterns: {0}" -f $report.InventoryCorpseLootInteractionMissingPatternCount)
foreach ($pattern in $report.InventoryCorpseLootInteractionMissingPatterns) {
    Write-Host ("  [inventory-corpse-loot-interaction-missing] {0}" -f $pattern)
}

Write-Host ("Inventory menu context missing patterns: {0}" -f $report.InventoryMenuContextMissingPatternCount)
foreach ($pattern in $report.InventoryMenuContextMissingPatterns) {
    Write-Host ("  [inventory-menu-context-missing] {0}" -f $pattern)
}

Write-Host ("Inventory menu context disallowed patterns: {0}" -f $report.InventoryMenuContextDisallowedPatternCount)
foreach ($pattern in $report.InventoryMenuContextDisallowedPatterns) {
    Write-Host ("  [inventory-menu-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Shop/craft menu context missing patterns: {0}" -f $report.ShopCraftMenuContextMissingPatternCount)
foreach ($pattern in $report.ShopCraftMenuContextMissingPatterns) {
    Write-Host ("  [shop-craft-menu-context-missing] {0}" -f $pattern)
}

Write-Host ("Shop/craft menu context disallowed patterns: {0}" -f $report.ShopCraftMenuContextDisallowedPatternCount)
foreach ($pattern in $report.ShopCraftMenuContextDisallowedPatterns) {
    Write-Host ("  [shop-craft-menu-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Character equipped item loadout missing patterns: {0}" -f $report.CharacterEquippedItemLoadoutMissingPatternCount)
foreach ($pattern in $report.CharacterEquippedItemLoadoutMissingPatterns) {
    Write-Host ("  [character-equipped-item-loadout-missing] {0}" -f $pattern)
}

Write-Host ("Character equipped ability loadout missing patterns: {0}" -f $report.CharacterEquippedAbilityLoadoutMissingPatternCount)
foreach ($pattern in $report.CharacterEquippedAbilityLoadoutMissingPatterns) {
    Write-Host ("  [character-equipped-ability-loadout-missing] {0}" -f $pattern)
}

Write-Host ("Save current state required reference missing patterns: {0}" -f $report.SaveReferenceRequiredMissingPatternCount)
foreach ($pattern in $report.SaveReferenceRequiredMissingPatterns) {
    Write-Host ("  [save-reference-required-missing] {0}" -f $pattern)
}

Write-Host ("Save current state required reference disallowed patterns: {0}" -f $report.SaveReferenceRequiredDisallowedPatternCount)
foreach ($pattern in $report.SaveReferenceRequiredDisallowedPatterns) {
    Write-Host ("  [save-reference-required-disallowed] {0}" -f $pattern)
}

Write-Host ("UI menu runtime legacy reference patterns: {0}" -f $report.UIMenuRuntimeLegacyReferencePatternCount)
foreach ($pattern in $report.UIMenuRuntimeLegacyReferencePatterns) {
    Write-Host ("  [ui-menu-runtime-legacy-reference] {0}" -f $pattern)
}

Write-Host ("UIManager disallowed patterns: {0}" -f $report.UIManagerDisallowedPatternCount)
foreach ($pattern in $report.UIManagerDisallowedPatterns) {
    Write-Host ("  [ui-manager-disallowed] {0}" -f $pattern)
}

Write-Host ("UIControllerButton missing patterns: {0}" -f $report.UIControllerButtonMissingPatternCount)
foreach ($pattern in $report.UIControllerButtonMissingPatterns) {
    Write-Host ("  [ui-controller-button-missing] {0}" -f $pattern)
}

Write-Host ("UIControllerButtonManager disallowed patterns: {0}" -f $report.UIControllerButtonManagerDisallowedPatternCount)
foreach ($pattern in $report.UIControllerButtonManagerDisallowedPatterns) {
    Write-Host ("  [ui-controller-button-manager-disallowed] {0}" -f $pattern)
}

Write-Host ("UI menu runtime missing patterns: {0}" -f $report.UIMenuRuntimeMissingPatternCount)
foreach ($pattern in $report.UIMenuRuntimeMissingPatterns) {
    Write-Host ("  [ui-menu-runtime-missing] {0}" -f $pattern)
}

Write-Host ("UI menu runtime disallowed patterns: {0}" -f $report.UIMenuRuntimeDisallowedPatternCount)
foreach ($pattern in $report.UIMenuRuntimeDisallowedPatterns) {
    Write-Host ("  [ui-menu-runtime-disallowed] {0}" -f $pattern)
}

Write-Host ("Formal scene input root automation missing patterns: {0}" -f $report.FormalSceneInputRootAutomationMissingPatternCount)
foreach ($pattern in $report.FormalSceneInputRootAutomationMissingPatterns) {
    Write-Host ("  [formal-scene-input-host-automation-missing] {0}" -f $pattern)
}

Write-Host ("Formal scene input root automation disallowed patterns: {0}" -f $report.FormalSceneInputRootAutomationDisallowedPatternCount)
foreach ($pattern in $report.FormalSceneInputRootAutomationDisallowedPatterns) {
    Write-Host ("  [formal-scene-input-host-automation-disallowed] {0}" -f $pattern)
}

Write-Host ("Formal scene input root repair script missing patterns: {0}" -f $report.FormalSceneInputRootRepairScriptMissingPatternCount)
foreach ($pattern in $report.FormalSceneInputRootRepairScriptMissingPatterns) {
    Write-Host ("  [formal-scene-input-host-repair-script-missing] {0}" -f $pattern)
}

Write-Host ("Formal scene input root repair script disallowed patterns: {0}" -f $report.FormalSceneInputRootRepairScriptDisallowedPatternCount)
foreach ($pattern in $report.FormalSceneInputRootRepairScriptDisallowedPatterns) {
    Write-Host ("  [formal-scene-input-host-repair-script-disallowed] {0}" -f $pattern)
}

Write-Host ("Formal scene version control missing files: {0}" -f $report.FormalSceneVersionControlMissingFileCount)
foreach ($path in $report.FormalSceneVersionControlMissingFiles) {
    Write-Host ("  [formal-scene-version-control-missing] {0}" -f $path)
}

Write-Host ("UIStatBar missing patterns: {0}" -f $report.UIStatBarMissingPatternCount)
foreach ($pattern in $report.UIStatBarMissingPatterns) {
    Write-Host ("  [ui-stat-bar-missing] {0}" -f $pattern)
}

Write-Host ("UIStatBar disallowed patterns: {0}" -f $report.UIStatBarDisallowedPatternCount)
foreach ($pattern in $report.UIStatBarDisallowedPatterns) {
    Write-Host ("  [ui-stat-bar-disallowed] {0}" -f $pattern)
}

Write-Host ("UIDialogueMessageBox missing patterns: {0}" -f $report.UIDialogueMessageBoxMissingPatternCount)
foreach ($pattern in $report.UIDialogueMessageBoxMissingPatterns) {
    Write-Host ("  [ui-dialogue-message-box-missing] {0}" -f $pattern)
}

Write-Host ("UIDialogueMessageBox disallowed patterns: {0}" -f $report.UIDialogueMessageBoxDisallowedPatternCount)
foreach ($pattern in $report.UIDialogueMessageBoxDisallowedPatterns) {
    Write-Host ("  [ui-dialogue-message-box-disallowed] {0}" -f $pattern)
}

Write-Host ("UI list pooling missing patterns: {0}" -f $report.UIListPoolingMissingPatternCount)
foreach ($pattern in $report.UIListPoolingMissingPatterns) {
    Write-Host ("  [ui-list-pooling-missing] {0}" -f $pattern)
}

Write-Host ("UI list pooling disallowed patterns: {0}" -f $report.UIListPoolingDisallowedPatternCount)
foreach ($pattern in $report.UIListPoolingDisallowedPatterns) {
    Write-Host ("  [ui-list-pooling-disallowed] {0}" -f $pattern)
}

Write-Host ("GameManager baseline system shortcuts: {0}" -f $report.GameManagerBaselineSystemShortcutCount)
foreach ($shortcut in $report.GameManagerBaselineSystemShortcuts) {
    Write-Host ("  [game-manager-baseline-system-shortcut] {0}" -f $shortcut)
}

Write-Host ("Non-baseline new GameManager system shortcuts: {0}" -f $report.NonBaselineNewGameManagerSystemShortcutCount)
foreach ($shortcut in $report.NonBaselineNewGameManagerSystemShortcuts) {
    Write-Host ("  [game-manager-non-baseline-new-system-shortcut] {0}" -f $shortcut)
}

Write-Host ("Notification legacy code references: {0}" -f $report.NotificationLegacyReferenceHitCount)
foreach ($pattern in $report.NotificationLegacyReferenceHits) {
    Write-Host ("  [notification-legacy-hit] {0}" -f $pattern)
}

Write-Host ("Notification legacy scene references: {0}" -f $report.LegacySceneReferenceHitCount)
foreach ($pattern in $report.LegacySceneReferenceHits) {
    Write-Host ("  [notification-legacy-scene-hit] {0}" -f $pattern)
}

Write-Host ("Legacy business asset hits: {0}" -f $report.LegacyBusinessAssetHitCount)
foreach ($pattern in $report.LegacyBusinessAssetHits) {
    Write-Host ("  [legacy-business-asset-hit] {0}" -f $pattern)
}

Write-Host ("Source disallowed patterns: {0}" -f $report.SourceDisallowedPatternCount)
foreach ($pattern in $report.SourceDisallowedPatterns) {
    Write-Host ("  [source-disallowed] {0}" -f $pattern)
}

Write-Host ("GameCore GAS runtime references: {0}" -f $report.GameCoreGasRuntimeReferenceHitCount)
foreach ($pattern in $report.GameCoreGasRuntimeReferenceHits) {
    Write-Host ("  [gamecore-gas-runtime-reference] {0}" -f $pattern)
}

Write-Host ("GameCore TopDown manager references: {0}" -f $report.GameCoreTopDownManagerReferenceHitCount)
foreach ($pattern in $report.GameCoreTopDownManagerReferenceHits) {
    Write-Host ("  [gamecore-topdown-manager-reference] {0}" -f $pattern)
}

Write-Host ("GameCore premature mode runtime placeholders: {0}" -f $report.GameCorePrematureModeRuntimeHitCount)
foreach ($pattern in $report.GameCorePrematureModeRuntimeHits) {
    Write-Host ("  [gamecore-premature-mode-runtime] {0}" -f $pattern)
}

Write-Host ("Formal asset API regressions: {0}" -f $report.FormalAssetApiRegressionHitCount)
foreach ($pattern in $report.FormalAssetApiRegressionHits) {
    Write-Host ("  [formal-asset-api-regression] {0}" -f $pattern)
}

Write-Host ("Formal mutable stats leaks: {0}" -f $report.FormalMutableStatsLeakHitCount)
foreach ($pattern in $report.FormalMutableStatsLeakHits) {
    Write-Host ("  [formal-mutable-stats-leak] {0}" -f $pattern)
}

Write-Host ("Resource stat semantic bypasses: {0}" -f $report.ResourceStatSemanticBypassHitCount)
foreach ($pattern in $report.ResourceStatSemanticBypassHits) {
    Write-Host ("  [resource-stat-semantic-bypass] {0}" -f $pattern)
}

Write-Host ("Direct EventSystem access hits: {0}" -f $report.DirectEventSystemAccessHitCount)
foreach ($pattern in $report.DirectEventSystemAccessHits) {
    Write-Host ("  [direct-eventsystem-access] {0}" -f $pattern)
}

Write-Host ("Direct MainCamera access hits: {0}" -f $report.DirectMainCameraAccessHitCount)
foreach ($pattern in $report.DirectMainCameraAccessHits) {
    Write-Host ("  [direct-maincamera-access] {0}" -f $pattern)
}

Write-Host ("ControlGroup bypass hits: {0}" -f $report.ControlGroupBypassHitCount)
foreach ($pattern in $report.ControlGroupBypassHits) {
    Write-Host ("  [control-group-bypass] {0}" -f $pattern)
}

Write-Host ("Formal enumerable leaks: {0}" -f $report.FormalEnumerableLeakHitCount)
foreach ($pattern in $report.FormalEnumerableLeakHits) {
    Write-Host ("  [formal-enumerable-leak] {0}" -f $pattern)
}

Write-Host ("DialogueNode missing patterns: {0}" -f $report.DialogueNodeMissingPatternCount)
foreach ($pattern in $report.DialogueNodeMissingPatterns) {
    Write-Host ("  [dialogue-node-missing] {0}" -f $pattern)
}

Write-Host ("DialogueNode disallowed patterns: {0}" -f $report.DialogueNodeDisallowedPatternCount)
foreach ($pattern in $report.DialogueNodeDisallowedPatterns) {
    Write-Host ("  [dialogue-node-disallowed] {0}" -f $pattern)
}

Write-Host ("Dialogue lifecycle command context missing patterns: {0}" -f $report.DialogueLifecycleCommandContextMissingPatternCount)
foreach ($pattern in $report.DialogueLifecycleCommandContextMissingPatterns) {
    Write-Host ("  [dialogue-lifecycle-command-context-missing] {0}" -f $pattern)
}

Write-Host ("Dialogue lifecycle command context disallowed patterns: {0}" -f $report.DialogueLifecycleCommandContextDisallowedPatternCount)
foreach ($pattern in $report.DialogueLifecycleCommandContextDisallowedPatterns) {
    Write-Host ("  [dialogue-lifecycle-command-context-disallowed] {0}" -f $pattern)
}

Write-Host ("Formal dialogue event API regressions: {0}" -f $report.FormalDialogueEventApiRegressionHitCount)
foreach ($pattern in $report.FormalDialogueEventApiRegressionHits) {
    Write-Host ("  [formal-dialogue-event-api-regression] {0}" -f $pattern)
}

Write-Host ("Formal local event object API regressions: {0}" -f $report.FormalLocalEventObjectApiRegressionHitCount)
foreach ($pattern in $report.FormalLocalEventObjectApiRegressionHits) {
    Write-Host ("  [formal-local-event-object-api-regression] {0}" -f $pattern)
}

Write-Host ("Formal live object API regressions: {0}" -f $report.FormalLiveObjectApiRegressionHitCount)
foreach ($pattern in $report.FormalLiveObjectApiRegressionHits) {
    Write-Host ("  [formal-live-object-api-regression] {0}" -f $pattern)
}

Write-Host ("Formal presentation event API regressions: {0}" -f $report.FormalPresentationEventApiRegressionHitCount)
foreach ($pattern in $report.FormalPresentationEventApiRegressionHits) {
    Write-Host ("  [formal-presentation-event-api-regression] {0}" -f $pattern)
}

Write-Host ("Formal runtime comment debt hits: {0}" -f $report.FormalRuntimeCommentDebtHitCount)
foreach ($pattern in $report.FormalRuntimeCommentDebtHits) {
    Write-Host ("  [formal-runtime-comment-debt] {0}" -f $pattern)
}

Write-Host ("Animation legacy propagation mode hits: {0}" -f $report.AnimationLegacyPropagationModeHitCount)
foreach ($pattern in $report.AnimationLegacyPropagationModeHits) {
    Write-Host ("  [animation-legacy-propagation-hit] {0}" -f $pattern)
}

Write-Host ("EventKit dispatch boundary violations: {0}" -f $report.EventKitDispatchBoundaryViolationCount)
foreach ($pattern in $report.EventKitDispatchBoundaryViolations) {
    Write-Host ("  [eventkit-dispatch-violation] {0}" -f $pattern)
}

if ($hasGateFailure) {
    exit 2
}

exit 0
