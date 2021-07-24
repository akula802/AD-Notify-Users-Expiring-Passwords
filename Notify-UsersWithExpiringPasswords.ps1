# This script provides two functions
# The first defines an email-send tool, that uses SendGrid as a mail server (can be tweaked for Exchange or other)
# The second loops through AD and finds users with soon-expiring passwords
# When the second is done, it writes to the event log for monitoring



# First, a function to send emails
Function Send-EmailToUsers(){

    # Required parameters
    Param(
        [Parameter(Mandatory=$true)]
        [string]$EmailTo,
        [string]$Subject,
        [string]$Message
    )

    # Get current timestamp and local computer name
    $now = ([DateTime]::Now).ToString()
    $CompName = Get-Content Env:\COMPUTERNAME


# String to separate log entries for readability
$separator = @"

---------------------------------------------------------

"@


    # Construct the email credentials for the SendGrid user
    # Refer to this for generating these SecureString text files - it's not all that secure, other encryption could be used
    # https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-1/
    $username = "SendGridUser"
    $pass = Get-Content C:\ProgramData\Scripts\emailPass.txt | ConvertTo-SecureString
    $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $pass


    # Build the email parameters as splatting hash table
    $param = @{
        SmtpServer = "smtp.sendgrid.net"
        Port = 587
        UseSsl = $false
        Credential = $Creds
        From = "alerts@yourdomain.com"
        To = $EmailTo
        Subject = $Subject
        Body = $Message
    }


    # Clear the built-in error variable prior to sending admin email
    $error.Clear()


    # Send the email
    # If message fails, creates a failedEmailLog.txt file to assist in troubleshooting
    # Records whether it had problems connecting to the mail server, or with command syntax
    try {

        Send-MailMessage @param -BodyAsHtml

        if (!$error -eq $false) {
            # Don't forget to change the next line so your log file goes to the proper place
            $failedEmailLog = "C:\ProgramData\Scripts\failedEmailLog.txt"
            If (-Not (Test-Path $failedEmailLog)) {Out-File $failedEmailLog -Encoding ascii}
            Add-Content $failedEmailLog "Script was successful, but failed to send email at $now. See error below. `r`n"
            Add-Content $failedEmailLog $error
            Add-Content $failedEmailLog $separator
            } # End if loop
        } # End try block

    catch {
        # Don't forget to change the next line so your log file goes to the proper place
        $failedEmailLog = "C:\ProgramData\Scripts\failedEmailLog.txt"
        If (-Not (Test-Path $failedEmailLog)) {Out-File $failedEmailLog -Encoding ascii}
        Add-Content $failedEmailLog "Script was successful, but failed to invoke Send-MailMessage command at $now. See error below. `r`n"
        Add-Content $failedEmailLog $error
        Add-Content $failedEmailLog $separator
        } # End catch block


} # End function Send-EmailToUsers



# Second, a function to loop throuhg AD and email the users with nearly-expired passwords
Function Check-ADUsersPasswordsExpiringSoon(){

    # First, import the necessary modules etc.
    Import-Module ActiveDirectory

    # Second, define initial variables
    $ignoreList = @("serviceaccount1", "sql", "exchangesync", "scanner", "adminuser1")
    $AllUsers = get-aduser -filter * -properties * | Where-Object {$_.Enabled -eq "True"} | Where-Object { $_.PasswordNeverExpires -eq $false } `
    | Where-Object { $_.passwordexpired -eq $false } | Where-Object {$_.Name -notlike "SBS*"} | Where-Object {$_.SamAccountName -NotIn $ignoreList}


    # Do the needful
    Write-Host Starting the foreach loop in Check-ADUsersPassowrdsExpiringSoon

    # Loop through users
    foreach ($User in $AllUsers)
        {
            # Grab some details
            $Name = (Get-ADUser $User | ForEach-Object { $_.Name})
            $Email = $User.emailaddress
            $PasswdSetDate = (get-aduser $User -properties * | ForEach-Object { $_.PasswordLastSet })
            $MaxPasswdAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
            $ExpireDate = $PasswdSetDate + $MaxPasswdAge
            $Today = (get-date)
            $DaysToExpire = (New-TimeSpan -Start $Today -End $ExpireDate).Days

            # Details for the email function
            $EmailSubject="Password Expiry Notice - your password expires in $DaystoExpire days"
            $Message = "<p>Dear $Name,</p>

    <p>Your domain password will expire in $DaysToExpire days.</p>

    <p>To change your password, press CTRL+ ALT + DEL together and select the 'Change Password' option. If you are not at the office, you will first need to connect to the VPN.</p>

    <p>If you do not update your password in $DaysToExpire days, you will not be able to log in, so please make sure you update your password.</p>

    <p>If you need any help, contact the help desk by phone at 555-555-1234.</p><br />

    <p>Sincerely,<br /><br />
    IT Department
    </p>"


            # Do the needful
            if (($DaysToExpire -lt 10) -and ($Email)) # 10 day reminder
                {
                    # Send email indicating pw expires in 10 days, on $ExpireDate
                    Write-Host $Name ($Email), password expires in $DaysToExpire days.
                    Send-EmailToUsers -EmailTo $Email -Subject $EmailSubject -Message $Message
                }

            if (($DaysToExpire -eq 5) -and ($Email)) #5 day reminder
                {
                    # Send email indicating pw expires in 5 days, on $ExpireDate
                    Write-Host $Name ($Email), password expires in $DaysToExpire days.
                    Send-EmailToUsers -EmailTo $Email -Subject $EmailSubject -Message $Message
                }

            if (($DaysToExpire -eq 1) -and ($Email)) #1 day reminder
                {
                    # Send email indicating pw expires in 1 day, on $ExpireDate
                    Write-Host $Name ($Email), password expires in $DaysToExpire days.
                    Send-EmailToUsers -EmailTo $Email -Subject $EmailSubject -Message $Message
                } 
                  
        } # End foreach loop

        Write-Host Finished doing the things in the foreach loop of Check-ADUsersPassowrdsExpiringSoon
        Write-Host Creating the Application log entry...

        Try
            {
                $error.Clear()
                if ([system.diagnostics.eventlog]::SourceExists(“LTService”) -eq $true)
                    {
                        Write-EventLog -LogName Application -Source "LTService" -EntryType Information -EventId 101  -Message "The EmailADUsersWithExpiringPasswords task has completed successfully." -Category 1 #-ErrorAction SilentlyContinue
                    }
                else
                    {
                        New-EventLog -LogName Application -Source “LTService”
                        Write-EventLog -LogName Application -Source "LTService" -EntryType Information -EventId 101  -Message "The EmailADUsersWithExpiringPasswords task has completed successfully." -Category 1
                    }
            }
        Catch
            {
                Write-Host Failed to write to the event log. Error:
                Write-Host $error
            }


} # End function Check-ADUsersPasswordsExpiringSoon



# Do the things
Check-ADUsersPasswordsExpiringSoon
