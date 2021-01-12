function Test-vAppConnection {
    param (
     [Parameter( Mandatory=$false)]
     [ValidateSet('SSH','HTTPS')]
     [string]$TestType,
     [Parameter( Mandatory=$false)]
     [string]$TestTarget,
     [Parameter( Mandatory=$false)]
     [int]$TestMinutes
     )
     begin {
        #HELPER FUNCTION FOR MEASURING ELAPSED TIME
        function Get-ElapsedTime {
        [CmdletBinding()]
        param (
            [Parameter( Mandatory=$false)]
            [int]$Minutes
        )
            $Time = [System.Diagnostics.Stopwatch]::StartNew()

            while ($Time.Elapsed.Minutes -lt $Minutes) {
                $CurrentTime = $Time.Elapsed
                Write-Host $([string]::Format("`rTime: {0:d2}:{1:d2}:{2:d2}",
                    $CurrentTime.hours, 
                    $CurrentTime.minutes, 
                    $CurrentTime.seconds)) -nonewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            $Time.Reset()
            Write-Host
        } #END FUNCTION
     }
     process {
        do {
             switch($TestType) {
                'SSH' {
                    Write-Host    
                    Write-Host "[TESTING]: $($TestType) connectivity to { $($TestTarget):22 }"
                        $Connection = Test-Connection -TargetName "$($TestTarget)" -TcpPort 22
                    
                    }
                'HTTPS' {
                    Write-Host    
                    Write-Host "[TESTING]: $($TestType) connectivity to { $($TestTarget):443 }"
                    $Connection = Test-Connection -TargetName "$($TestTarget)" -TcpPort 443
                   }
             } #END SWITCH
             
             if($Connection  -eq $false)
             {
                 Write-Host "[SLEEPING]: $($TestMinutes) Minute. Will try again..." -ForegroundColor Yellow               
                 Get-ElapsedTime -Minutes $TestMinutes
             } #END IF

         } #END DO
         until ($Connection  -eq $true)
         $Connection = $null
     } #END PROCESS
} #END FUNCTION

#PROVISION DATA DOMAIN
function deploy-ddve {
    param (
     [Parameter( Mandatory=$false)]
     $vAppConnection,
     [Parameter( Mandatory=$false)]
     [string]$vAppHost,
     [Parameter( Mandatory=$false)]
     [string]$vAppDatastore,
     [Parameter( Mandatory=$false)]
     [string]$vAppFolder,
     [Parameter( Mandatory=$false)]
     [string]$vAppName,
     [Parameter( Mandatory=$false)]
     [string]$vAppDomain,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppIP,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppSubnet,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppIP1,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppSubnet1,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppGateway,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppDNS1,
     [Parameter( Mandatory=$false)]
     [ipaddress]$vAppDNS2,
     [Parameter( Mandatory=$false)]
     [string]$vAppNetwork,
     [Parameter( Mandatory=$false)]
     [string]$vAppNetwork1,
     [Parameter( Mandatory=$false)]
     [String]$vAppDiskSize,
     [Parameter( Mandatory=$false)]
     [ValidateSet('Thin','Thick')]
     [String]$vAppDiskType,
     [Parameter( Mandatory=$false)]
     [string]$account,
     [Parameter( Mandatory=$false)]
     [string]$oldpwd,
     [Parameter( Mandatory=$false)]
     [string]$vAppOvaPath
   )
     begin {
        #CHECK OVA PATH
        $Path = Test-Path $vAppOvaPath -PathType Leaf -IsValid

        if($Path -eq $true) {
        #CHECK VCENTER CONNECTION
            if($vAppConnection.isConnected -eq $false) {
                Write-Host "[ERROR]: vCenter connection = $($vappConnection.isConnected)"
                exit;
            } 

        } else {
            Write-Host "[ERROR]: Data Domain OVA not found on path $($vAppOVaPath)" -ForegroundColor Red
            exit;
        }
        
        $vAppVersion = ($vAppOVaPath -split 'ddve-' | Select-Object -Last 1) -split '.ova' | Select-Object -First 1
        

        $newpwd = (Get-Content '.\passwords\_DDVE.txt') | ConvertTo-SecureString

     } #END BEGIN
     process {
         Write-Host
         Write-Host "[BUILDING]: vApp parameters..."
         Write-Host "[NAME]: $($vAppName)"
         Write-Host "[DOMAIN]: $($vAppDomain)"
         Write-Host "[VERSION]: $($vAppVersion)"
         Write-Host "[IP]: $($vAppIp)"
         Write-Host "[NETMASK]: $($vAppSubnet)"
         Write-Host "[GATEWAY]: $($vAppGateway)"
         Write-Host "[DNS1]: $($vAppDNS1)"
         Write-Host "[DNS2]: $($vAppDNS2)"
         Write-Host "[VM NETWORK]: $($vAppNetwork)"
         
         if($vAppIP1 -ne '') {
            Write-Host "[IP1]: $($vAppIp1)"
            Write-Host "[NETMASK1]: $($vAppSubnet1)"
            Write-Host "[VM NETWORK1]: $($vAppNetwork1)"
         }

         Write-Host "[ESXI]: $($vAppHost)"
         Write-Host "[DATASTORE]: $($vAppDatastore)"
         Write-Host "[FOLDER]: $($vAppFolder)"
         Write-Host "[VDISK SIZE]: $($vAppDiskSize)"
         Write-Host "[VDISK TYPE]: $($vAppDiskType)"
         Write-Host "[OVA]: $($vAppOvaPath)"
         Write-Host
         Write-Host "##########"
         Write-Host
 
         $vApp = Get-OvfConfiguration -Ovf $vAppOVaPath
         $vApp.Common.hostname.Value = "$($vAppName)"
         $vApp.Common.ipAddress.Value = "$($vAppIp)"
         $vApp.Common.netmask.Value = "$($vAppSubnet)"
         $vApp.Common.gateway.Value = "$($vAppGateway)"
         $vApp.Common.dnsServer1.Value = "$($vAppDNS1)"
         $vApp.Common.dnsServer2.Value = "$($vAppDNS2)"
         $vApp.NetworkMapping.VM_Network_1.Value = "$($vAppNetwork)"

         if($vAppIP1 -ne '') {
            $vApp.NetworkMapping.VM_Network_2.Value = "$($vAppNetwork1)"
         }
         
        Write-Host "[IMPORTING]: vApp $($vAppName) this will take a few minutes..."
        Import-VApp `
        -Host $vAppHost `
        -Datastore $vAppDatastore `
        -Name $vAppName `
        -DiskStorageFormat $vAppDiskType `
        -OvfConfiguration $vApp `
        -Source $vAppOvaPath `
        -InventoryLocation $vAppFolder `
        -Force
        
        $Vm = Get-VM -Name $vAppName
         
        Write-Host "[ADDING]: Active Tier vDisk Size: $($vAppDiskSize) GB"
        $Vm | New-HardDisk -CapacityGB $vAppDiskSize -StorageFormat $vAppDiskType
         
        Start-VM $vAppName
         
        Write-Host  
        $auth = @{
            username="$($account)"
            password="$($oldpwd)"
         }
        
        Test-vAppConnection -TestType HTTPS -TestTarget "$($vAppName).$($vAppDomain)" -TestMinutes 1
        
        #LOGIN TO DD REST API      
        $Con = Invoke-RestMethod -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v1.0/auth" `
                    -Method POST `
                    -ContentType 'application/json' `
                    -Body (ConvertTo-Json $auth) `
                    -SkipCertificateCheck `
                    -ResponseHeadersVariable Headers
        
        $mytoken = @{
                'X-DD-AUTH-TOKEN'=$Headers['X-DD-AUTH-TOKEN'][0]
        }

        Write-Host
        #ADD DEV3 TO THE ACTIVE TIER
        Write-Host "[DDVE]: Adding dev3 disk to the active tier..."
        $action1 = @{
            disks = @("dev3")
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/api/v1/dd-systems/0/file-systems/block-storages" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action1) `
                    -SkipCertificateCheck
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: Successfully added $($action1.disks[0]) disk to the active tier!" -ForegroundColor Green
        } else {
            Write-Host "[DDVE]: Error adding $($action1.disks[0]) disk to the active tier!" -ForegroundColor red
            exit;
        }
        
        Write-Host
        #CREATE THE FILESYSTEM
        Write-Host "[DDVE]: Creating the filesystem..."
        $action2 = @{
            operation = "create"
            write_zeros = $false
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v1.0/dd-systems/0/file-systems" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action2) `
                    -SkipCertificateCheck
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: Successfully created the filesystem!" -ForegroundColor Green
        } else {
            Write-Host "[DDVE]: Error creating the filesystem!" -ForegroundColor red
            exit;
        }
        
        Write-Host
        #ENABLE THE FILESYSTEM
        Write-Host "[DDVE]: Enabling the filesystem..."
        $action3 = @{
            operation = "enable"
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v1.0/dd-systems/0/file-systems" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action3) `
                    -SkipCertificateCheck
        
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: Successfully enabled the filesystem!" -ForegroundColor Green
        } else {
            Write-Host "[DDVE]: Error creating the filesystem!" -ForegroundColor red
            exit;
        }

        Write-Host
        #ENABLE THE DDBOOST PROTOCOL
        Write-Host "[DDVE]: Enabling the ddboost protocol..."
        $action4 = @{
            operation = "enable"
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v1.0/dd-systems/0/protocols/ddboost" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action4) `
                    -SkipCertificateCheck
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: Successfully enabled the ddboost protocol!" -ForegroundColor Green
        } else {
            Write-Host "[DDVE]: Error enabling the ddboot protocol!" -ForegroundColor red
            exit;
        }

        Write-Host      
        #CHANGE PASSPHRASE
        Write-Host "[DDVE]: Updating system passphrase..."
        $action5 = @{
            operation="set_pphrase"
            pphrase_request= @{
                new_pphrase= "$(ConvertFrom-SecureString -SecureString $newpwd -AsPlainText)"
            }
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v3.0/dd-systems/0/systems" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action5) `
                    -SkipCertificateCheck
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: System passphrase updated successfully!" -ForegroundColor Green
        } else {
            Write-Host "[DDVE]: Error updating system passphrase!" -ForegroundColor red
            exit;
        }

        Write-Host 
        
        if($vAppIP1 -ne '') {
            #UPDATE NETWORK SETTINGS 
            Write-Host "[DDVE]: Updating ethV1 settings..."
            $action6 = @{
                address = "$($vAppIP1)"
                netmask = "$($vAppSubnet1)"
                }
            $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/api/v3/dd-systems/0/networks/interfaces/physicals/ethV1" `
                        -Method PUT `
                        -ContentType 'application/json' `
                        -Headers $mytoken `
                        -Body (ConvertTo-Json $action6) `
                        -SkipCertificateCheck
            if($Con.StatusCode -eq 200) {
                Write-Host "[DDVE]: ethV1 updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "[DDVE]: Error updating ethV1!" -ForegroundColor red
                exit;
            }
        }
        

        Write-Host
        #CHANGE SYSADMIN PASSWORD
        Write-Host "[DDVE]: Updating password for account sysadmin"
        $action7 = @{
            current_password="$($oldpwd)"
            new_password="$(ConvertFrom-SecureString -SecureString $newpwd -AsPlainText)"
        }
        $Con = Invoke-WebRequest -Uri "https://$($vAppName).$($vAppDomain):3009/rest/v1.0/dd-systems/0/users/sysadmin" `
                    -Method PUT `
                    -ContentType 'application/json' `
                    -Headers $mytoken `
                    -Body (ConvertTo-Json $action7) `
                    -SkipCertificateCheck
        if($Con.StatusCode -eq 200) {
            Write-Host "[DDVE]: Password updated for sysadmin account" -ForegroundColor green
        } else {
            Write-Host "[DDVE]: Error updating password for the sysadmin account!" -ForegroundColor red
            exit;
        }
        
        Write-Host
        Write-Host "[DDVE]: The virtual appliance has been successfully deployed" -ForegroundColor green
        Write-Host

     } #END PROCESS
 } #END FUNCTION
