#
# Create a VMware ESXi Virtual Machine on a Microsoft Azure offering
#
# The script creates a Generation V2 VM, temporary with VMware Photon OS. VMware Photon OS is provisioned using a preconfigured Azure image.
# An attached data disk is used for the installation bits of VMware ESXi 7.x. The prepared data disk then is promoted as OS disk.
# NESTED ESXI on AZURE is NOT OFFICIALLY SUPPORTED NEITHER FROM MICROSOFT NOR FROM VMWARE.
#
# USE THE SCRIPT AT YOUR OWN RISK! 
# 
#
# History
# 0.1  10.12.2019   dcasota  UNFINISHED! WORK IN PROGRESS!
# 0.2  03.11.2021   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites:
#    - Microsoft Powershell, Microsoft Azure Powershell, Microsoft Azure CLI
#    - Azure account: login is processed twice by device login method 
#
# How to use:
# 1. Create an Azure genV2 image with VMware Photon OS. The creation of the Azure image may be accomplished using create-AzImage-PhotonOS.ps1.
# 2. Create and upload your customized ESXi 7 ISO image to your Google drive.
# 3. Modify in prepare-disk-ventoy.sh the params ISOFILENAME and GOOGLEDRIVEFILEID
# 4. Change the default params ResourceGroupName, Imagename, etc. and run the script.
#
#
# Parameter LocalFilePath
#    Specifies the local file path to the unzipped VMware Photon OS .vhd
# Parameter BlobName
#    Azure Blob Name for the Photon OS .vhd
# Parameter cred
#    Azure login credentials
# Parameter Location
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
#               Findings (03.11.2021):
#                  The Azure Standard_E4s_v3 and above offerings include the accelerated networking feature, which is necessary to expose the underlying nic adapter functionality to the VM.
#                  Installing the VM as Photon OS, it exposes the Mellanox ConnectX-4 nic adapter virtual function. Unfortunately, installing the VM as ESXi does not show up any nic adapter type, hence, ESXi setup cannot proceed.
#
#                  Research/Findings on Photon OS:
#                     lspci output (tdnf install pciutils):
#                     lspci -nn -v| grep Mellanox
#                             1ac5:00:02.0 Ethernet controller [0200]: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] [15b3:1016] (rev 80)
#                                Subsystem: Mellanox Technologies Device [15b3:0190]
#                             f581:00:02.0 Ethernet controller [0200]: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] [15b3:1016] (rev 80)
#                                Subsystem: Mellanox Technologies Device [15b3:0190]
#                     dmesg output on Photon OS (tdnf install usbutils):
#                     dmesg | grep virtual
#                             [    0.080137] Booting paravirtualized kernel on Hyper-V
#                             [    0.412417] VMware vmxnet3 virtual NIC driver - version 1.5.0.0-k-NAPI
#                             [    0.599638] systemd[1]: Detected virtualization microsoft.
#                             [    1.976837] systemd[1]: Detected virtualization microsoft.
#
#                  Research/Findings on ESXi Shell:
#                     lspci output: The Mellanox device has not been detected
#                     localcli device driver list shows up vmhba0 only. There is no vmnic.
#
#                  According to the findings on Photon OS, the Azure offering includes Mellanox ConnectX-4 nic adapter virtual function [15b3:1016] subsystem 15b3:0190.    
#                  Possible drivers are:
#
#                     Mellanox ConnectX-4 driver support for VMware ESXi by VMware
#                        See https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=42583&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1016&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc
#
#                     VMware Driver support for Mellanox ConnectX-3 by Mellanox 
#                        See https://www.mellanox.com/products/ethernet-drivers/vmware/esxi-server
#
#                     Azure VM offering specifically with ConnectX functionality by Microsoft Azure
#                        See https://github.com/MicrosoftDocs/azure-docs/issues/45303 "There is no possibility for now for checking/selecting the Mellanox driver for specific VM size before deploying."
#
#                     Mellanox Adapter CIM Provider for VMware ESX/ESXi
#                        See https://www.mellanox.com/page/products_dyn?product_family=131&mtag=common_information_model
#
#                  Conclusion so far:
#                  1) Afaik none of the ESXi Mellanox ConnectX-4 adapter virtual function [15b3:1016] includes the 15b3:0190 subsystem for an Azure setup compatibility.
#                  2) Not 100% sure if ESXi UEFI boot is needed. 
#                     All the ESXi 7.x Mellanox ConnectX-4 adapter drivers are native drivers.
#                     As the Mellanox adapters DO show up on Photon OS, it has nothing to do with Azure Generation2-VM-sizes restrictions like Virtualization-based Security (VBS), Secure Boot, etc.
#                  3) The Azure VM created is HyperVGeneration V2. See https://docs.microsoft.com/en-us/azure/virtual-machines/generation-2
#                        - Nothing new, an Azure ESXi guest operating system is not supported, see https://github.com/MicrosoftDocs/windowsserverdocs/blob/master/WindowsServerDocs/virtualization/hyper-v/plan/Should-I-create-a-generation-1-or-2-virtual-machine-in-Hyper-V.md
#


function create-AzVM-vESXi_usingPhotonOS{
   [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$azconnect,
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string]$azclilogin,

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $HyperVGeneration="V2", # actually there is no prestage detection of the image disk Hyper-V Generation. it must be specified manually for the VM data disk created
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        $Imagename="photon-azure-4.0-ca7c9e933_V2.vhd",


        [Parameter(Mandatory = $false)][ValidateNotNull()]
        [ValidateSet('eastasia','southeastasia','centralus','eastus','eastus2','westus','northcentralus','southcentralus',`
        'northeurope','westeurope','japanwest','japaneast','brazilsouth','australiaeast','australiasoutheast',`
        'southindia','centralindia','westindia','canadacentral','canadaeast','uksouth','ukwest','westcentralus','westus2',`
        'koreacentral','koreasouth','francecentral','francesouth','australiacentral','australiacentral2',`
        'uaecentral','uaenorth','southafricanorth','southafricawest','switzerlandnorth','switzerlandwest',`
        'germanynorth','germanywestcentral','norwaywest','norwayeast','brazilsoutheast','westus3')]
        [String]$Location="switzerlandnorth",


        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ResourceGroupName="ph4Rev1lab",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$StorageAccountName="photonosstorage",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$ContainerName="disks",

        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$NetworkName="virtualesxi-lab-network",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$VnetAddressPrefix="192.168.0.0/16",
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$SubnetAddressPrefix="192.168.1.0/24",

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

        [Parameter(Mandatory = $false)][ValidateNotNull()]
        [string]$VMLocalAdminUser = "local", # admin user name cannot contain upper case character A-Z, special characters \/"[]:|<>+=;,?*@#()! or start with $ or -

        [Parameter(Mandatory = $false)][ValidateNotNull()]
        [string]$VMLocalAdminPwd="Secure2020123.", #12-123 chars
           		
        [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
        [String]$Bashfile="C:\Users\admin\Downloads\vesxi-on-azure-scripts\prepare-disk-ventoy.sh"	
    )

# virtual machine local admin setting
$VMLocalAdminSecurePassword = ConvertTo-SecureString $VMLocalAdminPwd -AsPlainText -Force
$VMLocalcred = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

# https://github.com/Azure/azure-powershell/blob/master/documentation/breaking-changes/breaking-changes-messages-help.md
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Check Windows Powershell environment. Original codesnippet parts from https://www.powershellgallery.com/packages/Az.Accounts/2.2.5/Content/Az.Accounts.psm1
$PSDefaultParameterValues.Clear()
Set-StrictMode -Version Latest

function Test-DotNet
{
    try
    {
        if ((Get-PSDrive 'HKLM' -ErrorAction Ignore) -and (-not (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' -ErrorAction Stop | Get-ItemPropertyValue -ErrorAction Stop -Name Release | Where-Object { $_ -ge 461808 })))
        {
            throw ".NET Framework versions lower than 4.7.2 are not supported in Az. Please upgrade to .NET Framework 4.7.2 or higher."
            exit
        }
    }
    catch [System.Management.Automation.DriveNotFoundException]
    {
        Write-Verbose ".NET Framework version check failed."
        exit
    }
}

if ($true -and ($PSEdition -eq 'Desktop'))
{
    if ($PSVersionTable.PSVersion -lt [Version]'5.1')
    {
        throw "PowerShell versions lower than 5.1 are not supported in Az. Please upgrade to PowerShell 5.1 or higher."
        exit
    }
    Test-DotNet
}

if ($true -and ($PSEdition -eq 'Core'))
{
    if ($PSVersionTable.PSVersion -lt [Version]'6.2.4')
    {
        throw "Current Az version doesn't support PowerShell Core versions lower than 6.2.4. Please upgrade to PowerShell Core 6.2.4 or higher."
        exit
    }
}

# check Azure CLI user install
if (test-path("$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin"))
{
    $Remove = "$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin"
    $env:Path = ($env:Path.Split(';') | Where-Object -FilterScript {$_ -ne $Remove}) -join ';'
    $env:path="$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin;"+$env:path
}

$version=""
try
{
    $version=az --version 2>$null
    $version=(($version | select-string "azure-cli")[0].ToString().Replace(" ","")).Replace("azure-cli","")
}
catch {}

# Update was introduced in 2.11.0, see https://docs.microsoft.com/en-us/cli/azure/update-azure-cli
if (($version -eq "") -or ($version -lt "2.11.0"))
{
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
    Start-Process msiexec.exe -Wait -ArgumentList "/a AzureCLI.msi /qb TARGETDIR=$env:APPDATA\azure-cli /quiet"
    if (!(test-path("$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin")))
    {
        throw "Azure CLI installation failed."
        exit
    }
    else
    {
        $Remove = "$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin"
        $env:Path = ($env:Path.Split(';') | Where-Object -FilterScript {$_ -ne $Remove}) -join ';'
        $env:path="$env:APPDATA\azure-cli\Microsoft SDKs\Azure\CLI2\wbin;"+$env:path

        $version=az --version 2>$null
        $version=(($version | select-string "azure-cli")[0].ToString().Replace(" ","")).Replace("azure-cli","")
    }
    if (test-path(.\AzureCLI.msi)) {rm .\AzureCLI.msi}
}
if ($version -lt "2.19.1")
{
    az upgrade --yes --all 2>&1 | out-null
}


# check Azure Powershell
# https://github.com/Azure/azure-powershell/issues/13530
# https://github.com/Azure/azure-powershell/issues/13337
if (!(([string]::IsNullOrEmpty((get-module -name Az.Accounts -listavailable)))))
{
    if ((get-module -name Az.Accounts -listavailable).Version.ToString() -lt "2.2.5") 
    {
        update-module Az -Scope User -RequiredVersion 5.5 -MaximumVersion 5.5 -force -ErrorAction SilentlyContinue
    }
}
else
{
    install-module Az -Scope User -RequiredVersion 5.5 -MaximumVersion 5.5 -force -ErrorAction SilentlyContinue
}


if (!(Get-variable -name azclilogin -ErrorAction SilentlyContinue))
{
    $azclilogin=az login --use-device-code
}
else
{
    if ([string]::IsNullOrEmpty($azclilogin))
    {
        $azclilogin=az login --use-device-code
    }
}

if (!(Get-variable -name azclilogin -ErrorAction SilentlyContinue))
{
    write-host "Azure CLI login required."
    exit
}

if (!(Get-variable -name azconnect -ErrorAction SilentlyContinue))
{
    $azconnect=connect-azaccount -devicecode
	$AzContext=$null
}
else
{
    if ([string]::IsNullOrEmpty($azconnect))
    {
        $azconnect=connect-azaccount -devicecode
	    $AzContext=$null
    }
}

if (!(Get-variable -name azconnect -ErrorAction SilentlyContinue))
{
    write-host "Azure Powershell login required."
    exit
}

if (!(Get-variable -name AzContext -ErrorAction SilentlyContinue))
{
	$AzContext = Get-AzContext
    $ArmToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(
    $AzContext.'Account',
    $AzContext.'Environment',
    $AzContext.'Tenant'.'Id',
    $null,
    [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never,
    $null,
    'https://management.azure.com/'
    )
    $tenantId = ($AzContext).Tenant.Id
    $accessToken = (Get-AzAccessToken -ResourceUrl "https://management.core.windows.net/" -TenantId $tenantId).Token
}


#Set the context to the subscription Id where Managed Disk exists and where virtual machine will be created if necessary
$subscriptionId=(get-azcontext).Subscription.Id
# set subscription
az account set --subscription $subscriptionId

# Verify virtual machine doesn't exist
[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if ($VM)
{
	write-host "VM $VMName already exists."
	break
}

# Verify if image exists
$result=get-azimage -ResourceGroupName $ResourceGroupName -Name $Imagename -ErrorAction SilentlyContinue
if ( -not $($result))
{
	write-host "Could not find Azure image $Imagename on resourcegroup $ResourceGroupName."
	break
}

# create lab resource group if it does not exist
$result = get-azresourcegroup -name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue
if ( -not $($result))
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

# storageaccount
$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if ( -not $($storageaccount))
{
	$storageaccount=New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $Location -Kind Storage -SkuName Standard_LRS -ErrorAction SilentlyContinue
	if ( -not $($storageaccount))
    {
        write-host "Storage account has not been created. Check if the name is already taken."
        break
    }
}
do {sleep -Milliseconds 1000} until ($((get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).ProvisioningState) -ieq "Succeeded") 
$storageaccountkey=(get-azstorageaccountkey -ResourceGroupName $ResourceGroupName -name $StorageAccountName)

$result=az storage container exists --account-name $storageaccountname --name ${ContainerName} --auth-mode login | convertfrom-json
if ($result.exists -eq $false)
{
	az storage container create --name ${ContainerName} --public-access blob --account-name $StorageAccountName --account-key ($storageaccountkey[0]).value
}


# network security rules configuration
$nsg=get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ( -not $($nsg))
{
    $nsRule1 = New-AzNetworkSecurityRuleConfig -Name myPort80Rule -Description "Allow http" `
	-Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
	-SourceAddressPrefix Internet -SourcePortRange * `
	-DestinationAddressPrefix * -DestinationPortRange 80	
	$nsRule2 = New-AzNetworkSecurityRuleConfig -Name mySSHRule -Description "Allow SSH" `
	-Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
	-SourceAddressPrefix Internet -SourcePortRange * `
	-DestinationAddressPrefix * -DestinationPortRange 22
	$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -Location $Location -SecurityRules $nsRule1,$nsRule2
}

# set network if not already set
$vnet = get-azvirtualnetwork -name $networkname -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue
if ( -not $($vnet))
{
    $ServerSubnet  = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet  -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroup $nsg
	$vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $ServerSubnet
	$vnet | Set-AzVirtualNetwork
}

# Step #5: create two nics, one with a public IP address
# ------------------------------------------------------
# Create a nic with a public IP address
# This IP address is created as AcceleratedNetworking. Hence, the underlying NIC will become presentable to the VM created.
$nic1=get-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not ($nic1))
{
	$pip1 = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -Name $PublicIPDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4
	# Create a virtual network card and associate with public IP address and NSG
	$nic1 = New-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -Location $Location `
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
	$nic2= New-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -Location $Location `
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
	
    $diskConfig = New-AzDiskConfig -AccountType 'Standard_LRS' -Location $Location -HyperVGeneration $HyperVGeneration -CreateOption Empty -DiskSizeGB ${diskSizeGB} -OSType Linux
    New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $ESXiDiskName

    # az vm create with custom-data
    try {
	az vm create --resource-group ${ResourceGroupName} --location ${Location} --name ${vmName} `
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

}

create-AzVM-vESXi_usingPhotonOS