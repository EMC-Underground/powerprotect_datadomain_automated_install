@{
vmware =@(
    @{
    vcenter='10.237.198.11'
    account='administrator@vsphere.local'
  }
) #END VMWARE

datadomain =@(
    @{
    esxi ='10.237.198.101'
    datastore ='production_ds01'
    folder = 'Tanzu'
    name = 'ddve-test'
    domain = 'paclabs.se.lab.emc.com'
    ip = '10.237.198.36'
    netmask = '255.255.255.0'
    ip1 = '10.237.198.37'
    netmask1 = '255.255.255.0'
    gateway = '10.237.198.1'
    dns1 = '10.237.198.254'
    dns2 = '10.201.16.29'
    vswitch = 'pg_344'
    vswitch1 = 'pg_344'
    vdisksize = 500
    vdisktype = 'Thin'
    account = 'sysadmin'
    oldpwd='changeme'
    ova = './ddve-7.4.0.5-671629.ova'
  }
  ) #END DATADOMAIN
  
powerprotect =@(
        @{
        api = 'v2'
        esxi ='10.237.198.101'
        datastore ='production_ds01'
        folder = 'Tanzu'
        name = 'ppdm-test'
        domain = 'paclabs.se.lab.emc.com'
        ip = '10.237.198.35'
        netmask = '255.255.255.0'
        gateway = '10.237.198.1'
        dns = @('10.237.198.254','10.201.16.29')
        ntp = @('10.254.140.49','64.113.44.54')
        vswitch = 'pg_344'
        vdisktype = 'Thin'
        account = 'admin'
        oldpwd='admin'
        timezone ='US/Central - Central Standard Time'
        ova = './dellemc-ppdm-sw-19.6.0-7.ova'
      }
    ) #END POWERPROTECT
}
