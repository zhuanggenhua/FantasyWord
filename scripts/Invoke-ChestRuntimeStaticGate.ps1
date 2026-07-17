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

function Get-CSharpMethodBlock {
    param(
        [string]$Text,
        [string]$MethodName
    )

    $lines = $Text -split "`r?`n"
    $capturing = $false
    $sawOpeningBrace = $false
    $braceDepth = 0
    $block = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if (-not $capturing) {
            if ($line -notmatch ("\b{0}\s*\(" -f [regex]::Escape($MethodName))) {
                continue
            }

            $capturing = $true
        }

        [void]$block.Add($line)

        foreach ($char in $line.ToCharArray()) {
            if ($char -eq '{') {
                $braceDepth++
                $sawOpeningBrace = $true
            }
            elseif ($char -eq '}') {
                $braceDepth--
            }
        }

        if ($sawOpeningBrace -and $braceDepth -le 0) {
            return ($block -join "`n")
        }
    }

    return ($block -join "`n")
}

$violations = [System.Collections.Generic.List[string]]::new()
$chestPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Entities/Chest.cs"
$chestText = if (Test-Path -LiteralPath $chestPath) { Get-Content -Raw -LiteralPath $chestPath } else { "" }

if ([string]::IsNullOrWhiteSpace($chestText)) {
    [void]$violations.Add("Chest.cs is missing or empty.")
}

$tryOpenMatch = [System.Text.RegularExpressions.Regex]::Match(
    $chestText,
    "public\s+async\s+Task<bool>\s+TryOpen\s*\(\s*CharacterBase\s+opener\s*\)[\s\S]*?return\s+await\s+TryOpenContainerInventory\s*\(\s*opener,\s*commandContext\s*\)\s*;\s*\}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$tryOpenBlock = if ($tryOpenMatch.Success) { $tryOpenMatch.Value } else { "" }
$tryRevealBlock = Get-CSharpMethodBlock -Text $chestText -MethodName "TryPlayContentRevealAnimation"
$onDisableBlock = Get-CSharpMethodBlock -Text $chestText -MethodName "OnDisable"
$onDestroyBlock = Get-CSharpMethodBlock -Text $chestText -MethodName "OnDestroy"
$onLoadBlock = Get-CSharpMethodBlock -Text $chestText -MethodName "OnLoad"

$openedAssignmentIndex = $tryOpenBlock.IndexOf("m_opened = true", [System.StringComparison]::Ordinal)
$playQueueIndex = $tryOpenBlock.IndexOf("await GameManager.DialogueSystem.PlayQueue", [System.StringComparison]::Ordinal)

$firstOpenReentryGuarded =
    $chestText -match "bool\s+m_opening\s*=\s*false" -and
    $tryOpenBlock -match "if\s*\(\s*m_opening\s*\)[\s\S]*?return\s+false\s*;" -and
    $tryOpenBlock -match "m_opening\s*=\s*true\s*;" -and
    $tryOpenBlock -match "try\s*\{" -and
    $tryOpenBlock -match "finally\s*\{[\s\S]*?m_opening\s*=\s*false\s*;" -and
    $openedAssignmentIndex -ge 0 -and
    $playQueueIndex -ge 0 -and
    $openedAssignmentIndex -lt $playQueueIndex -and
    $onLoadBlock -match "m_opening\s*=\s*false\s*;"
if (-not $firstOpenReentryGuarded) {
    [void]$violations.Add(("{0}: Chest first-open flow must guard reentry, clear the opening flag in finally/load, and commit opened before awaiting dialogue playback." -f (ConvertTo-RepoPath $chestPath)))
}

$contentRevealCoroutineLifecycleBound =
    $chestText -match "Coroutine\s+m_contentRevealCoroutine\s*=\s*null" -and
    $tryRevealBlock -match "StopContentRevealCoroutine\s*\(\s*\)" -and
    $tryRevealBlock -match "m_contentRevealCoroutine\s*=\s*StartCoroutine\s*\(" -and
    $onDisableBlock -match "StopContentRevealCoroutine\s*\(\s*\)" -and
    $onDestroyBlock -match "StopContentRevealCoroutine\s*\(\s*\)" -and
    $onLoadBlock -match "StopContentRevealCoroutine\s*\(\s*\)" -and
    $chestText -match "StopCoroutine\s*\(\s*m_contentRevealCoroutine\s*\)" -and
    $chestText -match "m_contentRevealCoroutine\s*=\s*null"
if (-not $contentRevealCoroutineLifecycleBound) {
    [void]$violations.Add(("{0}: Chest content reveal coroutine must be tracked and stopped on replacement, disable, destroy, and load." -f (ConvertTo-RepoPath $chestPath)))
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    FirstOpenReentryGuarded = $firstOpenReentryGuarded
    ContentRevealCoroutineLifecycleBound = $contentRevealCoroutineLifecycleBound
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Chest runtime static gate passed."
    }
    else {
        Write-Host "Chest runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
