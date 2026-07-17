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
$addressablesDataPath = Join-Path $ProjectRoot "Assets/AddressableAssetsData"
$fwResPath = Join-Path $resourcesRoot "Generated/FWRes.g.cs"
$fwScenePath = Join-Path $resourcesRoot "Generated/FWScene.g.cs"

$addressablesConfigPresent = Test-Path -LiteralPath $addressablesDataPath
$fwResEntryCount = Get-RegexMatchCount -Path $fwResPath -Pattern "new\s+global::YokiFrame\.[A-Za-z0-9_]*ResourceKey"
$fwSceneAssetPathCount = Get-RegexMatchCount -Path $fwScenePath -Pattern '"Assets/Scenes/[^"]+"'

$yooConfigFiles = @()
if (Test-Path -LiteralPath $assetsRoot) {
    $yooConfigFiles = @(
        Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "*\Assets\Plugins\*" -and
                ($_.Name -match "^(Yoo|YooAsset|AssetBundleCollector|PackageManifest).*\.(asset|json|bytes)$")
            } |
            ForEach-Object { ConvertTo-RepoPath $_.FullName }
    )
}

if (-not $addressablesConfigPresent -and $fwResEntryCount -gt 0) {
    [void]$violations.Add("FWRes contains resource keys but Assets/AddressableAssetsData is missing.")
}

if ($fwSceneAssetPathCount -gt 0 -and -not $addressablesConfigPresent) {
    [void]$warnings.Add("FWScene currently contains Unity editor scene paths without Addressables settings; keep it out of formal runtime resource ownership.")
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
            if ($line -match "ResourceSystem\.(LoadAssetAsync|InstantiateAsync|LoadAssetsAsync|LoadCatalog|EnsureAssetExists)" -or
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
    AddressablesConfigPresent = $addressablesConfigPresent
    YooAssetConfigCount = $yooConfigFiles.Count
    YooAssetConfigFiles = $yooConfigFiles
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
