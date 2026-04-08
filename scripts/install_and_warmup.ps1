param(
    [string]$VenvDir = ".venv",
    [string]$CacheDir = "model_cache",
    [switch]$NoCnMirror,
    [string]$PypiIndexUrl = "https://pypi.tuna.tsinghua.edu.cn/simple",
    [string]$HttpProxy = "",
    [string]$HttpsProxy = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-HostPython {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 @Args
        return
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        & python @Args
        return
    }
    throw "Python is not installed. Install Python 3.12+ first."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path (Join-Path $scriptDir "..")).Path
$venvPath = Join-Path $rootDir $VenvDir
$cachePath = Join-Path $rootDir $CacheDir
$pythonBin = Join-Path $venvPath "Scripts\python.exe"
$qwenScript = Join-Path $rootDir "scripts\qwen3_tts.py"
$placeholderWav = Join-Path $rootDir "outputs\placeholder.wav"

Write-Host "[1/4] create virtualenv: $venvPath"
Invoke-HostPython -Args @("-m", "venv", $venvPath)

if (-not (Test-Path $pythonBin)) {
    throw "Virtualenv python not found: $pythonBin"
}

Write-Host "[2/4] install qwen-tts"
& $pythonBin -m pip install -U pip
& $pythonBin -m pip install -U qwen-tts -i $PypiIndexUrl

Write-Host "[3/4] warm up model cache: $cachePath"
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null

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

Write-Host "[4/4] done"
Write-Host "Run TTS with:"
Write-Host "  $pythonBin $qwenScript --text `"你好`" --output $(Join-Path $rootDir 'outputs\reply.wav') --cache-dir $cachePath"
