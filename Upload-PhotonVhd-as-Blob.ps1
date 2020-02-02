#
# Helper-script to download, extract VMware Photon OS .vhd and upload it as Azure Blob.
#
# History
# 0.1   27.01.2020   dcasota  Initial release
#
#
# Prerequisites:
#   MS Windows OS
#

[CmdletBinding()]
param(
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$Uri="http://dl.bintray.com/vmware/photon/3.0/Rev2/azure/photon-azure-3.0-9355405.vhd.tar.gz",
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$tmppath,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$username,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$password,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$tenant,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$ResourceGroupName,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$LocationName,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$StorageAccountName,
[Parameter(Mandatory = $true, ParameterSetName = 'PlainText')]
[String]$ContainerName
)


Function DeGZip-File{
# Original Source https://scatteredcode.net/download-and-extract-gzip-tar-with-powershell/
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
        )
    if ($IsWindows -or $ENV:OS)
    {    
        $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
        $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
        $buffer = New-Object byte[](1024)
        while($true){
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0){break}
            $output.Write($buffer, 0, $read)
        }
        $gzipStream.Close()
        $output.Close()
        $input.Close()
    }
}


$RootDrive=(get-item $tmppath).Root.Name
$PhotonOSTarGzFileName=split-path -path $Uri -Leaf
$PhotonOSTarFileName=$PhotonOSTarGzFileName.Substring(0,$PhotonOSTarGzFileName.LastIndexOf('.')).split([io.path]::DirectorySeparatorChar)[-1]
$PhotonOSVhdFilename=$PhotonOSTarFileName.Substring(0,$PhotonOSTarFileName.LastIndexOf('.')).split([io.path]::DirectorySeparatorChar)[-1]

# check Azure Powershell
if (([string]::IsNullOrEmpty((get-module -name Az* -listavailable)))) {install-module Az -force -ErrorAction SilentlyContinue}

# check PS7Zip
if (([string]::IsNullOrEmpty((get-module -name PS7zip -listavailable)))) {install-module PS7zip -force -ErrorAction SilentlyContinue}

# check Azure CLI
az help 1>$null 2>$null
if ($lastexitcode -ne 0)
{
    if ($IsWindows -or $ENV:OS)
    {
        if (test-path AzureCLI.msi) {remove-item -path AzureCLI.msi -force}
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
        $env:path="C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin;"+$env:path
    }
    else
    {
        curl -L https://aka.ms/InstallAzureCli | bash
    }
}

$tarfile=$tmppath + [io.path]::DirectorySeparatorChar+$PhotonOSTarFileName
$vhdfile=$tmppath + [io.path]::DirectorySeparatorChar+$PhotonOSVhdFilename
$gzfile=$tmppath + [io.path]::DirectorySeparatorChar+$PhotonOSTarGzFileName

if (!(Test-Path $vhdfile))
{
    if (Test-Path -d $tmppath)
    {
        cd $tmppath
        if (!(Test-Path $gzfile))
        {
            $RootDrive="'"+$(split-path -path $tmppath -Qualifier)+"'"
            $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID=$RootDrive" | select-object @{Name="FreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}}
            if ($disk.FreeGB -gt 35)
            {
                Invoke-WebRequest $Uri -OutFile $PhotonOSTarGzFileName
                if (Test-Path $gzfile)
                {
                    DeGZip-File $gzfile $tarfile
                    if (Test-Path $tarfile)
                    {
                        # if $tarfile successfully extracted, delete $gzfile
                        Remove-Item -Path $gzfile
                        Expand-7zip $tarfile -destinationpath $tmppath
                        # if $vhdfile successfully extracted, delete $tarfile
                        if (Test-Path $vhdfile) { Remove-Item -Path $tarfile}
                    }
                }
            }
        }
    }
}

if (Test-Path $vhdfile)
{
    $secpasswd = ConvertTo-SecureString ${password} -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential ($username,$secpasswd)

    # Add URLs to trusted sites
    invoke-webrequest -Uri https://gallery.technet.microsoft.com/scriptcenter/How-to-batch-add-URLs-to-c8207c23/file/115241/1/Powershell.zip -Outfile Powershell.zip
    Expand-7zip Powershell.zip -destinationpath $tmppath
    $AddingtrustedSitesPath=$tmppath+[io.path]::DirectorySeparatorChar+"powershell"
    $AddingTrustedSites=$AddingtrustedSitesPath+[io.path]::DirectorySeparatorChar+"AddingTrustedSites.ps1"
    & "$AddingtrustedSites" -TrustedSites "login.microsoftonline.com","aadcdn.msftauth.net","aadcdn.msauth.net","login.live.com","logincdn.msauth.net"
    remove-item -d $AddingtrustedSitesPath -force

	# Azure login
    # TODO Zuerst alle Adressen einbauen. Immer noch WS Management Fehler Remoting anschauen
	connect-Azaccount -Credential $cred -tenant $tenant -ServicePrincipal
	$azcontext=get-azcontext
	if ($azcontext)
	{
		#Set the context to the subscription Id
		$subscriptionId=($azcontext).Subscription.Id
		az account set --subscription $subscriptionId

		$result = get-azresourcegroup -name $ResourceGroupName -Location $LocationName -ErrorAction SilentlyContinue
		if ($result)
		{
			$storageaccount=get-azstorageaccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
			if ($storageaccount)
			{
				$storageaccountkey=(get-azstorageaccountkey -ResourceGroupName $ResourceGroupName -name $StorageAccountName)
				$result=az storage container exists --account-name $storageaccountname --name ${ContainerName} | convertfrom-json
				if ($result.exists -eq $true)
				{
					$BlobName= split-path $vhdfile -leaf
					$urlOfUploadedVhd = "https://${StorageAccountName}.blob.core.windows.net/${ContainerName}/${BlobName}"
					$result=az storage blob exists --account-key ($storageaccountkey[0]).value --account-name $StorageAccountName --container-name ${ContainerName} --name ${BlobName} | convertfrom-json
					if ($result.exists -eq $false)
					{
						try {
						az storage blob upload --account-name $StorageAccountName `
						--account-key ($storageaccountkey[0]).value `
						--container-name ${ContainerName} `
						--type page `
						--file $vhdfile `
						--name ${BlobName}
						} catch{}
					}			
				}
			}
		}
	}
}
