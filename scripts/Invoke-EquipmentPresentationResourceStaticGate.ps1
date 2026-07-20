param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Read-Text {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path
    }

    return ""
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

$violations = [System.Collections.Generic.List[string]]::new()
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/Presentation/EquipmentSystem/Runtime"
$workbenchPrefabPath = Join-Path $ProjectRoot "Assets/GameRes/UI/Panels/UIEquipmentWorkbench.prefab"
$rendererPath = Join-Path $ProjectRoot "Assets/Settings/Renderer2D.asset"

Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File -Filter *.cs | ForEach-Object {
    $text = Read-Text $_.FullName
    if ($text -match 'Resources\.Load') {
        [void]$violations.Add(("{0}: presentation runtime must not load assets by Resources.Load string paths." -f (Convert-ToProjectRelativePath $ProjectRoot $_.FullName)))
    }
}

$prefabText = Read-Text $workbenchPrefabPath
if ($prefabText -notmatch '(?m)^\s*workbenchFont:\s*\{fileID:\s*(?!0(?:,|\}))') {
    [void]$violations.Add("Assets/GameRes/UI/Panels/UIEquipmentWorkbench.prefab: EquipmentWorkbenchRuntimeUI must bind workbenchFont explicitly.")
}

$rendererText = Read-Text $rendererPath
if ($rendererText -notmatch '(?ms)m_EditorClassIdentifier:\s*Assembly-CSharp::EquipmentSystem\.HQ4xRendererFeature.*?lut:\s*\{fileID:\s*(?!0(?:,|\}))') {
    [void]$violations.Add("Assets/Settings/Renderer2D.asset: HQ4xRendererFeature must bind LUT explicitly.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    RuntimeRoot = Convert-ToProjectRelativePath $ProjectRoot $runtimeRoot
    WorkbenchPrefabPath = Convert-ToProjectRelativePath $ProjectRoot $workbenchPrefabPath
    RendererPath = Convert-ToProjectRelativePath $ProjectRoot $rendererPath
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Equipment presentation resource static gate passed."
    }
    else {
        Write-Host "Equipment presentation resource static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
