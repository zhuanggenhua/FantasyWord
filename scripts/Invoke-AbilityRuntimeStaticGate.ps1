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

$violations = [System.Collections.Generic.List[string]]::new()
$abilityRuntimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Combat/Abilities"
$activeAbilityRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active"
$activeAbilityBasePath = Join-Path $activeAbilityRoot "ActiveAbilityBase.cs"
$formalGameplayTagCatalogPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Combat/FormalGameplayTagCatalog.cs"
$gameplayTagTablePath = Join-Path $ProjectRoot "Assets/DataGenerated/Luban/Json/GAS/exgas_tbgameplaytags.json"
$legacyAbilityShimRelativePaths = @(
    "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Ability.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbility.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Passive/PassiveAbility.cs",
    "Assets/Scripts/GameCore/Runtime/Combat/Abilities/Passive/PassiveAbilityBase.cs"
)

$legacyAbilityShimsRemoved = $true
foreach ($relativePath in $legacyAbilityShimRelativePaths) {
    $legacyPath = Join-Path $ProjectRoot $relativePath
    if (Test-Path -LiteralPath $legacyPath) {
        $legacyAbilityShimsRemoved = $false
        [void]$violations.Add(("{0}: legacy AbilitySheet wrapper must not return; formal runtime identity comes from EX-GAS ability code." -f (ConvertTo-RepoPath $legacyPath)))
    }
}

$legacyAbilitySheetRuntimeTypesAbsent = $true
if (Test-Path -LiteralPath $abilityRuntimeRoot) {
    $legacyTypePattern = "\bclass\s+(Ability|ActiveAbility|PassiveAbility|PassiveAbilityBase|AbilitySheet|ActiveAbilitySheet|PassiveAbilitySheet|DashAbilitySheet|ProjectileAbilitySheet|SummoningAbilitySheet|ContactDamageAbilitySheet|TickingAbilitySheet)\b"
    foreach ($file in Get-ChildItem -LiteralPath $abilityRuntimeRoot -Recurse -File -Filter "*.cs") {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        if ($text -match $legacyTypePattern) {
            $legacyAbilitySheetRuntimeTypesAbsent = $false
            [void]$violations.Add(("{0}: runtime ability code must not declare legacy Ability/AbilitySheet wrapper types." -f (ConvertTo-RepoPath $file.FullName)))
        }
    }
}

$legacyTemporalRuleEffectTypeNames = @(
    "TemporalDamageEffect",
    "TemporalHealEffect",
    "TemporalRestoreManaEffect",
    "TemporalStatModifierEffect",
    "TemporalSpeedModifierEffect",
    "TemporalControlEffect",
    "FantasyWord.GameCore.TemporalDamageEffect",
    "FantasyWord.GameCore.TemporalHealEffect",
    "FantasyWord.GameCore.TemporalRestoreManaEffect",
    "FantasyWord.GameCore.TemporalStatModifierEffect",
    "FantasyWord.GameCore.TemporalSpeedModifierEffect",
    "FantasyWord.GameCore.TemporalControlEffect"
)
$legacyTemporalRuleEffectAssetReferenceHits = [System.Collections.Generic.List[string]]::new()
$assetReferenceExtensions = @(
    ".asset",
    ".prefab",
    ".unity",
    ".anim",
    ".controller",
    ".overrideController"
)
$assetsRoot = Join-Path $ProjectRoot "Assets"
if (Test-Path -LiteralPath $assetsRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $assetsRoot -Recurse -File) {
        $repoPath = ConvertTo-RepoPath $file.FullName
        if ($repoPath -like "Assets/Scripts/*" -or
            $repoPath -like "Assets/Editor/*" -or
            $repoPath -like "Assets/Plugins/*" -or
            $repoPath -like "*.meta") {
            continue
        }

        if ($assetReferenceExtensions -notcontains $file.Extension) {
            continue
        }

        $text = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction SilentlyContinue
        foreach ($typeName in $legacyTemporalRuleEffectTypeNames) {
            if ($text -like "*$typeName*") {
                [void]$legacyTemporalRuleEffectAssetReferenceHits.Add(("{0}: formal assets must not reference legacy temporal rule effect type [{1}]; use EX-GAS GameplayEffect/Timeline or an explicit migration-only path." -f $repoPath, $typeName))
                break
            }
        }
    }
}
$legacyTemporalRuleEffectAssetReferencesAbsent = $legacyTemporalRuleEffectAssetReferenceHits.Count -eq 0
if (-not $legacyTemporalRuleEffectAssetReferencesAbsent) {
    foreach ($hit in $legacyTemporalRuleEffectAssetReferenceHits) {
        [void]$violations.Add($hit)
    }
}

$activeAbilityBaseAnimatorTriggerPathRemoved = $false
if (Test-Path -LiteralPath $activeAbilityBasePath) {
    $activeAbilityBaseText = Get-Content -Raw -LiteralPath $activeAbilityBasePath
    $activeAbilityBaseAnimatorTriggerPathRemoved =
        $activeAbilityBaseText -notmatch "m_characterAnimator" -and
        $activeAbilityBaseText -notmatch "ResolveCharacterAnimator\s*\(" -and
        $activeAbilityBaseText -notmatch "TrySetCharacterAnimatorTrigger\s*\(" -and
        $activeAbilityBaseText -notmatch "TrySetAnimatorTrigger\s*\(" -and
        $activeAbilityBaseText -notmatch "GetComponentInChildren\s*<\s*Animator\s*>" -and
        $activeAbilityBaseText -notmatch "AnimatorControllerParameter" -and
        $activeAbilityBaseText -notmatch "\.SetTrigger\s*\("

    if (-not $activeAbilityBaseAnimatorTriggerPathRemoved) {
        [void]$violations.Add("ActiveAbilityBase must not own Animator trigger helpers or resolve child Animator; formal ability animation goes through ICharacterAnimationDriver or gameplay cues.")
    }
}
else {
    [void]$violations.Add("ActiveAbilityBase.cs is missing.")
}

$activeAbilityRuntimeNoDirectAnimatorTrigger = $true
if (Test-Path -LiteralPath $activeAbilityRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $activeAbilityRoot -Recurse -File -Filter "*.cs") {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        $forbiddenPatterns = @(
            "GetComponentInChildren\s*<\s*Animator\s*>",
            "AnimatorControllerParameter",
            "\.SetTrigger\s*\(",
            "TrySetCharacterAnimatorTrigger\s*\(",
            "TrySetAnimatorTrigger\s*\("
        )

        foreach ($pattern in $forbiddenPatterns) {
            if ($text -match $pattern) {
                $activeAbilityRuntimeNoDirectAnimatorTrigger = $false
                [void]$violations.Add(("{0}: active ability runtime must not drive Animator trigger/path logic directly: {1}" -f (ConvertTo-RepoPath $file.FullName), $pattern))
            }
        }
    }
}
else {
    $activeAbilityRuntimeNoDirectAnimatorTrigger = $false
    [void]$violations.Add("Active ability runtime folder is missing.")
}

$formalAttackingTagGeneratedFromLubanTable = $false
if (Test-Path -LiteralPath $gameplayTagTablePath) {
    $tagRows = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $gameplayTagTablePath | ConvertFrom-Json)
    $attackingTagRows = @($tagRows | ForEach-Object { $_ } | Where-Object { $_.Name -eq "Event.Attacking" })
    $attackingTagId = if ($attackingTagRows.Count -eq 1) {
        @($attackingTagRows[0].id | Select-Object -First 1)[0]
    }
    else {
        0
    }

    if ($attackingTagRows.Count -eq 1 -and [int]$attackingTagId -gt 0) {
        $formalAttackingTagGeneratedFromLubanTable = $true
    }
    else {
        [void]$violations.Add(("{0}: EX-GAS gameplay tag table must contain exactly one positive Event.Attacking tag id." -f (ConvertTo-RepoPath $gameplayTagTablePath)))
    }
}
else {
    [void]$violations.Add("Assets/DataGenerated/Luban/Json/GAS/exgas_tbgameplaytags.json is missing.")
}

$formalGameplayTagCatalogDoesNotDirectlyReferenceGeneratedXTag = $false
$formalGameplayTagCatalogUsesGeneratedTagReflection = $false
if (Test-Path -LiteralPath $formalGameplayTagCatalogPath) {
    $formalGameplayTagCatalogText = Get-Content -Raw -LiteralPath $formalGameplayTagCatalogPath
    $formalGameplayTagCatalogDoesNotDirectlyReferenceGeneratedXTag =
        $formalGameplayTagCatalogText -notmatch "\bXTag\s*\.\s*Event_Attacking\b" -and
        $formalGameplayTagCatalogText -notmatch "using\s+GAS\.Runtime\s*;"
    $formalGameplayTagCatalogUsesGeneratedTagReflection =
        $formalGameplayTagCatalogText -match "ResolveRequiredGeneratedTagCode\s*\(\s*""Event_Attacking""" -and
        $formalGameplayTagCatalogText -match "GAS\.Runtime\.XTag"

    if (-not $formalGameplayTagCatalogDoesNotDirectlyReferenceGeneratedXTag) {
        [void]$violations.Add(("{0}: GameCore must not directly compile against generated XTag constants; generated GAS runtime already references GameCore." -f (ConvertTo-RepoPath $formalGameplayTagCatalogPath)))
    }

    if (-not $formalGameplayTagCatalogUsesGeneratedTagReflection) {
        [void]$violations.Add(("{0}: Formal gameplay tag catalog must resolve Event.Attacking from generated EX-GAS tag symbols without an asmdef back-reference." -f (ConvertTo-RepoPath $formalGameplayTagCatalogPath)))
    }
}
else {
    [void]$violations.Add("FormalGameplayTagCatalog.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    LegacyAbilityShimsRemoved = $legacyAbilityShimsRemoved
    LegacyAbilitySheetRuntimeTypesAbsent = $legacyAbilitySheetRuntimeTypesAbsent
    LegacyTemporalRuleEffectAssetReferencesAbsent = $legacyTemporalRuleEffectAssetReferencesAbsent
    LegacyTemporalRuleEffectAssetReferenceHitCount = $legacyTemporalRuleEffectAssetReferenceHits.Count
    LegacyTemporalRuleEffectAssetReferenceHits = $legacyTemporalRuleEffectAssetReferenceHits
    ActiveAbilityBaseAnimatorTriggerPathRemoved = $activeAbilityBaseAnimatorTriggerPathRemoved
    ActiveAbilityRuntimeNoDirectAnimatorTrigger = $activeAbilityRuntimeNoDirectAnimatorTrigger
    FormalAttackingTagGeneratedFromLubanTable = $formalAttackingTagGeneratedFromLubanTable
    FormalGameplayTagCatalogDoesNotDirectlyReferenceGeneratedXTag = $formalGameplayTagCatalogDoesNotDirectlyReferenceGeneratedXTag
    FormalGameplayTagCatalogUsesGeneratedTagReflection = $formalGameplayTagCatalogUsesGeneratedTagReflection
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Ability runtime static gate passed."
    }
    else {
        Write-Host "Ability runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
