param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Name,
    [int]$Wait = 30
)
$logPath = "F:\BMServer\bms\console.log"
$before = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
$p = Start-Process -FilePath $Exe -WorkingDirectory "F:\BMServer" -ArgumentList "-game bms +map dm_boom +maxplayers 16 -condebug" -WindowStyle Minimized -PassThru
Start-Sleep -Seconds $Wait
$alive = $null -ne $p -and -not $p.HasExited
$mods = ""
$wsMB = 0
if ($alive) {
    try {
        $wsMB = [math]::Round($p.WorkingSet64 / 1MB)
        $mods = ($p.Modules | ForEach-Object { $_.ModuleName }) -join ","
    } catch { $mods = "ERR" }
}
$after = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
$earlyOK = $mods -match "kernel32"
$logGrew = ($after - $before) -gt 5120
Write-Output ("TRIAL {0} alive={1} earlyOK={2} logGrew={3} wsMB={4} mods={5}" -f $Name, $alive, $earlyOK, $logGrew, $wsMB, $mods)
if ($alive) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
