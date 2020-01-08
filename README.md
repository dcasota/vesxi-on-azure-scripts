# VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

This lab project contains scripts for provisioning VMware ESXi as Microsoft Azure VM.
 
# Why are people running their stuff in a nested virtualization lab? 
VMware ESXi, the cloud provider- and onpremise datacenter type-1-hypervisor for many guest OS has been established for more than fifteen years. As a VMware enthusiast simply put I love plan, do and run datacenter infrastructure. On the same side, reliability, scalability, performance for compute resources is a main topic on Microsoft Azure and its Hyper-V type-1 hypervisor, too.

If you want to go for more hypervisor software learning, and without the need to spec, order, rack, stack, cable, image and deploy hardware, nested hypervisor labs could be a useful addition, but, it is not officially supported. See
  - https://kb.vmware.com/s/article/2009916
  - https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  
Automation&Integration engineers often use nested hypervisor labs to test their kickstart/setup/configuration scripts without the need of tests always allocating own realworld physical hardware. That said, keep in mind the operational economy radius of realworld physical hardware. It doesn't end with nested hypervisors: There is degraded value of running compute resources in a nested virtualization environment only.

Realworld physical hardware is a key point in a 'type-1 hypervisor running in a VM on top of a type-1 hypervisor' scenario. Some nested hypervisor configurations are technically possible. If you run into issues with a nested lab, give up or try to fix it on your own support. 

This study work running an ESXi VM on top of Azure pursues the following goals:
- learn back-to-the-basics in pairs. As example, if you newly learned how to create from an ISO a .vhd data disk, try to find similarities to previous achievements of making a bootable usb medium. 
- pay more attention to interoperability and capabilities history. As example, disk formats like .vhd or .vhdx (conectix/Microsoft), .vmdk or .ova (VMware) or .vdi (Oracle) offer vendor specific benefits. There is no common cloud interchange disk format, but it became easier to export a disk as different formats.
- code Microsoft Azure VM and VMware ESXi setup or kickstart scripts step by step. Be pragmatic with findings from user interface interactions or results.
- document the findings. The mission of this cross-type-1-hypervisor nested lab is pushing the horizon view of my own to both worlds.
   
 The repo contains several scripts.
  - ```create-AzVM-vESXi_usingPhotonOS.ps1```
  - ```prepare-disk.sh```
  - ```create-customizedESXi-iso.ps1```
  
 # ```create-AzVM-vESXi_usingPhotonOS.ps1```
The Azure powershell script creates a VMware ESXi VM on Microsoft Azure. The hardware used is a Standard_DS3_v2 offering.
An ESXi VM offering on Azure must support:
- Accelerated Networking. Without acceleratednetworking, network adapters are not presented to the ESXi VM.
- Premium disk support. The uploaded VMware Photon OS vhd must be stored as page blob on a premium disk to make use of it in a VM.

VMware Photon OS is installed first as some sort of helper-OS for the ESXi boot medium preparation. VMware Photon OS is a tiny IoT cloud os. See https://vmware.github.io/photon/.
The VMware Linux-distro is delivered in several disk formats. The script uses the Azure .vhd. It is important to know that actually (December 2019), .vhd is still the only Azure supported interoperability disk format. See .vhd limitations https://docs.microsoft.com/en-us/azure/virtual-machines/windows/generation-2#features-and-capabilities. Keep that in mind when running some tests.

VMware ESXi usually is delivered as an ISO file. An Azure VM cannot attach an ISO like VMware vSphere. In my studies so far the simplest solution make run ESXi is creating the VM with temporary installed VMware Photon OS. In short: from the VMware Photon OS .vhd, the Azure VM is created using it as osdisk as well as an attached data disk. The data disk is installed with the ISO bits of ESXi. Then, the disks are switched and ESXi boots from the prepared data disk. During ESXi setup, you select the second disk as installation disk, and detach the .vhdified ISO after ESXi setup.

The script processes following steps:
 1. Check prerequisites and Azure login
 2. create a resource group and storage container
 3. upload the Photon OS .vhd as page blob
 4. create virtual network and security group
    (ToDo: As soon as the ESXi installation has finished, more communication ports have to be configured)
 5. create two nics, one with a public IP address
 6. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```$Bashfilename```
    See ```prepare-disk.sh``` for detailed information.
 7. Wait for powerstate stopped. Convert the disks created to managed disks.
    Detach and re-attach the bootable ESXi data disk as os disk. Afterwards, boot the VM into ESXi Setup.
    The ESXi kickstart setup and the detach of the .vhdified ISO after ESXi setup, aren't automated yet.
   
   In the actual development phase, the ESXi setup stops as no network adapter can be found.
   See ```prepare-disk.sh``` 'Network adapter Mellanox ConnectX-3 virtual function'.
    
![NoNetworkAdapter](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/NoNetworkAdapter.png)


 
# ```prepare-disk.sh```
The bash script configures an attached data disk as ESXi bootable medium. It must run on VMware Photon OS. And you have to enter your location of the ESXi ISO medium. See comments inside the script. The script processes following steps:

  1. Configure sshd. Use the LocalAdminUser credentials specified in ```create-AzVM-vESXi_usingPhotonOS.ps1``` for ssh login.

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
On the ESXi setup Shell phase, the Mellanox nic adapter are not listed through 'lspci'. The findings are documented in 'Findings ESXi Shell about Virtual Machine Hardware.txt'.
'DMA IB RoCE iWARP.txt' is a beginner help about RDMA and Infiniband technology to get start reading docs like  http://www.mellanox.com/related-docs/prod_software/Mellanox_Native_ESX_Driver_for_VMware_vSphere_6.5_User_Manual_v3.16.11.10.pdf.

 # ```create-customizedESXi-iso.ps1```
The powershell script creates a customized ESXi ISO with Mellanox adapter driver.
It downloads the ESXi image using the ESXi-Customizer from v-front.de, removes all builtin Mellanox drivers as for ESXi 6.0, 6.5 and 6.7 out-of-the-box it does not work yet for a target Azure hardware offering. The script is configured to process an ESXi 6.5 image, hence, it adds specific offline bundles (see https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=35390&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1004&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc) and cim modules, and creates the iso.


Suggestions and issues discussions about the homelab project are welcome.
