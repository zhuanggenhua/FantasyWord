[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [ValidateSet("core", "full")]
    [string]$Profile = "full",
    [string]$ExportRoot,
    [string]$TargetProjectRoot,
    [switch]$SkipCleanup
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

if ([string]::IsNullOrWhiteSpace($ExportRoot)) {
    $ExportRoot = Join-Path $ProjectRoot "Temp\FoundationTemplateSmoke\Export\$Profile"
}

if ([string]::IsNullOrWhiteSpace($TargetProjectRoot)) {
    $TargetProjectRoot = Join-Path $ProjectRoot "Temp\FoundationTemplateSmoke\Bootstrap\$Profile"
}

function Invoke-PowerShellFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $command = @(
        "powershell",
        "-ExecutionPolicy", "Bypass",
        "-File", $ScriptPath
    ) + $Arguments

    & $command[0] $command[1..($command.Count - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $ScriptPath (exit code: $LASTEXITCODE)"
    }
}

if (-not $SkipCleanup) {
    foreach ($path in @($ExportRoot, $TargetProjectRoot)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

$exportScript = Join-Path $ProjectRoot "scripts\Export-FoundationTemplate.ps1"
$bootstrapScript = Join-Path $ProjectRoot "scripts\Bootstrap-FoundationTemplate.ps1"

Invoke-PowerShellFile -ScriptPath $exportScript -Arguments @(
    "-ProjectRoot", $ProjectRoot,
    "-OutputRoot", $ExportRoot,
    "-Profile", $Profile
)

Invoke-PowerShellFile -ScriptPath $bootstrapScript -Arguments @(
    "-ProjectRoot", $ProjectRoot,
    "-TargetProjectRoot", $TargetProjectRoot,
    "-Profile", $Profile
)

$targetScriptsRoot = Join-Path $TargetProjectRoot "scripts"
$targetSteps = @(
    "Invoke-WorkspacePreflight.ps1",
    "Invoke-FoundationStaticGate.ps1"
)

if ($Profile -eq "full") {
    $targetSteps += @(
        "Invoke-PluginFacadeBoundaryGate.ps1",
        "Invoke-EquipmentSystemStaticGate.ps1"
    )
}

foreach ($scriptName in $targetSteps) {
    Invoke-PowerShellFile -ScriptPath (Join-Path $targetScriptsRoot $scriptName)
}

Invoke-PowerShellFile -ScriptPath (Join-Path $targetScriptsRoot "Sync-2DRPGFoundation.ps1") -Arguments @(
    "-ProjectRoot", $TargetProjectRoot,
    "-PruneExtraCopiedFiles"
)

Invoke-PowerShellFile -ScriptPath (Join-Path $targetScriptsRoot "Test-FoundationReferenceParity.ps1") -Arguments @(
    "-ProjectRoot", $TargetProjectRoot
)

Invoke-PowerShellFile -ScriptPath (Join-Path $targetScriptsRoot "Invoke-FoundationStaticGate.ps1")

Write-Host "Foundation template smoke finished."
Write-Host "ProjectRoot:" $ProjectRoot
Write-Host "Profile:" $Profile
Write-Host "ExportRoot:" $ExportRoot
Write-Host "TargetProjectRoot:" $TargetProjectRoot
