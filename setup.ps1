#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Setup one-click per Skin Analyzer Pro — Flutter Windows Desktop
  Installa i prerequisiti mancanti (VS C++ Build Tools) e prepara il progetto.
.USAGE
  Aprire PowerShell come Amministratore e lanciare:
    Set-ExecutionPolicy Bypass -Scope Process; .\setup.ps1
#>

$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Write-Step([string]$msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}
function Write-OK([string]$msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}
function Write-Warn([string]$msg) {
    Write-Host "  [!]  $msg" -ForegroundColor Yellow
}
function Write-Fail([string]$msg) {
    Write-Host "  [X]  $msg" -ForegroundColor Red
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Flutter
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Verifica Flutter..."
try {
    $flutterVer = (flutter --version 2>&1 | Select-Object -First 1).ToString()
    Write-OK "Flutter trovato: $flutterVer"
} catch {
    Write-Fail "Flutter non trovato. Installalo da https://flutter.dev e aggiungi al PATH."
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Visual Studio — verifica workload C++
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Verifica Visual Studio C++ Build Tools..."

$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msvcOk = $false

if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vsPath) {
        $msvcOk = $true
        Write-OK "MSVC v143 trovato in: $vsPath"
    }
}

if (-not $msvcOk) {
    Write-Warn "MSVC v143 e/o Windows 10 SDK mancanti. Avvio installazione..."

    $vsInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
    if (-not (Test-Path $vsInstallerPath)) {
        Write-Fail "Visual Studio Installer non trovato. Installa VS 2022 da https://visualstudio.microsoft.com/"
        Write-Warn "Poi seleziona: 'Sviluppo di applicazioni desktop con C++'"
        exit 1
    }

    Write-Host "  Installazione componenti in corso (può richiedere qualche minuto)..." -ForegroundColor Yellow
    $args = @(
        'modify',
        '--installPath', (& $vsWhere -latest -products * -property installationPath),
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '--add', 'Microsoft.VisualStudio.Component.Windows10SDK.19041',
        '--quiet', '--norestart'
    )
    $proc = Start-Process -FilePath $vsInstallerPath -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-OK "Componenti installati con successo."
        if ($proc.ExitCode -eq 3010) {
            Write-Warn "RIAVVIO RICHIESTO per completare l'installazione. Riavvia e riesegui questo script."
            exit 0
        }
    } else {
        Write-Fail "Installazione fallita (exit code: $($proc.ExitCode)). Installa manualmente."
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Crea il progetto Flutter Windows se non esiste già
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Inizializzazione progetto Flutter..."

$windowsDir = Join-Path $ProjectDir "windows"
if (Test-Path $windowsDir) {
    Write-OK "Cartella windows/ già presente — skip flutter create."
} else {
    Write-Host "  Esecuzione 'flutter create --platforms=windows .' ..." -ForegroundColor Yellow

    Push-Location $ProjectDir
    try {
        flutter create --platforms=windows . 2>&1 | Tee-Object -Variable createOut
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "flutter create fallito. Output: $createOut"
            exit 1
        }
        Write-OK "Progetto Flutter creato."
    } finally {
        Pop-Location
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Crea cartella assets/ se mancante
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Setup assets..."
$assetsDir = Join-Path $ProjectDir "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir | Out-Null
}
Write-OK "assets/ presente."

# ─────────────────────────────────────────────────────────────────────────────
# 5. flutter pub get
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Installazione dipendenze Flutter (pub get)..."
Push-Location $ProjectDir
try {
    flutter pub get 2>&1 | Tee-Object -Variable pubOut
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "flutter pub get fallito."
        Write-Host $pubOut
        exit 1
    }
    Write-OK "Dipendenze installate."
} finally {
    Pop-Location
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Configurazione Windows manifest (nome app in italiano)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Aggiornamento runner.rc (nome app)..."

$rcFile = Join-Path $ProjectDir "windows\runner\Runner.rc"
if (Test-Path $rcFile) {
    $rc = Get-Content $rcFile -Raw
    $rc = $rc -replace 'VALUE "FileDescription",.*', 'VALUE "FileDescription", "Skin Analyzer Pro\0"'
    $rc = $rc -replace 'VALUE "ProductName",.*', 'VALUE "ProductName", "Skin Analyzer Pro\0"'
    Set-Content $rcFile $rc -Encoding UTF8
    Write-OK "Runner.rc aggiornato."
} else {
    Write-Warn "Runner.rc non trovato — skip."
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. Build di verifica (optional — commenta se vuoi solo pub get)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Build Windows Release..."
Push-Location $ProjectDir
try {
    flutter build windows --release 2>&1 | Tee-Object -Variable buildOut
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Build fallita. Controlla i messaggi sopra."
        Write-Host ($buildOut | Select-Object -Last 30 | Out-String)
        exit 1
    }
    Write-OK "Build completata."
} finally {
    Pop-Location
}

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
$exePath = Join-Path $ProjectDir "build\windows\x64\runner\Release\skin_analyzer.exe"
Write-Host "`n" -NoNewline
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         Skin Analyzer Pro — Setup Completato!        ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Eseguibile: build\windows\x64\runner\Release\       ║" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "║  Per avviare in debug:  flutter run -d windows        ║" -ForegroundColor Green
Write-Host "║  Per rebuild release:   flutter build windows         ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green

if (Test-Path $exePath) {
    Write-Host "`nVuoi avviare l'app ora? (s/n): " -NoNewline -ForegroundColor Cyan
    $ans = Read-Host
    if ($ans -eq 's' -or $ans -eq 'S') {
        Start-Process $exePath
    }
}
