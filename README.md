# VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

This lab project contains scripts for provisioning VMware ESXi as Microsoft Azure VM. The repo contains several scripts.
  - create-AzVM-vESXi_usingPhotonOS.ps1
  - prepare-disk.sh  
 
# Why are people running their stuff in a nested virtualization lab? 
VMware ESXi, the cloud provider and onpremise datacenter type-1 hypervisor for many guest OS has been established for more than fifteen years. As a VMware enthusiast simply put I love plan, do and run datacenter infrastructure. On the same side, reliability, scalability, performance for compute resources is a main topic on Microsoft Azure and its Hyper-V type-1 hypervisor, too.

If you want to go for more hypervisor software learning, and without the need to spec, order, rack, stack, cable, image and deploy hardware, nested hypervisor labs could be a useful addition, but, it is not officially supported. See
  - https://kb.vmware.com/s/article/2009916
  - https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  
Automation&Integration engineers often uses nested hypervisor labs to test their kickstart/setup/configuration scripts without the need of tests always allocating own realworld physical hardware. That said, keep in mind the operational economy radius of realworld physical hardware. It doesn't end with nested hypervisors: There is degraded value of running compute resources in a nested virtualization environment only.

Realworld physical hardware is a key point in a 'type-1 hypervisor running in a VM on top of a type-1 hypervisor' scenario. Some nested hypervisor configurations are technically possible. If you run into issues with a nested lab, give up or try to fix it on your own support. 

This study work running an ESXi VM on top of Azure pursues the following goals:
- learn back-to-the-basics in pairs. As example, if you newly learned how to create from an ISO a .vhd data disk, try to find similarities to previous achievements of making a bootable usb medium. 
- pay more attention to interoperability and capabilities history. As example, disk formats like .vhd or .vhdx (conectix/Microsoft), .vmdk or .ova (VMware) or .vdi (Oracle) offer vendor specific benefits. There is no common cloud interchange disk format, but it became easier to export a disk as different formats.
- code Microsoft Azure VM and VMware ESXi setup or kickstart scripts step by step. Be pragmatic with findings from user interface interactions or results.
- document the findings. The mission of this cross-type-1-hypervisor nested lab is pushing the horizon view of my own to both worlds.
   
    
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
 5. create two nics, one with a public IP address
 6. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```$Bashfilename```
    See ```prepare-disk.sh``` for detailed information.
 7. Wait for powerstate stopped. Convert the disks created to managed disks.
    Detach and re-attach the bootable ESXi data disk as os disk. Afterwards, boot the ESXi VM.

 The ESXi kickstart setup and the detach of the .vhdified ISO after ESXi setup, aren't automated yet.
 
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

     4.6. In the context of Azure, enable serial console redirection and add virtualization extension compatibility setting.
          This is an important step to make run serial console for the setup phase of ESXi VM on Azure, as well as
          providing the compatibility setting like iovDisableIR=TRUE, ignoreHeadless=TRUE and noIOMMU to be passed for grub.

     4.7. power down the VM
  
UNFINISHED! WORK IN PROGRESS!
