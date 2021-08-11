<#

.DESCRIPTION

    Get metrics of the Virtual Machines in VMWare


.NOTES 
    
    • N/A
    

.CREATED_DATE
    
    2021/08/11 (YYYY/MM/DD)


.AUTHOR
    Gabriel Gonzalez/gagonzalez - Automation and Data Solutions 


.VERSIONES
	Version Powershell 3.0 

#>

# Import Modules
Import-Module VMware.VimAutomation.Core -force -ErrorAction Stop
Import-Module vmware.vimautomation.cloud -force -ErrorAction Stop
Import-Module VMware.VimAutomation.Vds -force -ErrorAction Stop

# Declaration Creds
$VCenterAddress = "vcdtc" + ".ifxcorp.com"
$User = "powerclicloud@ifxcorp.com"
$Password = "CLOUD-hk1167pi"
#$vmid = "VirtualMachine-vm-"+$Vmid
$vmid = "VirtualMachine-vm-"+12207

# Connection
Connect-VIServer -Server $VCenterAddress -User $User -Password $Password -ErrorAction Stop
$vm = Get-VM -id $vmid

# Process
function dataNet{
    param(
        $data
    )
    return $data | Get-Stat -Network -IntervalSecs 20 | Select-Object -Property  MetricId, @{N="Timestamp";E={$_.timestamp.ToString("yyyy/MM/dd HH:mm:ss")}}, Value, Unit, instance, IntervalSecs | ConvertTo-Json
}

function dataStg{
    param(
        $data
    )
    return $data | Get-Stat -Stat "disk.usage.average" -Start (Get-Date).AddDays(-7) -IntervalMins 30 | Select-Object -Property MetricId, @{N="Timestamp";E={$_.timestamp.ToString("yyyy/MM/dd HH:mm:ss")}}, value, unit, instance, IntervalSecs | ConvertTo-Json #No Entity
}

function dataMem{
    param(
        $data
    )
    return $data | Get-Stat -Stat "mem.usage.average" -Start (Get-Date).AddDays(-7) -IntervalMins 30 | Select-Object -Property MetricId, @{N="Timestamp";E={$_.timestamp.ToString("yyyy/MM/dd HH:mm:ss")}}, value, unit, instance, IntervalSecs | ConvertTo-Json #No Entity
}

function dataCpu{
    param(
        $data
    )
    return $data | Get-Stat -Stat "cpu.usage.average" -Start (Get-Date).AddDays(-7) -IntervalMins 30 | Select-Object -Property MetricId, @{N="Timestamp";E={$_.timestamp.ToString("yyyy/MM/dd HH:mm:ss")}}, value, unit, instance, IntervalSecs | ConvertTo-Json #No Entity
}

$statsNet = dataNet($vm)
$statsStg = dataStg($vm)
$statsMem = dataMem($vm)
$statsCpu = dataCpu($vm)

# Disconnection
Disconnect-VIServer * -Confirm:$false