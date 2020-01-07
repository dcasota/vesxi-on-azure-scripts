#
# Create a customized ESXi 6.5 ISO with Mellanox adapter driver to work on a target Azure hardware offering 
#
# 
#
# History
# 0.1  05.01.2020   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites
#    - VMware PowerCLI (with ImageBuilder cmdlets)
#    - ESXi-Customizer https://www.v-front.de/p/esxi-customizer-ps.html
#    - Mellanox adapter driver .zip and .vib
#
# Interesting weblinks
#    https://vmexplorer.com/2018/06/08/home-lab-gen-iv-part-v-installing-mellanox-hcas-with-esxi-6-5/
#    https://www.virtualizestuff.com/2016/11/03/creating-custom-esxi-image/
#

$ESXiZipFileName="ESXi-6.5.0-20191204001-standard"
$ESXiZipFile="J:/"+$ESXiZipFileName+".zip"
$ImageProfileName="ESXi6.5-Lab"
$DepotFolder="J:\driver-offline-bundle65"
$VendorName="customized by dcasota"
$ISOFile="j:\ESXi65-customized.iso"


if (-not (test-path($ESXiZipFile))) {
	j:\ESXi-Customizer-PS-v2.6.0.ps1 -ozip -v65
	if (-not (test-path($ESXiZipFile))) {break}
}

add-esxsoftwaredepot $ESXiZipFile
new-esximageprofile -CloneProfile $ESXiZipFileName -Name $ImageProfileName -Vendor $VendorName
set-esximageprofile -imageprofile $ImageProfileName -AcceptanceLevel PartnerSupported
# get-esximageprofile -name $ImageProfileName | select-object -expandproperty viblist | sort-object
# Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-mlx4-en
# Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-mlx4-core
# Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-rdma
# Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-en
# Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-core

# Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MEL-mlnx-3.15.5.5-offline_bundle-4038025.zip
# Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-core,nmlx4-en,nmlx4-rdma

# OFED driver
Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MLNX-OFED-ESX-1.8.2.5-10EM-600.0.0.2494585.zip
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-ib-cm,net-ib-core,net-ib-ipoib,net-ib-mad,net-ib-sa,net-ib-umad,net-memtrack,net-mlx4-core,net-mlx4-ib,scsi-ib-srp

# CIM provider
Add-EsxSoftwareDepot -DepotUrl $DepotFolder\VENDOR_CODE-ESX-5.5.0-mcim5_5-1331820-offline_bundle-1989798.zip
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage mlnxprovider

# $vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\net-mst-3.5.1.7-1OEM.550.0.0.1331820.x86_64.vib -ErrorAction SilentlyContinue
# Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib

Export-EsxImageProfile -ImageProfile $ImageProfileName -ExportToIso -NoSignatureCheck -force -FilePath $ISOFile
