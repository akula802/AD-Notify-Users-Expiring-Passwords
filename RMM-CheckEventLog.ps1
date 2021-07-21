# Checks if the script ran successfully, by looking for its log entry
# If the event is not found, the RMM can raise an alert, as the notoifier script did not run successfuly

$Time = [DateTime]::Now.AddHours(-4)
$Test = Get-EventLog -LogName Application -After $Time | Where-Object {$_.EventID -eq 101 -and $_.Message -match "The EmailADUsersWithExpiringPasswords task has completed successfully."}

if (!$test)
    {
        Write-Host Log entry not found!
    }
else
    {
        Write-Host $test.TimeGenerated, $test.Message
    }
