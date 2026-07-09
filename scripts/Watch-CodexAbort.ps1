[CmdletBinding()]
param(
    [string]$CodexHome = 'D:\codex-home',
    [string]$OutputRoot = 'D:\codex-home\diagnostics\codex-abort-monitor',
    [string]$WorkspaceRoot = 'C:\Gamedev\Unity\Project\FantasyWord',
    [string]$ThreadId = '',
    [int]$PollSeconds = 2,
    [int]$LookbackHours = 24,
    [switch]$Once,
    [switch]$CaptureExisting
)

$ErrorActionPreference = 'Stop'

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content -Raw $Path | ConvertFrom-Json -Depth 20
    }
    catch {
        return $null
    }
}

function ConvertTo-Hashtable {
    param([object]$Object)

    $map = @{}
    if ($null -eq $Object) {
        return $map
    }

    foreach ($property in $Object.PSObject.Properties) {
        $map[$property.Name] = $property.Value
    }

    return $map
}

function Get-StatePath {
    return Join-Path $OutputRoot 'state.json'
}

function Load-State {
    $defaultState = @{
        processedEventKeys = @()
        processedHistoryKeys = @()
    }

    $state = Read-JsonFile -Path (Get-StatePath)
    if ($null -eq $state) {
        return $defaultState
    }

    $result = @{
        processedEventKeys = @()
        processedHistoryKeys = @()
    }

    if ($state.processedEventKeys) {
        $result.processedEventKeys = @($state.processedEventKeys)
    }
    if ($state.processedHistoryKeys) {
        $result.processedHistoryKeys = @($state.processedHistoryKeys)
    }

    return $result
}

function Save-State {
    param([hashtable]$State)

    Ensure-Directory -Path $OutputRoot
    $payload = @{
        processedEventKeys = @($State.processedEventKeys | Sort-Object -Unique)
        processedHistoryKeys = @($State.processedHistoryKeys | Sort-Object -Unique)
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Get-StatePath)
}

function Get-RecentSessionFiles {
    $sessionsRoot = Join-Path $CodexHome 'sessions'
    if (-not (Test-Path $sessionsRoot)) {
        return @()
    }

    $cutoff = (Get-Date).AddHours(-1 * $LookbackHours)
    return @(Get-ChildItem -Path $sessionsRoot -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoff } |
        Sort-Object LastWriteTime)
}

function Get-SessionMeta {
    param([string]$Path)

    try {
        $firstLine = Get-Content -Path $Path -TotalCount 1 -ErrorAction Stop
        if (-not $firstLine) {
            return $null
        }

        $entry = $firstLine | ConvertFrom-Json -Depth 20
        if ($entry.type -ne 'session_meta') {
            return $null
        }

        return $entry.payload
    }
    catch {
        return $null
    }
}

function Get-AbortEvents {
    param([string]$Path)

    $meta = Get-SessionMeta -Path $Path
    if ($ThreadId -and ($null -eq $meta -or $meta.id -ne $ThreadId)) {
        return @()
    }

    $events = @()
    try {
        foreach ($line in Get-Content -Path $Path -ErrorAction Stop) {
            if ($line -notlike '*"type":"turn_aborted"*') {
                continue
            }

            $entry = $line | ConvertFrom-Json -Depth 20
            if ($entry.type -ne 'event_msg' -or $entry.payload.type -ne 'turn_aborted') {
                continue
            }

            $eventKey = '{0}|{1}|{2}' -f $Path, $entry.payload.turn_id, $entry.payload.completed_at
            $events += [pscustomobject]@{
                Kind = 'turn_aborted'
                Key = $eventKey
                SessionPath = $Path
                SessionMeta = $meta
                Event = $entry
                Timestamp = $entry.timestamp
            }
        }
    }
    catch {
        Write-Warning "Failed to parse session file: $Path`n$($_.Exception.Message)"
    }

    return $events
}

function Get-TerminateBatchHistoryEvents {
    $historyPath = Join-Path $CodexHome 'history.jsonl'
    if (-not (Test-Path $historyPath)) {
        return @()
    }

    $events = @()
    foreach ($line in Get-Content -Path $historyPath -Tail 300 -ErrorAction SilentlyContinue) {
        if ($line -notlike '*Terminate batch job*') {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json -Depth 10
            if ($ThreadId -and $entry.session_id -ne $ThreadId) {
                continue
            }

            $historyKey = '{0}|{1}|{2}' -f $entry.session_id, $entry.ts, ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($entry.text)))
            $events += [pscustomobject]@{
                Kind = 'terminate_batch_job'
                Key = $historyKey
                HistoryEntry = $entry
                Timestamp = [DateTimeOffset]::FromUnixTimeSeconds([int64]$entry.ts).ToString('o')
            }
        }
        catch {
            continue
        }
    }

    return $events
}

function Get-SessionTailPathForThread {
    param([string]$TargetThreadId)

    if (-not $TargetThreadId) {
        return $null
    }

    $recentFiles = Get-RecentSessionFiles | Sort-Object LastWriteTime -Descending
    foreach ($file in $recentFiles) {
        $meta = Get-SessionMeta -Path $file.FullName
        if ($meta -and $meta.id -eq $TargetThreadId) {
            return $file.FullName
        }
    }

    return $null
}

function Write-FileSafely {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    Ensure-Directory -Path $directory
    Set-Content -Path $Path -Encoding UTF8 -Value $Content
}

function New-SnapshotDirectory {
    param(
        [string]$EventKind,
        [string]$Timestamp,
        [string]$ThreadKey
    )

    $safeTimestamp = $Timestamp.Replace(':', '-')
    $safeThreadKey = if ($ThreadKey) { $ThreadKey } else { 'all-threads' }
    $dir = Join-Path $OutputRoot ('{0}_{1}_{2}' -f $safeTimestamp, $EventKind, $safeThreadKey)
    Ensure-Directory -Path $dir
    return $dir
}

function Capture-ProcessSnapshot {
    $names = @('codex.exe', 'node.exe', 'powershell.exe', 'pwsh.exe', 'cmd.exe', 'conhost.exe', 'python.exe', 'WindowsTerminal.exe', 'OpenConsole.exe')
    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $names -contains $_.Name } |
        Select-Object Name, ProcessId, ParentProcessId, CommandLine, CreationDate

    $list = Get-Process codex,node,powershell,pwsh,cmd,conhost,python -ErrorAction SilentlyContinue |
        Select-Object ProcessName, Id, StartTime, Path, MainWindowTitle

    return @{
        cim = @($processes)
        list = @($list)
    }
}

function Capture-WorkspaceSnapshot {
    if (-not $WorkspaceRoot -or -not (Test-Path $WorkspaceRoot)) {
        return $null
    }

    $bridgeDir = Join-Path $WorkspaceRoot 'Temp\UnityBridge'
    $result = @{
        workspaceRoot = $WorkspaceRoot
        bridgeDirExists = (Test-Path $bridgeDir)
        bridgeFiles = @()
        cliLock = $null
        sceneLock = $null
        heartbeat = $null
    }

    if (Test-Path $bridgeDir) {
        $result.bridgeFiles = @(Get-ChildItem -Force $bridgeDir -ErrorAction SilentlyContinue |
            Select-Object Name, FullName, Length, LastWriteTime, Attributes)

        $cliLockPath = Join-Path $bridgeDir '.cli.lock'
        $sceneLockPath = Join-Path $bridgeDir '.scene.lock'
        $heartbeatPath = Join-Path $bridgeDir 'heartbeat'

        if (Test-Path $cliLockPath) { $result.cliLock = Get-Content -Raw $cliLockPath }
        if (Test-Path $sceneLockPath) { $result.sceneLock = Get-Content -Raw $sceneLockPath }
        if (Test-Path $heartbeatPath) { $result.heartbeat = Get-Content -Raw $heartbeatPath }
    }

    return $result
}

function Write-Snapshot {
    param([pscustomobject]$EventRecord)

    $threadKey = ''
    if ($EventRecord.Kind -eq 'turn_aborted' -and $EventRecord.SessionMeta) {
        $threadKey = $EventRecord.SessionMeta.id
    }
    elseif ($EventRecord.Kind -eq 'terminate_batch_job' -and $EventRecord.HistoryEntry) {
        $threadKey = $EventRecord.HistoryEntry.session_id
    }

    $snapshotDir = New-SnapshotDirectory -EventKind $EventRecord.Kind -Timestamp $EventRecord.Timestamp -ThreadKey $threadKey

    $processSnapshot = Capture-ProcessSnapshot
    $workspaceSnapshot = Capture-WorkspaceSnapshot
    $chatProcessesPath = Join-Path $CodexHome 'process_manager\chat_processes.json'
    $historyPath = Join-Path $CodexHome 'history.jsonl'

    $payload = @{
        capturedAt = (Get-Date).ToString('o')
        eventKind = $EventRecord.Kind
        eventKey = $EventRecord.Key
        eventRecord = $EventRecord
        getCommandCodex = (Get-Command codex -ErrorAction SilentlyContinue | Select-Object Name, CommandType, Source, Definition)
        processSnapshot = $processSnapshot
        workspaceSnapshot = $workspaceSnapshot
    }

    $payload | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'snapshot.json')

    if (Test-Path $historyPath) {
        Get-Content -Path $historyPath -Tail 120 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'history-tail.jsonl')
    }

    if (Test-Path $chatProcessesPath) {
        Copy-Item -Path $chatProcessesPath -Destination (Join-Path $snapshotDir 'chat_processes.json') -Force
    }

    if ($EventRecord.Kind -eq 'turn_aborted' -and $EventRecord.SessionPath) {
        Get-Content -Path $EventRecord.SessionPath -Tail 220 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'session-tail.jsonl')
    }
    elseif ($threadKey) {
        $sessionTailPath = Get-SessionTailPathForThread -TargetThreadId $threadKey
        if ($sessionTailPath) {
            Get-Content -Path $sessionTailPath -Tail 220 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'session-tail.jsonl')
        }
    }

    $processSnapshot.cim | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'process-cim.json')
    $processSnapshot.list | Format-Table -AutoSize | Out-String -Width 320 | Set-Content -Encoding UTF8 (Join-Path $snapshotDir 'process-list.txt')

    return $snapshotDir
}

function Get-NewEvents {
    param([hashtable]$State)

    $processedEventKeys = @{}
    foreach ($key in $State.processedEventKeys) { $processedEventKeys[$key] = $true }

    $processedHistoryKeys = @{}
    foreach ($key in $State.processedHistoryKeys) { $processedHistoryKeys[$key] = $true }

    $events = @()
    foreach ($file in Get-RecentSessionFiles) {
        foreach ($event in Get-AbortEvents -Path $file.FullName) {
            if (-not $CaptureExisting -and -not $processedEventKeys.ContainsKey($event.Key)) {
                $events += $event
                continue
            }
            if ($CaptureExisting -and -not $processedEventKeys.ContainsKey($event.Key)) {
                $events += $event
            }
        }
    }

    foreach ($event in Get-TerminateBatchHistoryEvents) {
        if (-not $processedHistoryKeys.ContainsKey($event.Key)) {
            $events += $event
        }
    }

    return @($events | Sort-Object Timestamp, Kind)
}

Ensure-Directory -Path $OutputRoot
$state = Load-State

if (-not $CaptureExisting -and $state.processedEventKeys.Count -eq 0 -and $state.processedHistoryKeys.Count -eq 0) {
    foreach ($file in Get-RecentSessionFiles) {
        foreach ($event in Get-AbortEvents -Path $file.FullName) {
            $state.processedEventKeys += $event.Key
        }
    }

    foreach ($event in Get-TerminateBatchHistoryEvents) {
        $state.processedHistoryKeys += $event.Key
    }

    Save-State -State $state
}

do {
    $newEvents = Get-NewEvents -State $state
    foreach ($event in $newEvents) {
        $snapshotDir = Write-Snapshot -EventRecord $event
        Write-Host "[codex-abort-monitor] captured $($event.Kind) -> $snapshotDir"

        if ($event.Kind -eq 'turn_aborted') {
            $state.processedEventKeys += $event.Key
        }
        else {
            $state.processedHistoryKeys += $event.Key
        }
    }

    Save-State -State $state

    if ($Once) {
        break
    }

    Start-Sleep -Seconds $PollSeconds
} while ($true)
