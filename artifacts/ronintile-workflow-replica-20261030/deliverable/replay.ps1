param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference = 'Stop'
$package = $PSScriptRoot
$destination = [System.IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $destination) { throw '输出目录已存在，拒绝覆盖。' }
New-Item -ItemType Directory -Path $destination | Out-Null
if (-not $env:NODE_PATH) {
    $existingModules = Join-Path $env:APPDATA 'npm/node_modules/clawdbot/node_modules'
    if (Test-Path -LiteralPath (Join-Path $existingModules 'playwright-core')) { $env:NODE_PATH = $existingModules }
}
$runner = Join-Path $package 'toolkit/ronintile_cli.mjs'
$engine = Join-Path $package 'engine'
$baseOutput = Join-Path $destination 'base'
node $runner --recipe (Join-Path $package 'input/world-recipe.json') --output $baseOutput --engine $engine --quiet true
if ($LASTEXITCODE -ne 0) { throw '原素材完整生成失败；保留现场。' }
$edit = Get-Content -LiteralPath (Join-Path $package 'input/final-edit-template.json') -Raw | ConvertFrom-Json
$edit.project = Join-Path $baseOutput 'project.json'
$editRecipe = Join-Path $destination 'final-edit.json'
[System.IO.File]::WriteAllText($editRecipe, ($edit | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
node $runner --recipe $editRecipe --output (Join-Path $destination 'final') --engine $engine --quiet true
if ($LASTEXITCODE -ne 0) { throw '原生工程继续编辑失败；保留现场。' }
Write-Output ('原生工程：' + (Join-Path $destination 'final/project.json'))
