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
$modsRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Mods"
$modConfigPath = Join-Path $modsRoot "ModConfig.cs"
$modLoaderPath = Join-Path $modsRoot "ModLoader.cs"

$modStateQueryIsPure = $false
$modStateEnsureIsExplicit = $false
$modStateDeleteConsumeIsExplicit = $false
$modLoaderConsumesDeletedState = $false

if (Test-Path -LiteralPath $modConfigPath) {
    $modConfigText = Get-Content -Raw -LiteralPath $modConfigPath
    $getStateBlock = Get-CSharpMethodBlock -Text $modConfigText -MethodName "GetModState"
    $ensureStateBlock = Get-CSharpMethodBlock -Text $modConfigText -MethodName "EnsureModState"
    $deleteBlock = Get-CSharpMethodBlock -Text $modConfigText -MethodName "DeleteMod"
    $setEnabledBlock = Get-CSharpMethodBlock -Text $modConfigText -MethodName "SetModEnabled"
    $consumeDeletedBlock = Get-CSharpMethodBlock -Text $modConfigText -MethodName "ConsumeDeletedModState"

    $modStateQueryIsPure =
        $getStateBlock -match "TryGetModState\s*\(" -and
        $getStateBlock -match "return\s+ModStatus\.Enabled\s*;" -and
        $getStateBlock -notmatch "States\.(Add|Remove)\s*\("

    $modStateEnsureIsExplicit =
        $ensureStateBlock -match "TryGetModState\s*\(" -and
        $ensureStateBlock -match "new\s*\(\s*\)" -and
        $ensureStateBlock -match "status\s*=\s*ModStatus\.Enabled" -and
        $ensureStateBlock -match "States\.Add\s*\(" -and
        $deleteBlock -match "EnsureModState\s*\(" -and
        $setEnabledBlock -match "EnsureModState\s*\("

    $modStateDeleteConsumeIsExplicit =
        $consumeDeletedBlock -match "status\s*!=\s*ModStatus\.Delete" -and
        $consumeDeletedBlock -match "States\.Remove\s*\(" -and
        $consumeDeletedBlock -match "return\s+true\s*;"

    if (-not $modStateQueryIsPure) {
        [void]$violations.Add(("{0}: GetModState must be a pure status query and must not add or remove ModState records." -f (ConvertTo-RepoPath $modConfigPath)))
    }

    if (-not $modStateEnsureIsExplicit) {
        [void]$violations.Add(("{0}: Mod state creation must be explicit through EnsureModState, and mutating APIs must use it." -f (ConvertTo-RepoPath $modConfigPath)))
    }

    if (-not $modStateDeleteConsumeIsExplicit) {
        [void]$violations.Add(("{0}: deleted ModState consumption must be explicit through ConsumeDeletedModState." -f (ConvertTo-RepoPath $modConfigPath)))
    }
}
else {
    [void]$violations.Add("ModConfig.cs is missing.")
}

if (Test-Path -LiteralPath $modLoaderPath) {
    $modLoaderText = Get-Content -Raw -LiteralPath $modLoaderPath
    $modLoaderConsumesDeletedState =
        $modLoaderText -match "EnsureModState\s*\(" -and
        $modLoaderText -match "DeleteModFromDisk\s*\(" -and
        $modLoaderText -match "ConsumeDeletedModState\s*\("

    if (-not $modLoaderConsumesDeletedState) {
        [void]$violations.Add(("{0}: ModLoader must explicitly ensure scanned Mod states and consume Delete state after disk delete handling." -f (ConvertTo-RepoPath $modLoaderPath)))
    }
}
else {
    [void]$violations.Add("ModLoader.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    ModStateQueryIsPure = $modStateQueryIsPure
    ModStateEnsureIsExplicit = $modStateEnsureIsExplicit
    ModStateDeleteConsumeIsExplicit = $modStateDeleteConsumeIsExplicit
    ModLoaderConsumesDeletedState = $modLoaderConsumesDeletedState
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Mod runtime static gate passed."
    }
    else {
        Write-Host "Mod runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
