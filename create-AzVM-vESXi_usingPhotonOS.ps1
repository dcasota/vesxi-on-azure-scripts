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
# The ESXi VM offering on Azure must support:
# - Accelerated Networking. Without acceleratednetworking, network adapters are not presented to the ESXi VM.
# - Premium disk support. The uploaded VMware Photon OS vhd must be stored as page blob on a premium disk to make use of it.
#
# The script uses the Standard_DS3_v2 offering: 4vCPU,14GB RAM, Accelerating Networking: Yes, Premium disk support:Yes. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-general
#
# Alternative VM sizes as per 27.12.2019 are:
# Standard_D3_v2, Standard_D12_v2, Standard_D3_v2_Promo, Standard_D12_v2_Promo, Standard_DS3_v2, Standard_DS12_v2, Standard_DS13-4_v2, Standard_DS14-4_v2, Standard_DS3_v2_Promo, Standard_DS12_v2_Promo, 
# Standard_DS13-4_v2_Promo, Standard_DS14-4_v2_Promo, Standard_F4, Standard_F4s, Standard_D8_v3, Standard_D8s_v3, Standard_D32-8s_v3, Standard_E8_v3, Standard_E8s_v3, Standard_D3_v2_ABC, Standard_D12_v2_ABC, Standard_F4_ABC, Standard_F8s_v2, Standard_D4_v2, 
# Standard_D13_v2, Standard_D4_v2_Promo, Standard_D13_v2_Promo, Standard_DS4_v2, Standard_DS13_v2, Standard_DS14-8_v2, Standard_DS4_v2_Promo, Standard_DS13_v2_Promo, Standard_DS14-8_v2_Promo, Standard_F8, Standard_F8s, Standard_M64-16ms, Standard_D16_v3, 
# Standard_D16s_v3, Standard_D32-16s_v3, Standard_D64-16s_v3, Standard_E16_v3, Standard_E16s_v3, Standard_E32-16s_v3, Standard_D4_v2_ABC, Standard_D13_v2_ABC, Standard_F8_ABC, Standard_F16s_v2, Standard_D5_v2, Standard_D14_v2, Standard_D5_v2_Promo, 
# Standard_D14_v2_Promo, Standard_DS5_v2, Standard_DS14_v2, Standard_DS5_v2_Promo, Standard_DS14_v2_Promo, Standard_F16, Standard_F16s, Standard_M64-32ms, Standard_M128-32ms, Standard_D32_v3, Standard_D32s_v3, Standard_D64-32s_v3, Standard_E32_v3, 
# Standard_E32s_v3, Standard_E32-8s_v3, Standard_E32-16_v3, Standard_D5_v2_ABC, Standard_D14_v2_ABC, Standard_F16_ABC, Standard_F32s_v2, Standard_D15_v2, Standard_D15_v2_Promo, Standard_D15_v2_Nested, Standard_DS15_v2, Standard_DS15_v2_Promo, 
# Standard_DS15_v2_Nested, Standard_D40_v3, Standard_D40s_v3, Standard_D15_v2_ABC, Standard_M64ms, Standard_M64s, Standard_M128-64ms, Standard_D64_v3, Standard_D64s_v3, Standard_E64_v3, Standard_E64s_v3, Standard_E64-16s_v3, Standard_E64-32s_v3, 
# Standard_F64s_v2, Standard_F72s_v2, Standard_M128s, Standard_M128ms, Standard_L8s_v2, Standard_L16s_v2, Standard_L32s_v2, Standard_L64s_v2, SQLGL, SQLGLCore, Standard_D4_v3, Standard_D4s_v3, Standard_D2_v2, Standard_DS2_v2, Standard_E4_v3, Standard_E4s_v3, 
# Standard_F2, Standard_F2s, Standard_F4s_v2, Standard_D11_v2, Standard_DS11_v2, AZAP_Performance_ComputeV17C, AZAP_Performance_ComputeV17C_DDA, AZAP_Performance_ComputeV17C_HalfNode, Standard_PB6s, Standard_PB12s, Standard_PB24s, Standard_L80s_v2, 
# Standard_M8ms, Standard_M8-4ms, Standard_M8-2ms, Standard_M16ms, Standard_M16-8ms, Standard_M16-4ms, Standard_M32ms, Standard_M32-8ms, Standard_M32-16ms, Standard_M32ls, Standard_M32ts, Standard_M64ls, Standard_E64i_v3, Standard_E64is_v3, 
# Standard_E4-2s_v3, Standard_E8-4s_v3, Standard_E8-2s_v3, Standard_E16-4s_v3, Standard_E16-8s_v3, Standard_E20s_v3, Standard_E20_v3, Standard_D11_v2_Promo, Standard_D2_v2_Promo, Standard_DS11_v2_Promo, Standard_DS2_v2_Promo, Standard_M208ms_v2, 
# Standard_MDB16s, Standard_MDB32s, Experimental_E64-40s_v3, Standard_DS11-1_v2, Standard_DS12-1_v2, Standard_DS12-2_v2, Standard_DS13-2_v2, MSODSG5, Special_CCX_DS13_v2, Special_CCX_DS14_v2, F2_Flex, F4_Flex, F8_Flex, F16_Flex, F32_Flex, F64_Flex, F2s_Flex, 
# F4s_Flex, F8s_Flex, F16s_Flex, F32s_Flex, F64s_Flex, D2_Flex, D4_Flex, D8_Flex, D16_Flex, D32_Flex, D64_Flex, D2s_Flex, D4s_Flex, D8s_Flex, D16s_Flex, D32s_Flex, D64s_Flex, E2_Flex, E4_Flex, E8_Flex, E16_Flex, E32_Flex, E64_Flex, E64i_Flex, E2s_Flex, 
# E4s_Flex, E8s_Flex, E16s_Flex, E32s_Flex, E64s_Flex, E64is_Flex, Standard_M416ms_v2, Standard_M416s_v2, Standard_M208s_v2, FCA_E64-52s_v3, FCA_E32-28s_v3, FCA_E32-26s_v3, FCA_E32-24s_v3, FCA_E16-14s_v3, FCA_E16-12s_v3, FCA_E16-10s_v3, FCA_E8-6s_v3, 
# Special_D4_v2, D48_Flex, D48s_Flex, E20_Flex, E20s_Flex, E48_Flex, E48s_Flex, F48s_Flex, Standard_D48_v3, Standard_D48s_v3, Standard_E48_v3, Standard_E48s_v3, Standard_F48s_v2, Standard_L48s_v2, SQLG5_IaaS, Standard_M128, Standard_M128m, Standard_M64,
# Standard_M64m, AZAP_Performance_ComputeV17C_12, Standard_B12ms, Standard_B16ms, Standard_B20ms, SQLG5-80m, AZAP_Performance_ComputeV17C_QuarterNode, Standard_DS15i_v2, Standard_D15i_v2, Standard_F72fs_v2, AZAP_Performance_ComputeV17B_76, 
# Standard_ND40s_v3, SQLG5_NP80, SQLG6, StandardM208msv2, SQLG6_IaaS, SQLG7_AMD, SQLG6_NP2, SQLG6_NP4, SQLG6_NP8, SQLG6_NP16, SQLG6_NP24, SQLG6_NP32, SQLG6_NP40, SQLG6_NP64, SQLG6_NP80, SQLG6_NP96, SQLG6_NP96s, Standard_D4a_v3, Standard_D8a_v3, 
# Standard_D16a_v3, Standard_D32a_v3, Standard_D48a_v3, Standard_D64a_v3, Standard_D96a_v3, Standard_D104a_v3, Standard_D4as_v3, Standard_D8as_v3, Standard_D16as_v3, Standard_D32as_v3, Standard_D48as_v3, Standard_D64as_v3, Standard_D96as_v3, 
# Standard_D104as_v3, Standard_E4a_v3, Standard_E8a_v3, Standard_E16a_v3, Standard_E32a_v3, Standard_E48a_v3, Standard_E64a_v3, Standard_E96a_v3, Standard_E104a_v3, Standard_E4as_v3, Standard_E8as_v3, Standard_E16as_v3, Standard_E32as_v3, Standard_E48as_v3, 
# Standard_E64as_v3, Standard_E96as_v3, Standard_E104as_v3, SQLG5_NP80s, Standard_D4_v4, Standard_D8_v4, Standard_D16_v4, Standard_D32_v4, Standard_D48_v4, Standard_D64_v4, Standard_D4d_v4, Standard_D8d_v4, Standard_D16d_v4, Standard_D32d_v4, 
# Standard_D48d_v4, Standard_D64d_v4, Standard_D4s_v4, Standard_D8s_v4, Standard_D16s_v4, Standard_D32s_v4, Standard_D48s_v4, Standard_D64s_v4, Standard_D4ds_v4, Standard_D8ds_v4, Standard_D16ds_v4, Standard_D32ds_v4, Standard_D48ds_v4, Standard_D64ds_v4, 
# Standard_E4_v4, Standard_E8_v4, Standard_E16_v4, Standard_E20_v4, Standard_E32_v4, Standard_E48_v4, Standard_E64_v4, Standard_E4d_v4, Standard_E8d_v4, Standard_E16d_v4, Standard_E20d_v4, Standard_E32d_v4, Standard_E48d_v4, Standard_E64d_v4, 
# Standard_E4s_v4, Standard_E8s_v4, Standard_E16s_v4, Standard_E20s_v4, Standard_E32s_v4, Standard_E48s_v4, Standard_E64s_v4, Standard_E64is_v4, Standard_E4ds_v4, Standard_E8ds_v4, Standard_E16ds_v4, Standard_E20ds_v4, Standard_E32ds_v4, Standard_E48ds_v4, 
# Standard_E64ds_v4, Standard_E64ids_v4, Standard_DC2s_v2, Standard_DC4s_v2, Standard_DC8_v2, SQLDCGen6_2, AZAP_Performance_ComputeV17W_76, AZAP_Performance_ComputeV17B_40, Standard_D4a_v4, Standard_D4as_v4, Standard_D8a_v4, Standard_D8as_v4, 
# Standard_D16a_v4, Standard_D16as_v4, Standard_D32a_v4, Standard_D32as_v4, Standard_D48a_v4, Standard_D48as_v4, Standard_D64a_v4, Standard_D64as_v4, Standard_D96a_v4, Standard_D96as_v4, Standard_E4a_v4, Standard_E4as_v4, Standard_E8a_v4, Standard_E8as_v4, 
# Standard_E16a_v4, Standard_E16as_v4, Standard_E20a_v4, Standard_E20as_v4, Standard_E32a_v4, Standard_E32as_v4, Standard_E48a_v4, Standard_E48as_v4, Standard_E64a_v4, Standard_E64as_v4, Standard_E96a_v4, Standard_E96as_v4, Standard_E64is_v4_SPECIAL, 
# Standard_E64ids_v4_SPECIAL, Standard_E4-2s_v4, Standard_E8-2s_v4, Standard_E8-4s_v4, Standard_E16-8s_v4, Standard_E16-4s_v4, Standard_E32-16s_v4, Standard_E32-8s_v4, Standard_E64-32s_v4, Standard_E64-16s_v4, Standard_E4-2ds_v4, Standard_E8-4ds_v4, 
# Standard_E8-2ds_v4, Standard_E16-8ds_v4, Standard_E16-4ds_v4, Standard_E32-16ds_v4, Standard_E32-8ds_v4, Standard_E64-32ds_v4, Standard_E64-16ds_v4, SQLG7, SQLG7_IaaS, SQLG6_NP56, Experimental_Olympia20ls, Experimental_Olympia20s, Experimental_Olympia20ms, 
# Experimental_Olympia40ls, Experimental_Olympia40s, Experimental_Olympia40ms, Experimental_Olympia80ls, Experimental_Olympia80s, Experimental_Olympia80ms, Standard_E64i_v4_SPECIAL."
# 
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
		# Photon OS Image Blob name
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$BlobName= (split-path $LocalFilePath -leaf) ,	

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
        [String]$VMLocalAdminPassword = "Photonos123!" , #pwd must be 7-12 characters
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

# networksecurityruleconfig
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

# az vm create with ESXi creation script prepare-disk.sh
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
$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ([string]::IsNullOrEmpty($VM)))
{

	# The VM is configured through custom-data to automatically power down. Wait for powerstate stopped.
	$Timeout = 1800
	$i = 0
	for ($i=0;$i -lt $Timeout; $i++) {
		$percentComplete = ($i / $Timeout) * 100
		Write-Progress -Activity 'Provisioning' -Status "Provisioning in progress ..." -PercentComplete $percentComplete
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -status -ErrorAction SilentlyContinue
        if (-not ([string]::IsNullOrEmpty($VM)))
        {
		    if ((($VM).Statuses[1].Code) -ceq "PowerState/stopped") { break }
        }
		sleep 1
	}

	if ((($VM).Statuses[1].Code) -ceq "PowerState/stopped")
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