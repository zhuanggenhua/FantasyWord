param(
    [int]$Rounds = 3,
    [string]$ScenePath = "Assets/Scenes/MiniFantasyUVTest.unity",
    [int]$ConnectTimeoutMs = 60000,
    [int]$SceneLoadTimeoutMs = 60000,
    [int]$ScreenshotTimeoutMs = 20000,
    [int]$BootWaitSeconds = 240,
    [switch]$LaunchUnityIfNeeded,
    [string]$UnityExe = "C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe",
    [string]$ProjectPath = (Resolve-Path ".").Path
)

$ErrorActionPreference = "Stop"

function Find-AIBridgeCli {
    param(
        [string]$Root
    )

    $candidates = @(
        (Join-Path $Root "AIBridgeCache\CLI\AIBridgeCLI.exe"),
        (Join-Path $Root "Library\PackageCache\cn.lys.aibridge@34574354c0ed\Tools~\CLI\win-x64\AIBridgeCLI.exe"),
        (Join-Path $Root "Library\PackageCache\cn.lys.aibridge@34574354c0ed\Tools~\AIBridgeCLI\CLI\win-x64\AIBridgeCLI.exe")
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }

    $found = Get-ChildItem -Path $Root -Recurse -Filter "AIBridgeCLI.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($found) {
        return $found
    }

    throw "AIBridgeCLI.exe not found under project: $Root"
}

function Invoke-AIBridgeRaw {
    param(
        [string]$CliPath,
        [string[]]$CliArgs
    )

    $text = & $CliPath @CliArgs 2>&1 | Out-String
    $line = ($text -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 1)
    if (-not $line) {
        throw "AIBridge returned empty output. Raw=`n$text"
    }
    return $line
}

function Invoke-AIBridgeJson {
    param(
        [string]$CliPath,
        [string[]]$CliArgs
    )

    $line = Invoke-AIBridgeRaw -CliPath $CliPath -CliArgs $CliArgs
    try {
        return ($line | ConvertFrom-Json)
    }
    catch {
        throw "Failed to parse JSON. Output=$line"
    }
}

function Test-AIBridgeReady {
    param(
        [string]$CliPath,
        [int]$TimeoutMs
    )

    try {
        $result = Invoke-AIBridgeJson -CliPath $CliPath -CliArgs @("EditorCommand_GetState", "--raw", "--timeout", $TimeoutMs)
        return ($result.success -eq $true)
    }
    catch {
        return $false
    }
}

function Get-LatestPngPath {
    param(
        [string]$Dir
    )

    if (-not (Test-Path $Dir)) {
        return $null
    }

    $latest = Get-ChildItem -Path $Dir -Filter "*.png" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($latest) {
        return $latest.FullName
    }
    return $null
}

$projectRoot = (Resolve-Path $ProjectPath).Path
$cliPath = Find-AIBridgeCli -Root $projectRoot
$screenshotDir = Join-Path $projectRoot "AIBridgeCache\screenshots"
$resultDir = Join-Path $projectRoot "AIBridgeCache\results"
New-Item -ItemType Directory -Path $screenshotDir -Force | Out-Null
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $resultDir "aibridge-smoke-$stamp.log"
$summaryPath = Join-Path $resultDir "aibridge-smoke-$stamp.json"
$logs = New-Object System.Collections.Generic.List[string]

$logs.Add("StartTime=$(Get-Date -Format o)")
$logs.Add("Project=$projectRoot")
$logs.Add("Cli=$cliPath")
$logs.Add("Scene=$ScenePath")
$logs.Add("Rounds=$Rounds")
$logs.Add("Timeouts(ms): connect=$ConnectTimeoutMs scene=$SceneLoadTimeoutMs screenshot=$ScreenshotTimeoutMs")

$ready = Test-AIBridgeReady -CliPath $cliPath -TimeoutMs $ConnectTimeoutMs
if (-not $ready -and $LaunchUnityIfNeeded) {
    if (-not (Test-Path $UnityExe)) {
        throw "Unity executable not found: $UnityExe"
    }

    $logs.Add("Unity is offline. Launching editor: $UnityExe")
    Start-Process -FilePath $UnityExe -ArgumentList @("-projectPath", $projectRoot) | Out-Null

    $deadline = (Get-Date).AddSeconds($BootWaitSeconds)
    do {
        Start-Sleep -Seconds 5
        $ready = Test-AIBridgeReady -CliPath $cliPath -TimeoutMs $ConnectTimeoutMs
        if ($ready) { break }
    } while ((Get-Date) -lt $deadline)
}

if (-not $ready) {
    $logs.Add("ERROR: AIBridge is still offline. Unity Editor is required.")
    $logs | Set-Content -Path $logPath -Encoding UTF8
    throw "AIBridge offline. See log: $logPath"
}

$results = @()
for ($i = 1; $i -le $Rounds; $i++) {
    $roundStart = Get-Date
    $beforeLatest = Get-LatestPngPath -Dir $screenshotDir
    $round = [ordered]@{
        round = $i
        startTime = $roundStart.ToString("o")
        state = "pass"
        sceneLoad = $null
        screenshot = $null
        screenshotPath = $null
        error = $null
    }

    try {
        $sceneResult = Invoke-AIBridgeJson -CliPath $cliPath -CliArgs @(
            "SceneCommand_Load",
            "--raw",
            "--scenePath", $ScenePath,
            "--timeout", $SceneLoadTimeoutMs
        )
        $round.sceneLoad = $sceneResult
        if ($sceneResult.success -ne $true) {
            throw "SceneCommand_Load failed: $($sceneResult.error)"
        }

        $shotResult = Invoke-AIBridgeJson -CliPath $cliPath -CliArgs @(
            "ScreenshotCommand_Image",
            "--raw",
            "--timeout", $ScreenshotTimeoutMs
        )
        $round.screenshot = $shotResult
        if ($shotResult.success -ne $true) {
            throw "ScreenshotCommand_Image failed: $($shotResult.error)"
        }

        Start-Sleep -Milliseconds 800
        $afterLatest = Get-LatestPngPath -Dir $screenshotDir
        if ($afterLatest -and $afterLatest -ne $beforeLatest) {
            $round.screenshotPath = $afterLatest
        }
        else {
            throw "No new screenshot file detected in $screenshotDir"
        }
    }
    catch {
        $round.state = "fail"
        $round.error = $_.Exception.Message
    }

    $results += [pscustomobject]$round
    $logs.Add(("Round {0}: {1} | screenshot={2} | error={3}" -f $i, $round.state, $round.screenshotPath, $round.error))
}

$passCount = ($results | Where-Object { $_.state -eq "pass" }).Count
$final = [ordered]@{
    startTime = $logs[0].Split("=")[1]
    endTime = (Get-Date -Format o)
    rounds = $Rounds
    pass = $passCount
    fail = $Rounds - $passCount
    scenePath = $ScenePath
    screenshotDir = $screenshotDir
    details = $results
}

$logs.Add("Summary: pass=$passCount fail=$($Rounds - $passCount)")
$logs | Set-Content -Path $logPath -Encoding UTF8
($final | ConvertTo-Json -Depth 6) | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "Smoke test finished. pass=$passCount/$Rounds"
Write-Host "Log: $logPath"
Write-Host "Summary: $summaryPath"
