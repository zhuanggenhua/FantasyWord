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
$mapSystemPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/MapSystem.cs"

$mapRespawnCoroutineLifecycleBound = $false
$mapResultRequiresValidCheckpoint = $false
$mapTransitionRequiresTransitionSystem = $false
$mapTraversalCharacterRequiredForResults = $false
$mapLoadRequiresDataBlock = $false
if (Test-Path -LiteralPath $mapSystemPath) {
    $text = Get-Content -Raw -LiteralPath $mapSystemPath

    $mapRespawnCoroutineLifecycleBound =
        $text -match "private\s+Coroutine\s+m_respawnCoroutine" -and
        $text -match "public\s+override\s+void\s+OnSystemStop\s*\(\s*\)[\s\S]*?StopRespawnCoroutine\s*\(\s*\)" -and
        $text -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?StopRespawnCoroutine\s*\(\s*\)" -and
        $text -match "private\s+void\s+OnDestroy\s*\(\s*\)[\s\S]*?StopRespawnCoroutine\s*\(\s*\)" -and
        $text -match "private\s+void\s+StopRespawnCoroutine\s*\(\s*\)[\s\S]*?StopCoroutine\s*\(\s*m_respawnCoroutine\s*\)[\s\S]*?m_respawnCoroutine\s*=\s*null" -and
        $text -match "m_respawnCoroutine\s*=\s*StartCoroutine\s*\(\s*RespawnPlayerCoroutine\s*\(\s*\)\s*\)" -and
        $text -match "private\s+IEnumerator\s+RespawnPlayerCoroutine\s*\(\s*\)[\s\S]*?m_respawnCoroutine\s*=\s*null"

    $mapResultRequiresValidCheckpoint =
        $text -match "private\s+static\s+void\s+EnsureValidCheckpoint\s*\(\s*ICheckpoint\s+checkpoint\s*,\s*string\s+operationName\s*\)[\s\S]*?throw\s+new\s+InvalidOperationException" -and
        $text -match "public\s+void\s+SaveCheckpoint\s*\(\s*ICheckpoint\s+checkpoint\s*,\s*int\s+checkpointOrder\s*,\s*bool\s+forceAssignation\s*=\s*false\s*\)[\s\S]*?EnsureValidCheckpoint\s*\(\s*checkpoint\s*,\s*nameof\s*\(\s*SaveCheckpoint\s*\)\s*\)" -and
        $text -match "public\s+void\s+TeleportTo\s*\(\s*ICheckpoint\s+checkpoint[\s\S]*?EnsureValidCheckpoint\s*\(\s*checkpoint\s*,\s*nameof\s*\(\s*TeleportTo\s*\)\s*\)" -and
        $text -match "private\s+ICheckpoint\s+FindRequiredInitialSpawnCheckpoint\s*\(" -and
        $text -match "private\s+ICheckpoint\s+FindRequiredRespawnCheckpoint\s*\("

    $mapResultSilentlyReturnsOnMissingCheckpoint =
        $text -match "if\s*\(\s*checkpoint\s*==\s*null\s*\|\|\s*!\s*checkpoint\.IsValid\s*\(\s*\)\s*\)\s*\{\s*(Debug\.LogWarning\s*\([^\}]*\)\s*)?return\s*;"

    if ($mapResultSilentlyReturnsOnMissingCheckpoint) {
        $mapResultRequiresValidCheckpoint = $false
    }

    $mapTransitionRequiresTransitionSystem =
        $text -match "private\s+void\s+EnsureTransitionSystemReady\s*\(\s*\)[\s\S]*?GameManager\.TransitionSystem[\s\S]*?throw\s+new\s+InvalidOperationException" -and
        $text -match "public\s+void\s+RequestTransition\s*\([^\)]*\)[\s\S]*?EnsureTransitionSystemReady\s*\(\s*\)[\s\S]*?DelegateTransition" -and
        $text -notmatch "RequestTransition[\s\S]{0,400}Debug\.Assert\s*\("

    $mapTraversalCharacterRequiredForResults =
        $text -match "private\s+CharacterActor\s+GetRequiredTraversalCharacter\s*\(\s*string\s+operationName\s*\)[\s\S]*?throw\s+new\s+InvalidOperationException" -and
        $text -match "EnsureTraversalCharacterValidSpawnOnActiveMap\s*\(\s*\)[\s\S]*?GetRequiredTraversalCharacter\s*\(\s*nameof\s*\(\s*EnsureTraversalCharacterValidSpawnOnActiveMap\s*\)\s*\)" -and
        $text -match "public\s+void\s+TeleportTo\s*\(\s*ICheckpoint\s+checkpoint[\s\S]*?GetRequiredTraversalCharacter\s*\(\s*nameof\s*\(\s*TeleportTo\s*\)\s*\)" -and
        $text -match "TeleportToInitialSpawnPosition[\s\S]*?GetRequiredTraversalCharacter\s*\(\s*nameof\s*\(\s*TeleportToInitialSpawnPosition\s*\)\s*\)" -and
        $text -match "TeleportToPlaytestStartPosition[\s\S]*?GetRequiredTraversalCharacter\s*\(\s*nameof\s*\(\s*TeleportToPlaytestStartPosition\s*\)\s*\)" -and
        $text -match "RespawnPlayerCoroutine[\s\S]*?GetRequiredTraversalCharacter\s*\(\s*nameof\s*\(\s*RespawnPlayer\s*\)\s*\)"

    $mapLoadRequiresDataBlock =
        $text -match "public\s+void\s+LoadDataBlock\s*\(\s*MapDataBlock\s+block\s*\)[\s\S]*?if\s*\(\s*block\s*==\s*null\s*\)[\s\S]*?throw\s+new\s+InvalidOperationException" -and
        $text -notmatch "public\s+void\s+LoadDataBlock\s*\(\s*MapDataBlock\s+block\s*\)[\s\S]*?block\?\."

    $mapResultSilentlyReturnsOnMissingTraversalCharacter =
        $text -match "if\s*\(\s*traversalCharacter\s*==\s*null\s*\)\s*\{\s*(m_respawnCoroutine\s*=\s*null\s*;\s*)?(yield\s+break|return)\s*;"

    if ($mapResultSilentlyReturnsOnMissingTraversalCharacter) {
        $mapTraversalCharacterRequiredForResults = $false
    }

    if (-not $mapRespawnCoroutineLifecycleBound) {
        [void]$violations.Add(("{0}: MapSystem respawn coroutine must be stopped on system stop, disable, and destroy, and clear its handle on every exit path." -f (ConvertTo-RepoPath $mapSystemPath)))
    }

    if (-not $mapResultRequiresValidCheckpoint) {
        [void]$violations.Add(("{0}: MapSystem save, teleport, initial spawn, and respawn result paths must require a valid checkpoint instead of silently returning." -f (ConvertTo-RepoPath $mapSystemPath)))
    }

    if (-not $mapTransitionRequiresTransitionSystem) {
        [void]$violations.Add(("{0}: MapSystem transitions must require an active TransitionSystem now that the direct transition fallback has been removed." -f (ConvertTo-RepoPath $mapSystemPath)))
    }

    if (-not $mapTraversalCharacterRequiredForResults) {
        [void]$violations.Add(("{0}: MapSystem teleport, respawn, and invalid-spawn recovery must require a primary traversal character instead of silently returning." -f (ConvertTo-RepoPath $mapSystemPath)))
    }

    if (-not $mapLoadRequiresDataBlock) {
        [void]$violations.Add(("{0}: MapSystem.LoadDataBlock must reject a missing map data block explicitly instead of mixing null fallback with later dereferences." -f (ConvertTo-RepoPath $mapSystemPath)))
    }
}
else {
    [void]$violations.Add("MapSystem.cs is missing.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    MapRespawnCoroutineLifecycleBound = $mapRespawnCoroutineLifecycleBound
    MapResultRequiresValidCheckpoint = $mapResultRequiresValidCheckpoint
    MapTransitionRequiresTransitionSystem = $mapTransitionRequiresTransitionSystem
    MapTraversalCharacterRequiredForResults = $mapTraversalCharacterRequiredForResults
    MapLoadRequiresDataBlock = $mapLoadRequiresDataBlock
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Map runtime static gate passed."
    }
    else {
        Write-Host "Map runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
