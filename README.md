# VMware ESXi in a Microsoft Azure virtual machine

![ESXi7ShellOnAzure](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi7ShellonAzure.png)

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

# Findings
  In the ESXi shell we can start to do some checks.
  1. Checked the firmwareType ```vsish -e get /hardware/firmwareType```
  2. Bios information ```vsish -e cat /hardware/bios/biosInfo```
  Here's a sample output.
  
![ESXi7ShellOnAzure-Samples1](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/Esxi7ShellonAzure-Samples1.png)

  3. The newer Mellanox driver nmlx5 4.19.71.1 is listed however there are no available nics.
```
[root@localhost:~] localcli network nic list
Name  PCI Device  Driver  Admin Status  Link Status  Speed  Duplex  MAC Address  MTU  Description
----  ----------  ------  ------------  -----------  -----  ------  -----------  ---  -----------
[root@localhost:~] localcli network sriovnic list
Name  PCI Device  Driver  Link  Speed  Duplex  MAC Address  MTU  Description
----  ----------  ------  ----  -----  ------  -----------  ---  -----------
[root@localhost:~]
```

   The vendor and product id [15b3:0016] which can be identified through Photon OS, on ESXi it is integrated in the nmlx5_core.map, too.
```
cat /etc/vmware/default.map.d/nmlx5_core.map | grep 15b3 | gr
ep 0016
regtype=native,bus=pci,id=15b3101d15b30016......,driver=nmlx5_core
regtype=native,bus=pci,id=15b3101f15b30016......,driver=nmlx5_core
[root@localhost:~]
```
   It remains unclear why the specified nics are not configured and how to configure them.

  4. With ```dmesg | grep WARNING ``` the warnings during boot are listed.
```
0:00:00:00.002 cpu0:1)WARNING: Serial: 366: consolePort initialization failed: Not found
0:00:00:00.002 cpu0:1)WARNING: Serial: 368: debugShellPort initialization failed: Not found
0:00:00:00.010 cpu0:1)WARNING: Net: 116: Maximum active ports supported on the host: 1920
0:00:00:00.011 cpu0:1)WARNING: VMKAcpi: 1659: Platform has no MCFG table
0:00:00:02.094 cpu0:524288)WARNING: Vmkperf: 1570: Could not enable event fixed_unhalted_core_cycles
0:00:00:02.094 cpu1:524289)WARNING: Vmkperf: 1570: Could not enable event fixed_unhalted_core_cycles
0:00:00:02.094 cpu3:524291)WARNING: Vmkperf: 1570: Could not enable event fixed_unhalted_core_cycles
0:00:00:02.094 cpu2:524290)WARNING: Vmkperf: 1570: Could not enable event fixed_unhalted_core_cycles
0:00:00:04.220 cpu0:524288)WARNING: VTD: 733: ACPI DMAR table not found
0:00:00:04.220 cpu0:524288)WARNING: IOV: 250: IOV initialization failed
0:00:00:04.236 cpu0:524288)WARNING: VMKAcpi: 1122: No root bridges found!
0:00:00:04.240 cpu0:524288)WARNING: NTPClock: 1567: Failed to read time from RTC: I/O error
0:00:00:04.240 cpu0:524288)WARNING: NTPClock: 1585: Invalid time from RTC - setting clock to 00:00:00, 01/01/2001
2001-01-01T00:00:00.013Z cpu0:524288)WARNING: Serial: 366: consolePort initialization failed: Not found
2001-01-01T00:00:00.013Z cpu0:524288)WARNING: Serial: 368: debugShellPort initialization failed: Not found
2001-01-01T00:00:00.014Z cpu0:524288)WARNING: VMKAcpi: 290: Could not find ACPI CPU handle for PCPU0; power management will be disabled
2001-01-01T00:00:09.422Z cpu0:524500)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/vobd>
2001-01-01T00:00:09.422Z cpu0:524500)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:10.253Z cpu1:524503)WARNING: etherswitch: PortCfg_ModInit:1077: Skipped initializing etherswitch portcfg for VSS to use cswitch and portcfg module
2001-01-01T00:00:10.319Z cpu0:524503)WARNING: DVFilter: 7425: Maxfilters 7680 not a power of two, replaced with 8192
2001-01-01T00:00:24.496Z cpu2:524593)WARNING: UserMem: 5171: openssl: Unable to create heap mmInfo: Already exists start 0x38ff0ad000 end 0x38ff0ce000
2001-01-01T00:00:24.806Z cpu1:524594)WARNING: UserMem: 5171: openssl: Unable to create heap mmInfo: Already exists start 0xa525cca000 end 0xa525ceb000
2001-01-01T00:00:24.826Z cpu0:524595)WARNING: UserMem: 5171: openssl: Unable to create heap mmInfo: Already exists start 0x4f4237a000 end 0x4f4239b000
2001-01-01T00:00:24.841Z cpu0:524596)WARNING: UserMem: 5171: openssl: Unable to create heap mmInfo: Already exists start 0x604a07c000 end 0x604a09d000
2001-01-01T00:00:25.575Z cpu1:524597)WARNING: UserMem: 5171: openssl: Unable to create heap mmInfo: Already exists start 0x68161ab000 end 0x68161cc000
2001-01-01T00:00:27.588Z cpu2:524619)WARNING: UserTeletype: 1818: nativeExecutor: Unknown cmd 0x4b47 (data 0x3784c668026) for slave
2001-01-01T00:00:28.085Z cpu0:524753)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/kmxa>
2001-01-01T00:00:28.085Z cpu0:524753)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:31.590Z cpu3:525690)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/esxtokend>
2001-01-01T00:00:31.590Z cpu3:525690)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:31.598Z cpu2:525694)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/apiForwarder>
2001-01-01T00:00:31.598Z cpu2:525694)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:31.599Z cpu3:525696)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/apiForwarder>
2001-01-01T00:00:31.599Z cpu3:525696)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:31.629Z cpu1:525706)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/sioc>
2001-01-01T00:00:31.629Z cpu1:525706)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
2001-01-01T00:00:31.873Z cpu0:525761)WARNING: UserParam: 1367: sh: could not get group id for <host/vim/vmvisor/rhttpproxy>
2001-01-01T00:00:31.873Z cpu0:525761)WARNING: LinuxFileDesc: 6535: sh: Unrecoverable exec failure: Failure during exec while original state already lost
```

# Archive
  The repo contains several archived scripts.
  - ```create-AzVM-vESXi_usingAzImage-PhotonOS.ps1```, ```create-AzVM-vESXi_usingLocalFile-PhotonOS.ps1```
  - ```prepare-disk-bios.sh```, ```prepare-disk-efi.sh```
  - ```create-customizedESXi-iso.ps1```
 

Suggestions and issues discussions about the homelab project are welcome.
