# .SYNOPSIS
#  Deploy an Azure VM of VMware ESXi ISO installer
#
# .DESCRIPTION
#  The script creates an Azure VM of VMware ESXi ISO installer. It uses location, resource group and virtual machine name as mandatory parameters.
#
#  You can specify additional params value. The default virtual machine type offering used is a Standard_F4s_v2 offering with 4 vCPU, 8GB RAM, Premium Disk Support and 32GB temporary storage,
#  and Accelerating Networking with two nics. Without Accelerated Networking, network adapters would not be presented inside the virtual machine.
# 
#  What the script does:
#  1) First the script installs the Az 8.0 module if necessary and triggers an Azure login using the device code method. You get a similar message to
#      WARNUNG: To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code xxxxxxxxx to authenticate.
#     The Azure Powershell output shows up as warning (see above). Open a webbrowser, and fill in the code given by the Azure Powershell login output.
# 
#  2) a helper Azure virtual machine with Windows Server is created. From the Github repo https://github.com/VFrontDe/ESXi-Customizer-PS of Andreas Peetz,
#     the ESXi Customizer script is downloaded. It dynamically creates a customized ESXi iso, and the iso is uploaded as Azure blob. The helper VM is deallocated.
#  3) an Azure virtual machine from a Photon OS image is created. The image must have been created before. The virtual machine gets an additional data disk.
#     Inside Photon OS, Ventoy from https://github.com/ventoy/Ventoy is downloaded and installed as bootloader on the data disk.
#     The customized ESXi iso is downloaded into the Ventoy partition. Some Ventoy injection and com redirection tecniques are applied.
#  4) The data disk becomes the os disk. The virtual machine boots.
#  After the script has successfully finished, enter the Azure virtual machine serial console of the newly created vm.
#
#  .PREREQUISITES
#    - Script must run on MS Windows OS with Powershell PSVersion 5.1 or higher
#    - Azure account with Virtual Machine contributor role
#    - An Azure GenV2 image of Photon OS
#
#
# .NOTES
#   Author:  Daniel Casota
#   Version:
#   2.0   26.07.2022   dcasota  Complete rewrite
#   2.0.1 28.07.2022   dcasota  bugfixing ventoy.json path, Update Ventoy 1.0.79
#   2.0.2 02.08.2022   dcasota  bugfixing example
#
# .PARAMETER LocationName
#   Azure location name where to create or lookup the resource group
# .PARAMETER ResourceGroupName
#   resource group name
# .PARAMETER RuntimeId
#   random id used in names
# .PARAMETER NetworkName
#   vm network name
# .PARAMETER SubnetAddressPrefix
#   subnet address prefix
# .PARAMETER VNetAddressPrefix
#  vnet address prefix
# .PARAMETER nsgName
#   nsg name
# .PARAMETER NicName1
#   nic name 1
# .PARAMETER ip1Adress
#   ipAddress 1
# .PARAMETER PublicIPDNSName
#   public ip dns name
# .PARAMETER NicName2
#   nic name 2
# .PARAMETER ip2Adress
#   ipAddress 2
# .PARAMETER StorageAccountName
#   storage account name
# .PARAMETER StorageKind
#   storage kind
# .PARAMETER StorageAccountType
#   storage account type
# .PARAMETER ContainerName
#   container name
# .PARAMETER ESXiDiskName
#   ESXiDiskName
# .PARAMETER ESXiBootdiskSizeGB
#   ESXiBootdiskSizeGB
# .PARAMETER VMName
#   VMName
# .PARAMETER ComputerName
#   computername
# .PARAMETER VMSize
#   vm size
# .PARAMETER ResourceGroupNameImage
#   ResourceGroupNameImage
# .PARAMETER Imagename
#   Imagename
# .PARAMETER HyperVGeneration
#   HyperVGeneration		
# .PARAMETER ISOName
#   ISOName
# .PARAMETER HelperVMName
#   HelperVMName
# .PARAMETER HelperVMComputerName
#   HelperVMComputerName
# .PARAMETER HelperVMNICName
#   HelperVMNICName
# .PARAMETER HelperVMDiskName
#   HelperVMDiskName
# .PARAMETER HelperVMPublisherName 
#   HelperVMPublisherName
# .PARAMETER HelperVMPublisherName
#   HelperVMPublisherName
# .PARAMETER HelperVMofferName
#   HelperVMofferName
# .PARAMETER HelperVMsku
#   HelperVMsku
# .PARAMETER HelperVMsize
#   HelperVMsize
# .PARAMETER HelperVMLocalAdminUser
#   HelperVMLocalAdminUser
# .PARAMETER HelperVMLocalAdminPwd
#   HelperVMLocalAdminPwd
# .PARAMETER HelperVMsize_TempPath
#   HelperVMsize_TempPath
#
#
# .EXAMPLE
#    ./create-AzVM-vESXi7.ps1 -ResourceGroupName ESXiLab -Location switzerlandnorth -VMName ESXi01
#
#>

[CmdletBinding()]
param(
[Parameter(Mandatory = $true)][ValidateNotNull()]
[string]$LocationName,

[Parameter(Mandatory = $true)][ValidateNotNull()]
[string]$ResourceGroupName,

[Parameter(Mandatory = $false)]
[string]$RuntimeId = (Get-Random).ToString(),

[Parameter(Mandatory = $false)]
[string]$NetworkName = "${RuntimeId}vnet",

[Parameter(Mandatory = $false)]
[string]$SubnetAddressPrefix = "192.168.1.0/24",

[Parameter(Mandatory = $false)]
[string]$VnetAddressPrefix = "192.168.0.0/16",

[Parameter(Mandatory = $false)]
[string]$nsgName = "${RuntimeId}nsg",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$NICName1 = "${RuntimeId}nic1",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$Ip1Address="192.168.1.6",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$PublicIPDNSName="${NICName1}dns",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$NICName2 = "${RuntimeId}nic2",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$Ip2Address="192.168.1.5",

[Parameter(Mandatory = $false)][ValidateLength(3,24)][ValidatePattern("[a-z0-9]")]
[string]$StorageAccountName=("${RuntimeId}storage").ToLower(),

[Parameter(Mandatory = $false)]
[string]$StorageKind="Storage",

[Parameter(Mandatory = $false)]
[string]$StorageAccountType="Standard_LRS",

[Parameter(Mandatory = $false)]
[string]$ContainerName = "${RuntimeId}container",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$ESXiDiskName = "${RuntimeId}Disk",

[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
[String]$ESXiBootdiskSizeGB = '16', # DO NOT CHANGE BECAUSE THE VALUE IS HARDCODED IN ScriptrunLinux

[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$VMName="",

[Parameter(Mandatory = $false)]
[string]$ComputerName = $VMName,

[Parameter(Mandatory = $false)]
[string]$VMsize="Standard_F4s_v2", # This default virtual machine size offering includes a d: drive with 32GB non-persistent capacity

[Parameter(Mandatory = $false)][ValidateNotNull()]
[string]$ResourceGroupNameImage="PhotonOSTemplates",
		
[Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
$Imagename="photon-azure-4.0-c001795b8_V2.vhd",

[Parameter(Mandatory = $false)][ValidateSet('V1','V2')]
[string]$HyperVGeneration="V2",

[Parameter(Mandatory = $false)]
[string]$ISOName="ESXi-customized.iso",

[Parameter(Mandatory = $false)]
[string]$HelperVMName = "${RuntimeId}w2k22",

[Parameter(Mandatory = $false)]
[string]$HelperVMComputerName = $HelperVMName,

[Parameter(Mandatory = $false)]
[string]$HelperVMNICName = "${HelperVMComputerName}nic",

[Parameter(Mandatory = $false)]
[string]$HelperVMDiskName="${HelperVMComputerName}helperdisk",

[Parameter(Mandatory = $false)]
[string]$HelperVMPublisherName = "MicrosoftWindowsServer",

[Parameter(Mandatory = $false)]
[string]$HelperVMofferName = "WindowsServer",

[Parameter(Mandatory = $false)]
[string]$HelperVMsku = "2022-datacenter-core-smalldisk-g2",

[Parameter(Mandatory = $false)]
[string]$HelperVMsize="Standard_F4s_v2", # This default virtual machine size offering includes a d: drive with 32GB non-persistent capacity

[Parameter(Mandatory = $false)]
[string]$HelperVMLocalAdminUser = "LocalAdminUser",

[Parameter(Mandatory = $false)][ValidateLength(12,123)]
[string]$HelperVMLocalAdminPwd="Secure2020123!", #12-123 chars

[Parameter(Mandatory = $false)]
[string]$HelperVMsize_TempPath="d:" # $DownloadURL file is downloaded and extracted on this drive inside vm. Depending of the VMSize offer, it includes built-in an additional non persistent  drive.

)

# Specify Tls
$TLSProtocols = [System.Net.SecurityProtocolType]::'Tls13',[System.Net.SecurityProtocolType]::'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $TLSProtocols

# Check Azure Powershell
try
{
	# $version = (get-installedmodule -name Az).version # really slow
    $version = (get-command get-azcontext).Version.ToString()
	if ($version -lt "2.8")
	{
		write-output "Updating Azure Powershell ..."	
		update-module -Name Az -RequiredVersion "8.0" -ErrorAction SilentlyContinue
		write-output "Please restart Powershell session."
		break			
	}
}
catch
{
    write-output "Installing Azure Powershell ..."
    install-module -Name Az -RequiredVersion "8.0" -ErrorAction SilentlyContinue
    write-output "Please restart Powershell session."
    break	
}

$azconnect=$null
try
{
    # Already logged-in?
    $subscriptionId=(get-azcontext).Subscription.Id
    $TenantId=(get-azcontext).Tenant.Id
    # set subscription
    select-AzSubscription -Subscription $subscriptionId -tenant $TenantId -ErrorAction Stop
    $azconnect=get-azcontext -ErrorAction SilentlyContinue
}
catch {}
if ([Object]::ReferenceEquals($azconnect,$null))
{
    try
    {
        $azconnect=connect-azaccount -devicecode
        $subscriptionId=(get-azcontext).Subscription.Id
        $TenantId=(get-azcontext).Tenant.Id
        # set subscription
        select-AzSubscription -Subscription $subscriptionId -tenant $TenantId -ErrorAction Stop
    }
    catch
    {
        write-output "Azure Powershell login required."
        break
    }
}



# save credentials
$contextfile=$($env:public) + [IO.Path]::DirectorySeparatorChar + "azcontext.txt"
Save-AzContext -Path $contextfile -Force

$Scriptrun=
@'

# The core concept of this script is:
#   1) Download and extract the Photon OS bits from download url
#   2) do a blob upload of the extracted vhd file
# There are several culprits:
#   A) The script is started in localsystem account. In LocalSystem context there is no possibility to connect outside.
#      Hence, the script creates a run once scheduled task with user impersonation and executing the downloaded powershell script.
#      There are some hacks in localsystem context to make a run-once-scheduled task with user logon type.
#   B) Portion of the script uses Azure Powershell.

$RootDrive=(get-item $tmppath).Root.Name
$ISOFile=$tmppath + [IO.Path]::DirectorySeparatorChar + $ISOName
$IsISOUploaded=$env:public + [IO.Path]::DirectorySeparatorChar + "ISOUploaded.txt"

if ($env:username -ine $HelperVMLocalAdminUser)
{
    $filetostart=$MyInvocation.MyCommand.Source
    # $LocalUser=$env:computername + "\" + $HelperVMLocalAdminUser
    $LocalUser=$HelperVMLocalAdminUser

	$PowershellFilePath =  "$PsHome\powershell.exe"
    $Taskname = "Processing"
	$Argument = "\"""+$PowershellFilePath +"\"" -WindowStyle Hidden -NoLogo -NoProfile -Executionpolicy unrestricted -command \"""+$filetostart+"\"""

    # Scheduled task run takes time.
    $timeout=3600

    $i=0
    $rc=0
    do
    {
        $i++
        try
        {
            if ($rc -eq 0)
            {
                schtasks.exe /create /F /TN "$Taskname" /tr $Argument /SC ONCE /ST 00:00 /RU ${LocalUser} /RP ${HelperVMLocalAdminPwd} /RL HIGHEST /NP
                start-sleep -s 1
                schtasks /Run /TN "$Taskname" /I
                start-sleep -s 1
                $rc=1
            }
            if ($rc -eq 1)
            {
                start-sleep -s 1
                $i++
            }
        }
        catch {}
    }
    until ((test-path(${IsVhdUploaded})) -or ($i -gt $timeout))
    exit
}



$orgfile=$($env:public) + [IO.Path]::DirectorySeparatorChar + "azcontext.txt"
$fileencoded=$($env:public) + [IO.Path]::DirectorySeparatorChar + "azcontext_encoded.txt"
if ((test-path($fileencoded)) -eq $false)
{
	out-file -inputobject $CachedAzContext -FilePath $fileencoded
	if ((test-path($orgfile)) -eq $true) {remove-item -path ($orgfile) -force}
	certutil -decode $fileencoded $orgfile
	if ((test-path($orgfile)) -eq $true)
    {
        import-azcontext -path $orgfile
        remove-item -path ($fileencoded) -force
        remove-item -path ($orgfile) -force
    }
}

if (Test-Path -d $tmppath)
{
    cd $tmppath
    if (!(Test-Path $ISOfile))
    {
        $RootDrive="'"+$(split-path -path $tmppath -Qualifier)+"'"
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID=$RootDrive" | select-object @{Name="FreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}}
        if ($disk.FreeGB -gt 30)
        {
            if (!(Test-Path ".\ESXi-Customizer-PS.ps1"))
            {
                c:\windows\system32\curl.exe -J -O -L https://raw.githubusercontent.com/VFrontDe/ESXi-Customizer-PS/master/ESXi-Customizer-PS.ps1
            }
            if (Test-Path ".\ESXi-Customizer-PS.ps1")
            {
                try
                {
					.\ESXi-Customizer-PS.ps1 -v70 -pkgDir $tmppath -outdir $tmppath -nsc
					$ESXiFileName= (get-childitem -path .\*.iso)[0].name
                    rename-item -Path $ESXiFileName -NewName $ISOName
                }
                catch
                {
                    write-output Failed to assemble isofile.
                }
            }
        }
    }
}

if (Test-Path $ISOFile)
{
	# Azure login
	$azcontext=get-azcontext
	if ($azcontext)
	{
		$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
		if ($result)
		{
			$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
			if ($storageaccount)
			{
                $result=get-azstoragecontainer -Name ${ContainerName} -Context $storageaccount.Context -ErrorAction SilentlyContinue
                if ($result)
				{
                    $result=get-azstorageblob -Container ${ContainerName} -Blob ${ISOName} -Context $storageaccount.Context -ErrorAction SilentlyContinue
                    if ( -not ($result))
					{
                        Set-AzStorageBlobContent -Container ${ContainerName} -File $ISOFile -Blob ${ISOName} -BlobType page -Context $storageaccount.Context
					}
                    $result=get-azstorageblob -Container ${ContainerName} -Blob ${ISOName} -Context $storageaccount.Context -ErrorAction SilentlyContinue
                    if ($result)
					{
                        $ISOFile | out-file -filepath $IsISOUploaded -append
                    }
				}
			}
		}
	}
}
'@

$ScriptrunLinux=
@'
# search empty device
export DEVICE=`lsblk --output PATH,UUID,PTUUID,PARTTYPE | awk '{ if ($2 == "" && $3 == "" && $4 == "") print $1}'`

cd /tmp

# download required packages. parted and dosfstools are for Ventoy2Disk.sh
tdnf install -y tar wget curl parted dosfstools xz

# download and install Ventoy
curl -O -J -L https://github.com/ventoy/Ventoy/releases/download/v1.0.79/ventoy-1.0.79-linux.tar.gz
tar -xzvf /tmp/ventoy-1.0.79-linux.tar.gz
cd /tmp/ventoy-1.0.79
echo y > /tmp/ventoy-1.0.79/y
echo y >> /tmp/ventoy-1.0.79/y
cat /tmp/ventoy-1.0.79/y | /tmp/ventoy-1.0.79/Ventoy2Disk.sh -I -s -g $DEVICE

# mount ventoy partition 1
mkdir /tmp/exfat
xz -d -v /tmp/ventoy-1.0.79/tool/x86_64/mount.exfat-fuse.xz
chmod a+x /tmp/ventoy-1.0.79/tool/x86_64/mount.exfat-fuse
/tmp/ventoy-1.0.79/tool/x86_64/mount.exfat-fuse ${DEVICE}1 /tmp/exfat

# download ISO to /tmp/exfat and mount it
cd /tmp/exfat
curl -O -J -L $ISOURL
ESXICD=/tmp/esxicd
mkdir $ESXICD
mount -t iso9660 -o ro,nojoliet,iocharset=utf8 ./$ISOFILENAME $ESXICD

# set compatible mark https://www.ventoy.net/en/doc_compatible_mark.html
echo ventoy > /tmp/exfat/ventoy.dat

# set Ventoy parameters for console
mkdir /tmp/exfat/ventoy

# Specify serial ports in isolinux.cfg
cp $ESXICD/isolinux.cfg /tmp/exfat/ventoy/isolinux.cfg
# Add line 'serial 0 115200' and 'serial 1 115200' after 'DEFAULT menu.c32'
#    Serial 0 = /dev/ttyS0 = com1
#    Serial 1 = /dev/ttyS1 = com2
cp /tmp/exfat/ventoy/isolinux.cfg /tmp/exfat/ventoy/isolinux.cfg.0
sed 's/DEFAULT menu.c32/&\nserial 0 115200/' /tmp/exfat/ventoy/isolinux.cfg.0 > /tmp/exfat/ventoy/isolinux.cfg
cp /tmp/exfat/ventoy/isolinux.cfg /tmp/exfat/ventoy/isolinux.cfg.0
sed 's/serial 0 115200/&\nserial 1 115200/' /tmp/exfat/ventoy/isolinux.cfg.0 > /tmp/exfat/ventoy/isolinux.cfg
cp /tmp/exfat/ventoy/isolinux.cfg /tmp/exfat/ventoy/isolinux.cfg.0
#    apply setting B)
#       - Redirect tty2port to serial port com1
#       As result the setup boots into DCUI
sed "s/boot.cfg/boot.cfg text nofb ignoreHeadless=TRUE tty2Port=com1 logPort=none gdbPort=none/" /tmp/exfat/ventoy/isolinux.cfg.0 > /tmp/exfat/ventoy/isolinux.cfg

# Specify serial ports in boot.cfg
cp $ESXICD/boot.cfg /tmp/exfat/ventoy/boot.cfg
#    apply setting A)
#       - runweasel text nofb
cp /tmp/exfat/ventoy/boot.cfg /tmp/exfat/ventoy/boot.cfg.0
sed "s/kernelopt=runweasel cdromBoot/kernelopt=runweasel cdromBoot text nofb tty2Port=com1 logPort=none gdbPort=none/" /tmp/exfat/ventoy/boot.cfg.0 > /tmp/exfat/ventoy/boot.cfg


# Ventoy injection file 
cat << EOF1 >> /tmp/exfat/ventoy/ventoy.json
{
    "theme_legacy": {
        "display_mode": "serial",
        "serial_param": "--unit=0 --speed=115200 --word=8 --parity=no --stop=1"
    },
    "theme_uefi": {
        "display_mode": "serial",
        "serial_param": "--unit=0 --speed=115200 --word=8 --parity=no --stop=1"
    },
    "conf_replace_legacy": [
        {
            "iso": "/ESXi-customized.iso",
            "org": "/boot.cfg",
            "new": "/ventoy/boot.cfg"
        },
        {
            "iso": "/ESXi-customized.iso",
            "org": "/isolinux.cfg",
            "new": "/ventoy/isolinux.cfg"
        }
    ],
    "conf_replace_uefi": [
        {
            "iso": "/ESXi-customized.iso",
            "org": "/EFI/BOOT/boot.cfg",
            "new": "/ventoy/boot.cfg"
        },
        {
            "iso": "/ESXi-customized.iso",
            "org": "/isolinux.cfg",
            "new": "/ventoy/isolinux.cfg"
        }
    ]	
}
EOF1

cd /tmp
# unmount esxi cd
umount $ESXICD
# unmount partition 1
umount /tmp/exfat

# poweroff
shutdown --poweroff now
'@

# create lab resource group if it does not exist
$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
if ( -not $($result))
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
}

# storageaccount
$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if ( -not $($storageaccount))
{
	$storageaccount=New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $LocationName -Kind $StorageKind -SkuName $StorageAccountType -ErrorAction SilentlyContinue
	if ( -not $($storageaccount))
    {
        write-output "Storage account has not been created. Check if the name is already taken."
        break
    }
}
do {start-sleep -Milliseconds 1000} until ($((get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).ProvisioningState) -ieq "Succeeded")
$storageaccountkey=(get-azstorageaccountkey -ResourceGroupName $ResourceGroupName -name $StorageAccountName)
$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue


$result=get-azstoragecontainer -Name ${ContainerName} -Context $storageaccount.Context -ErrorAction SilentlyContinue
if ( -not $($result))
{
    new-azstoragecontainer -Name ${ContainerName} -Context $storageaccount.Context -ErrorAction SilentlyContinue -Permission Blob
}

$UploadedISO=Get-AzStorageBlob -Container ${ContainerName} -Blob ${ISOName} -Context $storageaccount.Context -ErrorAction SilentlyContinue
if ([Object]::ReferenceEquals($UploadedISO,$null))
{
	# create a temporary windows virtual machine and process VMware.Imagebuilder
	[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $HelperVMName -ErrorAction SilentlyContinue
	if (-not ($VM))
	{
    	# networksecurityruleconfig
    	$nsg=get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    	if ( -not $($nsg))
    	{
    		$nsgRule1 = New-AzNetworkSecurityRuleConfig -Name nsgRule1 -Description "Allow RDP" `
    		-Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    		-SourceAddressPrefix Internet -SourcePortRange * `
    		-DestinationAddressPrefix * -DestinationPortRange 3389
    		$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -Location $LocationName -SecurityRules $nsgRule1
    	}

    	# set network if not already set
    	$vnet = get-azvirtualnetwork -name $NetworkName -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue
    	if ( -not $($vnet))
    	{
    		$ServerSubnet  = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroup $nsg
    		$vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $ServerSubnet
    		$vnet | Set-AzVirtualNetwork
    	}

		# virtual machine local admin setting
		$VMLocalAdminSecurePassword = ConvertTo-SecureString $HelperVMLocalAdminPwd -AsPlainText -Force
		$LocalAdminUserCredential = New-Object System.Management.Automation.PSCredential ($HelperVMLocalAdminUser, $VMLocalAdminSecurePassword)

		# Create a virtual network card
		$nic=get-AzNetworkInterface -Name $HelperVMNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
		if ( -not $($nic))
		{
			$nic = New-AzNetworkInterface -Name $HelperVMNICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id
		}

		# Create a virtual machine configuration
		$vmConfig = New-AzVMConfig -VMName $HelperVMName -VMSize $HelperVMsize | `
		Add-AzVMNetworkInterface -Id $nic.Id

        # Get-AzVMImage -Location switzerlandnorth -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2019-datacenter-with-containers-smalldisk-g2
        $productversion=((get-azvmimage -Location $LocationName -PublisherName $HelperVMPublisherName -Offer $HelperVMofferName -Skus $HelperVMsku)[(get-azvmimage -Location $LocationName -PublisherName $HelperVMPublisherName -Offer $HelperVMofferName -Skus $HelperVMsku).count -1 ]).version

		$vmimage= get-azvmimage -Location $LocationName -PublisherName $HelperVMPublisherName -Offer $HelperVMofferName -Skus $HelperVMsku -Version $productversion
		if (-not ([Object]::ReferenceEquals($vmimage,$null)))
		{
			if (-not ([Object]::ReferenceEquals($vmimage.PurchasePlan,$null)))
			{
				$agreementTerms=Get-AzMarketplaceterms -publisher $vmimage.PurchasePlan.publisher -Product $vmimage.PurchasePlan.product -name $vmimage.PurchasePlan.name
				Set-AzMarketplaceTerms -publisher $vmimage.PurchasePlan.publisher -Product $vmimage.PurchasePlan.product -name $vmimage.PurchasePlan.name -Terms $agreementTerms -Accept
				$agreementTerms=Get-AzMarketplaceterms -publisher $vmimage.PurchasePlan.publisher -Product $vmimage.PurchasePlan.product -name $vmimage.PurchasePlan.name
				Set-AzMarketplaceTerms -publisher $vmimage.PurchasePlan.publisher -Product $vmimage.PurchasePlan.product -name $vmimage.PurchasePlan.name -Terms $agreementTerms -Accept
				$vmConfig = Set-AzVMPlan -VM $vmConfig -publisher $vmimage.PurchasePlan.publisher -Product $vmimage.PurchasePlan.product -name $vmimage.PurchasePlan.name
			}

			$vmConfig = Set-AzVMOperatingSystem -Windows -VM $vmConfig -ComputerName $HelperVMComputerName -Credential $LocalAdminUserCredential | `
			Set-AzVMSourceImage -PublisherName $HelperVMPublisherName -Offer $HelperVMofferName -Skus $HelperVMsku -Version $productversion		
			$vmConfig | Set-AzVMBootDiagnostic -Disable

			# Create the virtual machine		
			New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $vmConfig
		}
    }
    
    [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $HelperVMName -ErrorAction SilentlyContinue
    if ($VM)
    {
	    Set-AzVMBootDiagnostic -VM $VM -Enable -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName		
        Update-AzVM -VM $VM -ResourceGroupName $ResourceGroupName
		
		# Prepare scriptfile
		$contextfileEncoded=$($env:public) + [IO.Path]::DirectorySeparatorChar + "azcontext_enc.txt"
		if ((test-path($contextfileEncoded)) -eq $true) {remove-item -path ($contextfileEncoded) -force}
		certutil -encode $contextfile $contextfileEncoded
		$content = get-content -path $contextfileEncoded
		$ScriptFile = $($env:public) + [IO.Path]::DirectorySeparatorChar + "importazcontext.ps1"
		$value = '$CachedAzContext=@'+"'`r`n"
		# https://stackoverflow.com/questions/42407136/difference-between-redirection-to-null-and-out-null
		$null = new-item $ScriptFile -type file -force -value $value
		out-file -inputobject $content -FilePath $ScriptFile -Encoding ASCII -Append
		out-file -inputobject "'@" -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$tmppath="'+$HelperVMsize_TempPath+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$tenant="'+$((get-azcontext).tenant.id)+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$ResourceGroupName="'+$ResourceGroupName+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$LocationName="'+$LocationName+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$StorageAccountName="'+$StorageAccountName+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$ISOName="'+$ISOName+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$ContainerName="'+$ContainerName+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$HelperVMLocalAdminUser="'+$HelperVMLocalAdminUser+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		$tmp='$HelperVMLocalAdminPwd="'+$HelperVMLocalAdminPwd+'"'; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
		out-file -inputobject $ScriptRun -FilePath $ScriptFile -Encoding ASCII -append
		remove-item -path ($contextfileEncoded) -force

        # Extensions preparation
		$Blobtmp="importazcontext.ps1"
        $Extensions = Get-AzVMExtensionImage -Location $LocationName -PublisherName "Microsoft.Compute" -Type "CustomScriptExtension"
        $ExtensionPublisher= $Extensions[$Extensions.count-1].PublisherName
        $ExtensionType = $Extensions[$Extensions.count-1].Type
        $ExtensionVersion = (($Extensions[$Extensions.count-1].Version)[0..2]) -join ""

		# blob upload of scriptfile
        $result=get-azstorageblob -Container $ContainerName -Blob ${BlobTmp} -Context $storageaccount.Context -ErrorAction SilentlyContinue
        if (!($result))
		{
            Set-AzStorageBlobContent -Container ${ContainerName} -File $ScriptFile -Blob ${BlobTmp} -BlobType Block -Context $storageaccount.Context
		}

        # Remote install Az + PowerCLI module
        $commandToExecute="powershell.exe Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force ; powershell install-module -name Az -force -ErrorAction SilentlyContinue; powershell install-module VMware.PowerCLI -scope AllUsers -force -SkipPublisherCheck -AllowClobber -ErrorAction SilentlyContinue; shutdown.exe /r /t 0"
        $ScriptSettings = @{}
        $ProtectedSettings = @{"storageAccountName" = $StorageAccountName; "storageaccountkey" = ($storageaccountkey[0]).value ; "commandToExecute" = $commandToExecute }
        Set-AzVMExtension -ResourceGroupName $ResourceGroupName -Location $LocationName -VMName $HelperVMName -Name $ExtensionType -Publisher $ExtensionPublisher -ExtensionType $ExtensionType -TypeHandlerVersion $ExtensionVersion -Settings $ScriptSettings -ProtectedSettings $ProtectedSettings
     	Remove-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $HelperVMName -Name $ExtensionType -force -ErrorAction SilentlyContinue
        # wait for the reboot
        start-sleep 15

        # Run scriptfile
        $Run = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.12\Downloads\0\$BlobTmp"
        Set-AzVMCustomScriptExtension -Name "CustomScriptExtension" -Location $LocationName -ResourceGroupName $ResourceGroupName -VMName $HelperVMName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -FileName $BlobTmp -Run $Run		
		Remove-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $HelperVMName -Name "CustomScriptExtension" -force -ErrorAction SilentlyContinue

        if (test-path($ScriptFile)) { remove-item -path ($ScriptFile) -force -ErrorAction SilentlyContinue }
    }
    else
    {
        write-Output "Error: Virtual machine hasn't been created."
        break
    }    	
}

# Wait for upload
$UploadedISO=$null
$timeout=300
$i=0
$rc=$false
do
{
    $i++
    start-sleep 1
    try
    {
        if ($rc -eq $false)
        {
            $UploadedISO=Get-AzStorageBlob -Container ${ContainerName} -Blob ${ISOName} -Context $storageaccount.Context -ErrorAction SilentlyContinue          
            $rc=(-not ([string]::IsNullOrEmpty($UploadedISO)))
        }
     }
     catch {}
}
until (($rc -eq $true) -or ($i -gt $timeout))
if ($rc -eq $false)
{
    write-Output "Error: ISO creation failed."
    break
}

# Cleanup temporary Windows Server machine
$obj=Get-AzVM -ResourceGroupName $ResourceGroupName -Name $HelperVMName -ErrorAction SilentlyContinue
if (-not ([Object]::ReferenceEquals($obj,$null)))
{
	Stop-AzVM -ResourceGroupName $resourceGroupName -Name $HelperVMName -Force -ErrorAction SilentlyContinue
    $HelperVMDiskName=$obj.StorageProfile.OsDisk.Name
    Remove-AzVM -ResourceGroupName $resourceGroupName -Name $HelperVMName -force -ErrorAction SilentlyContinue
    $obj=Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $HelperVMDiskName -ErrorAction SilentlyContinue
    if (-not ([Object]::ReferenceEquals($obj,$null)))
    {
        Remove-AzDisk -ResourceGroupName $resourceGroupName -DiskName $HelperVMDiskName -Force -ErrorAction SilentlyContinue
    }
}
$obj=Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $HelperVMNICName -ErrorAction SilentlyContinue
if (-not ([Object]::ReferenceEquals($obj,$null)))
{
	Remove-AzNetworkInterface -Name $HelperVMNICName -ResourceGroupName $ResourceGroupName -force -ErrorAction SilentlyContinue
}
$obj=Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPDNSName -ErrorAction SilentlyContinue
if (-not ([Object]::ReferenceEquals($obj,$null)))
{
	Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPDNSName -Force -ErrorAction SilentlyContinue
}

if (test-path($contextfile)) { remove-item -path ($contextfile) -force -ErrorAction SilentlyContinue }

# Verify VM doesn't exist
[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not ($VM))
{
    # Create a nic with a public IP address
    $nic1=get-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not ($nic1))
    {
	    $pip1 = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $PublicIPDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4 -ErrorAction SilentlyContinue
	    # Create a virtual network card with Accelerated Networking and associate with public IP address and NSG
	    $nic1 = New-AzNetworkInterface -Name $NICName1 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		    -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip1.Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking -EnableIPForwarding -ErrorAction SilentlyContinue
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
    $nic2=get-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not ($nic2))
    {
	    $nic2= New-AzNetworkInterface -Name $NICName2 -ResourceGroupName $ResourceGroupName -Location $LocationName `
		    -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -EnableAcceleratedNetworking -EnableIPForwarding -ErrorAction SilentlyContinue
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

    # networksecurityruleconfig
    $nsg = get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName | Add-AzNetworkSecurityRuleConfig -Name nsgRule2 -Description "Allow SSH" `
    		-Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
    		-SourceAddressPrefix Internet -SourcePortRange * `
    		-DestinationAddressPrefix * -DestinationPortRange 22 | set-AzNetworkSecurityGroup     
    Remove-AzNetworkSecurityRuleConfig -Name nsgRule1 -NetworkSecurityGroup $nsg
    $nsg | Set-AzNetworkSecurityGroup
		
	# create virtual machine
	$VM = New-AzVMConfig -VMName $VMName -VMSize $VMSize
	$VM = Set-AzVMOperatingSystem -VM $VM -Linux -ComputerName $ComputerName -Credential $LocalAdminUserCredential 
	$VM = Add-AzVMNetworkInterface -VM $VM -Id $nic1.Id -Primary
	$VM = Add-AzVMNetworkInterface -VM $VM -Id $nic2.Id		
	$VM = $VM | set-AzVMSourceImage -Id (get-azimage -ResourceGroupName $ResourceGroupNameImage -ImageName $ImageName).Id
	$VM| Set-AzVMBootDiagnostic -Disable

	$Disk = Get-AzDisk | where-object {($_.resourcegroupname -ieq $ResourceGroupName) -and ($_.Name -ieq $ESXiDiskName)}
	if (-not $($Disk))
	{
		$diskConfig = New-AzDiskConfig -AccountType 'Standard_LRS' -Location $LocationName -HyperVGeneration $HyperVGeneration -CreateOption Empty -DiskSizeGB ${ESXiBootdiskSizeGB} -OSType Linux
		$Disk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $ESXiDiskName -Disk $diskConfig
        do {start-sleep -Milliseconds 1000} until ($((get-azdisk -ResourceGroupName $ResourceGroupName -DiskName $ESXiDiskName).ProvisioningState) -ieq "Succeeded")
	}
    $VM = Add-AzVMDataDisk -VM $VM -ManagedDiskId $Disk.Id -Name $ESXiDiskName -Lun 1 -CreateOption Attach

	New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VM

    [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    if ($VM)
    {
	    Set-AzVMBootDiagnostic -VM $VM -Enable -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName		
        Update-AzVM -VM $VM -ResourceGroupName $ResourceGroupName
    }
    else
    {
        write-Output "Error: Virtual machine hasn't been created."
        break
    }
}

[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if ($VM)
{
	# Prepare scriptfile
	$ScriptFileName = "preparation.sh"
	$ScriptFile = $($env:public) + [IO.Path]::DirectorySeparatorChar + $ScriptFileName
	$value = "#!/bin/sh"+"`r`n"
	# https://stackoverflow.com/questions/42407136/difference-between-redirection-to-null-and-out-null
	$null = new-item $ScriptFile -type file -force -value $value	
	$isourl = "https://${storageaccountname}.blob.core.windows.net/${containername}/${ISOName}"+"`r`n"
	$tmp='export ISOURL='+$isourl; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
	$tmp='export ISOFILENAME='+$ISOName; out-file -inputobject $tmp -FilePath $ScriptFile -Encoding ASCII -Append
	out-file -inputobject $ScriptrunLinux -FilePath $ScriptFile -Encoding ASCII -append

	# blob upload of scriptfile
	$BlobResult=get-azstorageblob -Container $ContainerName -Blob $ScriptFileName -Context $storageaccount.Context -ErrorAction SilentlyContinue
	if (!($BlobResult))
	{
		$BlobResult=Set-AzStorageBlobContent -Container ${ContainerName} -File $ScriptFile -Blob $ScriptFileName -BlobType Block -Context $storageaccount.Context
	}

	# Remote execute
	$Extensions = Get-AzVMExtensionImage -Location $LocationName -PublisherName "Microsoft.Azure.Extensions" -Type "CustomScript"
	$ExtensionPublisher= $Extensions[$Extensions.count-1].PublisherName
	$ExtensionType = $Extensions[$Extensions.count-1].Type
	$ExtensionVersion = (($Extensions[$Extensions.count-1].Version)[0..2]) -join ""
	$commandToExecute="sh ${ScriptFileName}"
	$Uri = @((($BlobResult).BlobBaseClient).Uri.AbsoluteUri)
	$ScriptSettings = @{"fileUris" = $Uri; "commandToExecute" = $commandToExecute }
	$Key = ($storageaccountkey[0]).value
	$ProtectedSettings = @{"storageAccountName" = $storageAccountName; "storageAccountKey" = $Key};
	Set-AzVMExtension -ResourceGroupName $ResourceGroupName -Location $LocationName -VMName $VMName -Name $ExtensionType -Publisher $ExtensionPublisher -ExtensionType $ExtensionType -TypeHandlerVersion $ExtensionVersion -Settings $ScriptSettings -ProtectedSettings $ProtectedSettings
	start-sleep 20
    Remove-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $ExtensionType -force -ErrorAction SilentlyContinue

	Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Stayprovisioned -Force
	# Save Photon OS Disk name
	$PhotonDiskName=(get-azvm -ResourceGroupName $resourceGroupName -Name $vmName).StorageProfile.OSdisk.Name
	# Detach the prepared data disk
	$virtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	Remove-AzVMDataDisk -VM $VirtualMachine -Name $ESXiDiskName
	Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine
	# Set the prepared data disk as os disk
	$sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $ESXiDiskName
	$VirtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name
	Update-AzVM -ResourceGroupName $resourceGroupName -VM $VirtualMachine

	# Attach Photon OS disk as second disk
	# $sourceDisk = Get-AzDisk -ResourceGroupName $resourceGroupName  -DiskName $PhotonDiskName
	# $VirtualMachine = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
	# Add-AzVMDataDisk -VM $virtualMachine -ManagedDiskId $sourceDisk.Id -Name $sourceDisk.Name -Lun 2 -CreateOption Attach
	# Update-AzVM -ResourceGroupName $resourceGroupName -VM $virtualMachine

	Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

    if (test-path($ScriptFile)) { remove-item -path ($ScriptFile) -force -ErrorAction SilentlyContinue }
}
else
{
    write-Output "Error: Virtual machine hasn't been created."
}



