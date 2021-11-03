# VMware ESXi in a Microsoft Azure virtual machine

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

This lab project contains scripts for provisioning VMware ESXi in a Microsoft Azure virtual machine. It is not yet functioning. Use it at your own risk.
See https://github.com/dcasota/vesxi-on-azure-scripts/wiki/Work-in-Progress

# Automated provisioning of an Azure ESXi VM 

  How to use:
  1. Create an Azure GenV2 image with VMware Photon OS. The creation of the Azure image may be accomplished using https://github.com/dcasota/azure-scripts/blob/master/create-AzImage-PhotonOS.ps1.
  2. Create a customized ESXi 7 ISO image
  3. Upload the ESXi ISO image to a Google drive. In ```prepare-disk-ventoy.sh``` modify the params ISOFILENAME and GOOGLEDRIVEFILEID.
  4. In ```create-AzVM-vESXi7_usingAzImage-PhotonOS.ps1``` change the default params ResourceGroupName, Imagename, etc. and run the script.

  In the actual development phase, the ESXi setup stops as no network adapter can be found.

  ![NoNetworkAdapterOnESXi7](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/NoNetworkAdapterESXi7.png)

## Azure GenV2 image with VMware Photon OS
   Go through the steps in https://github.com/dcasota/azure-scripts#photon-os-on-azure---scripts to create the required Azure GenV2 image.
   
## Create a customized ESXi 7 ISO image
   The ESXi ISO image customization is processed to make use of newer Mellanox adapter driver versions.
   VMware ESXi as Microsoft Azure virtual machine has the same minimal requirements as a baremetal installation.
   The offering used includes ethernet adapters Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] [15b3:1016].

   For the ESXi ISO image customization,
   - download the ESXi-Customizer from github.com/VFrontDe/ESXi-Customizer-PS.
   - run the ESXi Customizer (```C:\ESXi-Customizer-PS-v2.8.1.ps1 -ozip -v70```) to download the standard ESXi image.
   - download the latest Mellanox drivers eg. https://customerconnect.vmware.com/en/downloads/details?downloadGroup=DT-ESXI70-MELLANOX-NMLX5_CORE-419711&productId=974
     and unzip it to a directory eg. c:\driver-offline-bundle70.
    
   Here's a powershell script sample which creates a customized iso. Change the variables as needed.
   ```
   $ESXiZipFileName="ESXi-7.0U3a-18825058-standard"
   $ESXiZipFile="C:/"+$ESXiZipFileName+".zip"
   $ImageProfileName="ESXi-v70-Lab"
   $DepotFolder="C:\driver-offline-bundle70"
   $VendorName="fill in a name"
   $ISOFile="C:\ESXi70-customized.iso"

   add-esxsoftwaredepot $ESXiZipFile
   new-esximageprofile -CloneProfile $ESXiZipFileName -Name $ImageProfileName -Vendor $VendorName
   set-esximageprofile -imageprofile $ImageProfileName -AcceptanceLevel PartnerSupported

   #Newer Mellanox driver
   Add-EsxSoftwareDepot -DepotUrl $DepotFolder\Mellanox-nmlx5_4.19.71.1-1OEM.700.1.0.15525992_17850538-package\Mellanox-nmlx5_4.19.71.1-1OEM.700.1.0.15525992_17850538.zip
   Add-EsxSoftwarePackage -ImageProfile $ImageProfileName -SoftwarePackage nmlx5-core,nmlx5-rdma

   Export-EsxImageProfile -ImageProfile $ImageProfileName -ExportToIso -NoSignatureCheck -force -FilePath $ISOFile
   ```

## ```prepare-disk-ventoy.sh```
   Upload the customized ESXi ISO image to a Google drive as this bash script will download it from there.
   Modify the params ISOFILENAME and GOOGLEDRIVEFILEID.
   
   The implementation uses the open source product Ventoy which includes an easy method to execute iso in an Azure virtual machine as well.
   In the context of Azure, serial console redirection must be explicitly configured. A basic serial console redirection configuration is included in the script.
   
   If you want to jump into the ESXi shell, you can modify the script by extending the ventoy-json creation code snippet.
   The following sample adds a customized isolinux.cfg and boot.cfg of an ESXi 7.0.3 iso.
   ```
cat << EOF3 >> ./isolinux.cfg
DEFAULT menu.c32
serial 0 115200
serial 1 115200
MENU TITLE ESXi-v70-Lab Boot Menu
NOHALT 1
PROMPT 0
TIMEOUT 80
LABEL install
  KERNEL mboot.c32
  APPEND -c boot.cfg
  MENU LABEL ESXi-v70-Lab ^Installer
LABEL hddboot
  LOCALBOOT 0x80
  MENU LABEL ^Boot from local disk
EOF3

cat << EOF2 >> ./boot.cfg
bootstate=0
title=Loading ESXi installer
timeout=5
prefix=
kernel=/b.b00
kernelopt=runweasel cdromBoot tty1Port=com1 tty2Port=com1
modules=/jumpstrt.gz --- /useropts.gz --- /features.gz --- /k.b00 --- /uc_intel.b00 --- /uc_amd.b00 --- /uc_hygon.b00 --- /procfs.b00 --- /vmx.v00 --- /vim.v00 --- /tpm.v00 --- /sb.v00 --- /s.v00 --- /nmlx5cor.v00 --- /nmlx5rdm.v00 --- /atlantic.v00 --- /bnxtnet.v00 --- /bnxtroce.v00 --- /brcmfcoe.v00 --- /elxiscsi.v00 --- /elxnet.v00 --- /i40en.v00 --- /iavmd.v00 --- /icen.v00 --- /igbn.v00 --- /ionic_en.v00 --- /irdman.v00 --- /iser.v00 --- /ixgben.v00 --- /lpfc.v00 --- /lpnic.v00 --- /lsi_mr3.v00 --- /lsi_msgp.v00 --- /lsi_msgp.v01 --- /lsi_msgp.v02 --- /mtip32xx.v00 --- /ne1000.v00 --- /nenic.v00 --- /nfnic.v00 --- /nhpsa.v00 --- /nmlx4_co.v00 --- /nmlx4_en.v00 --- /nmlx4_rd.v00 --- /ntg3.v00 --- /nvme_pci.v00 --- /nvmerdma.v00 --- /nvmetcp.v00 --- /nvmxnet3.v00 --- /nvmxnet3.v01 --- /pvscsi.v00 --- /qcnic.v00 --- /qedentv.v00 --- /qedrntv.v00 --- /qfle3.v00 --- /qfle3f.v00 --- /qfle3i.v00 --- /qflge.v00 --- /rste.v00 --- /sfvmk.v00 --- /smartpqi.v00 --- /vmkata.v00 --- /vmkfcoe.v00 --- /vmkusb.v00 --- /vmw_ahci.v00 --- /bmcal.v00 --- /crx.v00 --- /elx_esx_.v00 --- /btldr.v00 --- /esx_dvfi.v00 --- /esx_ui.v00 --- /esxupdt.v00 --- /tpmesxup.v00 --- /weaselin.v00 --- /esxio_co.v00 --- /loadesx.v00 --- /lsuv2_hp.v00 --- /lsuv2_in.v00 --- /lsuv2_ls.v00 --- /lsuv2_nv.v00 --- /lsuv2_oe.v00 --- /lsuv2_oe.v01 --- /lsuv2_oe.v02 --- /lsuv2_sm.v00 --- /native_m.v00 --- /qlnative.v00 --- /trx.v00 --- /vdfs.v00 --- /vmware_e.v00 --- /vsan.v00 --- /vsanheal.v00 --- /vsanmgmt.v00 --- /tools.t00 --- /xorg.v00 --- /gc.v00 --- /imgdb.tgz --- /imgpayld.tgz
build=7.0.3-0.5.18825058
updated=0
EOF2
  
cat << EOF1 >> ./ventoy.json
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
            "iso": "/ESXi70-customized.iso",
            "org": "/boot.cfg",
            "new": "/ventoy/boot.cfg"
        },
        {
            "iso": "/ESXi70-customized.iso",
            "org": "/isolinux.cfg",
            "new": "/ventoy/isolinux.cfg"
        }
    ],
    "conf_replace_uefi": [
        {
            "iso": "/ESXi70-customized.iso",
            "org": "/EFI/BOOT/boot.cfg",
            "new": "/ventoy/boot.cfg"
        },
        {
            "iso": "/ESXi70-customized.iso",
            "org": "/isolinux.cfg",
            "new": "/ventoy/isolinux.cfg"
        }
    ]	
}
EOF1
```

## ```create-AzVM-vESXi7_usingAzImage-PhotonOS.ps1```
   The virtual machine type used is a Standard_E4s_v3 offering with 4vCPU, 32GB RAM, Accelerating Networking with two nics and Premium Disk Support with 16 GB boot storage.
   Without Accelerated Networking, network adapters are not presented inside the virtual machine.
   The uploaded VMware Photon OS vhd is stored as page blob on a premium disk to make use of it in a virtual machine.
   
   Change the default params ResourceGroupName, Imagename, etc. and run the script.
   
   VMware Photon OS is installed first as sort of helper-OS for the ESXi boot medium preparation. The script processes following steps:
   1. Check prerequisites, remediate if necessary, and Azure login by device login method (twice!)
   2. Check Azure image, create a resource group, storage account, storage container, network security group and virtual network
   3. create network interface, two nics, one with a public IP address
   4. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```$Bashfilename```
    See ```prepare-disk-ventoy.sh``` for detailed information.
   5. The VM is created and boots into the Ventoy menu

# Archive
  The repo contains several archived scripts.
  - ```create-AzVM-vESXi_usingAzImage-PhotonOS.ps1```, ```create-AzVM-vESXi_usingLocalFile-PhotonOS.ps1```
  - ```prepare-disk-bios.sh```, ```prepare-disk-efi.sh```
  - ```create-customizedESXi-iso.ps1```
 

Suggestions and issues discussions about the homelab project are welcome.
