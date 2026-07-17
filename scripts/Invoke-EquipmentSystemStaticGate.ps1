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

function Convert-AssetPathToFullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AssetPath
    )

    $normalized = $AssetPath.Replace('/', '\').TrimStart('\')
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $normalized))
}

function ConvertFrom-YamlScalar {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $trimmed = ([string]$Value).Trim()
    if ($trimmed.Length -ge 2 -and $trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
        $unquoted = $trimmed.Substring(1, $trimmed.Length - 2)
        return [regex]::Unescape($unquoted)
    }

    return $trimmed
}

function ConvertFrom-EscapedUnicode {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    return [regex]::Unescape(([string]$Value))
}

function Get-YamlScalarValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$DefaultValue
    )

    $match = [regex]::Match(
        $Content,
        ("(?m)^\s*{0}:\s*(?<Value>.*?)\s*$" -f [regex]::Escape($Name)))
    if (-not $match.Success) {
        return $DefaultValue
    }

    $value = ConvertFrom-YamlScalar -Value $match.Groups["Value"].Value
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value
}

function Join-AssetPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Leaf
    )

    return $Root.TrimEnd('/').Replace('\', '/') + "/" + $Leaf.Trim('/').Replace('\', '/')
}

function Get-EquipmentGenerationSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $defaultSettingsAssetPath = ConvertFrom-EscapedUnicode -Value "Assets/GameData/EquipmentSystem/Data/Workbench/\u6362\u88C5\u52A8\u753B\u751F\u6210\u8BBE\u7F6E.asset"
    $defaultAnimationRoot = "Assets/GameData/EquipmentSystem/Animations"
    $defaultControllerFileName = ConvertFrom-EscapedUnicode -Value "\u6362\u88C5\u5171\u4EAB\u52A8\u753B\u72B6\u6001\u673A.controller"
    $defaultSharedClipFolderName = "SharedClips"
    $defaultSpriteLibraryFolderName = "SpriteLibraries"
    $defaultWorkbenchCatalogPath = ConvertFrom-EscapedUnicode -Value "Assets/GameData/EquipmentSystem/Data/Workbench/\u6362\u88C5\u5DE5\u4F5C\u53F0\u76EE\u5F55.asset"

    $settingsFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $defaultSettingsAssetPath
    $settingsMissing = -not (Test-Path -LiteralPath $settingsFullPath)
    $content = if ($settingsMissing) { "" } else { Get-FileContent -Path $settingsFullPath }

    $animationRootAssetPath = Get-YamlScalarValue -Content $content -Name "animationRoot" -DefaultValue $defaultAnimationRoot
    $controllerFileName = Get-YamlScalarValue -Content $content -Name "controllerFileName" -DefaultValue $defaultControllerFileName
    $sharedClipFolderName = Get-YamlScalarValue -Content $content -Name "sharedClipFolderName" -DefaultValue $defaultSharedClipFolderName
    $spriteLibraryFolderName = Get-YamlScalarValue -Content $content -Name "spriteLibraryFolderName" -DefaultValue $defaultSpriteLibraryFolderName
    $workbenchCatalogAssetPath = Get-YamlScalarValue -Content $content -Name "workbenchCatalogPath" -DefaultValue $defaultWorkbenchCatalogPath

    $sharedClipAssetPath = Join-AssetPath -Root $animationRootAssetPath -Leaf $sharedClipFolderName
    $spriteLibraryAssetPath = Join-AssetPath -Root $animationRootAssetPath -Leaf $spriteLibraryFolderName
    $controllerAssetPath = Join-AssetPath -Root $animationRootAssetPath -Leaf $controllerFileName

    return [pscustomobject]@{
        SettingsAssetPath = $defaultSettingsAssetPath
        SettingsFullPath = $settingsFullPath
        SettingsMissing = $settingsMissing
        AnimationRootAssetPath = $animationRootAssetPath
        AnimationRootFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $animationRootAssetPath
        SharedClipAssetPath = $sharedClipAssetPath
        SharedClipFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $sharedClipAssetPath
        SpriteLibraryAssetPath = $spriteLibraryAssetPath
        SpriteLibraryFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $spriteLibraryAssetPath
        ControllerAssetPath = $controllerAssetPath
        ControllerFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $controllerAssetPath
        WorkbenchCatalogAssetPath = $workbenchCatalogAssetPath
        WorkbenchCatalogFullPath = Convert-AssetPathToFullPath -ProjectRoot $ProjectRoot -AssetPath $workbenchCatalogAssetPath
    }
}

function Test-CompleteDirectionalSpriteLibrarySetBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Block,
        [Parameter(Mandatory = $true)]
        [string]$HeaderName
    )

    $complete = $Block -match ("(?m)^\s*{0}:\s*\r?$" -f [regex]::Escape($HeaderName))
    foreach ($field in @('southEast', 'southWest', 'northEast', 'northWest')) {
        $complete = $complete -and
            $Block -match ("(?m)^\s*{0}:\s*\{{fileID:\s*(?!0(?:,|\}}))" -f $field)
    }

    return [bool]$complete
}

$projectRoot = Get-ProjectRoot
$generationSettings = Get-EquipmentGenerationSettings -ProjectRoot $projectRoot
$equipmentDataRoot = Join-Path $projectRoot "Assets/GameData/EquipmentSystem"
$animationRoot = $generationSettings.AnimationRootFullPath
$sharedClipRoot = $generationSettings.SharedClipFullPath
$spriteLibraryRoot = $generationSettings.SpriteLibraryFullPath
$spriteLibrarySuffix = ConvertFrom-EscapedUnicode -Value "\u52A8\u753B\u7CBE\u7075\u5E93"
$spriteLibrarySuffixPattern = [regex]::Escape($spriteLibrarySuffix)
$directionalSpriteLibraryNamePattern = '^(?<Character>.+)_(?<Direction>SE|SW|NE|NW)' + $spriteLibrarySuffixPattern + '$'
$directionalSpriteLibraryDirectionPattern = '_(SE|SW|NE|NW)' + $spriteLibrarySuffixPattern + '$'
$transientDefaultGenerationSettingsPattern = [regex]::Escape(
    (ConvertFrom-EscapedUnicode -Value "\u4F7F\u7528\u5185\u7F6E\u9ED8\u8BA4\u751F\u6210\u8BBE\u7F6E"))
$legacyAnimationVariantSetRoot = Join-Path $animationRoot "CharacterAnimationVariants"
$controllerPath = $generationSettings.ControllerFullPath
$frameDataRoot = Join-Path $equipmentDataRoot "FrameData"
$workbenchCatalogPath = $generationSettings.WorkbenchCatalogFullPath
$baseCharacterPrefabPath = Join-Path $projectRoot "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
$legacyGeneratedClipRoot = Join-Path $animationRoot "GeneratedClips"
$legacyOverrideRoot = Join-Path $animationRoot "Overrides"
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
$directSpriteAnimationFiles = New-Object System.Collections.Generic.List[string]
$missingSpriteKeyAnimationFiles = New-Object System.Collections.Generic.List[string]
$emptySpriteLibraryFiles = New-Object System.Collections.Generic.List[string]
$overrideControllerFiles = New-Object System.Collections.Generic.List[string]
$directionalAnimationAssetFiles = New-Object System.Collections.Generic.List[string]
$directionalSpriteLibraryCategoryFiles = New-Object System.Collections.Generic.List[string]
$directionStateRuntimeFiles = New-Object System.Collections.Generic.List[string]
$directionalControllerStateFiles = New-Object System.Collections.Generic.List[string]
$incompleteDirectionalLibrarySets = New-Object System.Collections.Generic.List[string]
$legacyAnimationVariantSetFiles = New-Object System.Collections.Generic.List[string]
$legacyAnimationVariantSourceFiles = New-Object System.Collections.Generic.List[string]
$frameDataAnimationLibraryOwnerFiles = New-Object System.Collections.Generic.List[string]
$workbenchCatalogMissingAnimationLibraryEntries = New-Object System.Collections.Generic.List[string]
$prefabMissingAnimationLibraryEntries = New-Object System.Collections.Generic.List[string]
$architectureContractViolations = New-Object System.Collections.Generic.List[string]
$generationSettingsViolations = New-Object System.Collections.Generic.List[string]

if ($generationSettings.SettingsMissing) {
    [void]$generationSettingsViolations.Add(
        ("Missing formal EquipmentSystemGenerationSettings asset: {0}" -f $generationSettings.SettingsAssetPath))
}

Get-ChildItem -LiteralPath $equipmentDataRoot -Recurse -File -Filter *.asset | ForEach-Object {
    $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
    $content = Get-FileContent -Path $_.FullName

    if ($content -match $legacyTypePattern) {
        [void]$legacyIdentifierFiles.Add($relativePath)
    }

    if ($content -match 'm_EditorClassIdentifier:\s*(EquipmentSystem|FantasyWord\.Presentation\.EquipmentSystem)::') {
        [void]$businessAssemblyIdentifierFiles.Add($relativePath)
    }

    if ($content -match 'm_EditorClassIdentifier:\s*::CharacterAnimationVariantSet|(?m)^\s*animationVariants:\s*') {
        if (-not $legacyAnimationVariantSetFiles.Contains($relativePath)) {
            [void]$legacyAnimationVariantSetFiles.Add($relativePath)
        }
    }
}

if (Test-Path -LiteralPath $animationRoot) {
    Get-ChildItem -LiteralPath $animationRoot -Recurse -File -Filter *.anim | ForEach-Object {
        $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
        $content = Get-FileContent -Path $_.FullName
        if ($content -match '(?m)^\s*attribute:\s*m_Sprite\s*$') {
            [void]$directSpriteAnimationFiles.Add($relativePath)
        }
        if ($_.FullName.StartsWith($sharedClipRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
            $content -notmatch '(?m)^\s*attribute:\s*m_SpriteKey\s*$') {
            [void]$missingSpriteKeyAnimationFiles.Add($relativePath)
        }
        if ($_.BaseName -match '_(SE|SW|NE|NW)$') {
            [void]$directionalAnimationAssetFiles.Add($relativePath)
        }
    }

    Get-ChildItem -LiteralPath $animationRoot -Recurse -File -Filter *.overrideController | ForEach-Object {
        [void]$overrideControllerFiles.Add(
            (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName))
    }

    if (Test-Path -LiteralPath $controllerPath) {
        $controllerContent = Get-FileContent -Path $controllerPath
        if ($controllerContent -match '(?m)^\s*m_Name:\s*[^\r\n]*_(SE|SW|NE|NW)\s*\r?$') {
            [void]$directionalControllerStateFiles.Add(
                (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $controllerPath))
        }
    }
}

if (Test-Path -LiteralPath $spriteLibraryRoot) {
    $libraryAssets = @(Get-ChildItem -LiteralPath $spriteLibraryRoot -File -Filter *.asset)
    $libraryAssets | ForEach-Object {
        $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
        $content = Get-FileContent -Path $_.FullName
        if ($content -notmatch '(?m)^\s*- m_Name:\s*.+$' -or
            $content -notmatch '(?m)^\s*m_Sprite:\s*\{fileID:\s*(?!0(?:,|\}))') {
            [void]$emptySpriteLibraryFiles.Add($relativePath)
        }
        if ($content -match '(?m)^\s*m_Name:\s*[^\r\n]*_(SE|SW|NE|NW)\s*\r?$') {
            [void]$directionalSpriteLibraryCategoryFiles.Add($relativePath)
        }
    }

    $libraryGroups = $libraryAssets | Group-Object {
        if ($_.BaseName -match $directionalSpriteLibraryNamePattern) {
            return $Matches.Character
        }

        return "[invalid] " + $_.BaseName
    }
    foreach ($group in $libraryGroups) {
        $directions = @($group.Group | ForEach-Object {
            if ($_.BaseName -match $directionalSpriteLibraryDirectionPattern) { $Matches[1] }
        } | Sort-Object -Unique)
        if ($directions.Count -ne 4) {
            [void]$incompleteDirectionalLibrarySets.Add(
                ("{0}: {1}" -f $group.Name, ($directions -join ',')))
        }
    }
}

if (Test-Path -LiteralPath $legacyAnimationVariantSetRoot) {
    Get-ChildItem -LiteralPath $legacyAnimationVariantSetRoot -Recurse -File | ForEach-Object {
        $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
        if (-not $legacyAnimationVariantSetFiles.Contains($relativePath)) {
            [void]$legacyAnimationVariantSetFiles.Add($relativePath)
        }
    }
}

if (Test-Path -LiteralPath $frameDataRoot) {
    Get-ChildItem -LiteralPath $frameDataRoot -File -Filter *.asset | ForEach-Object {
        $content = Get-FileContent -Path $_.FullName
        if ($content -notmatch 'm_EditorClassIdentifier:\s*::CharacterFrameData') {
            return
        }

        if ($content -match '(?m)^\s*animationSpriteLibraries:\s*\r?$') {
            [void]$frameDataAnimationLibraryOwnerFiles.Add(
                (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName))
        }
    }
}

if (Test-Path -LiteralPath $workbenchCatalogPath) {
    $catalogContent = Get-FileContent -Path $workbenchCatalogPath
    $charactersSection = $catalogContent
    $charactersMatch = [regex]::Match(
        $catalogContent,
        '(?ms)^\s*characters:\s*\r?\n(?<Characters>.*?)(?=^\s*equipments:|\z)')
    if ($charactersMatch.Success) {
        $charactersSection = $charactersMatch.Groups["Characters"].Value
    }

    $characterEntries = [regex]::Matches(
        $charactersSection,
        '(?ms)^\s*-\s+displayName:\s*(?<Name>.+?)\r?\n(?<Block>.*?)(?=^\s*-\s+displayName:|\z)')

    foreach ($entry in $characterEntries) {
        $block = $entry.Groups["Block"].Value
        if (-not (Test-CompleteDirectionalSpriteLibrarySetBlock -Block $block -HeaderName "animationLibraries")) {
            [void]$workbenchCatalogMissingAnimationLibraryEntries.Add(
                $entry.Groups["Name"].Value.Trim())
        }
    }
}
else {
    [void]$workbenchCatalogMissingAnimationLibraryEntries.Add(
        (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $workbenchCatalogPath))
}

if (Test-Path -LiteralPath $baseCharacterPrefabPath) {
    $prefabContent = Get-FileContent -Path $baseCharacterPrefabPath
    if (-not (Test-CompleteDirectionalSpriteLibrarySetBlock -Block $prefabContent -HeaderName "defaultAnimationLibraries")) {
        [void]$prefabMissingAnimationLibraryEntries.Add(
            (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $baseCharacterPrefabPath))
    }

    if ($prefabContent -notmatch 'm_EditorClassIdentifier:\s*Assembly-CSharp::CharacterEquipmentPresentation(?s).*?equipmentRenderer:\s*\{fileID:\s*(?!0(?:,|\}))') {
        [void]$prefabMissingAnimationLibraryEntries.Add(
            "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab: CharacterEquipmentPresentation.equipmentRenderer explicit binding")
    }

    $animationControllerPrefabMatch = [regex]::Match(
        $prefabContent,
        'm_EditorClassIdentifier:\s*Assembly-CSharp::CharacterActionAnimatorDriver(?s).*?(?=\n--- !u!|\z)')
    if (-not $animationControllerPrefabMatch.Success) {
        [void]$architectureContractViolations.Add("Base character prefab is missing CharacterActionAnimatorDriver component")
    }
    else {
        $animationControllerPrefabBlock = $animationControllerPrefabMatch.Value
        if ($animationControllerPrefabBlock -notmatch '(?m)^\s*characterAnimator:\s*\{fileID:\s*(?!0(?:,|\}))') {
            [void]$architectureContractViolations.Add("Base character prefab must explicitly bind CharacterActionAnimatorDriver.characterAnimator")
        }
        if ($animationControllerPrefabBlock -notmatch '(?m)^\s*shadowObject:\s*\{fileID:\s*(?!0(?:,|\}))') {
            [void]$architectureContractViolations.Add("Base character prefab must explicitly bind CharacterActionAnimatorDriver.shadowObject")
        }
    }

    $equipmentRendererPrefabMatch = [regex]::Match(
        $prefabContent,
        'm_EditorClassIdentifier:\s*Assembly-CSharp::EquipmentRenderer(?s).*?(?=\n--- !u!|\z)')
    if (-not $equipmentRendererPrefabMatch.Success) {
        [void]$architectureContractViolations.Add("Base character prefab is missing EquipmentRenderer component")
    }
    else {
        $equipmentRendererPrefabBlock = $equipmentRendererPrefabMatch.Value
        if ($equipmentRendererPrefabBlock -notmatch '(?m)^\s*animationController:\s*\{fileID:\s*(?!0(?:,|\}))') {
            [void]$architectureContractViolations.Add("Base character prefab must explicitly bind EquipmentRenderer.animationController")
        }
        if ($equipmentRendererPrefabBlock -notmatch '(?m)^\s*characterAnimator:\s*\{fileID:\s*(?!0(?:,|\}))') {
            [void]$architectureContractViolations.Add("Base character prefab must explicitly bind EquipmentRenderer.characterAnimator")
        }
    }
}
else {
    [void]$prefabMissingAnimationLibraryEntries.Add(
        (Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $baseCharacterPrefabPath))
}

Get-ChildItem -LiteralPath (Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem") -Recurse -File -Filter *.cs | ForEach-Object {
    $relativePath = Convert-ToProjectRelativePath -ProjectRoot $projectRoot -FullPath $_.FullName
    $content = Get-FileContent -Path $_.FullName
    if ($content -match 'DirectionStateSuffixes|AnimatorEquipmentSync') {
        [void]$directionStateRuntimeFiles.Add($relativePath)
    }
    if ($content -match 'CharacterAnimationVariantSet|animationVariants|defaultAnimationVariants|SetAnimationVariants|CharacterAnimationVariants') {
        [void]$legacyAnimationVariantSourceFiles.Add($relativePath)
    }
}

$actionControllerPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs"
$directionDriverPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/DirectionalSpriteLibraryDriver.cs"
$animationBuilderPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/EquipmentWorkbenchAnimatorControllerTool.cs"
$generationSettingsPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Data/Workbench/EquipmentSystemGenerationSettings.cs"
$workbenchBootstrapPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchBootstrap.cs"
$workbenchIconSlotViewPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchIconSlotView.cs"
$workbenchChipButtonViewPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchChipButtonView.cs"
$gameCoreAnimatorCuePath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Presentation/CuePlayGameCoreAnimator.cs"
$characterEquipmentPresentationPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterEquipmentPresentation.cs"
$equipmentRendererPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs"
$characterActorPath = Join-Path $projectRoot "Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.cs"
$actionControllerContent = Get-FileContent -Path $actionControllerPath
$directionDriverContent = Get-FileContent -Path $directionDriverPath
$animationBuilderContent = Get-FileContent -Path $animationBuilderPath
$generationSettingsContent = Get-FileContent -Path $generationSettingsPath
$workbenchBootstrapContent = Get-FileContent -Path $workbenchBootstrapPath
$workbenchIconSlotViewContent = Get-FileContent -Path $workbenchIconSlotViewPath
$workbenchChipButtonViewContent = Get-FileContent -Path $workbenchChipButtonViewPath
$gameCoreAnimatorCueContent = Get-FileContent -Path $gameCoreAnimatorCuePath
$characterEquipmentPresentationContent = Get-FileContent -Path $characterEquipmentPresentationPath
$equipmentRendererContent = Get-FileContent -Path $equipmentRendererPath
$characterActorContent = Get-FileContent -Path $characterActorPath
if ($actionControllerContent -match 'using\s+UnityEngine\.U2D\.Animation|SpriteLibraryAsset|SpriteLibrary\s+[_a-zA-Z]|CurrentDirection|SetDirection\s*\(|SetFacingDirection\s*\(') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver owns direction or SpriteLibrary")
}
if ($directionDriverContent -match 'Animator\.Play|GetComponent(?:InParent|InChildren)?<Animator>|\bAnimator\s+[_a-zA-Z]') {
    [void]$architectureContractViolations.Add("DirectionalSpriteLibraryDriver drives Animator")
}
if ($animationBuilderContent -match 'EditorSceneManager|SceneManager|PrefabUtility') {
    [void]$architectureContractViolations.Add("Animation asset builder writes scenes or prefabs")
}
if ($animationBuilderContent -match ('CreateTransientDefault|HideAndDontSave|' + $transientDefaultGenerationSettingsPattern) -or
    $generationSettingsContent -match 'CreateTransientDefault|HideAndDontSave') {
    [void]$architectureContractViolations.Add("Animation asset builder falls back to transient generation settings")
}
if ($workbenchBootstrapContent -match 'FindFirstObjectByType<EquipmentWorkbenchRuntimeUI>|FindObject.*EquipmentWorkbenchRuntimeUI') {
    [void]$architectureContractViolations.Add("Workbench bootstrap searches hidden scene UI owner")
}
if ($workbenchBootstrapContent -match 'Resources\.Load<EquipmentWorkbenchRuntimeUI>|DefaultWorkbenchUiResourcePath') {
    [void]$architectureContractViolations.Add("Workbench bootstrap loads UI prefab by Resources path")
}
if ($actionControllerContent -match 'const\s+string\s+(DamageAnimationKey|DefaultFallbackAnimationKey)') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver hardcodes action policy constants")
}
if ($actionControllerContent -notmatch 'Animator\s+characterAnimator\s*;' -or
    $actionControllerContent -notmatch 'GameObject\s+shadowObject\s*;') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver must expose explicit Animator and shadow references")
}
if ($actionControllerContent -match 'GetComponentsInChildren<Animator>\s*\(') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver searches child Animator owner")
}
if ($actionControllerContent -match 'GetComponentInChildren<(?:SpriteRenderer|EquipmentRenderer)>\s*\(') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver infers Animator from child presentation components")
}
if ($actionControllerContent -match 'transform\.Find\s*\(\s*"Shadow"\s*\)') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver finds shadow object by hardcoded child name")
}
if ($actionControllerContent -match 'IsCharacterAnimator|ContainsIgnoreCase\s*\(objectName|"(?:Canvas|Dialogue|Dialog|Bubble|Speech|Floating)"') {
    [void]$architectureContractViolations.Add("CharacterActionAnimatorDriver filters candidate Animator by UI object names")
}
if ($gameCoreAnimatorCueContent -match 'TryRestoreAnimation\s*\([^,\r\n]+,\s*"') {
    [void]$architectureContractViolations.Add("GameCore animation cue owns fallback action key")
}
if ($characterEquipmentPresentationContent -match 'GetComponentInChildren<EquipmentRenderer>') {
    [void]$architectureContractViolations.Add("CharacterEquipmentPresentation searches hidden child EquipmentRenderer owner")
}
if ($equipmentRendererContent -notmatch 'CharacterActionAnimatorDriver\s+animationController\s*;' -or
    $equipmentRendererContent -notmatch 'Animator\s+characterAnimator\s*;') {
    [void]$architectureContractViolations.Add("EquipmentRenderer must expose explicit CharacterActionAnimatorDriver and Animator references")
}
if ($equipmentRendererContent -match 'GetComponentInParent<CharacterActionAnimatorDriver>') {
    [void]$architectureContractViolations.Add("EquipmentRenderer searches parent CharacterActionAnimatorDriver owner")
}
if ($equipmentRendererContent -match 'ResolveCharacterAnimator|IsCharacterAnimator|GetComponentsInChildren<Animator>\s*\(') {
    [void]$architectureContractViolations.Add("EquipmentRenderer searches or infers child Animator owner")
}
if ($equipmentRendererContent -match 'GetComponentInChildren<(?:SpriteRenderer|EquipmentRenderer)>\s*\(') {
    [void]$architectureContractViolations.Add("EquipmentRenderer infers Animator from child presentation components")
}
if ($equipmentRendererContent -match 'ContainsIgnoreCase\s*\(objectName|"(?:Canvas|Dialogue|Dialog|Bubble|Speech|Floating)"') {
    [void]$architectureContractViolations.Add("EquipmentRenderer filters candidate Animator by UI object names")
}
if ($characterActorContent -match 'Try(?:Play|Lock)Animation\s*\(\s*"(?:Idle|Dmg|SpinDie)"') {
    [void]$architectureContractViolations.Add("CharacterActor owns concrete formal action key")
}
if ($workbenchIconSlotViewContent -match 'RemoveAllListeners\s*\(' -or
    $workbenchChipButtonViewContent -match 'RemoveAllListeners\s*\(') {
    [void]$architectureContractViolations.Add("Workbench button views clear external click listeners")
}
if (($workbenchIconSlotViewContent -match 'onClick\.AddListener\s*\(' -and
        $workbenchIconSlotViewContent -notmatch 'onClick\.RemoveListener\s*\(\s*currentClickListener\s*\)') -or
    ($workbenchChipButtonViewContent -match 'onClick\.AddListener\s*\(' -and
        $workbenchChipButtonViewContent -notmatch 'onClick\.RemoveListener\s*\(\s*currentClickListener\s*\)')) {
    [void]$architectureContractViolations.Add("Workbench button views must remove only their own stored click listener")
}

$demoSceneContent = Get-FileContent -Path $demoScenePath
$demoSceneMissingPatterns = New-Object System.Collections.Generic.List[string]
foreach ($pattern in @(
    "m_Name: EquipmentSystemDemoCharacter",
    "m_EditorClassIdentifier: ::DirectionalSpriteLibraryDriver",
    "m_EditorClassIdentifier: ::EquipmentRenderer",
    "m_EditorClassIdentifier: ::CharacterActionAnimatorDriver",
    "UnityEngine.U2D.Animation.SpriteResolver",
    "UnityEngine.U2D.Animation.SpriteLibrary",
    "m_Controller:"
)) {
    if (-not $demoSceneContent.Contains($pattern)) {
        [void]$demoSceneMissingPatterns.Add($pattern)
    }
}
if ($demoSceneContent -notmatch '(?m)^\s*runtimeUiPrefab:\s*\{fileID:\s*(?!0(?:,|\}))') {
    [void]$demoSceneMissingPatterns.Add("EquipmentWorkbenchBootstrap.runtimeUiPrefab explicit binding")
}

$report = [ordered]@{
    ProjectRoot = $projectRoot
    EquipmentDataRoot = $equipmentDataRoot
    GenerationSettingsPath = $generationSettings.SettingsAssetPath
    GenerationSettingsMissing = $generationSettings.SettingsMissing
    AnimationRoot = $generationSettings.AnimationRootAssetPath
    SharedClipRoot = $generationSettings.SharedClipAssetPath
    SpriteLibraryRoot = $generationSettings.SpriteLibraryAssetPath
    ControllerPath = $generationSettings.ControllerAssetPath
    WorkbenchCatalogPath = $generationSettings.WorkbenchCatalogAssetPath
    DemoScenePath = $demoScenePath
    LegacyRuntimeDirectoryExists = $legacyRuntimeDirectoryExists
    LegacyRuntimeFileCount = @($legacyRuntimeFiles).Count
    GenerationSettingsViolationCount = $generationSettingsViolations.Count
    LegacyIdentifierFileCount = $legacyIdentifierFiles.Count
    BusinessAssemblyIdentifierFileCount = $businessAssemblyIdentifierFiles.Count
    DemoSceneMissingPatternCount = $demoSceneMissingPatterns.Count
    LegacyGeneratedClipDirectoryExists = Test-Path -LiteralPath $legacyGeneratedClipRoot
    LegacyOverrideDirectoryExists = Test-Path -LiteralPath $legacyOverrideRoot
    OverrideControllerFileCount = $overrideControllerFiles.Count
    DirectSpriteAnimationFileCount = $directSpriteAnimationFiles.Count
    SharedClipMissingSpriteKeyCount = $missingSpriteKeyAnimationFiles.Count
    EmptySpriteLibraryFileCount = $emptySpriteLibraryFiles.Count
    DirectionalAnimationAssetFileCount = $directionalAnimationAssetFiles.Count
    DirectionalSpriteLibraryCategoryFileCount = $directionalSpriteLibraryCategoryFiles.Count
    DirectionStateRuntimeFileCount = $directionStateRuntimeFiles.Count
    DirectionalControllerStateFileCount = $directionalControllerStateFiles.Count
    IncompleteDirectionalLibrarySetCount = $incompleteDirectionalLibrarySets.Count
    LegacyAnimationVariantSetFileCount = $legacyAnimationVariantSetFiles.Count
    LegacyAnimationVariantSourceFileCount = $legacyAnimationVariantSourceFiles.Count
    FrameDataAnimationLibraryOwnerFileCount = $frameDataAnimationLibraryOwnerFiles.Count
    WorkbenchCatalogMissingAnimationLibraryEntryCount = $workbenchCatalogMissingAnimationLibraryEntries.Count
    BasePrefabMissingAnimationLibraryEntryCount = $prefabMissingAnimationLibraryEntries.Count
    ArchitectureContractViolationCount = $architectureContractViolations.Count
    GenerationSettingsViolations = @($generationSettingsViolations)
    LegacyRuntimeFiles = @($legacyRuntimeFiles)
    LegacyIdentifierFiles = @($legacyIdentifierFiles)
    BusinessAssemblyIdentifierFiles = @($businessAssemblyIdentifierFiles)
    DemoSceneMissingPatterns = @($demoSceneMissingPatterns)
    OverrideControllerFiles = @($overrideControllerFiles)
    DirectSpriteAnimationFiles = @($directSpriteAnimationFiles)
    SharedClipMissingSpriteKeyFiles = @($missingSpriteKeyAnimationFiles)
    EmptySpriteLibraryFiles = @($emptySpriteLibraryFiles)
    DirectionalAnimationAssetFiles = @($directionalAnimationAssetFiles)
    DirectionalSpriteLibraryCategoryFiles = @($directionalSpriteLibraryCategoryFiles)
    DirectionStateRuntimeFiles = @($directionStateRuntimeFiles)
    DirectionalControllerStateFiles = @($directionalControllerStateFiles)
    IncompleteDirectionalLibrarySets = @($incompleteDirectionalLibrarySets)
    LegacyAnimationVariantSetFiles = @($legacyAnimationVariantSetFiles)
    LegacyAnimationVariantSourceFiles = @($legacyAnimationVariantSourceFiles)
    FrameDataAnimationLibraryOwnerFiles = @($frameDataAnimationLibraryOwnerFiles)
    WorkbenchCatalogMissingAnimationLibraryEntries = @($workbenchCatalogMissingAnimationLibraryEntries)
    BasePrefabMissingAnimationLibraryEntries = @($prefabMissingAnimationLibraryEntries)
    ArchitectureContractViolations = @($architectureContractViolations)
}

$hasFailures = $report.LegacyRuntimeDirectoryExists -or
    $report.LegacyRuntimeFileCount -gt 0 -or
    $report.GenerationSettingsViolationCount -gt 0 -or
    $report.LegacyIdentifierFileCount -gt 0 -or
    $report.BusinessAssemblyIdentifierFileCount -gt 0 -or
    $report.DemoSceneMissingPatternCount -gt 0 -or
    $report.LegacyGeneratedClipDirectoryExists -or
    $report.LegacyOverrideDirectoryExists -or
    $report.OverrideControllerFileCount -gt 0 -or
    $report.DirectSpriteAnimationFileCount -gt 0 -or
    $report.SharedClipMissingSpriteKeyCount -gt 0 -or
    $report.EmptySpriteLibraryFileCount -gt 0 -or
    $report.DirectionalAnimationAssetFileCount -gt 0 -or
    $report.DirectionalSpriteLibraryCategoryFileCount -gt 0 -or
    $report.DirectionStateRuntimeFileCount -gt 0 -or
    $report.DirectionalControllerStateFileCount -gt 0 -or
    $report.IncompleteDirectionalLibrarySetCount -gt 0 -or
    $report.LegacyAnimationVariantSetFileCount -gt 0 -or
    $report.LegacyAnimationVariantSourceFileCount -gt 0 -or
    $report.FrameDataAnimationLibraryOwnerFileCount -gt 0 -or
    $report.WorkbenchCatalogMissingAnimationLibraryEntryCount -gt 0 -or
    $report.BasePrefabMissingAnimationLibraryEntryCount -gt 0 -or
    $report.ArchitectureContractViolationCount -gt 0

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    if ($hasFailures) { exit 2 }
    exit 0
}

Write-Host "FantasyWord equipment-system static gate"
Write-Host ("ProjectRoot: {0}" -f $report.ProjectRoot)
Write-Host ("Equipment data root: {0}" -f $report.EquipmentDataRoot)
Write-Host ("Generation settings: {0}" -f $report.GenerationSettingsPath)
Write-Host ("Animation root: {0}" -f $report.AnimationRoot)
Write-Host ("Shared clip root: {0}" -f $report.SharedClipRoot)
Write-Host ("SpriteLibrary root: {0}" -f $report.SpriteLibraryRoot)
Write-Host ("Controller path: {0}" -f $report.ControllerPath)
Write-Host ("Workbench catalog path: {0}" -f $report.WorkbenchCatalogPath)
Write-Host ("Demo scene: {0}" -f $report.DemoScenePath)
Write-Host ("Generation settings violations: {0}" -f $report.GenerationSettingsViolationCount)
foreach ($violation in $report.GenerationSettingsViolations) {
    Write-Host ("  [generation-settings] {0}" -f $violation)
}
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

Write-Host ("Legacy generated clip directory exists: {0}" -f $report.LegacyGeneratedClipDirectoryExists)
Write-Host ("Legacy override directory exists: {0}" -f $report.LegacyOverrideDirectoryExists)
Write-Host ("Override controllers: {0}" -f $report.OverrideControllerFileCount)
Write-Host ("Direct Sprite animation clips: {0}" -f $report.DirectSpriteAnimationFileCount)
Write-Host ("Shared clips missing SpriteResolver key curves: {0}" -f $report.SharedClipMissingSpriteKeyCount)
Write-Host ("Empty generated SpriteLibrary assets: {0}" -f $report.EmptySpriteLibraryFileCount)
Write-Host ("Directional shared animation assets: {0}" -f $report.DirectionalAnimationAssetFileCount)
Write-Host ("Directional SpriteLibrary categories: {0}" -f $report.DirectionalSpriteLibraryCategoryFileCount)
Write-Host ("Legacy direction-state runtime files: {0}" -f $report.DirectionStateRuntimeFileCount)
Write-Host ("Directional Animator controller states: {0}" -f $report.DirectionalControllerStateFileCount)
Write-Host ("Incomplete four-direction library sets: {0}" -f $report.IncompleteDirectionalLibrarySetCount)
Write-Host ("Legacy animation variant set files: {0}" -f $report.LegacyAnimationVariantSetFileCount)
Write-Host ("Legacy animation variant source files: {0}" -f $report.LegacyAnimationVariantSourceFileCount)
Write-Host ("Frame data incorrectly owns animation libraries: {0}" -f $report.FrameDataAnimationLibraryOwnerFileCount)
Write-Host ("Workbench characters missing animation libraries: {0}" -f $report.WorkbenchCatalogMissingAnimationLibraryEntryCount)
Write-Host ("Base prefab missing default animation libraries: {0}" -f $report.BasePrefabMissingAnimationLibraryEntryCount)
Write-Host ("Animation architecture contract violations: {0}" -f $report.ArchitectureContractViolationCount)

if ($hasFailures) {
    exit 2
}

exit 0
