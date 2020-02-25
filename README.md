# VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

This lab project contains scripts for provisioning VMware ESXi as Microsoft Azure VM in the future.
See https://github.com/dcasota/vesxi-on-azure-scripts/wiki/Work-in-Progress

  
# Automated provisioning of an Azure ESXi VM 
  The repo contains several scripts.
  - ```create-AzVM-vESXi_usingAzImage-PhotonOS.ps1```, ```create-AzVM-vESXi_usingLocalFile-PhotonOS.ps1```
  - ```prepare-disk-bios.sh```, ```prepare-disk-efi.sh```
  - ```create-customizedESXi-iso.ps1```
 
## ```create-AzVM-vESXi_usingAzImage-PhotonOS.ps1```
The Azure powershell script ```create-AzVM-vESXi_usingAzImage-PhotonOS.ps1``` creates a VMware ESXi VM on Microsoft Azure using a specified Image. You can precreate the Azure image using ```create-AzImage-PhotonOS.ps1```.
The script ```create-AzVM-vESXi_usingLocalFile-PhotonOS.ps1``` uses a local .vhd file of VMware Photon OS.

An ESXi VM offering on Azure must support:
- Accelerated Networking. Without acceleratednetworking, network adapters are not presented to the ESXi VM.
- Premium disk support. The uploaded VMware Photon OS vhd must be stored as page blob on a premium disk to make use of it in a VM.

VMware Photon OS is installed first as some sort of helper-OS for the ESXi boot medium preparation. The script processes following steps:
 1. Check prerequisites and Azure login
 2. create a resource group and storage container
 3. upload the Photon OS .vhd as page blob
 4. create virtual network and security group
    (ToDo: As soon as the ESXi installation has finished, more communication ports have to be configured)
 5. create two nics, one with a public IP address
 6. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```$Bashfilename```
    See ```prepare-disk-bios.sh``` for detailed information.
 7. Wait for powerstate stopped. Convert the disks created to managed disks.
    Detach and re-attach the bootable ESXi data disk as os disk. Afterwards, boot the VM into ESXi Setup.
    The ESXi kickstart setup and the detach of the .vhdified ISO after ESXi setup, aren't automated yet.
   
   In the actual development phase, the ESXi setup stops as no network adapter can be found.
   See ```prepare-disk-bios.sh``` 'Network adapter Mellanox ConnectX-3 virtual function'.
    
![NoNetworkAdapter](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/NoNetworkAdapter.png)

Hint: The helper script ```set-AzVMboot-PhotonOS.ps1```switches os disk from ESXi to Photon OS (and ```set-AzVMboot-ESXi.ps1``` does vice versa).
 
## ```prepare-disk-bios.sh```,```prepare-disk-efi.sh```
The bash script configures an attached data disk as ESXi bootable medium. It must run on VMware Photon OS. And you have to enter your location of the ESXi ISO medium. See comments inside the script. The script processes following steps:

  1. Configure sshd. Use the LocalAdminUser credentials specified for ssh login.

  2. delete partitions on the data disk.
     Comment: In the context of Azure page blob only the data disk .vhd (conectix) header is needed for creating a bootable disk.

  3. dynamically create a bash file to be scheduled once as configurebootdisk.service after a reboot

  4. reboot, afterwards start the configurebootdisk.service created:

     4.1. download an ESXi ISO. Specify the variable ISOFILENAME.
          The options tested are download from a vendor URL or download from a Google drive download link.
          In case of using a vendor URL, uncomment the lines
          ```VENDORURL=...```, insert the VendorURL, and uncomment the next line ```curl -O -J -L $VENDORURL```.
          In case of using a Google drive download link, uncomment the lines beginning with ```GOOGLEDRIVEFILEID=```,
          insert your file id, and uncomment the lines beginning with ```GOOGLEDRIVEURL``` and ```wget --load-cookies```.

     4.2. partition the attached data disk

     4.3. format the data disk as FAT32. Hence, some packages and mtools-4.0.23.tar.gz used are installed temporarily.

     4.4. install Syslinux bootlader 3.86 for ESXi on the data disk. syslinux-3.86.tar.xz is installed temporarily.
 
     4.5. mount and copy ESXi content to the data disk

     4.6. In the context of Azure, enabling serial console redirection becomes important.
          The two files syslinux.cfg and boot.cfg are modified to make run serial console for the setup phase of ESXi VM on Azure.
          In addition, more compatibility settings to be passed in boot.cfg are necessary as the ESXi setup starts but fails with
          No Network Adapter. The integration of the detected network adapter Mellanox ConnectX-3 virtual function is unfinished
          (see below UNFINISHED! WORK IN PROGRESS!).

     4.7. power down the VM
  

Network adapter Mellanox ConnectX-3 virtual function (UNFINISHED! WORK IN PROGRESS!)
06.01.2020
The ESXi setup starts but fails with No Network Adapter found. Some efforts are documented at
- https://communities.vmware.com/thread/623892
- https://communities.vmware.com/thread/623049
- https://github.com/MicrosoftDocs/azure-docs/issues/45303
 

## ```create-customizedESXi-iso.ps1```
The powershell script creates a customized ESXi ISO with Mellanox adapter driver.
It downloads the ESXi image using the ESXi-Customizer from www.v-front.de, removes all builtin Mellanox drivers as for ESXi 6.0, 6.5 and 6.7 out-of-the-box it does not work yet for a target Azure hardware offering. The script is configured to process an ESXi 6.5 image, hence, it adds specific offline bundles (see https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=35390&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1004&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc) and cim modules, and creates the iso.


Suggestions and issues discussions about the homelab project are welcome.
