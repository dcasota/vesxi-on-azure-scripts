#
# This helper script modifies a specific VM (see Prerequisities) to boot from ESXi osdisk.
#
# The attached data disk is used for the installation bits of VMware ESXi. The prepared data disk then is promoted as OS disk.
#
# USE THE SCRIPT IT AT YOUR OWN RISK! If you run into issues, give up or try to fix it on your own support. Nested VMware ESXi on Azure is NOT OFFICIALLY SUPPORTED.
# 
#
# History
# 0.1  08.01.2020   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites:
#    - Azure account with ESXi VM created by create-AzVM-vESXi_usingPhotonOS.ps1
#    - Microsoft Powershell, Microsoft Azure Powershell


function set-AzVMboot-ESXi{
   [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $vmname="photonos",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $resourcegroupname="photonos-lab-rg"

    )

    $azcontext=get-azcontext
    if( -not $($azcontext) ) { return }   

    Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Stayprovisioned -Force
    # Detach the prepared data disk
    $SourceDiskName=(Get-AzDisk -ResourceGroupName $resourceGroupName | Select Name).Name[1]
    $sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
    $virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
    Remove-AzVMDataDisk -VM $VirtualMachine -Name $SourceDiskName
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
    # Set the prepared data disk as os disk
    $virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmname
    $sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
    Set-AzVMOSDisk -VM $virtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
    Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
}

set-AzVMboot-ESXi