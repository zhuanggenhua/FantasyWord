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

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $normalizedPath = [System.IO.Path]::GetFullPath($FullPath)

    if ($normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($normalizedRoot.Length).TrimStart('\')
    }

    return $normalizedPath
}

$projectRoot = Get-ProjectRoot
$scriptsRoot = Join-Path $projectRoot "Assets\Scripts"
$editorRoot = Join-Path $projectRoot "Assets\Editor"

$requiredDirectories = @(
    "Assets\Scripts\GameCore\Runtime",
    "Assets\Editor\GameCore",
    "Assets\Plugins\TopDownEngine",
    "Assets\Plugins\YokiFrame"
)

$forbiddenLayerPatterns = @(
    '(^|\\)(Compatibility|Compat|FoundationSupport|Adapter|Adapters|Wrapper|Wrappers|Facade|Facades)(\\|$)',
    '\b(class|struct|interface)\s+[A-Za-z0-9_]*(Compatibility|Compat|FoundationSupport|Adapter|Wrapper|Facade)[A-Za-z0-9_]*\b'
)

$missingDirectories = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $requiredDirectories) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        [void]$missingDirectories.Add($relativePath)
    }
}

$violations = New-Object System.Collections.Generic.List[object]
$scanRoots = @($scriptsRoot, $editorRoot)
$codeFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($root in $scanRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -Filter *.cs -File) {
        [void]$codeFiles.Add($file)
    }
}

foreach ($file in $codeFiles) {
    $relativePath = Get-RelativePath -ProjectRoot $projectRoot -FullPath $file.FullName

    foreach ($pattern in $forbiddenLayerPatterns) {
        if ($relativePath -match $pattern) {
            [void]$violations.Add([ordered]@{
                    RelativePath = $relativePath
                    LineNumber   = 0
                    Line         = "Forbidden path segment"
                })
        }
    }

    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        $lineNumber++
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith("//") -or $trimmed.StartsWith("///") -or $trimmed.StartsWith("*")) {
            continue
        }

        foreach ($pattern in $forbiddenLayerPatterns) {
            if ($line -match $pattern) {
                [void]$violations.Add([ordered]@{
                        RelativePath = $relativePath
                        LineNumber   = $lineNumber
                        Line         = $line.Trim()
                    })
            }
        }
    }
}

$dedupedViolations = @($violations.ToArray() |
    Group-Object -Property RelativePath, LineNumber, Line |
    ForEach-Object { $_.Group[0] })

$runtimeDirectories = @()
$runtimeRoot = Join-Path $projectRoot "Assets\Scripts\GameCore\Runtime"
if (Test-Path -LiteralPath $runtimeRoot) {
    $runtimeDirectories = @(Get-ChildItem -LiteralPath $runtimeRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

$editorDirectories = @()
$projectEditorRoot = Join-Path $projectRoot "Assets\Editor\GameCore"
if (Test-Path -LiteralPath $projectEditorRoot) {
    $editorDirectories = @(Get-ChildItem -LiteralPath $projectEditorRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

$pluginDirectories = @()
$pluginsRoot = Join-Path $projectRoot "Assets\Plugins"
if (Test-Path -LiteralPath $pluginsRoot) {
    $pluginDirectories = @(Get-ChildItem -LiteralPath $pluginsRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

$report = [ordered]@{
    Passed                     = ($missingDirectories.Count -eq 0 -and $dedupedViolations.Count -eq 0)
    MissingDirectoryCount      = $missingDirectories.Count
    MissingDirectories         = @($missingDirectories.ToArray())
    CompatibilityViolationCount = $dedupedViolations.Count
    CompatibilityViolations    = $dedupedViolations
    RuntimeDirectories         = $runtimeDirectories
    EditorDirectories          = $editorDirectories
    PluginDirectories          = $pluginDirectories
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
}
else {
    Write-Host ("Passed: {0}" -f $report.Passed)
    Write-Host ("MissingDirectoryCount: {0}" -f $report.MissingDirectoryCount)
    foreach ($entry in $report.MissingDirectories) {
        Write-Host ("  Missing: {0}" -f $entry)
    }

    Write-Host ("CompatibilityViolationCount: {0}" -f $report.CompatibilityViolationCount)
    foreach ($entry in $report.CompatibilityViolations) {
        if ($entry.LineNumber -gt 0) {
            Write-Host ("  {0}:{1}: {2}" -f $entry.RelativePath, $entry.LineNumber, $entry.Line)
        }
        else {
            Write-Host ("  {0}: {1}" -f $entry.RelativePath, $entry.Line)
        }
    }

    Write-Host ("RuntimeDirectories: {0}" -f ($report.RuntimeDirectories -join ", "))
    Write-Host ("EditorDirectories: {0}" -f ($report.EditorDirectories -join ", "))
    Write-Host ("PluginDirectories: {0}" -f ($report.PluginDirectories -join ", "))
}

if (-not $report.Passed) {
    exit 1
}
