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
        $resourcegroupname="photonos-lab-rg",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $AzVMOSDiskPrefix="photonos",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $AzVMDataDiskPrefix="ESX"
    )

    $azcontext=get-azcontext
    if( -not $($azcontext) ) {
        $cred = (Get-credential -message 'Enter a username and password for the Azure login.')
        connect-Azaccount -Credential $cred
    }   

    Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Stayprovisioned -Force
	# Detach the ESX disk  
	$SourceDiskName=((Get-AzDisk -ResourceGroupName $resourceGroupName | Where-Object {$_.name -ilike "$AzVMDataDiskPrefix*"})[0] | Select Name).Name
	$sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
	$virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	Remove-AzVMDataDisk -VM $VirtualMachine -Name $SourceDiskName
	Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
	# Set the ESX disk as os disk
	$virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmname
	$sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
	Set-AzVMOSDisk -VM $virtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name
	Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine

    # add Photon OS as VM data disk (will be setuped as ESXi OS disk)
    Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Stayprovisioned -Force
	$SourceDiskName=((Get-AzDisk -ResourceGroupName $resourceGroupName | Where-Object {$_.name -ilike "$AzVMOSDiskPrefix*"})[0] | Select Name).Name
	$sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
	$virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	Remove-AzVMDataDisk -VM $virtualMachine -Name $sourceDisk.Name
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
	$sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $SourceDiskName
	$virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	Add-AzVMDataDisk -VM $virtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name -Lun 1 -CreateOption Attach
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
    Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

}

set-AzVMboot-ESXi