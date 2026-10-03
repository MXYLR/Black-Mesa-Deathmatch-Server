$since = (Get-Date).AddMinutes(-60)
$events = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$since} -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 1000,1001,1002,1026 }
foreach ($e in $events | Select-Object -First 10) {
    $msg = $e.Message
    if ($msg.Length -gt 600) { $msg = $msg.Substring(0, 600) }
    Write-Output ("--- {0}  Event {1}  [{2}]" -f $e.TimeCreated, $e.Id, $e.ProviderName)
    Write-Output $msg
    Write-Output ""
}
Write-Output "=== Steam dumps ==="
Get-ChildItem 'C:\Program Files (x86)\Steam\dumps' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since } | Select-Object -First 5 Name, LastWriteTime | Format-Table -AutoSize
Write-Output "=== srcds dir dumps ==="
Get-ChildItem 'F:\BMServer' -Recurse -Include *.mdmp,*.dmp -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since } | Select-Object -First 5 FullName, LastWriteTime | Format-Table -AutoSize
