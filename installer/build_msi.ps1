# Gera dist\Camara7-<versão>.msi a partir de dist\Camara 7.exe + dist\Camara 7.pck (rode "Gerar EXE.bat" antes).
# Requisitos: Python + Pillow, WiX 3 em %USERPROFILE%\Tools\wix3 (ou $env:WIX3)
$ErrorActionPreference = "Continue"   # cada passo confere $LASTEXITCODE
$root = Split-Path -Parent $PSScriptRoot
$wix = if ($env:WIX3) { $env:WIX3 } else { "$env:USERPROFILE\Tools\wix3" }
$version = (Get-Content "$root\data\config\game.json" -Raw -Encoding UTF8 | ConvertFrom-Json).version
$build = "$PSScriptRoot\build"

python "$PSScriptRoot\make_assets.py"
if ($LASTEXITCODE -ne 0) { throw "make_assets falhou" }

$exe = "$root\dist\Camara 7.exe"
$pck = "$root\dist\Camara 7.pck"
if (-not (Test-Path $exe) -or -not (Test-Path $pck)) { throw "Exporte o jogo antes (Gerar EXE.bat): $exe + $pck" }

& "$wix\candle.exe" -nologo -arch x64 -ext WixUIExtension -ext WixUtilExtension `
    "-dVersion=$version" "-dExePath=$exe" "-dPckPath=$pck" "-dIconPath=$root\icon.ico" `
    "-dReadmePath=$build\LEIA-ME.txt" "-dLicensePath=$build\license.rtf" `
    "-dBannerPath=$build\banner.bmp" "-dDialogPath=$build\dialog.bmp" `
    -out "$build\Camara7.wixobj" "$PSScriptRoot\Camara7.wxs"
if ($LASTEXITCODE -ne 0) { throw "candle falhou" }

$msi = "$root\dist\Camara7-$version.msi"
& "$wix\light.exe" -nologo -ext WixUIExtension -ext WixUtilExtension -cultures:pt-BR `
    -spdb -sice:ICE61 -sice:ICE91 -out $msi "$build\Camara7.wixobj"
if ($LASTEXITCODE -ne 0) { throw "light falhou" }
Write-Output "MSI: $msi"
