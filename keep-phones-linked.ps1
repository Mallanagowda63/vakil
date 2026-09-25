# Keeps every USB-connected phone linked to the laptop's Vakil server (port 4000).
# The link (adb reverse) is lost whenever a phone is unplugged or its USB
# restarts; this re-creates it every 3 seconds. Leave it running; Ctrl+C stops it.
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "ADB was not found at $adb." }
$linked = @{}
Write-Host 'Keeping phones linked to the Vakil server (Ctrl+C to stop)...' -ForegroundColor Cyan
while ($true) {
  $devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" } | ForEach-Object { ($_ -split "\s+")[0] }
  foreach ($device in $devices) {
    $current = & $adb -s $device reverse --list 2>$null
    if (-not ($current -match 'tcp:4000 tcp:4000')) {
      & $adb -s $device reverse tcp:4000 tcp:4000 | Out-Null
      Write-Host "$(Get-Date -Format HH:mm:ss) Linked $device to the server" -ForegroundColor Green
    }
  }
  foreach ($gone in @($linked.Keys | Where-Object { $devices -notcontains $_ })) { $linked.Remove($gone); Write-Host "$(Get-Date -Format HH:mm:ss) $gone unplugged" -ForegroundColor Yellow }
  foreach ($device in $devices) { $linked[$device] = $true }
  Start-Sleep -Seconds 3
}
