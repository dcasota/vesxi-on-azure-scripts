# VMware ESXi 7.x in a Microsoft Azure virtual machine

![ESXi7ShellOnAzure](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ESXi7ShellonAzure.png)

The lab project target is to make run VMware ESXi 7.x in a Microsoft Azure virtual machine.
It is not yet finished. Use it at your own risk. See [Work-in-Progress](https://github.com/dcasota/vesxi-on-azure-scripts/wiki/Work-in-Progress).

# Getting started  

  1. This lab project uses a MS Windows client with installed Powershell and an Azure account.
  2. Create an Azure GenV2 image of VMware Photon OS.
  3. Run ```create-AzVM-vESXi7.ps1```.

  In the actual development phase, the ESXi setup stops as no network adapter can be found.

  ![NoNetworkAdapterOnESXi7](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/NoNetworkAdapterESXi7.png)

## MS Windows client with installed Powershell  

   This lab uses a laptop with installed
   - MS Powershell, Azure Powershell
   
   To make the lab run on eg. Windows 10, download ```create-AzVM-vESXi7.ps1```.
   
## Azure GenV2 image with VMware Photon OS
   The step-by-step-guide in https://github.com/dcasota/azure-scripts#photon-os-on-azure---scripts explains how to upload Photon OS on Azure and store it as a GenV2 image.
   Download and run https://github.com/dcasota/azure-scripts/blob/master/PhotonOS/create-AzImage-PhotonOS.ps1 to create an Azure GenV2 image. 
   
   As a result, you should get an Azure Photon OS image eg. 4.0 rev2.
   
   ![ph4rev2image](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/ph4rev2image.png)

## ```create-AzVM-vESXi.ps1```
   Run the script ```create-AzVM-vESXi7.ps1```.
   
   You can specify params value ResourceGroupName, VMName, etc. The default virtual machine type offering used is a Standard_F4s_v2 offering with 4 vCPU, 8GB RAM, Premium Disk Support and 32GB temporary storage, and Accelerating Networking with two nics. Without Accelerated Networking, network adapters would not be presented inside the virtual machine.  
   
   What the script does: 
   1) a helper Azure virtual machine with Windows Server is created.
      From the Github repo https://github.com/VFrontDe/ESXi-Customizer-PS of Andreas Peetz, the ESXi Customizer script is downloaded.
      It dynamically creates a customized ESXi iso, and the iso is uploaded as Azure blob. The helper VM is deallocated.  
   2) an Azure virtual machine from a Photon OS image is created. The image must have been created before. The virtual machine gets an additional data disk.
      Inside Photon OS, Ventoy from https://github.com/ventoy/Ventoy is downloaded and installed as bootloader on the data disk.
      The customized ESXi iso is downloaded into the Ventoy partition. Some Ventoy injection and com redirection tecniques are applied. 
   3) The data disk becomes the os disk. The virtual machine boots.
   
   After the script has successfully finished, enter the Azure virtual machine serial console of the newly created vm.
   
 ## First start  
 
   On the screen you see 'secure boot disabled'. Press Enter.
    
   If you have configured 'jump into ESXi Shell', the ESXi Shell prompt appears. Enter username and password. Without any kickstart, enter 'root' as username and press enter.

# Findings
  In the ESXi shell we can start to do some checks.
  1. Checked the firmwareType ```vsish -e get /hardware/firmwareType```
  2. Bios information ```vsish -e cat /hardware/bios/biosInfo```
  Here's a sample output.
  
![ESXi7ShellOnAzure-Samples1](https://github.com/dcasota/vesxi-on-azure-scripts/blob/master/Esxi7ShellonAzure-Samples1.png)

  3. The newer Mellanox driver nmlx5 4.19.71.1 is listed, however no available nics are in the nic list.
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
     There are a bunch of warnings. Missing VMKAcpi MCFG table, IOV initialization failure and missing realtime clock are the first ones.
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
  The repo contains several archived scripts. See https://github.com/dcasota/vesxi-on-azure-scripts/archive

Suggestions and issues discussions about the homelab project are welcome.
