param([string]$Exe = "F:\BMServer\srcds.exe", [int]$MaxSec = 300)
$logPath = "F:\BMServer\bms\console.log"
$before = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
$p = Start-Process -FilePath $Exe -WorkingDirectory "F:\BMServer" -ArgumentList "-game bms +map dm_boom +maxplayers 16 -condebug" -PassThru
$t0 = Get-Date
$elapsed = 0
while ($elapsed -lt $MaxSec) {
    Start-Sleep -Seconds 15
    $elapsed = [int]((Get-Date) - $t0).TotalSeconds
    $alive = -not $p.HasExited
    $mods = @()
    if ($alive) {
        try { $mods = @($p.Modules | ForEach-Object { $_.ModuleName }) } catch { $mods = @("ERR") }
    }
    $after = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
    $n = $mods.Count
    $hasK32 = $mods -contains "kernel32.dll"
    $hasUser32 = $mods -contains "USER32.dll"
    $wsMB = if ($alive) { [math]::Round($p.WorkingSet64 / 1MB) } else { 0 }
    Write-Output ("t={0}s alive={1} mods={2} kernel32={3} user32={4} wsMB={5} logDeltaKB={6}" -f $elapsed, $alive, $n, $hasK32, $hasUser32, $wsMB, [math]::Round(($after - $before) / 1KB))
    if (-not $alive) { Write-Output "PROCESS EXITED (exit code $($p.ExitCode))"; break }
    if ($hasUser32) { Write-Output "LOADER PROGRESSED PAST EARLY STAGE"; break }
}
if ($p.HasExited) { Write-Output "FINAL: exited code=$($p.ExitCode)" } else { Write-Output ("FINAL: still alive pid={0}" -f $p.Id) }
