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

function deploy-ppdm {
    [CmdletBinding()]
    param(
     [Parameter( Mandatory=$false)]
     $vAppConnection,
     [Parameter(Mandatory=$false)]
     [string]$vAppHost,
     [Parameter(Mandatory=$false)]
     [string]$vAppDataStore,
     [Parameter( Mandatory=$false)]
     [string]$vAppFolder,
     [Parameter(Mandatory=$false)]
     [string]$vAppNetwork,
     [Parameter(Mandatory=$false)]
     [string]$vAppName,
     [Parameter(Mandatory=$false)]
     [string]$vAppDomain,
     [Parameter(Mandatory=$false)]
     [ipaddress]$vAppIp,
     [Parameter(Mandatory=$false)]
     [ipaddress]$vAppSubnet,
     [Parameter(Mandatory=$false)]
     [ipaddress]$vAppGateway,
     [Parameter(Mandatory=$false)]
     [ipaddress[]]$vAppDns,
     [Parameter(Mandatory=$false)]
     [ValidateSet('Thin','Thick')]
     [string]$vAppDiskType='Thin',
     [Parameter(Mandatory=$false)]
     [string]$vAppOvaPath,
     [Parameter(Mandatory=$false)]
     [string]$vAppAccount,
     [Parameter(Mandatory=$false)]
     [string]$vAppDefaultPwd,
     [Parameter(Mandatory=$false)]
     [string]$vAppApi
    )
    begin {

        #CHECK OVA PATH
        $Path = Test-Path $vAppOvaPath -PathType Leaf -IsValid

        if($Path -eq $true) {
        #CHECK VCENTER CONNECTION
            if($vAppConnection.isConnected -eq $false) {
                Write-Host "[ERROR]: vCenter connection = $($vAppConnection.isConnected)" -ForegroundColor Red
                exit;
            } 

        } else {
            Write-Host "[ERROR]: PowerProtect OVA not found on path $($vAppOvaPath)" -ForegroundColor Red
            exit;
        }
        
        $vAppVersion = ($vAppOvaPath -split 'dellemc-ppdm-sw-' | Select-Object -Last 1) -split '.ova' | Select-Object -First 1

    } #END BEGIN
    process {
        Write-Host
        Write-Host "[BUILDING]: vApp parameters..."
        Write-Host "[VERSION]: $($vAppVersion)"
        Write-Host "[NAME]: $($vAppName)"
        Write-Host "[DOMAIN]: $($vAppDomain)"
        Write-Host "[IP]: $($vAppIp)"
        Write-Host "[NETMASK]: $($vAppSubnet)"
        Write-Host "[GATEWAY]: $($vAppGateway)"
        Write-Host "[DNS]: $($vAppDns -join ',')"
        Write-Host "FQDN]: $($vAppName).$($vAppDomain)"
        Write-Host "[VM NETWORK]: $($vAppNetwork)"
        Write-Host "[ESXI]: $($vAppHost)"
        Write-Host "[DATASTORE]: $($vAppDatastore)"
        Write-Host "[FOLDER]: $($vAppFolder)"
        Write-Host "[VDISK TYPE]: $($vAppDiskType)"
        Write-Host "[OVA]: $($vAppOvaPath)"
        Write-Host
        Write-Host "##########"
        Write-Host

        $vApp = Get-OvfConfiguration -Ovf $vAppOvaPath
        $vApp.vami.brs.ip0.Value = "$($vAppIp)"
        $vApp.vami.brs.gateway.Value = "$($vAppGateway)"
        $vApp.vami.brs.netmask0.Value = "$($vAppSubnet)"
        $vApp.vami.brs.DNS.Value = "$($vAppDns -join ',')"
        $vApp.vami.brs.fqdn.Value = "$($vAppName).$($vAppDomain)"

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
        $NIC = $Vm  | Get-NetworkAdapter
        Write-Host "[CONFIGURING]: PowerProtect Data Manager network adapters to: $($vAppNetwork)"
        Set-NetworkAdapter -NetworkAdapter $NIC -NetworkName $vAppNetwork -Confirm:$false

        Start-VM $vAppName
    } #END PROCESS
} #END FUNCTION

function connect-ppdmrestapi {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$Server,
        [Parameter( Mandatory=$false)]
        [PSCredential]$Credential
    )
    begin {
        if($Credential -eq $null){
            $Credential = (Get-Credential -Message "Please enter your PowerProtect credentials")
        }
        $login = @{
            username="$($Credential.username)"
            password="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
        }
        Test-vAppConnection -TestType HTTPS -TestTarget "$($Server)" -TestMinutes 1
        Write-Host "[CONNECTING]: PowerProtect Data Manager REST API"
    }
    process {
             
        $Auth = Invoke-RestMethod -Uri "https://$($Server):8443/api/v2/login" `
                    -Method POST `
                    -ContentType 'application/json' `
                    -Body (ConvertTo-Json $login) `
                    -SkipCertificateCheck
        $AuthObj = @{
            server ="$($Server)"
            token= @{
                authorization="Bearer $($Auth.access_token)"
            } #END TOKEN
        } #END AUTHOBJ
        return $AuthObj
    } #END PROCESS
} #END FUNCTION
function disconnect-ppdmrestapi {
    [CmdletBinding()]
    param (
        #NAME OF THE PowerProtect Server
        [Parameter( Mandatory=$true)]
        [object]$AuthObject
    )
    begin {
        Write-Host "[DISCONNECTING]: PowerProtect Data Manager REST API"
    }
    process {
        #Logoff of PowerProtect
        Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/logout" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
    }
} #END FUNCTION
function set-ppdminitialconfig {
    [CmdletBinding()]
    param(
    [Parameter( Mandatory=$true)]
    [object]$AuthObject,
    [Parameter( Mandatory=$false)]
    [ValidateCount(1,2)]
    [ipaddress[]]$vAppNTP,
    [Parameter( Mandatory=$false)]
    [string]$vAppTimezone
    )
    begin{
        $DecryptPwd = (Get-Content '.\passwords\_POWERPROTECT.txt') | ConvertTo-SecureString
        $CommonPwd = ConvertFrom-SecureString -SecureString $DecryptPwd -AsPlainText
        
        Test-vAppConnection -TestType HTTPS -TestTarget "$($AuthObject.server)" -TestMinutes 1
        Write-Host "[STARTING]: PowerProtect Data Manager Initial Configuration"
    }
    process{
        #GET THE PPDM EULA
        $AcceptEula = @{
            accepted= $true
        }
        $Eula = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/eulas/PPDM" `
        -Method PATCH `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-JSON $AcceptEula -Depth 5) `
        -SkipCertificateCheck

        #GET THE CURRENT CONFIGURATION
        $Config = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/configurations" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        #BUILD THE NEW CONFIGURATION
        $NewConfig = $Config.content[0]
        $NewConfig.PSObject.Properties.Remove('_links')
        $NewConfig | Add-Member -Name applicationUserPassword -Value $CommonPwd -MemberType NoteProperty
        $NewConfig.lockbox | Add-Member -Name passphrase -Value "Ch@ngeme1" -MemberType NoteProperty
        $NewConfig.lockbox | Add-Member -Name newPassphrase -Value $CommonPwd -MemberType NoteProperty
        $NewConfig.timeZone = "$($vAppTimezone)"
        for($i=0;$i -lt $NewConfig.osUsers.length;$i++) {
            switch($NewConfig.osUsers[$i].userName) {
                "root"{
                    $NewConfig.osUsers[$i] | Add-Member -Name password -Value "changeme" -MemberType NoteProperty
                    $NewConfig.osUsers[$i] | Add-Member -Name newPassword -Value $CommonPwd -MemberType NoteProperty
                }
                "admin"{
                    $NewConfig.osUsers[$i] | Add-Member -Name password -Value "admin" -MemberType NoteProperty
                    $NewConfig.osUsers[$i] | Add-Member -Name newPassword -Value $CommonPwd -MemberType NoteProperty
                }
                "support"{
                    $NewConfig.osUsers[$i] | Add-Member -Name password -Value "`$upp0rt!" -MemberType NoteProperty
                    $NewConfig.osUsers[$i] | Add-Member -Name newPassword -Value $CommonPwd -MemberType NoteProperty
                }
            } #END SWITCH
        } #END FOR

        #ADD NTP SERVERS
        if($vAppNTP.length -gt 0){
            $NewConfig.ntpServers = @($vAppNTP.IPAddressToString) 
        }
        
        #Write-Host "[REQUEST BODY]==> `n`n$(ConvertTo-Json $NewConfig -Depth 5)"

        $ConfigRequest = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/configurations/$($NewConfig.id)" `
        -Method PUT `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-JSON $NewConfig -Depth 5) `
        -SkipCertificateCheck
        
        do {
            
            try{
                $ConfigStatus = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/configurations/$($NewConfig.id)/config-status" `
                -Method GET `
                -ContentType 'application/json' `
                -Headers ($AuthObject.token) `
                -SkipCertificateCheck

                Write-Progress `
                -Activity "Configuring PowerProtect Data Manager" `
                -Status "Percent complete: $($ConfigStatus[0].percentageCompleted)%" `
                -PercentComplete $($ConfigStatus[0].percentageCompleted)
            } catch {
                Write-Host "[WARNING]: The config-stats REST API enpoint is not currently available." -ForegroundColor Yellow
            }

            Start-Sleep -Seconds 10
        }
        until($ConfigStatus[0].percentageCompleted -eq 100)
        Write-Host "[FINALIZING]: PowerProtect Data Manager Initial Configuration"
        Write-Host
        #Start-Sleep -Seconds 30
    } #END PROCESS
} #END FUNCTION
function add-datadomain {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$false)]
       [object]$AuthObject,
       [Parameter( Mandatory=$false)]
       [PSCredential]$Credential,
       [Parameter( Mandatory=$false)]
       [string]$DD,
       [Parameter( Mandatory=$false)]
       [int]$Port=3009

    )
    begin {
       if($Credential -eq $null){
            $Credential = (Get-Credential -Message "Please enter your Data Domain credentials:")
       }
       Write-Host "[ADDING]: Data Domain to PowerProtect Data Manager Configuration"
    }
    process {
        #GET THE DD HOST CERTIFICATE
        $CertQuery = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/certificates?host=$($DD)&port=$($Port)&type=Host" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck

        #SET THE CERTIFICATE STATE TO ACCEPTED
        $CertQuery[0].state = 'ACCEPTED'

        $CertUpdate = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/certificates/$($CertQuery[0].id)" `
            -Method PUT `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -Body (ConvertTo-Json $CertQuery[0]) `
            -SkipCertificateCheck

        $CredsDD = @{
            type='DATADOMAIN'
            name='SYSADMIN'
            username="$($Credential.username)"
            password="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
        }

        $CredsCreate = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/credentials" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-Json $CredsDD) `
        -SkipCertificateCheck

        $StorageDD=@{
            address=$DD    
            name=$DD
            type='EXTERNALDATADOMAIN'
            port=$Port
            credentials=@{
                id=$CredsCreate.id
            }
        }

        $StorageCreate = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/inventory-sources " `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-Json $StorageDD) `
        -SkipCertificateCheck
        Start-Sleep 5
        Write-Host
    } #END PROCESS
} #END FUNCTION

function get-ppdmmstoragesystems {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [object]$AuthObject,
        [Parameter( Mandatory=$true)]
        [string]$StorageSystem
    )
    begin {
        Write-Host "[QUERYING]: PowerProtect Data Manager for storage system name: ($StorageSystem)"
    } #END BEGIN
    process {
        #GET THE DD STORAGE UNIT BY ID
        
        $Response = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/storage-systems?filter=name%20eq%20`"$($StorageSystem)`"" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $Response -depth 5)" -foregroundcolor Green
        
        return $Response
    } #END PROCESS
} #END FUNCTION
function add-vcenter {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$false)]
       [object]$AuthObject,
       [Parameter( Mandatory=$false)]
       [PSCredential]$Credential,
       [Parameter( Mandatory=$false)]
       [string]$VCenter,
       [Parameter( Mandatory=$false)]
       [int]$Port=443
    )
    begin {
       if($Credential -eq $null){
            $Credential = (Get-Credential -Message "Please enter your vCenter credentials:")
       }
       Write-Host "[ADDING]: vCenter to PowerProtect Data Manager Configuration"
    }
    process {
        #GET THE DD HOST CERTIFICATE
        $CertQuery = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/certificates?host=$($VCenter)&port=$($Port)&type=Host" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck

        #SET THE CERTIFICATE STATE TO ACCEPTED
        $CertQuery[0].state = 'ACCEPTED'

        $CertUpdate = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/certificates/$($CertQuery[0].id)" `
            -Method PUT `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -Body (ConvertTo-Json $CertQuery[0]) `
            -SkipCertificateCheck

        $CredsVC = @{
            type='VCENTER'
            name='ADMINISTRATOR'
            username="$($Credential.username)"
            password="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
        }

        $CredsCreate = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/credentials" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-Json $CredsVC) `
        -SkipCertificateCheck

        $AddvCenter=@{
            address=$VCenter    
            name=$VCenter
            type='VCENTER'
            port=$Port
            credentials=@{
                id=$CredsCreate.id
            }
        }

        $vCenterCreate= Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/inventory-sources " `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-Json $AddvCenter) `
        -SkipCertificateCheck
        Start-Sleep 5
        Write-Host
    }
} #END FUNCTION

function new-ppdmprotectionpolicy {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [object]$AuthObject,
        [Parameter( Mandatory=$true)]
        [string]$StorageSystemId,
        [Parameter( Mandatory=$true)]
        [string]$PolicyName
    )
    begin {
        Write-Host "[ADDING]: Protection Policy $($PolicyName) with storage target id: $($StorageSystemId)"
    } #END BEGIN
    process {
        $Request = @{
            assetType = 'VMWARE_VIRTUAL_MACHINE'
            dataConsistency = 'CRASH_CONSISTENT'
            enabled = $true
            encrypted = $false
            name = $PolicyName
            priority = 1
            details = @{
                vm= @{
                    protectionEngine='VMDIRECT'
                }
            }
            stages = @(
                @{
                    id = [guid]::NewGuid().ToString()
                    passive = $false
                    type='PROTECTION'
                    retention = @{
                        interval = 5
                        unit = 'DAY'
                    }
                    target = @{
                        storageSystemId = $StorageSystemId
                    }
                    operations = @(
                        @{
                            type='AUTO_FULL'
                            schedule = @{
                                frequency = 'DAILY'
                                startTime = '2020-07-28T00:00:00Z'
                                duration = 'PT10H'
                            }
                        }
                    )
                }                            
            )        
            type='ACTIVE'
        }
        #GET THE DD STORAGE UNIT BY ID
        
        $Response = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/protection-policies" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-Json $Request -Depth 10) `
        -SkipCertificateCheck

        #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $Response -depth 5)" -foregroundcolor Green
        Write-Host
        return $Response
    } #END PROCESS
} #END FUNCTION

function get-ppdmasset {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$true)]
       [object]$AuthObject,
       [Parameter( Mandatory=$true)]
       [string]$Name
    )
    begin{
        Write-Host "[QUERYING]: PowerProtect Data Manager for asset name: $($Name)"
    }
    process {
        
        $Request = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/assets?filter=name%20eq%20%22$($Name)%22" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $Request -depth 5)" -foregroundcolor Green
        Write-Host
        return $Request

    } #END PROCESS
} #END FUNCTION

function set-ppdmassetpolicy {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$true)]
       [object]$AuthObject,
       [Parameter( Mandatory=$true)]
       [string]$AssetId,
       [Parameter( Mandatory=$true)]
       [string]$PolicyId
    )
    begin {
        Write-Host "[ADDING]: Asset ID: $($AssetId) to Protection Policy ID: $($PolicyId)"
    }
    process {
        
        $Body = @($AssetId)

        $Request = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/protection-policies/$($PolicyId)/asset-assignments" `
        -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $Body) `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $Request -depth 5)" -foregroundcolor Green

        do {
            #MONITOR ACTIVITY UNTIL COMPLETED RETURN THE ONLY ONE RUNNING
            $Status = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/activities" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck
            
            #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $Status.content[0] -depth 5)" -foregroundcolor Green
           Start-Sleep -Seconds 5
        }
        until ($Status.content[0].state -eq 'COMPLETED')
        Write-Host
    }  #END PROCESS
} #END FUNCTION

function start-ppdmassetbackup {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$true)]
       [object]$AuthObject,
       [Parameter( Mandatory=$true)]
       [string]$AssetId,
       [Parameter( Mandatory=$true)]
       [string]$PolicyId
    )
    begin {
        Write-Host "[STARTING]: backup for asset id: $($AssetId)"
    }
    process {
        $Body = @{
            assetId = @($AssetId)
            backupType = 'AUTO_FULL'
            retention = @{
                interval = 1
                unit = 'WEEK'
            }
        }

        $Request = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/protection-policies/$($PolicyId)/backups" `
        -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $Body) `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        Write-Host
    } #END PROCESS
} #END FUNCTION

function set-ppdmwhitelisting {
    [CmdletBinding()]
    param (
       [Parameter( Mandatory=$true)]
       [object]$AuthObject
    )
    begin {
        Write-Host "[ENABLING]: Automatic whitelisting for PowerProtect Data Manager clients"
    }
    process {
        $Body = @{
            ip='0.0.0.0'
            state='AUTOMATIC'
        }
        $Request = Invoke-RestMethod -Uri "https://$($AuthObject.server):8443/api/v2/whitelist/automatic" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body (ConvertTo-JSON $Body) `
        -SkipCertificateCheck

        #Write-Host "[RESPONSE BODY]==> `n`n$(ConvertTo-Json $ConfigRequest)"

        Write-Host
        Write-Host "[OPENING URL]: https://$($AuthObject.server)/#/login"
            
        #OPEN WEB UI
        Start-Process "chrome.exe" "https://$($AuthObject.server)/#/login"
    }
}
