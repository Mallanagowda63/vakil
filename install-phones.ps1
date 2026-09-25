# Builds small release APKs (arm64 only) and installs them as updates on every
# connected phone that has the app. `adb install -r` keeps each app's login.
# Use this instead of `flutter run` on phones with little free storage.
# Optional: -ServerIp 192.168.1.14 builds with that server address.
param([string]$ServerIp = '')

$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "ADB was not found at $adb." }

$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" } | ForEach-Object { ($_ -split "\s+")[0] }
if (-not $devices) { throw 'No phone found. Connect USB, enable USB debugging, and accept the prompt on the phone.' }

$define = @()
if ($ServerIp) { $define = @("--dart-define=API_BASE_URL=http://${ServerIp}:4000") }

$apps = @(
  @{ Folder = 'vakil'; Package = 'com.vakil.vakil'; Name = 'User App' },
  @{ Folder = 'partner'; Package = 'com.vakilpartner.vakil_partner'; Name = 'Partner App' }
)

foreach ($app in $apps) {
  $targets = $devices | Where-Object { (& $adb -s $_ shell pm list packages $app.Package) -match [regex]::Escape($app.Package) }
  if (-not $targets) { Write-Host "$($app.Name): not installed on any connected phone, skipped." -ForegroundColor Yellow; continue }
  Write-Host "Building $($app.Name)..." -ForegroundColor Cyan
  Push-Location (Join-Path $workspace $app.Folder)
  try {
    flutter build apk --release --target-platform android-arm64 @define
    if ($LASTEXITCODE -ne 0) { throw "$($app.Name) build failed." }
    $apk = Join-Path (Get-Location) 'build\app\outputs\flutter-apk\app-release.apk'
    foreach ($device in $targets) {
      $model = (& $adb -s $device shell getprop ro.product.model).Trim()
      Write-Host "Installing $($app.Name) on $model..." -ForegroundColor Cyan
      & $adb -s $device install -r $apk
      if ($LASTEXITCODE -ne 0) { Write-Host "Install failed on $model. Free some storage on the phone and try again." -ForegroundColor Red }
    }
  } finally { Pop-Location }
}
Write-Host 'Done. If an app says it cannot reach the server, open "Server address" on its sign-in screen.' -ForegroundColor Green
