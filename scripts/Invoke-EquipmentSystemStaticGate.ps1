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
$equipmentDataRoot = Join-Path $projectRoot "Assets/GameData/EquipmentSystem"
$animationRoot = Join-Path $equipmentDataRoot "Animations"
$sharedClipRoot = Join-Path $animationRoot "SharedClips"
$spriteLibraryRoot = Join-Path $animationRoot "SpriteLibraries"
$legacyAnimationVariantSetRoot = Join-Path $animationRoot "CharacterAnimationVariants"
$controllerPath = Join-Path $animationRoot "换装共享动画状态机.controller"
$frameDataRoot = Join-Path $equipmentDataRoot "FrameData"
$workbenchCatalogPath = Join-Path $equipmentDataRoot "Data/Workbench/换装工作台目录.asset"
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
        if ($_.BaseName -match '^(?<Character>.+)_(?<Direction>SE|SW|NE|NW)动画精灵库$') {
            return $Matches.Character
        }

        return "[invalid] " + $_.BaseName
    }
    foreach ($group in $libraryGroups) {
        $directions = @($group.Group | ForEach-Object {
            if ($_.BaseName -match '_(SE|SW|NE|NW)动画精灵库$') { $Matches[1] }
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

$actionControllerPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/AnimationController.cs"
$directionDriverPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime/DirectionalAnimationVariantDriver.cs"
$animationBuilderPath = Join-Path $projectRoot "Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/EquipmentWorkbenchAnimatorControllerTool.cs"
$actionControllerContent = Get-FileContent -Path $actionControllerPath
$directionDriverContent = Get-FileContent -Path $directionDriverPath
$animationBuilderContent = Get-FileContent -Path $animationBuilderPath
if ($actionControllerContent -match 'using\s+UnityEngine\.U2D\.Animation|SpriteLibraryAsset|SpriteLibrary\s+[_a-zA-Z]|CurrentDirection|SetDirection\s*\(|SetFacingDirection\s*\(') {
    [void]$architectureContractViolations.Add("AnimationController owns direction or SpriteLibrary")
}
if ($directionDriverContent -match 'Animator\.Play|GetComponent(?:InParent|InChildren)?<Animator>|\bAnimator\s+[_a-zA-Z]') {
    [void]$architectureContractViolations.Add("DirectionalAnimationVariantDriver drives Animator")
}
if ($animationBuilderContent -match 'EditorSceneManager|SceneManager|PrefabUtility') {
    [void]$architectureContractViolations.Add("Animation asset builder writes scenes or prefabs")
}

$demoSceneContent = Get-FileContent -Path $demoScenePath
$demoSceneMissingPatterns = New-Object System.Collections.Generic.List[string]
foreach ($pattern in @(
    "m_Name: EquipmentSystemDemoCharacter",
    "m_EditorClassIdentifier: ::DirectionalAnimationVariantDriver",
    "m_EditorClassIdentifier: ::EquipmentRenderer",
    "m_EditorClassIdentifier: ::AnimationController",
    "UnityEngine.U2D.Animation.SpriteResolver",
    "UnityEngine.U2D.Animation.SpriteLibrary",
    "m_Controller:"
)) {
    if (-not $demoSceneContent.Contains($pattern)) {
        [void]$demoSceneMissingPatterns.Add($pattern)
    }
}

$report = [ordered]@{
    ProjectRoot = $projectRoot
    EquipmentDataRoot = $equipmentDataRoot
    DemoScenePath = $demoScenePath
    LegacyRuntimeDirectoryExists = $legacyRuntimeDirectoryExists
    LegacyRuntimeFileCount = @($legacyRuntimeFiles).Count
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
Write-Host ("Demo scene: {0}" -f $report.DemoScenePath)
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
