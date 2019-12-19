#
# Create a VMware ESXi VM on Microsoft Azure
#
# The script creates a VM, temporary with VMware Photon OS. An attached data disk is used for the installation bits of ESXi. The prepared data disk then is promoted as OS disk.
# 
#
# History
# 0.1  10.12.2019   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites:
#    - Microsoft Powershell, Microsoft Azure Powershell, Microsoft Azure CLI
#    - must run in an elevated powershell session
#    - VMware Photon OS 3.0 .vhd image
#    - Azure account
#
# Important information:
# The VM created uses the DS3 v2 Offering: 4vCPU,14GB RAM, Accelerating Networking: Yes, Premium disk support:Yes, Cost/hour:$0.229
# An Azure offering must support:
# - Accelerated Networking. Without acceleratednetworking, network adapters are not presented to the ESXi VM.
# - Premium disk support. The uploaded VMware Photon OS vhd must be stored as page blob on a premium disk to make use of it.
#
# Known issues:
# - start of ESXi VM fails (no boot medium found)
#   workaround: re-attach the Photon OS disk as os disk and the data disk. Delete partitions on the data disk (/dev/sdc), reapply prepare-disk.sh, and rerun disk swap.
# - ESXi starts with 'no network adapters'
#   The Ethernet controller driver for 'Mellanox Technologies MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function] [15b3:1004]' does not work.
#   See https://kb.vmware.com/s/article/60421?lang=en_US
#   workaround: none
#               For ESXi 6.5 injecting driver MLNX-NATIVE-ESX-ConnectX-3_3.16.11.10-10EM-650.0.0.4598673-offline_bundle-12539849 didn't work yet.
#

function create-AzVM-vESXi_usingPhotonOS{
   [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        # This is the locally unzipped .vhd from https://vmware.bintray.com/photon/3.0/GA/azure/photon-azure-3.0-26156e2.vhd.tar.gz
        # This is the locally unzipped .vhd from https://vmware.bintray.com/photon/3.0/GA/azure/photon-azure-3.0-9355405.vhd.tar.gz
        $LocalFilePath="J:\photon-azure-3.0-9355405.vhd.tar\photon-azure-3.0-9355405.vhd",

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$cred = (Get-credential -message 'Enter a username and password.'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('westus','westeurope', 'switzerlandnorth','switzerlandwest')]
        [String]$LocationName="westeurope",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ResourceGroupName="photonos-lab-rg",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$StorageAccountName="photonos$(Get-Random)",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ContainerName="disks",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NetworkName="photonos-lab-network",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VnetAddressPrefix="192.168.0.0/16",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ServerSubnetAddressPrefix="192.168.1.0/24",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMName = "photonos",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMSize = "Standard_DS3_v2",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NICName1 = "${VMName}nic1",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NICName2 = "${VMName}nic2",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$PublicIPDNSName="mypublicdns$(Get-Random)",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$nsgName = "myNetworkSecurityGroup",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$diskName = "photonosdisk",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$diskSizeGB = '16', # minimum is 16gb
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ESXiDiskName = "ESXi",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ESXiBootdiskSizeGB = '16', # minimum is 16gb
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$Computername = $VMName ,		
   		
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMLocalAdminUser="adminuser", #all small letters
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMLocalAdminPassword = "PhotonOs123!" #pwd must be 7-12 characters
    )


$ScriptPath=$PSScriptRoot
# Photon OS Image Blob name
$BlobName= split-path $LocalFilePath -leaf


# Requires Run as Administrator
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-not ($myWindowsPrincipal.IsInRole($adminRole))) { return }


# Login
connect-Azaccount -Credential $cred
$azcontext=get-azcontext
if( -not $($azcontext) ) { return }
#Set the context to the subscription Id where Managed Disk exists and where VM will be created
$subscriptionId=($azcontext).Subscription.Id
az account set --subscription $subscriptionId


# Verify VM doesn't exist
[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] `
$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ([string]::IsNullOrEmpty($VM))) { return }


# create lab resource group if it does not exist
$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($result)))
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
}


# Prepare vhd
$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($storageaccount)))
{
    New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $LocationName -Kind Storage -SkuName Standard_LRS -ErrorAction SilentlyContinue
}
$storageaccountkey=(get-azstorageaccountkey -ResourceGroupName $ResourceGroupName -name $StorageAccountName)


$result=az storage container exists --account-name $storageaccountname --name ${ContainerName} | convertfrom-json
if ($result.exists -eq $false)
{
    try {
        az storage container create --name ${ContainerName} --public-access blob --account-name $StorageAccountName --account-key ($storageaccountkey[0]).value
    } catch{}
}
$urlOfUploadedVhd = "https://${StorageAccountName}.blob.core.windows.net/${ContainerName}/${BlobName}"


$result=az storage blob exists --account-key ($storageaccountkey[0]).value --account-name $StorageAccountName --container-name ${ContainerName} --name ${BlobName} | convertfrom-json
if ($result.exists -eq $false)
{
    try {
    az storage blob upload --account-name $StorageAccountName `
    --account-key ($storageaccountkey[0]).value `
    --container-name ${ContainerName} `
    --type page `
    --file $LocalFilePath `
    --name ${BlobName}
    } catch{}
}


# create network if not already set
$vnet = get-azvirtualnetwork -name $networkname -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($vnet)))
{
	$ServerSubnet  = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet  -AddressPrefix $ServerSubnetAddressPrefix
	$vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $ServerSubnet
	$vnet | Set-AzVirtualNetwork
}

# networksecurityruleconfig
$nsg=get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nsg)))
{
	$rdpRule = New-AzNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" `
	-Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
	-SourceAddressPrefix Internet -SourcePortRange * `
	-DestinationAddressPrefix * -DestinationPortRange 3389
	$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -Location $LocationName -SecurityRules $rdpRule
}

# Create a nic with a public IP address
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic1=get-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nic1)))
{
	$pip1 = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $PublicIPDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4
	# Create a virtual network card and associate with public IP address and NSG
	$nic1 = New-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		-SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip1.Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking
}

# Create a second nic
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic2=get-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nic2)))
{
	# Create a virtual network card
	$nic2= New-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		-SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking
}

#save and reapply location info because 'az vm create --custom-data' fails using a filename not in current path
$locationstack=get-location
set-location -Path ${ScriptPath}
# az vm create with ESXi creation script prepare-disk.sh
$BashfileName="prepare-disk.sh"
try {
	az vm create --resource-group $ResourceGroupName --location $LocationName --name $vmName `
	--size $VMSize `
	--admin-username $VMLocalAdminUser --admin-password $VMLocalAdminPassword `
	--storage-account $StorageAccountName `
	--storage-container-name ${ContainerName} `
	--os-type linux `
	--use-unmanaged-disk `
	--os-disk-size-gb $diskSizeGB `
	--image $urlOfUploadedVhd `
	--attach-data-disks $urlOfUploadedVhd `
	--computer-name $computerName `
	--nics $NICName1 $NicName2 `
	--custom-data $Bashfilename `
	--generate-ssh-keys `
	--boot-diagnostics-storage "https://${StorageAccountName}.blob.core.windows.net"
} catch {}

set-location -path $locationstack

$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ([string]::IsNullOrEmpty($VM)))
{

	# wait for custom data to be processed
	$Timeout = 1800
	$i = 0
	for ($i=0;$i -lt $Timeout; $i++) {
		$percentComplete = ($i / $Timeout) * 100
		Write-Progress -Activity 'Provisioning' -Status "Provisioning in progress ..." -PercentComplete $percentComplete
		$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
		if ($VM.OSProfile.LinuxConfiguration.ProvisionVMAgent -eq $true) {break}
		sleep 1
	}
	if ($VM.OSProfile.LinuxConfiguration.ProvisionVMAgent -eq $true)
	{
		# shutdown VM and deallocate it for the conversion to managed disks
		Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

		# Convert to managed disks https://docs.microsoft.com/en-us/azure/virtual-machines/windows/convert-unmanaged-to-managed-disks
		ConvertTo-AzVMManagedDisk -ResourceGroupName $ResourceGroupName -VMName $vmName
		# Starts VM automatically

		# Make sure the VM is stopped but not deallocated so you can detach/attach disk
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
}
}

create-AzVM-vESXi_usingPhotonOS