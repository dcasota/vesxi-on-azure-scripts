# VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

This lab project contains scripts for provisioning VMware ESXi as Microsoft Azure VM. The repo contains several scripts.
  - prepare-disk.sh
  - create-AzVM-vESXi_usingPhotonOS.ps1
  
VMware ESXi, the cloud provider and onpremise datacenter type-1 hypervisor for many guest OS has been established for more than fifteen years. Reliability, scalability, performance for compute resources is a main topic on Microsoft Azure and its Hyper-V type-1 hypervisor, too.
If you want to go for more hypervisor software learning, and without the need to spec, order, rack, stack, cable, image and deploy hardware, nested hypervisor labs could be a useful addition. Some nested hypervisor configurations are technically possible. Automation&Integration engineers often uses nested hypervisor labs to test their kickstart/setup/configuration scripts without the need of tests always with allocating realworld physical hardware. Realworld physical hardware is a key point as a 'type-1 hypervisor running in a VM on top of a type-1 hypervisor' scenario is not officially supported. See
  - https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  - https://kb.vmware.com/s/article/2009916

Keep in mind the operational economy for realworld physical hardware. It doesn't end with nested hypervisors. If you run into issues with a nested lab, give up or try to fix it on your own support. Running an ESXi VM on top of Azure pursues the following goals:
- learn in pairs. As example, if you know how to create from an ISO an .vhd data disk, try to find similarities to previous achievements of making a bootable usb medium. 
- pay more attention to interoperability and capabilities history. Disk formats like .vhd or .vhdx (conectix/Microsoft), .vmdk or .ova (VMware) or .vdi (Oracle) offer vendor specific benefits. There is no common cloud interchange disk format, but it became possible easily to export a disk as different formats.
- code Azure and VMware functions step by step. Be pragmatic with findings from user interface interactions or results.
- document the findings

# ```prepare-disk.sh```
VMware ESXi usually is delivered as an ISO file. An Azure VM cannot attach an ISO like in VMware vSphere. In my studies the simplest solution so far make run an Azure data disk for ESXi is:
  1. use a guest OS with an attached data disk
  2. download an ESXi ISO
  3. partition the attached data disk
  4. format the data disk as FAT32
  5. install Syslinux bootlader 3.86 for ESXi on the data disk
  6. mount and copy ESXi content to the data disk
  7. enable serial console redirection
  
```create-AzVM-vESXi_usingPhotonOS.ps1``` provides a solution for the step 1.
```prepare-disk.sh``` does step 2-7 for you. You have to configure manually the location of the ESXI ISO to be downloaded and the device name of the data disk attached. See the comments in the script.

 
 # ```create-AzVM-vESXi_usingPhotonOS.ps1```
This script creates a VMware Photon OS VM of Azure size DS3v2. DS3v2 offers accelerated networking and premium disk support.

Photon OS is a tiny IoT cloud os and used as some sort of helper os to create and boot ESXi.
The VMware Linux-distro is delivered in Azure .vhd disk format. The disk format .vhd has many limitations however, actually (December 2019), it's still the only Azure supported interoperability disk format. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/generation-2#features-and-capabilities. Keep that in mind when running some tests.

Packages like mfat, syslinux, lspci or powershell make it more comfortable to prepare an ESXi VM setup on Azure using VMware Photon OS.

The script does:
 1. create a resource group and storage container
 2. upload the Photon OS .vhd as page blob
 3. create virtual network and security group
 4. create two nics, one with a public IP address
 5. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```prepare-disk.sh```
 6. convert the disks created to managed disks, detach and re-attach the bootable ESXi data disk as os disk. Afterwards the VM is started.


NOT FINISHED! WORK IN PROGRESS!
