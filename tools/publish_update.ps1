# Publica uma atualização do Câmara 7 no GitHub (os jogos instalados baixam sozinhos).
#
#   powershell -File tools\publish_update.ps1                         # sobe a versão (0.6.0 -> 0.6.1) e publica
#   powershell -File tools\publish_update.ps1 -Version 0.7.0 -Notes "Novos inimigos"
#   powershell -File tools\publish_update.ps1 -Installer              # também gera e anexa .exe/.msi (1º release ou motor novo)
#   -SkipTests  pula os testes automáticos (não recomendado)
#
# O que faz: ajusta a versão -> roda os testes -> exporta só o conteúdo (Camara7.pck, ~4 MB) -> gera update.json
# (versão, motor, SHA-256) -> commit + tag com a SUA conta do git -> cria o release no GitHub com os arquivos.
param(
    [string]$Version = "",
    [string]$Notes = "",
    [switch]$Installer,
    [switch]$SkipTests
)
# "Continue": o Godot escreve avisos no stderr e o PowerShell 5.1 trataria isso como erro fatal.
# Cada passo confere o próprio resultado e para com throw se algo falhar.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$godot = if ($env:GODOT) { $env:GODOT } else { "$env:USERPROFILE\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Yellow }

# ---------------------------------------------------------------- pré-requisitos
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI não está logado. Rode: gh auth login" }
$repo = (Get-Content "data\config\update.json" -Raw -Encoding UTF8 | ConvertFrom-Json).repo
$engine = ((& $godot --version) -split "\.")[0..2] -join "."

# ---------------------------------------------------------------- versão
$gamePath = "data\config\game.json"
$gameText = [IO.File]::ReadAllText("$root\$gamePath", $utf8)
$current = ($gameText | ConvertFrom-Json).version
if ($Version -eq "") {
    $p = $current.Split(".")
    $Version = "{0}.{1}.{2}" -f $p[0], $p[1], ([int]$p[2] + 1)
}
$Version = $Version.TrimStart("v")
if ($Notes -eq "") { $Notes = Read-Host "O que mudou nesta versão (uma linha)" }
Step "Versão $current -> $Version (motor $engine)"
$gameText = $gameText -replace '"version":\s*"[^"]*"', ('"version": "' + $Version + '"')
[IO.File]::WriteAllText("$root\$gamePath", $gameText, $utf8)
$presets = [IO.File]::ReadAllText("$root\export_presets.cfg", $utf8)
$presets = $presets -replace 'application/(file|product)_version="[^"]*"', ('application/$1_version="' + $Version + '.0"')
[IO.File]::WriteAllText("$root\export_presets.cfg", $presets, $utf8)

# ---------------------------------------------------------------- testes
& $godot --headless --path . --import *> $null
if (-not $SkipTests) {
    Step "Testes"
    $out = & $godot --headless --path . res://tests/check_scripts.tscn 2>&1 | Out-String
    if ($out -match "FALHOU|SCRIPT ERROR") { Write-Host $out; throw "Scripts com erro — nada foi publicado." }
    $out = & $godot --headless --path . res://tests/smoke_test.tscn 2>&1 | Out-String
    if ($out -notmatch "SMOKE TEST OK") { ($out -split "`n" | Select-String "FAIL|ERROR") | ForEach-Object { Write-Host $_ }; throw "Smoke test falhou — nada foi publicado." }
    Write-Host "testes ok"
}

# ---------------------------------------------------------------- exportar
Step "Exportando"
New-Item -ItemType Directory -Force "dist" | Out-Null
$assets = @()
Remove-Item "dist\Camara7.pck", "dist\update.json", "dist\Camara 7.exe", "dist\Camara 7.pck", "dist\Camara7-$Version.msi" -ErrorAction SilentlyContinue
& $godot --headless --path . --export-pack "Windows Desktop" "dist\Camara7.pck" *> $null
if (-not (Test-Path "dist\Camara7.pck")) { throw "Export do .pck falhou." }
$assets += "dist\Camara7.pck"
if ($Installer) {
    & $godot --headless --path . --export-release "Windows Desktop" "dist\Camara 7.exe" *> $null
    if (-not (Test-Path "dist\Camara 7.exe")) { throw "Export do .exe falhou." }
    & "$PSScriptRoot\..\installer\build_msi.ps1"
    if (-not (Test-Path "dist\Camara7-$Version.msi")) { throw "Instalador falhou." }
    $assets += "dist\Camara7-$Version.msi"
}
$sha = (Get-FileHash "dist\Camara7.pck" -Algorithm SHA256).Hash.ToLower()
$manifest = [ordered]@{ version = $Version; engine = $engine; pck_sha256 = $sha; pck_size = (Get-Item "dist\Camara7.pck").Length; notes = $Notes }
[IO.File]::WriteAllText("$root\dist\update.json", ($manifest | ConvertTo-Json), $utf8)
$assets += "dist\update.json"
Write-Host ("pck: {0:N1} MB  sha256 {1}" -f ((Get-Item "dist\Camara7.pck").Length / 1MB), $sha.Substring(0, 12))

# ---------------------------------------------------------------- git + release
Step "Commit e release em $repo"
$null = git add -A 2>&1
$null = git commit -m "Versão $Version`: $Notes" 2>&1
$null = git tag -a "v$Version" -m "Câmara 7 v$Version" 2>&1
$null = git push origin HEAD --follow-tags 2>&1
if ($LASTEXITCODE -ne 0) { throw "git push falhou." }
$body = "$Notes`n`n---`nQuem já tem o jogo instalado recebe esta versão sozinho ao abrir o jogo.`nPrimeira instalação: baixe o arquivo .msi do release mais recente que tiver um."
gh release create "v$Version" @assets --repo $repo --title "Câmara 7 v$Version" --notes $body
if ($LASTEXITCODE -ne 0) { throw "gh release falhou." }
Step "Publicado: https://github.com/$repo/releases/tag/v$Version"
