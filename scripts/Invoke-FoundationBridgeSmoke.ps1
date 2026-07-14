[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$SkipAssetsRefresh,
    [switch]$SkipTests,
    [int]$HeartbeatMaxAgeSeconds = 120
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

$bridgePath = Join-Path $ProjectRoot ".codex\skills\aibridge\bridge.py"
$bridgeRoot = Join-Path $ProjectRoot "Temp\UnityBridge"
$commandsDir = Join-Path $bridgeRoot "commands"
$resultsDir = Join-Path $bridgeRoot "results"
$useBridgeProcess = Test-Path -LiteralPath $bridgePath

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-BridgeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    if (-not $useBridgeProcess) {
        return Invoke-FileBridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral
    }

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = "python"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true

    $rawArguments = [System.Collections.Generic.List[string]]::new()
    [void]$rawArguments.Add($bridgePath)
    [void]$rawArguments.Add($ToolName)
    if (-not [string]::IsNullOrWhiteSpace($JsonLiteral)) {
        [void]$rawArguments.Add($JsonLiteral)
    }

    $quotedArguments = $rawArguments | ForEach-Object { Quote-ProcessArgument $_ }
    $processStartInfo.Arguments = ($quotedArguments -join " ")

    $process = [System.Diagnostics.Process]::Start($processStartInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $output = ($stdout + [Environment]::NewLine + $stderr).Trim()

    if ($process.ExitCode -ne 0) {
        throw "AIBridge call failed: $ToolName`n$output"
    }

    return $output
}

function Invoke-FileBridgeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

    $id = "{0:yyyyMMddHHmmssfff}-{1}" -f [DateTime]::UtcNow, ([Guid]::NewGuid().ToString("N").Substring(0, 8))
    $commandPath = Join-Path $commandsDir "$id.json"
    $resultPath = Join-Path $resultsDir "$id.json"
    $params = if ([string]::IsNullOrWhiteSpace($JsonLiteral)) {
        @{}
    }
    else {
        $JsonLiteral | ConvertFrom-Json
    }

    $payload = [ordered]@{
        id = $id
        tool = $ToolName
        params = $params
    }
    $tmpPath = "$commandPath.tmp"
    [System.IO.File]::WriteAllText(
        $tmpPath,
        ($payload | ConvertTo-Json -Compress -Depth 32),
        [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath $tmpPath -Destination $commandPath -Force

    $timeoutSeconds = if ($ToolName -eq "tests-run") { 300 } else { 120 }
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($timeoutSeconds)
    do {
        if (Test-Path -LiteralPath $resultPath) {
            $resultJson = [System.IO.File]::ReadAllText($resultPath, [System.Text.Encoding]::UTF8)
            $result = $resultJson | ConvertFrom-Json
            if ($result.status -ne "success") {
                throw "AIBridge file bridge call failed: $ToolName`n$($result.message)"
            }

            return $resultJson
        }

        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timeout waiting for AIBridge file bridge result. tool=$ToolName id=$id timeoutSeconds=$timeoutSeconds"
}

function Test-IsRecoverableBridgeSceneListTimeout {
    param(
        [string]$ToolName,
        [string]$BridgeErrorMessage
    )

    return $ToolName -eq "tests-run" -and
        $BridgeErrorMessage -like "*Timeout after 60s waiting for Unity response*" -and
        $BridgeErrorMessage -like "*tool: scene-list-opened*"
}

function Invoke-BridgeProcessWithSingleRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [string]$JsonLiteral
    )

    try {
        return Invoke-BridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral
    }
    catch {
        $bridgeError = $_.Exception.Message
        if (-not (Test-IsRecoverableBridgeSceneListTimeout -ToolName $ToolName -BridgeErrorMessage $bridgeError)) {
            throw
        }

        Start-Sleep -Seconds 2
        $null = Invoke-BridgeProcess -ToolName "editor-application-get-state"
        $null = Invoke-BridgeProcess -ToolName "scene-list-opened"
        Start-Sleep -Seconds 2
        return Invoke-BridgeProcess -ToolName $ToolName -JsonLiteral $JsonLiteral
    }
}

function ConvertFrom-JsonOrNull {
    param([string]$JsonText)

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    try {
        return $JsonText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-BridgeMessagePayload {
    param([string]$BridgeOutput)

    $outer = ConvertFrom-JsonOrNull -JsonText $BridgeOutput
    if ($null -ne $outer -and
        $outer.PSObject.Properties.Name -contains "message" -and
        -not [string]::IsNullOrWhiteSpace([string]$outer.message)) {
        $messagePayload = ConvertFrom-JsonOrNull -JsonText ([string]$outer.message)
        if ($null -ne $messagePayload) {
            return $messagePayload
        }
    }

    return $outer
}

function Assert-BridgeTestSummaryPassed {
    param(
        [string]$BridgeOutput,
        [string]$Context
    )

    $payload = Get-BridgeMessagePayload -BridgeOutput $BridgeOutput
    if ($null -eq $payload -or -not ($payload.PSObject.Properties.Name -contains "summary")) {
        return
    }

    $summary = $payload.summary
    $status = [string]$summary.status
    $failedTests = if ($summary.PSObject.Properties.Name -contains "failedTests") {
        [int]$summary.failedTests
    }
    else {
        0
    }

    if ($status -ne "Passed" -or $failedTests -ne 0) {
        throw "Unity EditMode tests failed in ${Context}: $($BridgeOutput)"
    }
}

function TryGetUnityTestResultsSummary {
    param(
        [DateTime]$StartedAtUtc,
        [ref]$Summary
    )

    $testResultsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\DefaultCompany\FantasyWord\TestResults.xml"
    if (-not (Test-Path -LiteralPath $testResultsPath)) {
        return $false
    }

    $testResultsFile = Get-Item -LiteralPath $testResultsPath
    if ($testResultsFile.LastWriteTimeUtc -lt $StartedAtUtc.AddSeconds(-2)) {
        return $false
    }

    $xml = [System.Xml.XmlDocument]::new()
    $xml.Load($testResultsPath)
    $root = $xml.DocumentElement
    $failedNodes = $xml.SelectNodes("//*[@result='Failed']")
    $failedNames = New-Object System.Collections.Generic.List[string]
    foreach ($node in $failedNodes) {
        $name = $node.GetAttribute("fullname")
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = $node.GetAttribute("name")
        }

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$failedNames.Add($name)
        }
    }

    $Summary.Value = [ordered]@{
        Source = $testResultsPath
        Result = $root.GetAttribute("result")
        Total = [int]$root.GetAttribute("total")
        Passed = [int]$root.GetAttribute("passed")
        Failed = [int]$root.GetAttribute("failed")
        Skipped = [int]$root.GetAttribute("skipped")
        Duration = $root.GetAttribute("duration")
        LastWriteTimeUtc = $testResultsFile.LastWriteTimeUtc.ToString("o")
        FailedTests = $failedNames.ToArray()
    }

    return $true
}

function Wait-BridgeTestRunCompletion {
    param(
        [string]$InitialOutput,
        [DateTime]$StartedAtUtc
    )

    $payload = Get-BridgeMessagePayload -BridgeOutput $InitialOutput
    if ($null -eq $payload -or
        -not ($payload.PSObject.Properties.Name -contains "responseStatus") -or
        [string]$payload.responseStatus -ne "Processing") {
        Assert-BridgeTestSummaryPassed -BridgeOutput $InitialOutput -Context "immediate result"
        return $InitialOutput
    }

    $requestId = [string]$payload.requestID
    if ([string]::IsNullOrWhiteSpace($requestId)) {
        throw "Unity tests are still processing, but no deferred request id was returned: $InitialOutput"
    }

    $deferredResultPath = Join-Path $resultsDir "$requestId.json"
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
    do {
        if (Test-Path -LiteralPath $deferredResultPath) {
            $deferredOutput = [System.IO.File]::ReadAllText($deferredResultPath, [System.Text.Encoding]::UTF8)
            Assert-BridgeTestSummaryPassed -BridgeOutput $deferredOutput -Context $requestId
            return $deferredOutput
        }

        $xmlSummary = $null
        if (TryGetUnityTestResultsSummary -StartedAtUtc $StartedAtUtc -Summary ([ref]$xmlSummary)) {
            if ($xmlSummary.Result -ne "Passed" -or $xmlSummary.Failed -ne 0) {
                throw "Unity EditMode tests failed in TestResults.xml: $($xmlSummary | ConvertTo-Json -Compress -Depth 6)"
            }

            return "DeferredResult=TestResults.xml`n$($xmlSummary | ConvertTo-Json -Compress -Depth 6)"
        }

        Start-Sleep -Seconds 1
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for Unity EditMode test completion. requestId=$requestId deferredResultPath=$deferredResultPath"
}

function Get-BridgeHeartbeatInfo {
    param([string]$HeartbeatPath)

    $rawHeartbeat = Get-Content -LiteralPath $HeartbeatPath -Raw
    $heartbeat = $rawHeartbeat | ConvertFrom-Json
    $heartbeatTime = [DateTimeOffset]::FromUnixTimeMilliseconds([Int64]$heartbeat.timestamp)
    $ageSeconds = [Math]::Floor(([DateTimeOffset]::UtcNow - $heartbeatTime).TotalSeconds)
    $process = $null

    if ($heartbeat.PSObject.Properties.Name -contains "pid") {
        $process = Get-Process -Id ([int]$heartbeat.pid) -ErrorAction SilentlyContinue
    }

    return [ordered]@{
        Path = $HeartbeatPath
        Raw = $rawHeartbeat.Trim()
        TimestampUtc = $heartbeatTime.UtcDateTime.ToString("o")
        AgeSeconds = [int]$ageSeconds
        Pid = if ($null -ne $process) { $process.Id } else { $null }
        ProcessName = if ($null -ne $process) { $process.ProcessName } else { $null }
        Responding = if ($null -ne $process) { $process.Responding } else { $null }
    }
}

function Assert-BridgeHeartbeatReady {
    param(
        [string]$HeartbeatPath,
        [int]$MaxAgeSeconds
    )

    $info = Get-BridgeHeartbeatInfo -HeartbeatPath $HeartbeatPath

    if ($null -eq $info.Pid) {
        throw "Unity Editor process from AIBridge heartbeat is not running. Heartbeat=$($info.Raw)"
    }

    if ($info.Responding -eq $false) {
        throw "Unity Editor process is not responding. PID=$($info.Pid), heartbeatAgeSeconds=$($info.AgeSeconds), heartbeat=$($info.Raw)"
    }

    if ($info.AgeSeconds -gt $MaxAgeSeconds) {
        throw "Unity Editor heartbeat is stale. ageSeconds=$($info.AgeSeconds), maxAgeSeconds=$MaxAgeSeconds, heartbeat=$($info.Raw)"
    }

    return $info
}

$heartbeatPath = Join-Path $ProjectRoot "Temp\UnityBridge\heartbeat"
if (-not (Test-Path -LiteralPath $heartbeatPath)) {
    throw "Unity Editor is not connected to AIBridge. Missing heartbeat: $heartbeatPath"
}

$heartbeatInfo = Assert-BridgeHeartbeatReady -HeartbeatPath $heartbeatPath -MaxAgeSeconds $HeartbeatMaxAgeSeconds
$stateOutput = Invoke-BridgeProcess -ToolName "editor-application-get-state"

$refreshOutput = $null
if (-not $SkipAssetsRefresh) {
    $refreshJson = @{
        options = "ForceSynchronousImport"
    } | ConvertTo-Json -Compress -Depth 10
    $refreshOutput = Invoke-BridgeProcess -ToolName "assets-refresh" -JsonLiteral $refreshJson
}

$testsOutputs = New-Object System.Collections.Generic.List[string]
if (-not $SkipTests) {
    $testAssemblies = @(
        "FantasyWord.GameCore.EditModeTests"
    )

    foreach ($assemblyName in $testAssemblies) {
        $testsJson = @{
            testMode = "EditMode"
            testAssembly = $assemblyName
            includePassingTests = $false
            includeMessages = $true
            includeStacktrace = $true
            includeLogs = $false
            requestId = ("foundation-smoke-{0}-{1}" -f $assemblyName, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
        } | ConvertTo-Json -Compress -Depth 10

        $testStartedAtUtc = [DateTime]::UtcNow
        $output = Invoke-BridgeProcessWithSingleRetry -ToolName "tests-run" -JsonLiteral $testsJson
        $output = Wait-BridgeTestRunCompletion -InitialOutput $output -StartedAtUtc $testStartedAtUtc
        [void]$testsOutputs.Add(("Assembly={0}`n{1}" -f $assemblyName, $output))
    }
}

Write-Host "Foundation bridge smoke finished."
Write-Host "Heartbeat:"
Write-Host ($heartbeatInfo | ConvertTo-Json -Compress -Depth 5)
Write-Host "EditorState:"
Write-Host $stateOutput

if ($refreshOutput) {
    Write-Host "AssetsRefresh:"
    Write-Host $refreshOutput
}

if ($testsOutputs.Count -gt 0) {
    Write-Host "EditModeTests:"
    foreach ($output in $testsOutputs) {
        Write-Host $output
    }
}
