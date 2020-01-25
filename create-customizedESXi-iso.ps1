#
# Create a customized ESXi 6.5 ISO with Mellanox adapter driver to work on a target Azure hardware offering 
#
# A VM (accelerated networking enabled) on Azure with Photon OS shows up two Mellanox nics using 'lspci'. The same VM bootet as ESXi does not show any Mellanox nics.
# If the cards can't be seen, they can't get a PCI identifier on ESXi. The target of the script is to create a customized ESXi 6.5 ISO with a working driver configuration for a ESXi VM on Azure.
#
# History
# 0.1  05.01.2020   dcasota  UNFINISHED! WORK IN PROGRESS!
#
# Prerequisites
#    - VMware PowerCLI (with ImageBuilder cmdlets)
#    - ESXi-Customizer https://www.v-front.de/p/esxi-customizer-ps.html
#    - Mellanox adapter driver .zip and .vib
#
# Related weblinks:
#    https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli
#    https://forums.servethehome.com/index.php?threads/connectx-2-esxi-issues.5372/ "If the cards can't be seen by MST, they can't get a PCI identifier."
#    https://vmexplorer.com/2018/06/08/home-lab-gen-iv-part-v-installing-mellanox-hcas-with-esxi-6-5/
#    https://www.virtualizestuff.com/2016/11/03/creating-custom-esxi-image/
#
# drivers (samples)
# [root@localhost:/opt/mellanox/bin] localcli software vib list | grep MEL
# iser                           1.0.0.2-1OEM.650.0.0.4598673          MEL       PartnerSupported  -
# net-ib-core                    2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-ib-ipoib                   2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-ib-mad                     2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-ib-sa                      2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-mlx-compat                 2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-mlx4-core                  2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-mlx4-en                    2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# net-mlx4-ib                    2.4.0.0-1OEM.600.0.0.2494585          MEL       PartnerSupported  -
# nmlx4-core                     3.16.11.10-1OEM.650.0.0.4598673       MEL       VMwareCertified   -
# nmlx4-en                       3.16.11.10-1OEM.650.0.0.4598673       MEL       VMwareCertified   -
# nmlx4-rdma                     3.16.11.10-1OEM.650.0.0.4598673       MEL       VMwareCertified   -
# nmst                           4.13.3.6-1OEM.650.0.0.4598673         MEL       PartnerSupported  -
# [root@localhost:/opt/mellanox/bin]
# 

$ESXiZipFileName="ESXi-6.5.0-20191204001-standard"
$ESXiZipFile="J:/"+$ESXiZipFileName+".zip"
$ImageProfileName="ESXi-v65-Lab"
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


# OFED driver
# Mellanox OFED InfiniBand Driver for VMware® ESXi Server, see https://www.mellanox.com/page/products_dyn?product_family=36&mtag=vmware_drivers

# Reference https://vmexplorer.com/2018/06/08/home-lab-gen-iv-part-v-installing-mellanox-hcas-with-esxi-6-5/
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-mlx4-en
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-mlx4-core
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-rdma
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-en
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-core
Remove-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx5-core
Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MLNX-OFED-ESX-1.8.2.5-10EM-600.0.0.2494585.zip
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-ib-cm,net-ib-core,net-ib-ipoib,net-ib-mad,net-ib-sa,net-ib-umad,net-memtrack,net-mlx4-core,net-mlx4-ib,scsi-ib-srp
# newer OFED driver version
# Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MLNX-OFED-ESX-2.4.0.0-10EM-600.0.0.2494585.zip
# Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage net-ib-core,net-ib-ipoib,net-ib-mad,net-ib-sa,net-mlx-compat,net-mlx4-core,net-mlx4-en,net-mlx4-ib

# MLNX driver
# The following procedure does not work, see See https://support.hpe.com/hpsc/doc/public/display?docId=emr_na-a00026164en_us
# Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MEL-mlnx-3.15.5.5-offline_bundle-4038025.zip
# Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-core,nmlx4-en,nmlx4-rdma
# Unzip the offline bundle, and add all .vib one by one
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\MEL-mlnx-3.15.5.5-offline_bundle-4038025\vib20\nmlx4-core\MEL_bootbank_nmlx4-core_3.15.5.5-1OEM.600.0.0.2768847.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\MEL-mlnx-3.15.5.5-offline_bundle-4038025\vib20\nmlx4-en\MEL_bootbank_nmlx4-en_3.15.5.5-1OEM.600.0.0.2768847.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\MEL-mlnx-3.15.5.5-offline_bundle-4038025\vib20\nmlx4-rdma\MEL_bootbank_nmlx4-rdma_3.15.5.5-1OEM.600.0.0.2768847.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib

# Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MLNX-NATIVE-ESX-ConnectX-3_3.16.11.10-10EM-650.0.0.4598673-offline_bundle-12539849.zip
# Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx4-core,nmlx4-en,nmlx4-rdma

# MLNX sniffer
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\MEL-ESX-nmlx4_sniffer_mgmt-user-1.16.11-7.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib

# ISER driver
Add-EsxSoftwareDepot -DepotUrl $DepotFolder\MLNX-NATIVE-ESX-ISER_1.0.0.2-10EM-650.0.0.4598673.zip
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage iser

# MST and MFT driver
# See https://www.mellanox.com/page/management_tools
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\nmst-4.13.3.6-1OEM.650.0.0.4598673.x86_64.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\mft-4.13.3.6-10EM-650.0.0.4598673.x86_64.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib

# CIM provider
# See https://www.mellanox.com/page/products_dyn?product_family=131&mtag=common_information_model
Add-EsxSoftwareDepot -DepotUrl $DepotFolder\VENDOR_CODE-ESX-5.5.0-mcim5_5-1331820-offline_bundle-1989798.zip
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage mlnxprovider
$vib=Get-EsxSoftwarePackage -PackageUrl $DepotFolder\net-mst-3.5.1.7-1OEM.550.0.0.1331820.x86_64.vib -ErrorAction SilentlyContinue
Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage $vib


Export-EsxImageProfile -ImageProfile $ImageProfileName -ExportToIso -NoSignatureCheck -force -FilePath $ISOFile
