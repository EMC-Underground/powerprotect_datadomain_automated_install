function secure-password {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [array]$Application
    )
    if($Application.Length -gt 1){
        $MySecureString = Read-Host "[$($Application -join ',')]: Enter the common password for your accounts:" -AsSecureString
        $Application | ForEach-Object {
            if($MySecureString -ne '') {
                Set-Content ".\passwords\_$($_).txt" (ConvertFrom-SecureString -SecureString $MySecureString)
            } #END IF
        } #END IF
    } else {
        $MySecureString = Read-Host "[$($Application)]: Enter the password for your account:" -AsSecureString
        if($MySecureString -ne '') {
            Set-Content ".\passwords\_$($Application).txt" (ConvertFrom-SecureString -SecureString $MySecureString)
        } #END IF
    } #END ELSE
    
}
Write-Host "[SECURE]: Passwords for your data protection accounts (AES-256-CBC)..." -foregroundcolor Yellow
do {
    $Prompt = Read-Host "[Application]: Which password would you like to secure?
    `n1. Avamar
    `n2. Data Domain
    `n3. DDBoost
    `n4. Networker
    `n5. PowerProtect
    `n6. vCenter
    `n7. vProxy
    `nCommon
    `nExit  
    `n(Enter an option):"
    switch($Prompt){
        1{secure-password -Application 'AVAMAR'}
        2{secure-password -Application 'DDVE'}
        3{secure-password -Application 'DDBOOST'}
        4{secure-password -Application 'NETWORKER'}
        5{secure-password -Application 'POWERPROTECT'}
        6{secure-password -Application 'VCENTER'}
        7{secure-password -Application 'VPROXY'}
        'Common'{
            [array]$MyApps = @('AVAMAR','DDVE','DDBOOST','NETWORKER','POWERPROTECT','VPROXY')
            secure-password -Application $MyApps
        }
        'Exit' {
            Write-Host "[EXITITING]: You have chosen to exit the secure passwords script." -foregroundcolor Yellow
        }
    }   
} until ($Prompt -eq 'Exit')