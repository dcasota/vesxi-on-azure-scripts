#
# Create a VMware ESXi on a Microsoft Azure offering
#
# The script creates a VM, temporary with VMware Photon OS. An attached data disk is used for the installation bits of VMware ESXi. The prepared data disk then is promoted as OS disk.
#
# USE THE SCRIPT IT AT YOUR OWN RISK! VMware ESXi on Azure is NOT OFFICIALLY SUPPORTED. If you run into issues with a nested lab, give up or try to fix it on your own support.
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
#
# Parameter LocalFilePath
#    Specifies the local file path to the unzipped VMware Photon OS .vhd
# Parameter BlobName
#    Azure Blob Name for the Photon OS .vhd
# Parameter cred
#    Azure login credentials
# Parameter LocationName
#    Azure location name where to create or lookup the resource group
# Parameter ResourceGroupName
#    Azure resource group name
# Parameter StorageAccountName
#    Azure storage account name
# Parameter ContainerName
#    Azure storage container name 
# Parameter NetworkName
#    Azure VNet Network name
# Parameter VnetAddressPrefix
#    Azure VNet subnet. Use the format like "192.168.0.0/16"
# Parameter ServerSubnetAddressPrefix
#    Azure Server subnet address prefix. Use the format like "192.168.1.0/24"
# Parameter VMName
#    Name of the Azure VM
# Parameter VMSize
#    Azure offering. Use the format like "Standard_E4s_v3". See 'Important information' below.
# Parameter NICName1
#    Name for the first nic adapter
# Parameter Ip1Address
#    Private IP4 address of the first nic adapter exposed to the Azure VM
# Parameter PublicIPDNSName
#    Public IP4 name of the first nic adapter
# Parameter NICName2
#    Name for the second nic adapter exposed to the Azure VM
# Parameter Ip2Address
#    Private IP4 address of the second nic adapter
# Parameter nsgName
#    Name of the network security group, the nsg is applied to both nics
# Parameter diskName
#    Name of the Photon OS disk
# Parameter diskSizeGB
#    Disk size of the Photon OS disk. Minimum is 16gb
# Parameter Computername
#    Hostname Photon OS. The hostname is not set for ESXi (yet).
# Parameter VMLocalAdminUser
#    Local Photon OS user
# Parameter VMLocalAdminPassword
#    Local Photon OS user password. Must be 7-12 characters long, and meet pwd complexitiy rules.
# Parameter BashfileName
#    Name of the bash file to be processed as vm create custom-data. The script be stored in the script file path.
# Parameter ESXiDiskName
#    Name of the ESXi boot medium disk. The disk is attached as VM data disk.
# Parameter ESXiBootdiskSizeGB
#    Disk size of the ESXi boot medium disk. Minimum is 16gb
#	
#
# Example
# 1. Modify in prepare-disk.sh ISOFILENAME and GOOGLEDRIVEFILEID
# 2. create-AzVM-vESXi_usingPhotonOS -LocalFilePath 'InsertYourPathToPhotonOsvhd' -cred (get-credential)
# 	
#
# Important information:
#
#    Nested virtualization on Azure support:
#
#    - Azure Stack Level 0,1,2 nested virtualization:
#
#       – Level 0 Azure hardware virtualization layer inside Azure stack is officially supported for Level 1 Hypervisor Hyper-V only.
#         And, there are Microsoft CSP-specific solutions (like Azure VMware Solution by CloudSimple).
#         There are no Microsoft baremetal-kubernetesified, ipmi/iLO/iDRAC/..-included Virtual Machines offerings.
# 
#       - “Level 2 nested virtualization” is supported for Windows Server Virtual Machines with Hyper-V only, in reference to
#         https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization, and,
#         only using the Dv3 and Ev3 VM sizes, or premium disk support possible through Esv3. Accelerated Networking is included
#         according to https://azure.microsoft.com/de-de/blog/maximize-your-vm-s-performance-with-accelerated-networking-now-generally-available-for-both-windows-and-linux/ .
#
#    - VMware statement: https://kb.vmware.com/s/article/2009916
#
# 
#    The ESXi VM offering on Azure must support:
#       - Accelerated Networking. Without acceleratednetworking, network adapters are not presented to the ESXi VM.
#       - Premium disk support. The uploaded VMware Photon OS vhd must be stored as page blob on a premium disk to make use of it.
#       The script uses the Standard_E4s_v3 offering: 4vCPU,32GB RAM, Accelerating Networking: Yes, Premium disk support:Yes. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-memory#esv3-series
#
#
# Known issues:
# - Creation of the VM has finished but custom-data of az vm create was not processed. On the console you see an error of missing ovf-env.xml file.
#   workaround: none
#               delete resource group and rerun script.
# - ESXi starts with 'no network adapters'
#   workaround: none
#               Findings:
#                  The Azure Standard_E4s_v3 offering includes the accelerated networking feature, and exposes ConnectX-3 as nic adapter type.
#
#                  Research/Findings:
#                     lspci output on Photon OS (tdnf install pciutils):
#                     lspci | grep Mellanox
#                        82d1:00:02.0 Ethernet controller [0200]: Mellanox Technologies MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function] [15b3:1004]
#                        Subsystem: Mellanox Technologies Device [15b3:61b0]
#                        9832:00:02.0 Ethernet controller [0200]: Mellanox Technologies MT27500/MT27520 Family [ConnectX-3/ConnectX-3 Pro Virtual Function] [15b3:1004]
#                        Subsystem: Mellanox Technologies Device [15b3:61b0]
#                     dmesg output on Photon OS (tdnf install usbutils):
#                     dmesg | grep virtual
#                        [    0.088113] Booting paravirtualized kernel on bare hardware
#                        [    0.592879] VMware vmxnet3 virtual NIC driver - version 1.4.16.0-k-NAPI
#                        [    1.109043] systemd[1]: Detected virtualization microsoft.
#                        [    4.618174] systemd[1]: Detected virtualization microsoft.
#                        [    8.898099] mlx4_core 9ba0:00:02.0: Detected virtual function - running in slave mode
#                        [    8.928888] mlx4_core 85e5:00:02.0: Detected virtual function - running in slave mode
# 
#                  Mellanox ConnectX-3 [15b3:1004] driver support for VMware ESXi by VMware
#                  See https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=35390&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1004&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc
#
#                  VMware Driver support for Mellanox ConnectX-3 by Mellanox 
#                  See https://www.mellanox.com/page/products_dyn?product_family=29&mtag=vmware_driver (click on 'View the list of the latest VMware driver version for Mellanox products')
#
#                  Azure VM offering specifically with ConnectX functionality by Microsoft Azure
#                  See https://github.com/MicrosoftDocs/azure-docs/issues/45303 "There is no possibility for now for checking/selecting the Mellanox driver for specific VM size before deploying."
#


function create-AzVM-vESXi_usingPhotonOS{
   [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        # Local file path of unzipped Photon OS 3.0 GA .vhd from https://vmware.bintray.com/photon/3.0/GA/azure/photon-azure-3.0-26156e2.vhd.tar.gz
        # Local file path of unzipped Photon OS 3.0 rev2 .vhd from https://vmware.bintray.com/photon/3.0/GA/azure/photon-azure-3.0-9355405.vhd.tar.gz
        $LocalFilePath="J:\photon-azure-3.0-9355405.vhd.tar\photon-azure-3.0-9355405.vhd",

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$cred = (Get-credential -message 'Enter a username and password.'),	

        [Parameter(Mandatory = $false)]
        [ValidateSet('eastus','westus','westeurope')]
        [String]$LocationName="westeurope",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ResourceGroupName="photonos-lab-rg",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$StorageAccountName="photonos$(Get-Random)",
		# Photon OS Image Blob name
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$BlobName= (split-path $LocalFilePath -leaf) ,
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ContainerName="disks",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NetworkName="photonos-lab-network",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VnetAddressPrefix="192.168.0.0/16",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ServerSubnetAddressPrefix="192.168.1.0/24",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMSize = "Standard_E4s_v3",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VMName = "photonos",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NICName1 = "${VMName}nic1",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$Ip1Address="192.168.1.6",
		[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$PublicIPDNSName="${NICName1}dns",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NICName2 = "${VMName}nic2",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$Ip2Address="192.168.1.5",		
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
        [String]$VMLocalAdminPassword = "PhotonOs123!" , #pwd must be 7-12 characters
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$BashfileName="prepare-disk.sh"		
    )

# Step #1: Check prerequisites and Azure login
# --------------------------------------------
# check if .vhd exists
if (!(Test-Path $LocalFilePath)) {break}

# check Azure CLI
az help 1>$null 2>$null
if ($lastexitcode -ne 0) {break}

# check Azure Powershell
if (([string]::IsNullOrEmpty((get-module -name Az* -listavailable)))) {break}

# Azure login
connect-Azaccount -Credential $cred
$azcontext=get-azcontext
if( -not $($azcontext) ) { return }
#Set the context to the subscription Id where Managed Disk exists and where VM will be created
$subscriptionId=($azcontext).Subscription.Id
# set subscription
az account set --subscription $subscriptionId

# Verify VM doesn't exist
[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] `
$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ([string]::IsNullOrEmpty($VM))) { return }


# Step #2: create a resource group and storage container
# ------------------------------------------------------
# create lab resource group if it does not exist
$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($result)))
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
}

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

# Step #3: upload the Photon OS .vhd as page blob
# -----------------------------------------------
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

# Step #4: create virtual network and security group
# --------------------------------------------------
# create network if not already set
$vnet = get-azvirtualnetwork -name $networkname -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($vnet)))
{
	$ServerSubnet  = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet  -AddressPrefix $ServerSubnetAddressPrefix
	$vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $ServerSubnet
	$vnet | Set-AzVirtualNetwork
}

# networksecurityruleconfig, UNFINISHED as VMware ESXi ports must be included
$nsg=get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nsg)))
{
	$rdpRule1 = New-AzNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" `
	-Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
	-SourceAddressPrefix Internet -SourcePortRange * `
	-DestinationAddressPrefix * -DestinationPortRange 3389
	$rdpRule2 = New-AzNetworkSecurityRuleConfig -Name mySSHRule -Description "Allow SSH" `
	-Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
	-SourceAddressPrefix Internet -SourcePortRange * `
	-DestinationAddressPrefix * -DestinationPortRange 22
	$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -Location $LocationName -SecurityRules $rdpRule1,$rdpRule2
}

# Step #5: create two nics, one with a public IP address
# ------------------------------------------------------
# Create a nic with a public IP address
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic1=get-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nic1)))
{
	$pip1 = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $PublicIPDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4
	# Create a virtual network card and associate with public IP address and NSG
	$nic1 = New-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		-SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip1.Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking -EnableIPForwarding
    # assign static IP adress
    if (-not ([string]::IsNullOrEmpty($nic1)))
    {
        $nic1=get-aznetworkinterface -resourcegroupname $resourcegroupname -name $NICName1
        $nic1.IpConfigurations[0].PrivateIpAddress=$Ip1Address
        $nic1.IpConfigurations[0].PrivateIpAllocationMethod="static"
        $nic1.tag=@{Name="Name";Value="Value"}
        set-aznetworkinterface -networkinterface $nic1
    }

}

# Create a second nic
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic2=get-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (([string]::IsNullOrEmpty($nic2)))
{
	# Create a virtual network card
	$nic2= New-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		-SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking -EnableIPForwarding
    # assign static IP adress
    if (-not ([string]::IsNullOrEmpty($nic2)))
    {
        $nic2=get-aznetworkinterface -resourcegroupname $resourcegroupname -name $NICName2
        $nic2.IpConfigurations[0].PrivateIpAddress=$Ip2Address
        $nic2.IpConfigurations[0].PrivateIpAllocationMethod="static"
        $nic2.tag=@{Name="Name";Value="Value"}
        set-aznetworkinterface -networkinterface $nic2
    }
}


# Step #6: create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from $Bashfilename 
# ------------------------------------------------------------------------------------------------------------------------
# save and reapply location info because 'az vm create --custom-data' fails using a filename not in current path
$locationstack=get-location
set-location -Path ${PSScriptRoot}

# az vm create with custom-data
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


# Step #7: convert the disks created to managed disks, detach and re-attach the bootable ESXi data disk as os disk. Afterwards the VM is started.
# -----------------------------------------------------------------------------------------------------------------------------------------------
# The VM is configured through custom-data to automatically power down. Wait for PowerState/stopped.
$Timeout = 1800
$i = 0
for ($i=0;$i -lt $Timeout; $i++) {
	sleep 1
    $percentComplete = ($i / $Timeout) * 100
    Write-Progress -Activity 'Provisioning' -Status "Provisioning in progress ..." -PercentComplete $percentComplete
    $objVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -status -ErrorAction SilentlyContinue
    if (-not ([string]::IsNullOrEmpty($objVM))) {
        if (((($objVM).Statuses[1]).Code) -ceq "PowerState/stopped") { 
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
            break
        }
    }
}

}

create-AzVM-vESXi_usingPhotonOS