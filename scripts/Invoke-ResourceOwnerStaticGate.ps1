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

function Get-RegexMatchCount {
    param(
        [string]$Path,
        [string]$Pattern
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    $text = Get-Content -Raw -LiteralPath $Path
    return [regex]::Matches($text, $Pattern).Count
}

$violations = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$assetsRoot = Join-Path $ProjectRoot "Assets"
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$resourcesRoot = Join-Path $runtimeRoot "Resources"
$modsRoot = Join-Path $runtimeRoot "Mods"
$formalGasResolverPath = Join-Path $runtimeRoot "Database/Abilities/FormalGasAbilityRuntimeConfigResolver.cs"
$collectorConfigPath = Join-Path $ProjectRoot "Assets/BundleCollectorSetting.asset"
$gameCoreAsmdefPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/FantasyWord.GameCore.asmdef"
$resourceSystemPath = Join-Path $resourcesRoot "ResourceSystem.cs"
$modLoaderPath = Join-Path $modsRoot "ModLoader.cs"
$projectResourcesRoot = Join-Path $ProjectRoot "Assets/Resources"
$fwResPath = Join-Path $resourcesRoot "Generated/FWRes.g.cs"
$fwScenePath = Join-Path $resourcesRoot "Generated/FWScene.g.cs"

$collectorConfigPresent = Test-Path -LiteralPath $collectorConfigPath
$collectorConfigText = if ($collectorConfigPresent) { Get-Content -Raw -LiteralPath $collectorConfigPath } else { "" }
$collectorContractPresent =
    $collectorConfigText -match '(?m)^\s*-\sPackageName:\s*DefaultPackage\s*$' -and
    $collectorConfigText -match '(?m)^\s*EnableAddressable:\s*1\s*$' -and
    $collectorConfigText -match '(?m)^\s*SupportExtensionless:\s*1\s*$' -and
    $collectorConfigText -match '(?m)^\s*-\s*CollectPath:\s*Assets/GameRes/UI/Panels\s*$' -and
    $collectorConfigText -match '(?m)^\s*-\s*CollectPath:\s*Assets/GameRes/Localization\s*$' -and
    ([regex]::Matches($collectorConfigText, '(?m)^\s*AddressRuleName:\s*AddressByFileName\s*$').Count -ge 2) -and
    ([regex]::Matches($collectorConfigText, '(?m)^\s*PackRuleName:\s*PackDirectory\s*$').Count -ge 2) -and
    ([regex]::Matches($collectorConfigText, '(?m)^\s*FilterRuleName:\s*CollectAll\s*$').Count -ge 2)
$fwResEntryCount = Get-RegexMatchCount -Path $fwResPath -Pattern "new\s+global::YokiFrame\.[A-Za-z0-9_]*ResourceKey"
$fwSceneAssetPathCount = Get-RegexMatchCount -Path $fwScenePath -Pattern '"Assets/Scenes/[^"]+"'

$yooConfigFiles = @()
if (Test-Path -LiteralPath $assetsRoot) {
    $yooConfigFiles = @(
        Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "*\Assets\Plugins\*" -and
                ($_.Name -match "^(Yoo|YooAsset|AssetBundleCollector|BundleCollector|PackageManifest).*\.(asset|json|bytes)$")
            } |
            ForEach-Object { ConvertTo-RepoPath $_.FullName }
    )
}

if (-not $collectorConfigPresent) {
    [void]$violations.Add("YooAsset collector config is missing: Assets/BundleCollectorSetting.asset")
}
elseif (-not $collectorContractPresent) {
    [void]$violations.Add("YooAsset collector config does not contain the complete DefaultPackage UI/localization contract.")
}

if ($collectorConfigText -match '(?m)^\s*-\sPackageName:\s*ModSmokePackage\s*$') {
    [void]$violations.Add("Temporary ModSmokePackage must not remain in the formal YooAsset collector config.")
}

if ($fwResEntryCount -gt 0 -and -not $collectorConfigPresent) {
    [void]$violations.Add("FWRes contains resource keys but YooAsset collector config is missing.")
}

if ($fwSceneAssetPathCount -gt 0) {
    [void]$warnings.Add("FWScene stores Build Settings scene paths; scene identity remains separate from YooAsset dynamic-content ownership.")
}

$runtimeAddressablesHits = [System.Collections.Generic.List[string]]::new()
foreach ($path in @($gameCoreAsmdefPath, $resourceSystemPath, $modLoaderPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        if ($line -match "UniTask\.Addressables|Unity\.Addressables|Unity\.ResourceManager|UnityEngine\.AddressableAssets|LoadContentCatalogAsync|LoadCatalogAsync") {
            [void]$runtimeAddressablesHits.Add(("{0}:{1}: {2}" -f (ConvertTo-RepoPath $path), $lineNumber, $line.Trim()))
        }
    }
}

foreach ($hit in $runtimeAddressablesHits) {
    [void]$violations.Add("GameCore dynamic resources must use YooAsset instead of Addressables: $hit")
}

$unexpectedResourcesAssets = @()
if (Test-Path -LiteralPath $projectResourcesRoot) {
    $unexpectedResourcesAssets = @(
        Get-ChildItem -LiteralPath $projectResourcesRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -ne ".meta" -and
                $_.Name -ne "DOTweenSettings.asset"
            } |
            ForEach-Object { ConvertTo-RepoPath $_.FullName }
    )
}

foreach ($asset in $unexpectedResourcesAssets) {
    [void]$violations.Add("Project gameplay/content assets must not return to Assets/Resources: $asset")
}

$directRuntimeResourceUsages = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $runtimeRoot) {
    $runtimeFiles = Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File -Filter "*.cs" |
        Where-Object {
            $fullName = $_.FullName
            -not $fullName.StartsWith($resourcesRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
            -not $fullName.StartsWith($modsRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::Equals($fullName, $formalGasResolverPath, [System.StringComparison]::OrdinalIgnoreCase)
        }

    foreach ($file in $runtimeFiles) {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            if ($line -match "ResourceSystem\.(LoadAssetAsync|InstantiateAsync|LoadAssetsAsync|EnsureAssetExists)" -or
                $line -match "new\s+SoftAssetReference" -or
                $line -match "SoftAssetReference\s*<" -or
                $line -match "\bFWRes\.") {
                [void]$directRuntimeResourceUsages.Add(("{0}:{1}: {2}" -f (ConvertTo-RepoPath $file.FullName), $lineNumber, $line.Trim()))
            }
        }
    }
}

foreach ($usage in $directRuntimeResourceUsages) {
    [void]$violations.Add("Formal GameCore runtime must not bypass database ownership with ResourceSystem/FWRes: $usage")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    CollectorConfigPresent = $collectorConfigPresent
    CollectorContractPresent = $collectorContractPresent
    YooAssetConfigCount = $yooConfigFiles.Count
    YooAssetConfigFiles = $yooConfigFiles
    RuntimeAddressablesHitCount = $runtimeAddressablesHits.Count
    RuntimeAddressablesHits = $runtimeAddressablesHits
    UnexpectedResourcesAssetCount = $unexpectedResourcesAssets.Count
    UnexpectedResourcesAssets = $unexpectedResourcesAssets
    FWResEntryCount = $fwResEntryCount
    FWSceneEditorPathCount = $fwSceneAssetPathCount
    DirectRuntimeResourceOwnerBypassCount = $directRuntimeResourceUsages.Count
    DirectRuntimeResourceOwnerBypasses = $directRuntimeResourceUsages
    WarningCount = $warnings.Count
    Warnings = $warnings
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Resource owner static gate passed."
    }
    else {
        Write-Host "Resource owner static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }

    foreach ($warning in $warnings) {
        Write-Host " warning: $warning"
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
