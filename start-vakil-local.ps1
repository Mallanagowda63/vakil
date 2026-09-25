$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverDirectory = Join-Path $workspace 'vakil\server'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$healthUrl = 'http://localhost:4000/api/health'
$readyUrl = 'http://localhost:4000/api/ready'

if (-not (Test-Path -LiteralPath $adb)) {
  throw "ADB was not found at $adb. Install Android SDK platform-tools first."
}

$deviceLines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" }
if (-not $deviceLines) {
  throw 'No authorized Android phone found. Connect USB, enable USB debugging, and accept the authorization prompt.'
}
$deviceIds = $deviceLines | ForEach-Object { ($_ -split "\s+")[0] }

$backendReady = $false
try {
  $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5
  $backendReady = $health.status -eq 'ok'
} catch {}

if (-not $backendReady) {
  $stdout = Join-Path $serverDirectory 'server-output.log'
  $stderr = Join-Path $serverDirectory 'server-error.log'
  Start-Process -FilePath 'node.exe' -ArgumentList 'src/index.js' -WorkingDirectory $serverDirectory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $deadline = (Get-Date).AddSeconds(60)
  do {
    Start-Sleep -Milliseconds 500
    try {
      $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
      $backendReady = $health.status -eq 'ok'
    } catch {}
  } until ($backendReady -or (Get-Date) -ge $deadline)
}

if (-not $backendReady) {
  throw "Backend failed to start. Check $serverDirectory\server-error.log"
}

$databaseReady = $false
$databaseDeadline = (Get-Date).AddSeconds(60)
do {
  try {
    $ready = Invoke-RestMethod -Uri $readyUrl -TimeoutSec 2
    $databaseReady = $ready.status -eq 'ready'
  } catch {}
  if (-not $databaseReady) { Start-Sleep -Seconds 1 }
} until ($databaseReady -or (Get-Date) -ge $databaseDeadline)

if (-not $databaseReady) {
  throw "Backend started but MongoDB did not become ready. Check $serverDirectory\server-error.log and your internet connection."
}

foreach ($deviceId in $deviceIds) {
  & $adb -s $deviceId reverse tcp:4000 tcp:4000
  if ($LASTEXITCODE -ne 0) { throw "ADB port forwarding failed for $deviceId." }
}

Write-Host "Ready: backend, MongoDB, and USB forwarding are active for $($deviceIds -join ', ')" -ForegroundColor Green
Write-Host 'Phone apps can now connect to http://localhost:4000'
