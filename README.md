# VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

VMware ESXi, the datacenter type-1 hypervisor for many guest OS has been established for more than fifteen years.
Thanks to fabrics achievements, customers can provision their compute or storage hardware easily and securely from public cloud providers or onpremise.

Reliability, scalability, performance were achieved for functions as well as for compute resources on Microsoft Azure/Hyper-V, too.
A 'type-1 hypervisor running in a VM on top of a type-1 hypervisor' scenario is not supported. Though, some nested hypervisor configurations are technically possible. Automation&Integration engineers often uses nested hypervisor labs to test their kickstart/setup/configuration scripts without the need of tests always with allocating realworld physical hardware.

Nested ESXi hypervisor lab on VMware workstation or on VMware ESXi are popular and community-driven. If you want to go for more hypervisor software learning, for headless functions, for easily run software labs and without the need to spec, order, rack, stack, cable, image and deploy hardware, nested hypervisor labs are a useful addition. If you run into issues with a nested lab, give up or try to fix it on your own support. See
  - https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  - https://kb.vmware.com/s/article/2009916

This lab project contains scripts for provisioning VMware ESXi as Microsoft Azure VM. The repo contains several scripts.
  - prepare-disk.sh
  - create-AzVM-vESXi_usingPhotonOS.ps1

# ```prepare-disk.sh```
VMware ESXi usually is delivered as an ISO file. An Azure VM cannot attach an ISO like in VMware vSphere. In my studies the simpliest solution so far make run an Azure data disk for ESXi is:
  1. use a guest OS with an attached data disk
  2. download an ESXi ISO
  3. partition the attached data disk
  4. format the data disk as FAT32
  5. install Syslinux bootlader 3.86 for ESXi on the data disk
  6. mount and copy ESXi content to the data disk
  7. enable serial console redirection
  
  ```prepare-disk.sh``` does step 2-7 for you. ```create-AzVM-vESXi_usingPhotonOS.ps1``` provides a solution for the first step.
 
 # ```create-AzVM-vESXi_usingPhotonOS.ps1```
This script creates a VMware Photon OS VM of Azure size DS3v2 which offers accelerated networking and premium disk support.

Photon OS is a tiny IoT cloud os though. The VMware Linux-distro is delivered in Azure .vhd disk format. The disk format .vhd has many limitations however, actually (December 2019), it's still the only Azure supported interoperability disk format. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/generation-2#features-and-capabilities. Keep that in mind when running some tests.

Packages like mfat, syslinux, lspci or powershell makes it more comfortable to prepare an ESXi VM setup on Azure using VMware Photon OS.

The script does:
 1. create a resource group and storage container
 2. upload the Photon OS .vhd as page blob
 3. create virtual network and security group
 4. create two nics, one with a public IP address
 5. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```prepare-disk.sh```
 6. convert the disks created to managed disks, detach and re-attach the bootable ESXi data disk as os disk
Afterwards the VM is started.


NOT FINISHED! WORK IN PROGRESS!
