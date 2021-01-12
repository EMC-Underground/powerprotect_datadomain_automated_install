Import-Module '.\modules\dellemc.ppdm.deployment.psm1'
$cfg = Import-PowerShellDataFile -Path '.\config\config.psd1'

#TIMER
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.start()

#VMWARE
$vSpherePwd = (Get-Content '.\passwords\_VCENTER.txt') | ConvertTo-SecureString 
$vSphereCredObject = New-Object System.Management.Automation.PSCredential -ArgumentList $cfg.vmware.account, $vSpherePwd

#POWERPROTECT
$vAppCredObject = New-Object System.Management.Automation.PSCredential `
-ArgumentList $cfg.powerprotect.account, ($cfg.powerprotect.oldpwd | ConvertTo-SecureString -AsPlainText -Force)

<# NEW PPDM ADMIN PASSWORD FOR TROUBLESHOOTING
$vappPwd = (Get-Content '..\passwords\_POWERPROTECT.txt') | ConvertTo-SecureString 
$vAppCredObject = New-Object System.Management.Automation.PSCredential `
-ArgumentList $cfg.powerprotect.account, $vappPwd
#>

#DATADOMAIN
$ddvePwd = (Get-Content '.\passwords\_DDVE.txt') | ConvertTo-SecureString 
$ddveCredObject = New-Object System.Management.Automation.PSCredential -ArgumentList $cfg.datadomain.account, $ddvePwd

$ErrorActionPreference ='stop'

#CONNECT TO VCENTER SERVER
try
{
    Write-Host "[CONNECTING] to: $($cfg.vmware.vcenter)"
    $Con = Connect-VIServer -Protocol https -Server $cfg.vmware.vcenter -Credential $vSphereCredObject
}
catch {
    Write-Host "Unable to connect to: $($cfg.vmware.vcenter)" -ForegroundColor Red
    exit;
}


deploy-ppdm `
    -vAppConnection $Con `
    -vAppHost $cfg.powerprotect.esxi `
    -vAppDataStore $cfg.powerprotect.datastore `
    -vAppFolder $cfg.powerprotect.folder `
    -vAppNetwork $cfg.powerprotect.vswitch `
    -vAppName $cfg.powerprotect.name `
    -vAppDomain $cfg.powerprotect.domain `
    -vAppIp $cfg.powerprotect.ip `
    -vAppSubnet $cfg.powerprotect.netmask `
    -vAppGateway $cfg.powerprotect.gateway `
    -vAppDns $cfg.powerprotect.dns `
    -vAppDiskType $cfg.powerprotect.vdisktype `
    -vAppOvaPath $cfg.powerprotect.ova `
    -vAppAccount $cfg.powerprotect.account `
    -vAppDefaultPwd $cfg.powerprotect.oldpwd `
    -vAppApi $cfg.powerprotect.api

    $auth = connect-ppdmrestapi `
     -Server "$($cfg.powerprotect.name).$($cfg.powerprotect.domain)" `
     -Credential $vAppCredObject

    set-ppdminitialconfig `
     -AuthObject $auth `
     -vAppNTP $cfg.powerprotect.ntp `
     -vAppTimezone $cfg.powerprotect.timezone

    add-datadomain `
     -AuthObject $auth `
     -Credential $ddveCredObject `
     -DD "$($cfg.datadomain.name).$($cfg.datadomain.domain)" `

    add-vcenter `
    -AuthObject $auth `
    -Credential $vSphereCredObject `
    -VCenter $cfg.vmware.vcenter

    set-ppdmwhitelisting `
    -AuthObject $auth

    disconnect-ppdmrestapi `
     -AuthObject $auth 

    $StopWatch.Stop()

    Write-Host
    Write-Host "[DEPLOYMENT TIME]: h:$($StopWatch.Elapsed.Hours) m:$($StopWatch.Elapsed.Minutes) s:$($StopWatch.Elapsed.Seconds)" -ForegroundColor Green
    Write-Host