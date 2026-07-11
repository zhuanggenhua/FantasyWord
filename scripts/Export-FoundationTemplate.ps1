[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [ValidateSet("core", "full")]
    [string]$Profile = "full"
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

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-RelativeItem {
    param(
        [string]$BaseRoot,
        [string]$RelativePath,
        [string]$DestinationRoot
    )

    $sourcePath = Join-Path $BaseRoot $RelativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Template item not found: $sourcePath"
    }

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    Ensure-Directory -Path (Split-Path -Parent $destinationPath)

    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        Ensure-Directory -Path $destinationPath
        $null = robocopy $sourcePath $destinationPath /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed: $sourcePath -> $destinationPath, exit code: $LASTEXITCODE"
        }

        $sourceMetaPath = $sourcePath + ".meta"
        $destinationMetaPath = $destinationPath + ".meta"
        if (Test-Path -LiteralPath $sourceMetaPath) {
            Copy-Item -LiteralPath $sourceMetaPath -Destination $destinationMetaPath -Force
        }
        return
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

function Remove-UnapprovedEmptyDirectories {
    param(
        [string]$Root,
        [string[]]$PreservedRelativePaths
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return
    }

    $preserved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $PreservedRelativePaths) {
        [void]$preserved.Add($path.Replace('/', '\').TrimStart('\'))
    }

    $directories = Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending
    foreach ($directory in $directories) {
        $relativePath = $directory.FullName.Substring($Root.Length).TrimStart('\')
        if ($preserved.Contains($relativePath)) {
            continue
        }

        $hasContent = Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hasContent) {
            continue
        }

        Remove-Item -LiteralPath $directory.FullName -Force

        $metaPath = $directory.FullName + ".meta"
        if (Test-Path -LiteralPath $metaPath) {
            Remove-Item -LiteralPath $metaPath -Force
        }
    }
}

$coreItems = @(
    "AGENTS.md",
    ".gitattributes",
    ".gitignore",
    ".agents\skills",
    ".codex\skills",
    "Assets\Scripts\GameCore",
    "Assets\Editor\GameCore",
    "Assets\GameData\GameCore",
    "Assets\Editor\GameCore\Tests",
    "Assets\Editor\GameCore\Tests.meta",
    "Assets\Editor\GameCore\FantasyWord.GameCore.Editor.asmdef",
    "Assets\Editor\GameCore\FantasyWord.GameCore.Editor.asmdef.meta",
    "Assets\Editor\GameCore\Tests\FantasyWord.GameCore.EditModeTests.asmdef",
    "Assets\Editor\GameCore\Tests\FantasyWord.GameCore.EditModeTests.asmdef.meta",
    ".spec",
    "openspec\AGENTS.md",
    "openspec\project.md",
    "scripts",
    "openspec\changes\define-fantasyword-foundation-framework"
)

$fullOnlyItems = @(
    "ProjectSettings",
    "ProjectSettings\SceneTemplateSettings.json",
    "Packages\manifest.json",
    "Packages\packages-lock.json",
    "Packages\com.aibridge.unity",
    "Assets\Database",
    "Assets\GameData\EquipmentSystem",
    "Assets\Prefabs",
    "Assets\Scenes\SampleScene.unity",
    "Assets\Scenes\SampleScene.unity.meta",
    "Assets\Scenes\EquipmentSystemDemo.unity",
    "Assets\Scenes\EquipmentSystemDemo.unity.meta",
    "Assets\Scripts\Presentation\EquipmentSystem",
    "Assets\Settings",
    "Assets\UniversalRenderPipelineGlobalSettings.asset",
    "Assets\UniversalRenderPipelineGlobalSettings.asset.meta",
    "Assets\InputSystem_Actions.inputactions",
    "Assets\InputSystem_Actions.inputactions.meta",
    "Assets\Plugins\NaughtyAttributes",
    "Assets\Plugins\MackySoft.SerializeReferenceExtensions",
    "Assets\Plugins\azixMcAze.SerializableDictionary",
    "Assets\Plugins\GAS",
    "Assets\Plugins\TopDownEngine",
    "Assets\Plugins\YokiFrame",
    "Assets\Plugins\UniTask",
    "Assets\Plugins\BroAudio",
    "ReferenceSources"
)

$itemsToCopy = [System.Collections.Generic.List[string]]::new()
$coreItems | ForEach-Object { [void]$itemsToCopy.Add($_) }

if ($Profile -eq "full") {
    $fullOnlyItems | ForEach-Object { [void]$itemsToCopy.Add($_) }
}

Ensure-Directory -Path $OutputRoot

foreach ($item in $itemsToCopy) {
    Copy-RelativeItem -BaseRoot $ProjectRoot -RelativePath $item -DestinationRoot $OutputRoot
}

$preservedEmptyDirectories = @(
    "Assets\Scripts\Presentation\EquipmentSystem\Tools",
    "Assets\Scripts\Presentation\EquipmentSystem\Shaders\Includes",
    ".codex\skills\unity-production\agents"
)

Remove-UnapprovedEmptyDirectories -Root $OutputRoot -PreservedRelativePaths $preservedEmptyDirectories

$manifest = [ordered]@{
    exportedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    projectRoot = $ProjectRoot
    profile = $Profile
    items = $itemsToCopy
}

$manifestPath = Join-Path $OutputRoot "foundation-template-manifest.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "Foundation template export finished."
Write-Host "OutputRoot:" $OutputRoot
Write-Host "Profile:" $Profile
