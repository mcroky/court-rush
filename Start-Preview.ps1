param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$taskUrl = 'http://127.0.0.1:8791/'
$taskNode = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $taskNode) {
    $taskNode = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
}
if (-not (Test-Path -LiteralPath $taskNode)) { throw 'Node.js를 설치한 뒤 다시 실행해 주세요.' }
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'build\web\index.html'))) { throw '웹 빌드가 없습니다. README의 빌드 순서를 먼저 실행하세요.' }
$taskRunning = $false
try {
    $taskResponse = Invoke-WebRequest -Uri $taskUrl -TimeoutSec 2
    if ($taskResponse.Content -notmatch 'COURT RUSH') { throw '8791 포트를 다른 서비스가 사용하고 있습니다.' }
    $taskRunning = $true
} catch {
    if ($_.Exception.Message -match '다른 서비스') { throw }
}
if (-not $taskRunning) {
    New-Item -ItemType Directory -Force -Path (Join-Path $taskRoot 'artifacts') | Out-Null
    $taskServer = Join-Path $taskRoot 'tools\serve.mjs'
    $taskProcess = Start-Process -FilePath $taskNode -ArgumentList @(('"' + $taskServer + '"'), '8791') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRoot 'artifacts\preview.log') -RedirectStandardError (Join-Path $taskRoot 'artifacts\preview-error.log')
    Set-Content -LiteralPath (Join-Path $taskRoot 'artifacts\preview.pid') -Value $taskProcess.Id
    for ($taskAttempt = 0; $taskAttempt -lt 20; $taskAttempt++) {
        try { $null = Invoke-WebRequest -Uri $taskUrl -TimeoutSec 1; $taskRunning = $true; break } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $taskRunning) { throw '미리보기 서버가 시작되지 않았습니다. artifacts/preview-error.log를 확인하세요.' }
}
Write-Output ('코트러시: ' + $taskUrl)
if (-not $NoBrowser) { Start-Process $taskUrl }
