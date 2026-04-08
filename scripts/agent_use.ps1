param(
    [Parameter(Mandatory = $true)]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [string]$Output,

    [string]$CacheDir = "model_cache",
    [string]$ModelId = "Qwen/Qwen3-TTS-12Hz-0.6B-Base",
    [ValidateSet("auto", "base", "clone", "custom", "design")]
    [string]$VoiceMode = "auto",
    [string]$Speaker = "",
    [string]$Instruct = "",
    [string]$SpkAudio = "",
    [string]$SpkText = "",
    [string]$Language = "",
    [switch]$NoCnMirror,
    [string]$HttpProxy = "",
    [string]$HttpsProxy = "",
    [string]$PypiIndexUrl = "https://pypi.tuna.tsinghua.edu.cn/simple"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path (Join-Path $scriptDir "..")).Path
$venvPath = Join-Path $rootDir ".venv"
$pythonBin = Join-Path $venvPath "Scripts\python.exe"
$qwenScript = Join-Path $rootDir "scripts\qwen3_tts.py"
$cachePath = Join-Path $rootDir $CacheDir
$installScript = Join-Path $rootDir "scripts\install_and_warmup.ps1"
$placeholderWav = Join-Path $rootDir "outputs\placeholder.wav"

if (-not (Test-Path $pythonBin)) {
    Write-Host "info: runtime missing, running install_and_warmup.ps1 ..."
    $installArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $installScript,
        "-VenvDir", ".venv",
        "-CacheDir", $CacheDir,
        "-PypiIndexUrl", $PypiIndexUrl,
        "-HttpProxy", $HttpProxy,
        "-HttpsProxy", $HttpsProxy
    )
    if ($NoCnMirror) {
        $installArgs += "-NoCnMirror"
    }
    & powershell @installArgs
}

if (-not (Test-Path $pythonBin)) {
    throw "Virtualenv python not found: $pythonBin"
}

& $pythonBin -m pip show qwen-tts *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "info: qwen-tts not found in venv, installing ..."
    & $pythonBin -m pip install -U qwen-tts -i $PypiIndexUrl
}

if (-not (Test-CommandAvailable "sox")) {
    throw @"
Missing external dependency: sox

Install SoX and reopen PowerShell so PATH is refreshed.
Then verify with:
  sox --version

Windows download:
  https://sourceforge.net/projects/sox/
"@
}

New-Item -ItemType Directory -Force -Path $cachePath | Out-Null

if (-not (Test-Path (Join-Path $cachePath "hub"))) {
    Write-Host "info: model cache missing, pre-downloading ..."
    $warmupArgs = @(
        $qwenScript,
        "--output", $placeholderWav,
        "--download-only",
        "--cache-dir", $cachePath
    )
    if (-not $NoCnMirror) {
        $warmupArgs += "--cn-mirror"
    }
    if ($HttpProxy) {
        $warmupArgs += @("--http-proxy", $HttpProxy)
    }
    if ($HttpsProxy) {
        $warmupArgs += @("--https-proxy", $HttpsProxy)
    }
    & $pythonBin @warmupArgs
}

$ttsArgs = @(
    $qwenScript,
    "--text", $Text,
    "--output", $Output,
    "--cache-dir", $cachePath,
    "--model-id", $ModelId,
    "--voice-mode", $VoiceMode
)

if (-not $NoCnMirror) {
    $ttsArgs += "--cn-mirror"
}
if ($Speaker) {
    $ttsArgs += @("--speaker", $Speaker)
}
if ($Instruct) {
    $ttsArgs += @("--instruct", $Instruct)
}
if ($SpkAudio) {
    $ttsArgs += @("--spk-audio", $SpkAudio)
}
if ($SpkText) {
    $ttsArgs += @("--spk-text", $SpkText)
}
if ($Language) {
    $ttsArgs += @("--language", $Language)
}
if ($HttpProxy) {
    $ttsArgs += @("--http-proxy", $HttpProxy)
}
if ($HttpsProxy) {
    $ttsArgs += @("--https-proxy", $HttpsProxy)
}

& $pythonBin @ttsArgs
