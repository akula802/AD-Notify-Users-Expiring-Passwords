# Script loops through users and updates their AD user objects with their email address
# Specify the OU, AD domain, and email domain
# Based on the assumption that the AD SamAccountName is the same as their email username

Import-Module ActiveDirectory

#Initial vars
$ignoreList = @("exchangesync", "scanner", "serviceaccount1")
$userou = 'OU=Users,DC=yourdomain,DC=local'
$users = Get-ADUser -Filter * -SearchBase $userou -Properties * `
    | where {$_.Enabled -eq "True"} `
    | where { $_.PasswordNeverExpires -eq $false } `


ForEach($user in $users)
    {
        if (($user.Enabled -eq $true) -and (!($user.EmailAddress)) -and ($user.SamAccountName -notin $ignoreList))
            {
                # To update with a SamAccountName@ format:
                $NewEmail = $user.SamAccountName.ToString() + "@yourdomain.com"
                
                # To update with a firstname.lastname@ format:
                #$firstName = $user.GivenName.Split(" ")[0]
                #$lastName = $user.Surname.Replace(" ", "")
                #$NewEmail = $firstName + "." + $lastName + "@yourdomain.com"
                
                Write-Host $NewEmail

                try
                    {
                        $error.Clear()
                        Set-ADUser $user -Add @{ProxyAddresses="SMTP:$NewEmail"}
                        Set-AdUser $user -EmailAddress $NewEmail
                    } # End try

                catch
                    {
                        Write-Host Something went wrong. Error:`r`n
                        Write-Host $error
                    } # end catch
                    
            }
    }


