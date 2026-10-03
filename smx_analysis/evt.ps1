Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-25)} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'srcds' } |
  Select-Object -First 6 TimeCreated, ProviderName, Id |
  ForEach-Object { $_.TimeCreated.ToString('HH:mm:ss') + ' [' + $_.ProviderName + '] EventID ' + $_.Id }
