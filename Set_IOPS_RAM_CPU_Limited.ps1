<#

.DESCRIPTION

    Recolecta las VM's que no tienen limite de RAM, CPU e IOPS, ademas de la reserva de CPU
    RAM sea mayor a 0


.NOTES 
    
    • Se debe tener instalado "Import Excel" => Install-Module ImportExcel -scope CurrentUser
    • Eliminar archivo .xlsx en caso de que exista.
    • Genera error al crear un objeto con maquinas inexistentes o nulas.
    

.CREATED_DATE
    
    2019/11/26 (YYYY/MM/DD)


.AUTHOR

    Gabriel Gonzalez/gagonzalez - Automation and Data Solutions 


.VERSIONES

	Version Powershell 5.1 

#>

Import-Module VMware.VimAutomation.Core -force -ErrorAction Ignore
Import-Module vmware.vimautomation.cloud -force -ErrorAction Ignore
Import-Module VMware.VimAutomation.Vds -force -ErrorAction Ignore 

Write-Host "INICIO DEL SCRIPT $(GET-DATE)" -ForegroundColor Green

$vm =@() 
# Traer VCenters
$vcenters = @("algunvcenter.algundominio.com")
$Error.Clear()


# ForEach Parallel para ahorrar tiempo
workflow foreachpsptest {

Param(
        [string[]]$vcenters
    )
       
        ForEach -Parallel ($item in $vcenters) {

          
           inlinescript {
                Import-Module VMware.VimAutomation.Core -force -ErrorAction Ignore
                Import-Module vmware.vimautomation.cloud -force -ErrorAction Ignore
                Import-Module VMware.VimAutomation.Vds -force -ErrorAction Ignore

                # Creacion de Objeto
                $metrics = New-Object -TypeNa PSObject

                # Conexion con cada maquina
                $Connect = Connect-VIServer  $Using:item -User 'algunusuario.algundominio.com' -Password 'algunacontraseña' -Force
                
                # RAM ILIMITADA
                $vmsss = Get-VM | Where-Object {$_.ExtensionData.ResourceConfig.MemoryAllocation.Limit -eq '-1'} 
                $metrics | Add-Member -Type NoteProperty -Name LimitRAM -Value $vmsss
                $metrics.LimitRAM | Add-Member -Type NoteProperty -Name VCenter -Value $Using:item

                # CPU ILIMITADO
                $vmsss = Get-VM | Where-Object {$_.ExtensionData.ResourceConfig.CpuAllocation.Limit -eq '-1'}
                $metrics | Add-Member -Type NoteProperty -Name LimitCPU -Value $vmsss
                $metrics.LimitCPU | Add-Member -Type NoteProperty -Name VCenter -Value $Using:item

                # RAM RESERVA
                $vmsss = Get-VM | Where-Object {$_.ExtensionData.ResourceConfig.MemoryAllocation.Reservation -gt "0"}
                $metrics | Add-Member -Type NoteProperty -Name ReserveRAM -Value $vmsss
                $metrics.ReserveRAM | Add-Member -Type NoteProperty -Name VCenter -Value $Using:item
                $metrics.ReserveRAM | Add-Member -Type NoteProperty -Name ReservedRAM -Value $vmsss.ExtensionData.ResourceConfig.MemoryAllocation.Reservation

                # CPU RESERVA
                $vmsss = Get-VM | Where-Object {$_.ExtensionData.ResourceConfig.CpuAllocation.Reservation -gt "0"}
                $metrics | Add-Member -Type NoteProperty -Name ReserveCPU -Value $vmsss
                $metrics.ReserveCPU | Add-Member -Type NoteProperty -Name VCenter -Value $Using:item

                # IOPS ILIMITADO
                $vmsss = Get-VM | Where-Object {$_.ExtensionData.Config.Hardware.Device.StorageIOAllocation.Limit -eq '-1'}
                $metrics | Add-Member -Type NoteProperty -Name LimitIOPS -Value $vmsss
                $metrics.LimitIOPS | Add-Member -Type NoteProperty -Name VCenter -Value $Using:item

                # Set limite RAM
                ForEach ($machine in $metrics.LimitRAM){
                    Get-VMResourceConfiguration -VM (Get-VM -name ($machine.Name)) | Where-Object {$_.MemLimitGB -eq '-1'} | Set-VMResourceConfiguration -MemLimitGB $machine.MemoryGB
                    Get-VMResourceConfiguration -VM (Get-VM -name ($machine.Name)) | Where-Object {$_.MemReservationGB -ne '-1'} | Set-VMResourceConfiguration -MemReservationGB 0
                }

                # Set limite CPU
                ForEach ($machine in $metrics.LimitCPU){
                    Get-VMResourceConfiguration -VM (Get-VM -name ($machine.Name)) | Where-Object {$_.CpuLimitMhz -eq '-1'} | Set-VMResourceConfiguration -CpuLimitMhz ($machine.NumCpu * 2100)
                    Get-VMResourceConfiguration -VM (Get-VM -name ($machine.Name)) | Where-Object {$_.CpuReservationMhz -ne '-1'} | Set-VMResourceConfiguration -CpuReservationMhz 0
                }

                # Set limite IOPS
                ForEach ($machine in $metrics.LimitIOPS){
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

                    $machine.ExtensionData.Config.Hardware.Device |
                    where {$_ -is [VMware.Vim.VirtualDisk]} | %{
                      $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
                      $dev.Operation = "edit"
                      $dev.Device = $_
                      $dev.Device.StorageIOAllocation.Limit = 50
                      $spec.DeviceChange += $dev
                    }
    
                    $machine.ExtensionData.ReconfigVM_Task($spec)
                }


                # Desconexion
                Disconnect-VIServer $Using:item  -Force -Confirm:$false
                
                Return $metrics
            }
     }
}

# $vm es el objeto que devuelve el ForEach Parallel
$vm = foreachpsptest $vcenters

# Correccion de inconsistencias
Try{
    foreach($rs in $vm.ReserveRAM){
        $rs.ReservedRAM = $rs.ReservedRAM[0]
    }
}Catch{}

# Exportacion a un archivo .xlsx por pestañas, filtra el objeto $vm
$vm.LimitRAM | Select Name, PowerState, NumCpu, CoresPerSocket, MemoryGB, Id, VCenter | Export-Excel -workSheetName "Limite RAM" -path "C:\VMs_Ilimitadas_Reserva.xlsx"
$vm.LimitCPU | Select Name, PowerState, NumCpu, CoresPerSocket, MemoryGB, Id, VCenter | Export-Excel -workSheetName "Limite CPU" -path "C:\VMs_Ilimitadas_Reserva.xlsx"
$vm.ReserveRAM | Select Name, PowerState, NumCpu, CoresPerSocket, MemoryGB, ReservedRAM, Id, VCenter | Export-Excel -workSheetName "Reserva RAM" -path "C:\VMs_Ilimitadas_Reserva.xlsx"
$vm.ReserveCPU | Select Name, PowerState, NumCpu, CoresPerSocket, MemoryGB, Id, VCenter | Export-Excel -workSheetName "Reserva CPU" -path "C:\VMs_Ilimitadas_Reserva.xlsx"
$vm.LimitIOPS | Select Name, PowerState, NumCpu, CoresPerSocket, MemoryGB, Id, VCenter | Export-Excel -workSheetName "Limite IOPS" -path "C:\VMs_Ilimitadas_Reserva.xlsx"

# Enviar reporte de maquinas
$emails = @("algunusuario@algundominio.com")


# Parametros de envio
[string]$From="algunusuario@algundominio.com"
[array]$To = $emails.Split(';')
[string]$subject = "Reporte CPU RAM e IOPS ilimitados"
[string]$body = "Se adjunta reporte con maquinas con CPU, RAM e IOPS ilimitados de cada VM."
$SMTPServer = "DIRECCION SERVIDOR SMTP"

# Enviar correo - un solo destinatario
Send-MailMessage -From $From -to $To -Cc "algunusuario@algundominio.com" -Body $body -Attachments C:\VMs_Ilimitadas_Reserva.xlsx -Priority High -SmtpServer $SMTPServer -Subject $subject -Port 25

Write-Host "FINAL DEL SCRIPT $(GET-DATE)" -ForegroundColor Green