# Provision a VMware ESXi VM on Azure

![ESXi67](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi67.png)

VMware ESXi, the datacenter type-1 hypervisor for many guest OS has been established for more than fifteen years.
Thanks to fabrics achievements, customers can provision their compute or storage hardware easily and securely from public cloud providers or onpremise.
Reliability, scalability, performance were also implemented for installations on Microsoft Azure and on Hyper-V.
A 'type-1 hypervisor running in a VM on top of a type-1 hypervisor' scenario is not supported. Though, some nested hypervisor configurations are technically possible. Automation&Integration engineers often uses nested hypervisor labs to test their kickstart/setup/configure scripts without the need of tests always allocating realworld physical hardware.

Nested ESXi hypervisor lab on VMware workstation or on VMware ESXi are popular and community-driven. If you want to go for more deeper hypervisor software learning, for easily run software labs and without the need to spec, order, rack, stack, cable, image and deploy hardware, nested hypervisor labs are a useful addition. If you run into issues with a nested lab, give up or try to fix it on your own support.
See https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
See https://kb.vmware.com/s/article/2009916

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
  ```prepare-disk.sh``` does 2-7 for you. Step 1 is accomplished within the script ```create-AzVM-vESXi_usingPhotonOS.ps1```.
  
  
 # ```create-AzVM-vESXi_usingPhotonOS.ps1```
This script creates a VMware Photon OS VM on Azure using the size Standard_DS3_v2 which offers accelerated networking and premium disk support. VMware Photon OS is a tiny cloud os. The Linux-distro is delivered in Azure .vhd disk format. It makes more comfortable to prepare an ESXi VM setup on Azure using VMware Photon OS. The script does:
 1. Login to Azure
 2. create a resource group and storage container
 3. upload the Photon OS .vhd as page blob
 4. create virtual network and security group
 5. create two nics, one with a public IP address
 6. create the vm with Photon OS as os disk an a data disk processed with cloud-init custom data from ```prepare-disk.sh```
 7. convert the disks created to managed disks, detach and re-attach the bootable ESXi data disk as os disk

Actually (December 2019) the disk format .vhd is still a limitation on Azure for many purposes. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/generation-2#features-and-capabilities. Keep that in mind when running some tests.


NOT FINISHED! WORK IN PROGRESS!
