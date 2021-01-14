@{
vmware =@(
    @{
    vcenter='vc-03.vcorp.local'
    account='administrator@vsphere.local'
  }
) #END VMWARE

datadomain =@(
    @{
    esxi ='pesx-01.vcorp.local'
    datastore ='XIO-DS1'
    folder = 'Automation'
    name = 'auto-ddve-01'
    domain = 'vcorp.local'
    ip = '192.168.3.211'
    netmask = '255.255.252.0'
    ip1 = '192.168.3.216'
    netmask1 = '255.255.252.0'
    gateway = '192.168.1.250'
    dns1 = '192.168.1.11'
    dns2 = '192.168.1.12'
    vswitch = 'VM Network'
    vswitch1 = 'VM Network'
    vdisksize = 500
    vdisktype = 'Thin'
    account = 'sysadmin'
    oldpwd='changeme'
    ova = 'D:\software\ddve-7.4.0.5-671629.ova'
  }
  ) #END DATADOMAIN
  
powerprotect =@(
        @{
        api = 'v2'
        esxi ='pesx-01.vcorp.local'
        datastore ='XIO-DS1'
        folder = 'Automation'
        name = 'auto-ppdm-01'
        domain = 'vcorp.local'
        ip = '192.168.3.214'
        netmask = '255.255.252.0'
        gateway = '192.168.1.250'
        dns = @('192.168.1.11','192.168.1.12')
        ntp = @('192.168.1.11','192.168.1.12')
        vswitch = 'VM Network'
        vdisktype = 'Thin'
        account = 'admin'
        oldpwd='admin'
        timezone ='US/Central - Central Standard Time'
        ova = 'D:\software\dellemc-ppdm-sw-19.6.0-7.ova'
      }
    ) #END POWERPROTECT
}
