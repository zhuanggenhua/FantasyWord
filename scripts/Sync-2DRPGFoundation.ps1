[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReferenceCoreRoot = "C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\Mythril2D\Core",
    [string]$BrandName = "FantasyWord",
    [switch]$PruneExtraCopiedFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runtimeSourceRoot = Join-Path $ReferenceCoreRoot "Runtime\Scripts"
$editorSourceRoot = Join-Path $ReferenceCoreRoot "Editor\Scripts"
$runtimeTargetRoot = Join-Path $ProjectRoot "Assets\Scripts\GameCore\Runtime"
$editorTargetRoot = Join-Path $ProjectRoot "Assets\Editor\GameCore"

$runtimeNamespaceRoot = "$BrandName.GameCore"
$editorNamespaceRoot = "$BrandName.GameCore"
$assetRootsToRepair = @(
    "Assets\Database",
    "Assets\Prefabs",
    "Assets\Animations",
    "Assets\Scenes",
    "Assets\GameData"
)
$serializedAssetExtensionsToRepair = @(
    ".asset",
    ".prefab",
    ".unity",
    ".anim",
    ".controller",
    ".overrideController"
)

$preservedRuntimeExtraPaths = @(
    "AssemblyInfo.cs",
    "Animation\DamageScreenFlash.cs",
    "Audio\AudioChannelFallbackPlayer.cs",
    "Combat\Abilities\AbilityPermissionSettings.cs",
    "Controllers\IPlayerInputTarget.cs",
    "Combat\Weapons\WeaponExecutionRuntime.cs",
    "Combat\Weapons\WeaponExecutionSettings.cs",
    "Combat\Weapons\WeaponHitWindowRuntime.cs",
    "Diagnostics\RuntimeLogOverlay.cs",
    "Loot\ItemPickable.cs",
    "Loot\MoneyPickable.cs",
    "Loot\PickableItem.cs",
    "Miscellaneous\MovementZone.cs",
    "Diagnostics\RuntimeLogOverlayBootstrap.cs",
    "Presentation\GameplayFeedbackSet.cs",
    "Resources\Generated\FWRes.g.cs",
    "Resources\Generated\FWScene.g.cs",
    "Resources\Generated\FWText.g.cs",
    "UI\UIPointerUtility.cs",
    "UI\UITipsItem.cs",
    "UI\UITipsService.cs"
)
$preservedEditorExtraPaths = @(
    "Bridge\BridgePollerRecovery.cs"
)
# Preserve approved project-side patches when re-pulling reference files.
$preservedRuntimePatchedPaths = @(
    "Animation\CameraShake.cs",
    "Audio\AudioChannel.cs",
    "Audio\AudioRegion.cs",
    "Commands\AddExperience.cs",
    "Commands\AddOrRemoveAbility.cs",
    "Commands\AddOrRemoveMana.cs",
    "Commands\ApplyEffectsToPlayer.cs",
    "Commands\ExecuteCommandList.cs",
    "Commands\HealOrDamagePlayer.cs",
    "Commands\MovePlayer.cs",
    "Commands\RevivePlayer.cs",
    "Combat\Abilities\AbilityBase.cs",
    "Combat\Abilities\Active\ActiveAbilityBase.cs",
    "Combat\Abilities\Active\MeleeAttackAbility.cs",
    "Combat\Abilities\Active\SelfCastAbility.cs",
    "Combat\EffectDispatcher.cs",
    "Combat\Effects\AEffect.cs",
    "Combat\Effects\Immediate\ImmediateDamageEffect.cs",
    "Combat\Effects\Temporal\TemporalDamageEffect.cs",
    "Combat\PerTargetCooldown.cs",
    "Database\Abilities\Active\ActiveAbilitySheet.cs",
    "Database\Audio\AudioClipResolver.cs",
    "Database\Characters\CharacterSheet.cs",
    "Controllers\PlayerController.cs",
    "Entities\Entity.cs",
    "Entities\Characters\CharacterBase.cs",
    "Entities\Characters\Monster.cs",
    "Entities\Characters\NPC.cs",
    "Entities\Movable.cs",
    "Conditional\Conditions\IsAbilityUnlocked.cs",
    "Game\Systems\AudioSystem.cs",
    "Game\Systems\InputSystem.cs",
    "Game\Systems\InventorySystem.cs",
    "Game\Systems\JournalSystem.cs",
    "Game\Systems\MapSystem.cs",
    "Game\Systems\PlayerSystem.cs",
    "Game\Systems\SaveSystem.cs",
    "Interactions\InnInteraction.cs",
    "Maps\Checkpoint.cs",
    "Maps\ICheckpoint.cs",
    "Maps\MapInfo.cs",
    "Maps\Teleporter.cs",
    "Miscellaneous\CommandTrigger.cs",
    "UI\FloatingTexts\CombatTextDisplay.cs",
    "UI\FloatingTexts\FloatingText.cs",
    "UI\FloatingTexts\FloatingTextPool.cs",
    "UI\HUD\Abilities\UIHUDAbilityMessage.cs",
    "UI\Effects\UIEffectList.cs",
    "UI\HUD\Abilities\UIHUDAbilityBar.cs",
    "UI\HUD\Abilities\UIHUDAbilityBarEntry.cs",
    "UI\HUD\EventLog\UIEventLog.cs",
    "UI\HUD\Effects\UIHUDEffectBar.cs",
    "UI\HUD\ItemDetails\UIItemDetails.cs",
    "UI\HUD\Stats\UIStatBar.cs",
    "UI\Menus\Abilities\UIAbilities.cs",
    "UI\Menus\Abilities\UIAbilityBar.cs",
    "UI\Menus\Character\UICharacter.cs",
    "UI\Menus\Character\UICharacterStat.cs",
    "UI\Menus\Craft\UICraft.cs",
    "UI\Generic\UIStat.cs",
    "UI\Menus\Inventory\UIInventory.cs",
    "UI\Menus\Inventory\UIInventoryStats.cs",
    "UI\UICharacterInfo.cs",
    "UI\UIPlayerControllerFeedback.cs"
)
$preservedEditorPatchedPaths = @()
$relocatedRuntimeReferencePaths = @()
$excludedRuntimeReferencePaths = @(
    # UIKit 正式菜单运行时已取代旧 2DRPG 菜单运行时，这组旧菜单文件不再属于正式同步闭包。
    "Pooling\InstancePool.cs",
    "UI\Menus\AUIMenu.cs",
    "UI\Menus\IUIMenu.cs",
    "UI\Menus\UIMenuManager.cs",
    "UI\Menus\Death\UIDeath.cs"
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

function Ensure-ParentDirectory {
    param([string]$FilePath)

    $parent = Split-Path -Parent $FilePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Get-MappedRuntimeRelativePaths {
    param([string]$SourceRoot)

    return Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.cs | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceRoot.Length + 1)
        Get-MappedRuntimeRelativePath -RelativePath $relativePath
    }
}

function Get-RelativePaths {
    param([string]$SourceRoot)

    return Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.cs | ForEach-Object {
        $_.FullName.Substring($SourceRoot.Length + 1)
    }
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

function Get-MetaGuid {
    param([string]$MetaPath)

    if (-not (Test-Path -LiteralPath $MetaPath)) {
        return $null
    }

    $match = Select-String -LiteralPath $MetaPath -Pattern '^guid:\s*([0-9a-f]{32})$' | Select-Object -First 1
    if ($null -eq $match) {
        return $null
    }

    return $match.Matches[0].Groups[1].Value
}

function Build-ScriptGuidMap {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot,
        [switch]$RuntimeMappings
    )

    $guidMap = @{}
    $sourceFiles = Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.cs

    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Substring($SourceRoot.Length + 1)
        if ($RuntimeMappings) {
            $relativePath = Get-MappedRuntimeRelativePath -RelativePath $relativePath
        }

        $sourceGuid = Get-MetaGuid -MetaPath ($file.FullName + ".meta")
        $targetPath = Join-Path $TargetRoot $relativePath
        $targetGuid = Get-MetaGuid -MetaPath ($targetPath + ".meta")

        if ([string]::IsNullOrWhiteSpace($sourceGuid) -or [string]::IsNullOrWhiteSpace($targetGuid)) {
            continue
        }

        if ($sourceGuid -ieq $targetGuid) {
            continue
        }

        $guidMap[$sourceGuid] = $targetGuid
    }

    return $guidMap
}

function Repair-SerializedAssetScriptGuids {
    param(
        [string]$ProjectRootPath,
        [hashtable]$GuidMap,
        [string[]]$AssetRoots,
        [string[]]$Extensions
    )

    if ($GuidMap.Count -eq 0) {
        Write-Host "Foundation asset GUID repair skipped: no remap entries."
        return
    }

    $normalizedExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) {
        [void]$normalizedExtensions.Add($extension)
    }

    $filesTouched = 0
    $replacementCount = 0
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    foreach ($assetRoot in $AssetRoots) {
        $absoluteRoot = Join-Path $ProjectRootPath $assetRoot
        if (-not (Test-Path -LiteralPath $absoluteRoot)) {
            continue
        }

        $files = Get-ChildItem -Path $absoluteRoot -Recurse -File | Where-Object {
            $normalizedExtensions.Contains($_.Extension)
        }

        foreach ($file in $files) {
            $content = [System.IO.File]::ReadAllText($file.FullName)
            $updated = $content

            foreach ($sourceGuid in $GuidMap.Keys) {
                $targetGuid = $GuidMap[$sourceGuid]
                if ($updated.Contains($sourceGuid)) {
                    $updated = $updated.Replace($sourceGuid, $targetGuid)
                }
            }

            if ($updated -eq $content) {
                continue
            }

            foreach ($sourceGuid in $GuidMap.Keys) {
                $targetGuid = $GuidMap[$sourceGuid]
                $replacementCount += ([regex]::Matches($content, [regex]::Escape($sourceGuid))).Count
            }

            [System.IO.File]::WriteAllText($file.FullName, $updated, $utf8NoBom)
            $filesTouched++
        }
    }

    Write-Host "Foundation asset GUID repair finished."
    Write-Host "FilesTouched:" $filesTouched
    Write-Host "ReplacementCandidatesMatched:" $replacementCount
}

function Capture-FileSnapshots {
    param(
        [string]$TargetRoot,
        [string[]]$RelativePaths
    )

    $snapshots = @{}
    foreach ($relativePath in $RelativePaths) {
        $targetPath = Join-Path $TargetRoot $relativePath
        if (Test-Path -LiteralPath $targetPath) {
            $snapshots[$relativePath] = Get-Content -LiteralPath $targetPath -Raw
        }
    }

    return $snapshots
}

function Restore-FileSnapshots {
    param(
        [string]$TargetRoot,
        [hashtable]$Snapshots
    )

    foreach ($relativePath in $Snapshots.Keys) {
        $targetPath = Join-Path $TargetRoot $relativePath
        Ensure-ParentDirectory -FilePath $targetPath
        Set-Content -Path $targetPath -Value $Snapshots[$relativePath] -Encoding UTF8
    }
}

function Remove-RelativeFiles {
    param(
        [string]$TargetRoot,
        [string[]]$RelativePaths
    )

    foreach ($relativePath in $RelativePaths) {
        $targetPath = Join-Path $TargetRoot $relativePath
        if (Test-Path -LiteralPath $targetPath) {
            Remove-Item -LiteralPath $targetPath -Force
        }

        $metaPath = "$targetPath.meta"
        if (Test-Path -LiteralPath $metaPath) {
            Remove-Item -LiteralPath $metaPath -Force
        }
    }
}

function Get-SerializedTypeNamespaceMap {
    param([string]$Brand)

    $namespace = "$Brand.GameCore"
    return @{
        GameConfig = $namespace
        ExecuteCommandList = $namespace
        Wait = $namespace
        ExecuteCommandIf = $namespace
        AddOrRemoveItem = $namespace
        PlayDialogueLine = $namespace
        RespawnPlayer = $namespace
        OpenMenu = $namespace
        IsItemInInventory = $namespace
        PlayerController = $namespace
        BidirectionalAnimationStrategy = $namespace
        UICharacter = $namespace
        UIInventoryBagCategory = $namespace
    }
}

function Update-SerializedTypeReferences {
    param(
        [string]$AssetsRoot,
        [string]$Brand
    )

    if (-not (Test-Path -LiteralPath $AssetsRoot)) {
        return
    }

    $assemblyName = "$Brand.GameCore"
    $typeNamespaceMap = Get-SerializedTypeNamespaceMap -Brand $Brand
    $serializedFiles = Get-ChildItem -Path $AssetsRoot -Recurse -File -Include *.asset, *.prefab, *.unity

    foreach ($file in $serializedFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $updated = $content

        $updated = [regex]::Replace(
            $updated,
            [regex]::Escape("$Brand.GameCore.Runtime.") + '[A-Za-z0-9_.]*\.([A-Za-z0-9_]+)',
            "$Brand.GameCore.`$1"
        )
        $updated = [regex]::Replace(
            $updated,
            [regex]::Escape("$Brand.GameCore.Editor.") + '[A-Za-z0-9_.]*\.([A-Za-z0-9_]+)',
            "$Brand.GameCore.`$1"
        )

        if ($updated.Contains("Gyvr.Mythril2D:Gyvr.Mythril2D:GameConfig")) {
            $updated = $updated.Replace(
                "Gyvr.Mythril2D:Gyvr.Mythril2D:GameConfig",
                "${assemblyName}::${Brand}.GameCore.GameConfig"
            )
        }

        foreach ($typeName in $typeNamespaceMap.Keys) {
            $targetNamespace = $typeNamespaceMap[$typeName]
            $updated = $updated.Replace(
                "type: {class: $typeName, ns: Gyvr.Mythril2D, asm: Gyvr.Mythril2D}",
                "type: {class: $typeName, ns: $targetNamespace, asm: $assemblyName}"
            )
            $updated = $updated.Replace(
                "m_TargetAssemblyTypeName: Gyvr.Mythril2D.$typeName, Gyvr.Mythril2D",
                "m_TargetAssemblyTypeName: ${targetNamespace}.${typeName}, $assemblyName"
            )
            $updated = $updated.Replace(
                "value: Gyvr.Mythril2D.$typeName, Gyvr.Mythril2D",
                "value: ${targetNamespace}.${typeName}, $assemblyName"
            )
        }

        if ($updated -ne $content) {
            Set-Content -Path $file.FullName -Value $updated -Encoding UTF8
        }
    }
}

function Copy-DirectCSharpTree {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot,
        [string]$NamespaceRoot,
        [switch]$RuntimeMappings
    )

    $files = Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.cs
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourceRoot.Length + 1)
        if ($RuntimeMappings) {
            $relativePath = Get-MappedRuntimeRelativePath -RelativePath $relativePath
        }

        if ($RuntimeMappings -and $excludedRuntimeReferencePaths -contains $relativePath) {
            continue
        }

        $namespace = Get-NamespaceForRelativePath -RelativePath $relativePath -NamespaceRoot $NamespaceRoot
        $targetPath = Join-Path $TargetRoot $relativePath
        Ensure-ParentDirectory -FilePath $targetPath

        $content = Get-Content -Path $file.FullName -Raw
        $content = [regex]::Replace($content, 'namespace\s+Gyvr\.Mythril2D', "namespace $namespace")
        $content = $content.Replace("using Gyvr.Mythril2D;", "")
        $content = $content.Replace("AssetMenuIndexer.Mythril2D_", "AssetMenuIndexer.${BrandName}_")
        $content = $content.Replace("AssetMenuIndexer.Mythril2D", "AssetMenuIndexer.$BrandName")
        $content = Update-Branding -Content $content -Brand $BrandName

        if ($relativePath -eq "Database\AssetMenuIndexer.cs") {
            $content = $content.Replace('public const string Mythril2D = "Mythril2D/";', "public const string ${BrandName} = `"$BrandName/`";")
            $content = $content.Replace("public const string Mythril2D_Abilities", "public const string ${BrandName}_Abilities")
            $content = $content.Replace("public const string Mythril2D_Animation", "public const string ${BrandName}_Animation")
            $content = $content.Replace("public const string Mythril2D_Audio", "public const string ${BrandName}_Audio")
            $content = $content.Replace("public const string Mythril2D_Characters", "public const string ${BrandName}_Characters")
            $content = $content.Replace("public const string Mythril2D_Dialogues", "public const string ${BrandName}_Dialogues")
            $content = $content.Replace("public const string Mythril2D_Game", "public const string ${BrandName}_Game")
            $content = $content.Replace("public const string Mythril2D_Inns", "public const string ${BrandName}_Inns")
            $content = $content.Replace("public const string Mythril2D_Items", "public const string ${BrandName}_Items")
            $content = $content.Replace("public const string Mythril2D_Crafting", "public const string ${BrandName}_Crafting")
            $content = $content.Replace("public const string Mythril2D_Quests", "public const string ${BrandName}_Quests")
            $content = $content.Replace("public const string Mythril2D_Quests_Tasks", "public const string ${BrandName}_Quests_Tasks")
            $content = $content.Replace("public const string Mythril2D_Save", "public const string ${BrandName}_Save")
            $content = $content.Replace("public const string Mythril2D_Shops", "public const string ${BrandName}_Shops")
            $content = $content.Replace("public const string Mythril2D_UI", "public const string ${BrandName}_UI")
            $content = $content.Replace("public const string Mythril2D_Utils", "public const string ${BrandName}_Utils")
            $content = $content.Replace("= Mythril2D + ", "= $BrandName + ")
            $content = $content.Replace("= Mythril2D_Quests + ", "= ${BrandName}_Quests + ")
        }

        Set-Content -Path $targetPath -Value $content -Encoding UTF8
    }
}

function Remove-ExtraCopiedFiles {
    param(
        [string]$TargetRoot,
        [string[]]$ExpectedRelativePaths,
        [string[]]$PreservedRelativePaths = @()
    )

    if (-not (Test-Path -LiteralPath $TargetRoot)) {
        return
    }

    $expectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $ExpectedRelativePaths) {
        [void]$expectedSet.Add($item)
    }

    $preservedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $PreservedRelativePaths) {
        [void]$preservedSet.Add($item)
    }

    $files = Get-ChildItem -Path $TargetRoot -Recurse -File -Filter *.cs
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($TargetRoot.Length + 1)
        if ($expectedSet.Contains($relativePath) -or $preservedSet.Contains($relativePath)) {
            continue
        }

        Remove-Item -LiteralPath $file.FullName -Force
    }
}

function Get-ExpectedRelativeDirectories {
    param([string[]]$RelativePaths)

    $directorySet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relativePath in $RelativePaths) {
        $directory = Split-Path -Parent $relativePath
        while (-not [string]::IsNullOrWhiteSpace($directory) -and $directory -ne ".") {
            [void]$directorySet.Add($directory)
            $directory = Split-Path -Parent $directory
        }
    }

    return $directorySet
}

function Remove-ExtraEmptyDirectories {
    param(
        [string]$TargetRoot,
        [System.Collections.Generic.HashSet[string]]$ExpectedRelativeDirectories,
        [string[]]$PreservedRelativeDirectories = @()
    )

    if (-not (Test-Path -LiteralPath $TargetRoot)) {
        return
    }

    $preservedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $PreservedRelativeDirectories) {
        [void]$preservedSet.Add($item)
    }

    $directories = Get-ChildItem -Path $TargetRoot -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending
    foreach ($directory in $directories) {
        $relativePath = $directory.FullName.Substring($TargetRoot.Length + 1)
        if ($ExpectedRelativeDirectories.Contains($relativePath) -or $preservedSet.Contains($relativePath)) {
            continue
        }

        $hasContent = Get-ChildItem -LiteralPath $directory.FullName -Force | Select-Object -First 1
        if ($hasContent) {
            continue
        }

        Remove-Item -LiteralPath $directory.FullName -Force
        $metaPath = "$($directory.FullName).meta"
        if (Test-Path -LiteralPath $metaPath) {
            Remove-Item -LiteralPath $metaPath -Force
        }
    }
}

function Write-RuntimeAsmdef {
    $path = Join-Path $ProjectRoot "Assets\Scripts\GameCore\$BrandName.GameCore.asmdef"
    $json = @"
{
  "name": "$BrandName.GameCore",
  "rootNamespace": "$BrandName.GameCore",
  "references": [
    "MackySoft.SerializeReferenceExtensions",
    "BroAudio",
    "azixMcAze.SerializableDictionary",
    "YokiFrame",
    "YokiFrame.ActionKit",
    "YokiFrame.LocalizationKit",
    "YokiFrame.InputKit",
    "YokiFrame.SaveKit",
    "YokiFrame.SceneKit",
    "MoreMountains.Tools",
    "Unity.InputSystem",
    "Unity.TextMeshPro",
    "Unity.2D.Animation.Runtime",
    "Unity.Mathematics"
  ],
  "includePlatforms": [],
  "excludePlatforms": [],
  "allowUnsafeCode": false,
  "overrideReferences": false,
  "precompiledReferences": [],
  "autoReferenced": true,
  "defineConstraints": [],
  "versionDefines": [],
  "noEngineReferences": false
}
"@
    Ensure-ParentDirectory -FilePath $path
    Set-Content -Path $path -Value $json -Encoding UTF8
}

function Write-EditorAsmdef {
    $path = Join-Path $ProjectRoot "Assets\Editor\GameCore\$BrandName.GameCore.Editor.asmdef"
    $json = @"
{
  "name": "$BrandName.GameCore.Editor",
  "rootNamespace": "$BrandName.GameCore",
  "references": [
    "$BrandName.GameCore",
    "BroAudio",
    "AiBridge.Unity.Editor",
    "Unity.Addressables.Editor",
    "MackySoft.SerializeReferenceExtensions",
    "azixMcAze.SerializableDictionary",
    "Unity.Mathematics"
  ],
  "includePlatforms": [
    "Editor"
  ],
  "excludePlatforms": [],
  "allowUnsafeCode": false,
  "overrideReferences": false,
  "precompiledReferences": [],
  "autoReferenced": true,
  "defineConstraints": [],
  "versionDefines": [],
  "noEngineReferences": false
}
"@
    Ensure-ParentDirectory -FilePath $path
    Set-Content -Path $path -Value $json -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $runtimeSourceRoot)) {
    throw "Reference runtime source root not found: $runtimeSourceRoot"
}

if (-not (Test-Path -LiteralPath $editorSourceRoot)) {
    throw "Reference editor source root not found: $editorSourceRoot"
}

$runtimePatchedSnapshots = Capture-FileSnapshots -TargetRoot $runtimeTargetRoot -RelativePaths $preservedRuntimePatchedPaths
$editorPatchedSnapshots = Capture-FileSnapshots -TargetRoot $editorTargetRoot -RelativePaths $preservedEditorPatchedPaths

Copy-DirectCSharpTree -SourceRoot $runtimeSourceRoot -TargetRoot $runtimeTargetRoot -NamespaceRoot $runtimeNamespaceRoot -RuntimeMappings
Copy-DirectCSharpTree -SourceRoot $editorSourceRoot -TargetRoot $editorTargetRoot -NamespaceRoot $editorNamespaceRoot

if ($PruneExtraCopiedFiles) {
    $expectedRuntimeRelativePaths = Get-MappedRuntimeRelativePaths -SourceRoot $runtimeSourceRoot
    $expectedRuntimeRelativePaths = @($expectedRuntimeRelativePaths | Where-Object { $excludedRuntimeReferencePaths -notcontains $_ })
    $expectedEditorRelativePaths = Get-RelativePaths -SourceRoot $editorSourceRoot
    $expectedRuntimeDirectories = Get-ExpectedRelativeDirectories -RelativePaths $expectedRuntimeRelativePaths
    $expectedEditorDirectories = Get-ExpectedRelativeDirectories -RelativePaths $expectedEditorRelativePaths
    $preservedRuntimeDirectories = Get-ExpectedRelativeDirectories -RelativePaths $preservedRuntimeExtraPaths
    $preservedEditorDirectories = Get-ExpectedRelativeDirectories -RelativePaths $preservedEditorExtraPaths

    Remove-ExtraCopiedFiles -TargetRoot $runtimeTargetRoot -ExpectedRelativePaths $expectedRuntimeRelativePaths -PreservedRelativePaths $preservedRuntimeExtraPaths
    Remove-ExtraCopiedFiles -TargetRoot $editorTargetRoot -ExpectedRelativePaths $expectedEditorRelativePaths -PreservedRelativePaths $preservedEditorExtraPaths
    Remove-ExtraEmptyDirectories -TargetRoot $runtimeTargetRoot -ExpectedRelativeDirectories $expectedRuntimeDirectories -PreservedRelativeDirectories $preservedRuntimeDirectories
    Remove-ExtraEmptyDirectories -TargetRoot $editorTargetRoot -ExpectedRelativeDirectories $expectedEditorDirectories -PreservedRelativeDirectories $preservedEditorDirectories
}

Restore-FileSnapshots -TargetRoot $runtimeTargetRoot -Snapshots $runtimePatchedSnapshots
Restore-FileSnapshots -TargetRoot $editorTargetRoot -Snapshots $editorPatchedSnapshots
Remove-RelativeFiles -TargetRoot $runtimeTargetRoot -RelativePaths $relocatedRuntimeReferencePaths
Remove-RelativeFiles -TargetRoot $runtimeTargetRoot -RelativePaths $excludedRuntimeReferencePaths

$runtimeGuidMap = Build-ScriptGuidMap -SourceRoot $runtimeSourceRoot -TargetRoot $runtimeTargetRoot -RuntimeMappings
$editorGuidMap = Build-ScriptGuidMap -SourceRoot $editorSourceRoot -TargetRoot $editorTargetRoot
$scriptGuidMap = @{}
foreach ($key in $runtimeGuidMap.Keys) {
    $scriptGuidMap[$key] = $runtimeGuidMap[$key]
}
foreach ($key in $editorGuidMap.Keys) {
    $scriptGuidMap[$key] = $editorGuidMap[$key]
}

Repair-SerializedAssetScriptGuids `
    -ProjectRootPath $ProjectRoot `
    -GuidMap $scriptGuidMap `
    -AssetRoots $assetRootsToRepair `
    -Extensions $serializedAssetExtensionsToRepair

Write-RuntimeAsmdef
Write-EditorAsmdef
Update-SerializedTypeReferences -AssetsRoot (Join-Path $ProjectRoot "Assets") -Brand $BrandName

Write-Host "2DRPG foundation sync finished."
Write-Host "ProjectRoot:" $ProjectRoot
Write-Host "ReferenceCoreRoot:" $ReferenceCoreRoot
Write-Host "BrandName:" $BrandName
