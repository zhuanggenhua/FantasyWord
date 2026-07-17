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
$audioRuntimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Audio"
$audioSystemPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Game/Systems/AudioSystem.cs"
$resolverPath = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime/Database/Audio/AudioClipResolver.cs"
$audioChannelPath = Join-Path $audioRuntimeRoot "AudioChannel.cs"
$fallbackPlayerPath = Join-Path $audioRuntimeRoot "AudioChannelFallbackPlayer.cs"
$audioRegionPath = Join-Path $audioRuntimeRoot "AudioRegion.cs"

$directBroAudioBypassCount = 0
if (Test-Path -LiteralPath (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime")) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime") -Recurse -File -Filter "*.cs") {
        $repoPath = ConvertTo-RepoPath $file.FullName
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            if ($line -match "\bBroAudio\.Play\s*\(" -and $repoPath -ne "Assets/Scripts/GameCore/Runtime/Audio/AudioChannel.cs") {
                $directBroAudioBypassCount++
                [void]$violations.Add(("{0}:{1}: BroAudio.Play must be routed through AudioChannel/AudioSystem: {2}" -f $repoPath, $lineNumber, $line.Trim()))
            }

            if ($line -match "Resources\.Load\s*<" -or $line -match "\bFWRes\.") {
                [void]$violations.Add(("{0}:{1}: formal audio runtime must not use Resources/FWRes directly: {2}" -f $repoPath, $lineNumber, $line.Trim()))
            }
        }
    }
}

$audioChannelText = if (Test-Path -LiteralPath $audioChannelPath) { Get-Content -Raw -LiteralPath $audioChannelPath } else { "" }
$audioSystemText = if (Test-Path -LiteralPath $audioSystemPath) { Get-Content -Raw -LiteralPath $audioSystemPath } else { "" }
$resolverText = if (Test-Path -LiteralPath $resolverPath) { Get-Content -Raw -LiteralPath $resolverPath } else { "" }
$audioRegionText = if (Test-Path -LiteralPath $audioRegionPath) { Get-Content -Raw -LiteralPath $audioRegionPath } else { "" }
$fallbackPlayerText = if (Test-Path -LiteralPath $fallbackPlayerPath) { Get-Content -Raw -LiteralPath $fallbackPlayerPath } else { "" }

$audioChannelRequiresSource = $audioChannelText.Contains("[RequireComponent(typeof(AudioSource))]")
if (-not $audioChannelRequiresSource) {
    [void]$violations.Add("AudioChannel must explicitly require AudioSource.")
}

$audioChannelAutoAddsSource = $audioChannelText -match "AddComponent\s*<\s*AudioSource\s*>"
if ($audioChannelAutoAddsSource) {
    [void]$violations.Add("AudioChannel must not auto-add AudioSource at runtime; missing required setup must be visible.")
}

$audioSystemReportsMissingChannel = $audioSystemText.Contains("TryGetConfiguredChannel") -and $audioSystemText.Contains("Debug.LogError")
if (-not $audioSystemReportsMissingChannel) {
    [void]$violations.Add("AudioSystem must report missing/null AudioChannel configuration instead of silently dropping playback.")
}

$audioRegionChecksResolver = $audioRegionText.Contains("TryGetAudioClipResolver") -and $audioRegionText.Contains("Debug.LogError")
if (-not $audioRegionChecksResolver) {
    [void]$violations.Add("AudioRegion must validate AudioClipResolver before reading targetChannel.")
}

$audioRegionGuardsTriggerContext =
    $audioRegionText.Contains("TryGetCurrentControlledCharacter") -and
    $audioRegionText.Contains("TryGetAudioSystem") -and
    $audioRegionText.Contains("TryGetAudioClipResolver") -and
    $audioRegionText.Contains("return false") -and
    $audioRegionText.Contains("GameRuntimeEvents.RequestAudioPlayback(audioClipResolver)") -and
    $audioRegionText.Contains("GameRuntimeEvents.RequestAudioPlayback(m_previousAudio)")
if (-not $audioRegionGuardsTriggerContext) {
    [void]$violations.Add("AudioRegion must keep the trigger-flow contract: if the player/audio/resolver context is not ready, skip the region switch and do not replace or restore channel audio.")
}

$resolverHandlesSingleClipPingPong = $resolverText.Contains("m_audioClips.Length == 1")
if (-not $resolverHandlesSingleClipPingPong) {
    [void]$violations.Add("AudioClipResolver PingPong mode must handle a single AudioClip without index underflow.")
}

$audioChannelStopsPlaybackOnDisable =
    $audioChannelText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?m_isPaused\s*=\s*false" -and
    $audioChannelText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?m_playbackRuntime\?\.Stop\s*\(\s*\)"
if (-not $audioChannelStopsPlaybackOnDisable) {
    [void]$violations.Add("AudioChannel must stop active playback when the channel component is disabled.")
}

$fallbackPlayerLifecycleBound =
    $fallbackPlayerText -match "public\s+void\s+StopPlayback\s*\(\s*\)[\s\S]*?StopPlaybackInternal\s*\(\s*deactivate:\s*true\s*\)" -and
    $fallbackPlayerText -match "private\s+void\s+OnDisable\s*\(\s*\)[\s\S]*?StopPlaybackInternal\s*\(\s*deactivate:\s*false\s*\)" -and
    $fallbackPlayerText -match "private\s+void\s+OnDestroy\s*\(\s*\)[\s\S]*?StopPlaybackInternal\s*\(\s*deactivate:\s*false\s*\)" -and
    $fallbackPlayerText -match "StopCoroutine\s*\(\s*m_playbackCoroutine\s*\)" -and
    $fallbackPlayerText -match "m_playbackCoroutine\s*=\s*null" -and
    $fallbackPlayerText -match "m_audioSource\.Stop\s*\(\s*\)" -and
    $fallbackPlayerText -match "m_audioSource\.clip\s*=\s*null" -and
    $fallbackPlayerText -match "m_followTarget\s*=\s*null" -and
    $fallbackPlayerText -match "m_onCompleted\s*=\s*null" -and
    $fallbackPlayerText -match "if\s*\(\s*deactivate\s*&&\s*gameObject\.activeSelf\s*\)"
if (-not $fallbackPlayerLifecycleBound) {
    [void]$violations.Add("AudioChannelFallbackPlayer must stop playback coroutines and clear pooled playback state on StopPlayback, disable, and destroy.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    DirectBroAudioBypassCount = $directBroAudioBypassCount
    AudioChannelRequiresAudioSource = $audioChannelRequiresSource
    AudioChannelAutoAddsAudioSource = $audioChannelAutoAddsSource
    AudioSystemReportsMissingChannel = $audioSystemReportsMissingChannel
    AudioRegionChecksResolver = $audioRegionChecksResolver
    AudioRegionGuardsTriggerContext = $audioRegionGuardsTriggerContext
    ResolverHandlesSingleClipPingPong = $resolverHandlesSingleClipPingPong
    AudioChannelStopsPlaybackOnDisable = $audioChannelStopsPlaybackOnDisable
    FallbackPlayerLifecycleBound = $fallbackPlayerLifecycleBound
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Audio runtime static gate passed."
    }
    else {
        Write-Host "Audio runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
