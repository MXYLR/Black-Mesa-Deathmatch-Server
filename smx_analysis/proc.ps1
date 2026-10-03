$p = Get-Process -Id 44616 -ErrorAction SilentlyContinue
if (-not $p) { Write-Output "process gone"; exit }
Write-Output "=== Threads ==="
$p.Threads | Select-Object Id, ThreadState, WaitReason | Group-Object WaitReason | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
Write-Output "=== Modules ==="
$p.Modules | Select-Object -ExpandProperty ModuleName | Sort-Object -Unique
