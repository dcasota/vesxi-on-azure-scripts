#
# Create a VMware ESXi Virtual Machine on a Microsoft Azure offering
#
# The script creates a Generation V2 VM, temporary with VMware Photon OS. VMware Photon OS is provisioned using a preconfigured Azure image.
# An attached data disk is used for the installation bits of VMware ESXi. The prepared data disk then is promoted as OS disk.
#
# USE THE SCRIPT IT AT YOUR OWN RISK! If you run into issues, give up or try to fix it on your own support. Nested VMware ESXi on Azure is NOT OFFICIALLY SUPPORTED.
# 
#
# History
# 0.1  10.12.2019   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites:
#    - Microsoft Powershell, Microsoft Azure Powershell, Microsoft Azure CLI
#    - Azure account
#    - Azure image with VMware Photon OS. The creation of the Azure image may be accomplished using create-AzImage_GenV2-PhotonOS.ps1.
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
# - ESXi setup starts with 'no network adapters'
#   workaround: none
#               Findings:
#                  The Azure Standard_E4s_v3 and above offerings include the accelerated networking feature, which is necessary to expose the underlying nic adapter functionality to the VM.
#                  Installing the VM as Photon OS, it exposes the Mellanox ConnectX-3 nic adapter virtual function. Unfortunately, installing the VM as ESXi does not show up any nic adapter type, hence, ESXi setup cannot proceed.
#
#                  Research/Findings on Photon OS:
#                     lspci output (tdnf install pciutils):
#                     lspci -nn -v| grep Mellanox
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
#                  Research/Findings on ESXi Shell:
#                     lspci output: The Mellanox device has not been detected
#                        0000:00:00.0 Host bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (AGP disabled)
#                        0000:00:07.0 ISA bridge: Intel Corporation 82371AB/EB/MB PIIX4 ISA
#                        0000:00:07.1 IDE interface: Intel Corporation PIIX4 for 430TX/440BX/MX IDE Controller [vmhba0]
#                        0000:00:07.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI
#                        0000:00:08.0 VGA compatible controller: Microsoft Corporation Hyper-V virtual VGA
#                     localcli device driver list shows up vmhba0 only. There is no vmnic.
#
#                  According to the findings on Photon OS, the Azure offering includes Mellanox ConnectX-3 nic adapter virtual function [15b3:1004] subsystem 15b3:61b0.    
#                  Possible drivers are:
#
#                     Mellanox ConnectX-3 [15b3:1004] driver support for VMware ESXi by VMware
#                        See https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=35390&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1004&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc
#
#                     VMware Driver support for Mellanox ConnectX-3 by Mellanox 
#                        See https://www.mellanox.com/page/products_dyn?product_family=29&mtag=vmware_driver (click on 'View the list of the latest VMware driver version for Mellanox products')
#
#                     Azure VM offering specifically with ConnectX functionality by Microsoft Azure
#                        See https://github.com/MicrosoftDocs/azure-docs/issues/45303 "There is no possibility for now for checking/selecting the Mellanox driver for specific VM size before deploying."
#
#                     Mellanox Adapter CIM Provider for VMware ESX/ESXi
#                        See https://www.mellanox.com/page/products_dyn?product_family=131&mtag=common_information_model
#
#                  Conclusion so far:
#                  1) Afaik none of the ESXi Mellanox ConnectX-3 adapter virtual function [15b3:1004] includes the 15b3:61b0 subsystem for an Azure setup compatibility.
#                  2) Not 100% sure if ESXi UEFI boot is needed. In any case, early ESXi boot using in Bios does not show up any correlating dmesg ACPI message.
#                     All the Mellanox ESXi ConnectX-3 adapters are native drivers.
#                     As the Mellanox adapters DO show up on Photon OS, it has nothing to do with Azure Generation2-VM-sizes restrictions like Virtualization-based Security (VBS), Secure Boot, etc.
#                  3) The Azure VM created is HyperVGeneration V1. Hence,
#                        - The VHD to boot from is not UEFI-compatible
#                        - Generation 2 doesn't support the boot method you want to use.
#                        - Nothing new, an Azure ESXi guest operating system is not supported, see https://github.com/MicrosoftDocs/windowsserverdocs/blob/master/WindowsServerDocs/virtualization/hyper-v/plan/Should-I-create-a-generation-1-or-2-virtual-machine-in-Hyper-V.md
#


function create-AzVM-vESXi_usingPhotonOS{
   [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $Imagename="photon-azure-3.0-9355405",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $HyperVGeneration="V1", # actually there is no prestage detection of the image disk Hyper-V Generation. it must be specified manually for the VM data disk created

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$cred = (Get-credential -message 'Enter a username and password for the Azure login.'),	

        [Parameter(Mandatory = $false)]
        [ValidateSet('eastus','westus','westeurope','switzerlandnorth')]
        [String]$LocationName="switzerlandnorth",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ResourceGroupName="photonos-lab-rg",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$StorageAccountName="photonoslab",
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
        
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$VMLocalcred = (Get-credential -message 'Enter username and password for the VM user account to be created locally. Password must be 7-12 characters. Username must be all in small letters.'),	        	
   		
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$Bashfile="C:\Users\admin\Downloads\vesxi-on-azure-scripts\prepare-disk-bios.sh" # or prepare-disk-efi.sh		
    )

## check Azure CLI
if (-not ($($env:path).contains("CLI2\wbin")))
{
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    $env:path="C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin;"+$env:path
}

# check Azure Powershell
if (([string]::IsNullOrEmpty((get-module -name Az* -listavailable)))) {install-module Az -force -ErrorAction SilentlyContinue}

# Azure login
connect-Azaccount -Credential $cred
$azcontext=get-azcontext
if( -not $($azcontext) ) { return }
#Set the context to the subscription Id where Managed Disk exists and where VM will be created
$subscriptionId=($azcontext).Subscription.Id
# set subscription
az account set --subscription $subscriptionId

# create lab resource group if it does not exist
$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
if (-not ($result))
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
}

$ImageId=(get-azimage -ResourceGroupName $ResourceGroupName -ImageName $ImageName).Id
if (-not ($ImageId)) {break}

$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not ($storageaccount))
{
    New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $LocationName -Kind Storage -SkuName Standard_LRS -ErrorAction SilentlyContinue
}
do {sleep -Milliseconds 1000} until ($((get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).ProvisioningState) -ieq "Succeeded") 
$storageaccountkey=(get-azstorageaccountkey -ResourceGroupName $ResourceGroupName -name $StorageAccountName)

$result=az storage container exists --account-name $storageaccountname --name ${ContainerName} | convertfrom-json
if ($result.exists -eq $false)
{
    try {
        az storage container create --name ${ContainerName} --public-access blob --account-name $StorageAccountName --account-key ($storageaccountkey[0]).value
    } catch{}
}

# networksecurityruleconfig, UNFINISHED as VMware ESXi ports must be included
$nsg=get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not ($nsg))
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

# network if not already set
$vnet = get-azvirtualnetwork -name $networkname -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue
if (-not ($vnet))
{
	$ServerSubnet  = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet  -AddressPrefix $ServerSubnetAddressPrefix -NetworkSecurityGroup $nsg
	$vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $ServerSubnet
	$vnet | Set-AzVirtualNetwork
}

# Step #5: create two nics, one with a public IP address
# ------------------------------------------------------
# Create a nic with a public IP address
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic1=get-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not ($nic1))
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
if (-not ($nic2))
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


# Verify VM doesn't exist
[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ($VM))
{
	# save and reapply location info because 'az vm create --custom-data' fails using a filename not in current path
	$locationstack=get-location
    $Bashfilepath=split-path $Bashfile -Parent
    $Bashfilename=split-path $Bashfile -leaf
	set-location -Path ${Bashfilepath}

	$VMLocalAdminUser=$VMLocalcred.GetNetworkCredential().username
	$VMLocalAdminPassword=$VMLocalcred.GetNetworkCredential().password
	
    $diskConfig = New-AzDiskConfig -AccountType 'Standard_LRS' -Location $LocationName -HyperVGeneration $HyperVGeneration -CreateOption Empty -DiskSizeGB ${diskSizeGB} -OSType Linux
    New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $ESXiDiskName

    # az vm create with custom-data
    try {
	az vm create --resource-group ${ResourceGroupName} --location ${LocationName} --name ${vmName} `
	--size ${VMSize} `
	--admin-username ${VMLocalAdminUser} --admin-password ${VMLocalAdminPassword} `
	--os-disk-size-gb ${diskSizeGB} `
    --attach-data-disks $ESXiDiskName `
	--image ${ImageName} `
	--computer-name ${computerName} `
	--nics ${NICName1} ${NicName2} `
	--generate-ssh-keys `
	--custom-data ${Bashfilename} `	
	--boot-diagnostics-storage "https://${StorageAccountName}.blob.core.windows.net"
    } catch {}

    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    Set-AzVMBootDiagnostic -VM $VM -Enable -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

	set-location -path $locationstack
    }

# The VM is configured through custom-data to automatically power down. Wait for PowerState/stopped.
$Timeout = 1800
$i = 0
for ($i=0;$i -lt $Timeout; $i++) {
	sleep 1
    $percentComplete = ($i / $Timeout) * 100
    Write-Progress -Activity 'Provisioning' -Status "Provisioning in progress ..." -PercentComplete $percentComplete
    $objVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -status -ErrorAction SilentlyContinue
	if (-not ([Object]::ReferenceEquals($objVM,$null))) {
        if (((($objVM).Statuses[1]).Code) -ceq "PowerState/stopped") { 		
		    # Make sure the VM is stopped but not deallocated so you can detach/attach disk
		    Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Stayprovisioned -Force
            # Save Photon OS Disk name
		    $PhotonDiskName=(get-azvm -ResourceGroupName $resourceGroupName -Name $vmName).StorageProfile.OSdisk.Name
		    # Detach the prepared data disk
		    $virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
		    Remove-AzVMDataDisk -VM $VirtualMachine -Name $ESXiDiskName
		    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
		    # Set the prepared data disk as os disk
		    $VirtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
		    $sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $ESXiDiskName
		    Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name
		    Update-AzVM -ResourceGroupName $resourceGroupName -VM $VirtualMachine

            # Attach Photon OS disk as second disk
            Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
		    $sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $PhotonDiskName
		    $VirtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
		    Add-AzVMDataDisk -VM $virtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name -Lun 0 -CreateOption Attach
		    Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine

		    Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            break
        }
    }
}

}

create-AzVM-vESXi_usingPhotonOS