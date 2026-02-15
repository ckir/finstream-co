while ($true) {
    $ts = [int][double]::Parse((Get-Date -UFormat %s))
    Write-Output ('{ "price": 123.45, "ts": ' + $ts + ' }')
    Start-Sleep -Seconds 1
}
