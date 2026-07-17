param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$violations = [System.Collections.Generic.List[string]]::new()
$systemRegistryPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Game/GameManager.SystemRegistryRuntime.cs"
$systemRegistryText = if (Test-Path -LiteralPath $systemRegistryPath) {
    Get-Content -Raw -LiteralPath $systemRegistryPath
}
else {
    ""
}

if ([string]::IsNullOrWhiteSpace($systemRegistryText)) {
    [void]$violations.Add("GameManager system registry runtime file is missing or empty.")
}

$hasSystemGuardsInstance =
    $systemRegistryText -match "public\s+static\s+bool\s+HasSystem\s*<\s*T\s*>\s*\(\s*\)[\s\S]*?_instance\s*!=\s*null[\s\S]*?_instance\.m_systems\s*!=\s*null[\s\S]*?ContainsKey\s*\("
if (-not $hasSystemGuardsInstance) {
    [void]$violations.Add("GameManager.HasSystem must guard missing GameManager instance and missing system registry.")
}

$tryGetSystemGuardsInstance =
    $systemRegistryText -match "public\s+static\s+bool\s+TryGetSystem\s*<\s*T\s*>\s*\(\s*out\s+T\s+system\s*\)[\s\S]*?system\s*=\s*null[\s\S]*?_instance\s*==\s*null\s*\|\|\s*_instance\.m_systems\s*==\s*null[\s\S]*?return\s+false[\s\S]*?TryGetValue\s*\("
if (-not $tryGetSystemGuardsInstance) {
    [void]$violations.Add("GameManager.TryGetSystem must return false when the GameManager instance or system registry is not ready.")
}

$getSystemThrowsOnMissingSystem =
    $systemRegistryText -match "public\s+static\s+T\s+GetSystem\s*<\s*T\s*>\s*\(\s*\)[\s\S]*?TryGetSystem\s*\(\s*out\s+T\s+system\s*\)[\s\S]*?return\s+system[\s\S]*?throw\s+new\s+InvalidOperationException"
if (-not $getSystemThrowsOnMissingSystem) {
    [void]$violations.Add("GameManager.GetSystem must use the guarded registry lookup path and throw a clear exception when a formal system is missing.")
}

$duplicateSystemsThrow =
    $systemRegistryText -match "private\s+void\s+FindSystems\s*\(\s*\)[\s\S]*?m_systems\.ContainsKey\s*\(\s*type\s*\)[\s\S]*?throw\s+new\s+InvalidOperationException"
if (-not $duplicateSystemsThrow) {
    [void]$violations.Add("GameManager.FindSystems must throw on duplicate game systems instead of continuing after a debug assert.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    HasSystemGuardsInstance = $hasSystemGuardsInstance
    TryGetSystemGuardsInstance = $tryGetSystemGuardsInstance
    GetSystemThrowsOnMissingSystem = $getSystemThrowsOnMissingSystem
    DuplicateSystemsThrow = $duplicateSystemsThrow
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "GameManager runtime static gate passed."
    }
    else {
        Write-Host "GameManager runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
