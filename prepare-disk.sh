#!/bin/sh
#
# Prepare a vhd data disk device as bootable VMware ESXi Hypervisor
# UNFINISHED! WORK IN PROGRESS!
#
# The bash script configures an attached data disk as ESXi bootable medium. It must run on VMware Photon OS. And you have to enter your location of the ESXi ISO medium. See comments inside the script.
# The script processes following steps:
# 1. Configure sshd
# 2. delete partitions on the data disk. Comment: In the context of Azure page blob only the data disk .vhd (conectix) header is needed for creating a bootable disk.
# 3. dynamically create a bash file to be scheduled once as configurebootdisk.service after a reboot
# 4. reboot, afterwards start the configurebootdisk.service created:
#    4.1. download an ESXi ISO. Specify the variable ISOFILENAME. The options tested are download from a vendor URL or download from a Google drive download link.
#         In case of using a vendor URL, uncomment the lines VENDORURL=..., insert the VendorURL, and uncomment the next line curl -O -J -L $VENDORURL.
#         In case of using a Google drive download link, uncomment the lines beginning with GOOGLEDRIVEFILEID=, insert your file id, and uncomment the lines beginning with GOOGLEDRIVEURL and wget --load-cookies.
#    4.2. partition the attached data disk
#    4.3. format the data disk as FAT32. Hence, some packages and mtools-4.0.23.tar.gz used are installed temporarily.
#    4.4. install Syslinux bootlader 3.86 for ESXi on the data disk. syslinux-3.86.tar.xz is installed temporarily.
#    4.5. mount and copy ESXi content to the data disk
#    4.6. In the context of Azure, enabling serial console redirection becomes important. The two files syslinux.cfg and boot.cfg are modified to make run serial console for the setup phase of ESXi VM on Azure.
#         In addition, more compatibility settings to be passed in boot.cfg are necessary as the ESXi setup starts but fails with No Network Adapter.
#         The integration of the detected network adapter Mellanox ConnectX-3 virtual function is unfinished.
#         Mellanox ConnectX-3 [15b3:1004] driver support for VMware ESXi by VMware
#         See https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=io&productid=35390&deviceCategory=io&details=1&partner=55&deviceTypes=6&VID=15b3&DID=1004&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc
#    4.7. power down the VM
# 
#
# History
# 0.1  10.12.2019   dcasota  UNFINISHED! WORK IN PROGRESS!
#
#
# Prerequisites:
#    - runs on VMware Photon OS 3.0
#    - Run as root
#    - attached disk /dev/sdc
#    - network connectivity
#    - specify vendor/google drive URL for ESXi ISO
#
# Known issues:
#

cd /root

# Step #1: configure sshd
# -----------------------
systemctl stop sshd
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

systemctl enable sshd
systemctl restart sshd


# Step #2: delete partitions on the data disk
# -------------------------------------------
# On Azure the data disk resources might be presented as busy. A reboot is necessary to delete partitions successfully.
export DEVICE="/dev/sdc"
export DEVICE1=${DEVICE}1
export DEVICE2=${DEVICE}2
export DEVICE3=${DEVICE}3

if grep $DEVICE3 /etc/mtab > /dev/null 2>&1; then
    umount $DEVICE3
fi
if grep $DEVICE2 /etc/mtab > /dev/null 2>&1; then
    umount $DEVICE2
fi
if grep $DEVICE1 /etc/mtab > /dev/null 2>&1; then
    umount $DEVICE1
fi
# Press [d] to delete existing partitions. d 1 d 2 d
echo -e "d\n1\nd\n2\nd\nw" | fdisk $DEVICE

# Step #3: dynamically create a bash file to be scheduled once as configurebootdisk.service after a reboot
# --------------------------------------------------------------------------------------------------------
BASHFILE="/root/configure-bootdisk.sh"
# create bash file to be processed after a reboot 
cat > $BASHFILE <<'EOF'
#!/bin/sh

# INSERT YOUR ISOFILENAME HERE
ISOFILENAME="ESXi65-customized.iso"

export DEVICE="/dev/sdc"
export DEVICE1="/dev/sdc1"
export DEVICE2="/dev/sdc2"


tdnf install -y tar wget curl sed syslinux

cd /root
# First configure packages to make run Msdos tools for Linux
tdnf install -y dosfstools glibc-iconv autoconf automake binutils diffutils gcc glib-devel glibc-devel linux-api-headers make ncurses-devel util-linux-devel zlib-devel
wget ftp://ftp.gnu.org/gnu/mtools/mtools-4.0.23.tar.gz
tar -xzvf mtools-4.0.23.tar.gz
cd ./mtools-4.0.23
./configure --disable-floppyd
make
make install


# The installed ESXi must use the syslinux bootloader 3.86 to run legacy BIOS firmware. See https://docs.vmware.com/en/VMware-vSphere/6.7/vsphere-esxi-67-upgrade-guide.pdf S.21/S.52
# To boot UEFI for an ESXi setup however, only syslinux 6.x supports UEFI.
cd /root
# curl -O -J -L https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/3.xx/syslinux-3.86.tar.xz
# tar xf syslinux-3.86.tar.xz
# cd ./syslinux-3.86
curl -O -J -L https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/Testing/6.04/syslinux-6.04-pre1.tar.xz
tar xf syslinux-6.04-pre1.tar.xz
export SYSLINUXPATH="/root/syslinux-6.04-pre1"
cd $SYSLINUXPATH
make installer

# Step #4.1: download an ESXi ISO
# -------------------------------
cd /root
# Option #1: ESXi Customizer (UNFINISHED!)
# tdnf install -y powershell
# pwsh -c "install-module VMware.PowerCLI -force"
# TODO VMware.Imagebuilder compatibility
# TODO download and inject Mellanox offline bundle
# wget http://vibsdepot.v-front.de/tools/ESXi-Customizer-PS-v2.6.0.ps1
# mkdir ./driver-offline-bundle
# ./ESXi-Customizer-PS-v2.6.0.ps1 -ozip -v65
# ./ESXi-Customizer-PS-v2.6.0.ps1 -izip ./ESXi-6.5.0-20191203001-standard.zip -v65 -pkgDir ./driver-offline-bundle
# tdnf remove -y powershell

# Option #2: Download from Vendor URL
# VENDORURL=inserthere
# curl -O -J -L $VENDORURL

# Option #3: Download from a Google Drive Download Link
# Example: 
#   raw google drive web url:  https://drive.google.com/open?id=1Ff_Lt6Yh6qPoZZEbiT4rC3eKmGvqPS4l
#   resulting GOOGLEDRIVEFILEID="1Ff_Lt6Yh6qPoZZEbiT4rC3eKmGvqPS4l"
GOOGLEDRIVEFILEID="1j2SbfBIFHbzxli9LLAFhaE6uT5QKgo6j"
GOOGLEDRIVEURL="https://docs.google.com/uc?export=download&id=$GOOGLEDRIVEFILEID"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate $GOOGLEDRIVEURL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$GOOGLEDRIVEFILEID" -O $ISOFILENAME && rm -rf /tmp/cookies.txt


# Step #4.2: partition the data disk attached
# -------------------------------------------
# Press [d] to delete any existing primary partition on data disk.
# echo -e "d\nw" | fdisk $DEVICE
# create partition
# Press [o] to create a new empty DOS partition table.
# Press [n], [p] and press Enter 3 times to accept the default settings. This step creates a primary partition for you.
# echo -e "o\nn\np\n1\n\n\nw" | fdisk $DEVICE
# EFI
# echo -e "n\n1\n\n\nw" | fdisk $DEVICE
# configure an active and bootable FAT32 partition
# Press [t] to toggle the partition file system type.
# Press [c] to set the file system type to FAT32
# Press [a] to make the partition active.
# Press [w] to write the changes to disk.
# echo -e "t\nc\nc\na\nw" | fdisk $DEVICE
# EFI
# echo -e "t\n1\nM\na\nw" | fdisk $DEVICE

# https://gist.github.com/syzdek/ac4bb4ddc9414839474dbea64cdc5897
# clear existing data
sgdisk $DEVICE --zap-all

# create 1st partition
sgdisk $DEVICE --new=1:0:+1M
sgdisk $DEVICE --typecode=1:EF02

# create 2nd parition
sgdisk $DEVICE --new=2:0:0
sgdisk $DEVICE --typecode=2:0700

# make hybrid
sgdisk $DEVICE --hybrid=1:2

# convert to MBR and activate partition 2
sgdisk $DEVICE --zap
sfdisk --activate $DEVICE 2

# add boot code to MBR
dd \
	bs=440 count=1 conv=notrunc \
	if=$SYSLINUXPATH/bios/mbr/gptmbr.bin \
	of=$DEVICE
	
# backup MBR table
rm -f /tmp/mbr.backup
dd bs=512 count=1 conv=notrunc \
if=$DEVICE \
of=/tmp/mbr.backup

# convert back to GPT and adjust partition numbers
sgdisk $DEVICE --mbrtogpt
sgdisk $DEVICE --transpose=1:2
sgdisk $DEVICE --transpose=2:3
# re-adjust partition 2 information for GPT
sgdisk $DEVICE --typecode=2:EF00
sgdisk $DEVICE --change-name=2:"ESXIBOOT"
sgdisk $DEVICE --attributes=2:set:2
# convert GPT to hybrid GPT
sgdisk $DEVICE --hybrid=1:2
# restore MBR with bootable partition 2
dd bs=512 count=1 conv=notrunc \
if=/tmp/mbr.backup \
of=$DEVICE
# refresh partition table in kernel memory
partx $DEVICE


# Step #4.3: format the data disk partition as FAT32
# --------------------------------------------------
# format
/sbin/mkfs.vfat -F 32 -n "ESXIBOOT" $DEVICE2


# Step #4.4: mount and copy ESXi content to the data disk
# -------------------------------------------------------
cd /root
VHDMOUNT=/root/vhdmount
mkdir $VHDMOUNT
mount $DEVICE2 $VHDMOUNT

ESXICD=/root/esxicd
mkdir $ESXICD

# Copy ISO data including Bios syslinux
mount -o loop /root/$ISOFILENAME $ESXICD
cp -R $ESXICD/* $VHDMOUNT


# Step #4.5: Enable serial console redirection, add virtualization extension compatibility setting and add kickstart file
#------------------------------------------------------------------------------------------------------------------------
# On Azure install ESXi via serial port, see weblinks about installing ESXi over serial console
#    http://www.vmwareadmins.com/installing-esxi-serial-console-headless-video-card/ and
#    https://pcengines.ch/ESXi_6.5.0_installation.txt and
#    https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.esxi.install.doc/GUID-B67A3552-CECA-4BF7-9487-4F36507CD99E.html
#    https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.esxi.install.doc/GUID-7651C4A2-C358-40C2-8990-D82BDB8127E0.html

# Add kickstart file
cp /root/ks.cfg $VHDMOUNT/ks.cfg

# Specify serial ports by adding line 'serial 0 115200' and 'serial 1 115200' after 'DEFAULT menu.c32' in syslinux.cfg
#    Serial 0 = /dev/ttyS0 = com1
#    Serial 1 = /dev/ttyS1 = com2
mv $VHDMOUNT/isolinux.cfg $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
sed 's/DEFAULT menu.c32/&\nserial 0 115200/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
sed 's/serial 0 115200/&\nserial 1 115200/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0

#    apply setting A)
#       - Redirect tty2Port=com1 to serial port com1
#       - Redirect tty1Port=com1 to serial port com1
#       - parameters text nofb
#       As result the setup boots into ESXi Shell
sed "s/boot.cfg/boot.cfg text nofb tty1Port=com1 tty2Port=com1 logPort=none gdbPort=none iovDisableIR=TRUE/" $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg

#    apply setting B)
#       - Redirect tty2port to serial port com1
#       As result the setup boots into DCUI
# sed "s/boot.cfg/boot.cfg tty2Port=com1 logPort=none gdbPort=none/" $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg

#    apply setting C)
#       - Redirect tty2Port=com1 to serial port com1
#       - Redirect tty1Port=com1 to serial port com1
#       - ks.cfg
#            https://stackoverflow.com/questions/16790793/how-to-replace-strings-containing-slashes-with-sed
# VALUE="ks=file://ks.cfg"
# LINE=$(echo ${VALUE} | sed -e "s#/#\\\/#g")
# sed "s/boot.cfg/boot.cfg tty1Port=com1 tty2Port=com1 logPort=none gdbPort=none ${LINE}/" $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg

# Findings of boot.cfg kernelopt compatibility setting to install ESXi on more hardware offerings
#    Use 'tty2Port=com1 logPort=none gdbPort=none' to redirect the Direct Console to com1
#       If necessary to enforce serial port settings, use 'com1_baud=115200 com1_Port=0x3f8 tty1Port=com1 com2_baud=115200 com2_Port=0x2f8 tty2Port=com1 logPort=none gdbPort=none'
#    'preferVmklinux=TRUE' is to change the behaviour during boot process, first to load Linux drivers instead of Native drivers.
#       As example, this is the case for driver MEL-mlnx-en-1.9.9.4-1OEM-550.0.0.1331820-offline_bundle-2765235.zip.
#       See zip content \vib20\net-mlx4-core\Mellanox_bootbank_net-mlx4-core_1.9.9.4-1OEM.550.0.0.1331820.vib\descriptor.xml: It contains 'etc/vmware/driver.map.d/mlx4_core.map'.
#       See http://www.justait.net/2014/08/vsphere-native-drivers-22.html, https://www.virtuallyghetto.com/2013/11/esxi-55-introduces-new-native-device.html,
#           https://allvirtualblog.wordpress.com/2016/05/10/getting-ahead-with-esxi-on-headless-system/
#       Be aware, the mklinux driver stack is deprecated https://blogs.vmware.com/vsphere/2019/04/what-is-the-impact-of-the-vmklinux-driver-stack-deprecation.html
#    'ignoreHeadless=TRUE' During system boot up, if ESXi finds No VGA Present or Headless flag set in ACPI FADT table and if there is no user specified change in any of the serial services, 
#       the DCUI service will display on a serial port. See https://communities.vmware.com/thread/600995
#       Related settings: 'ACPI=FALSE powerManagement=FALSE'
#    'runweasel text nofb' to get window in text mode. The Linux framebuffer allows graphics to be displayed on the console without needing to run X-Windows. 
#    'installerDiskDumpSlotSize=2560 no-auto-partition devListStabilityCount=10' is to avoid that bootbank/scratch is not get mounted, see https://kb.vmware.com/s/article/2149444
#    'iovDisableIR=TRUE' disables interrupt remapping as PCI devices may stop responding when using interrupt remapping. See https://kb.vmware.com/s/article/1030265
#       See weblinks http://www.garethjones294.com/running-esxi-6-on-server-2016-hyper-v/ and https://communities.vmware.com/thread/600995
#    'noIOMMU' see https://communities.vmware.com/thread/515358
#
cp $VHDMOUNT/boot.cfg $VHDMOUNT/boot.cfg.0
#    apply setting A)
#       - runweasel text nofb
#       - preferVmklinux=TRUE
#       - iovDisableIR=TRUE
sed "s/kernelopt=runweasel cdromBoot/kernelopt=runweasel text nofb /" $VHDMOUNT/boot.cfg.0 > $VHDMOUNT/boot.cfg

#    apply setting B)
#       - runweasel, add ks.cfg
#            https://stackoverflow.com/questions/16790793/how-to-replace-strings-containing-slashes-with-sed
# VALUE="ks=file:/ks.cfg"
# LINE=$(echo ${VALUE} | sed -e "s#/#\\\/#g")
# sed "s/kernelopt=runweasel cdromBoot/kernelopt=runweasel ${LINE} /" $VHDMOUNT/boot.cfg.0 > $VHDMOUNT/boot.cfg

# setting for EFI
cp $VHDMOUNT/efi/boot/boot.cfg $VHDMOUNT/efi/boot/boot.cfg.0
cp $VHDMOUNT/boot.cfg $VHDMOUNT/efi/boot/boot.cfg


# Step #4.6: install syslinux bootloader
# --------------------------------------

# copy EFI64 syslinux
cp $VHDMOUNT/efi/boot/bootx64.efi $VHDMOUNT/mboot.efi

# copy these syslinux files as they are necessary for boot.cfg
cp /usr/share/syslinux/libcom32.c32 $VHDMOUNT/libcom32.c32
cp /usr/share/syslinux/libutil.c32 $VHDMOUNT/libutil.c32

$SYSLINUXPATH/bios/linux/syslinux $DEVICE2
cat $SYSLINUXPATH/bios/mbr/mbr.bin > $DEVICE

# Step #4.7: power down the VM
#-----------------------------
# Cleanup
cd /root
umount $ESXICD
rm -r $ESXICD
rm ./$ISOFILENAME

cd /root
umount $VHDMOUNT
rm -r $VHDMOUNT

rm -r ./mtools-4.0.23
rm ./mtools-4.0.23.tar.gz
rm -r $SYSLINUXPATH
rm syslinux-6.04-pre1.tar.xz
tdnf remove -y dosfstools glibc-iconv autoconf automake binutils diffutils gcc glib-devel glibc-devel linux-api-headers make ncurses-devel util-linux-devel zlib-devel

systemctl disable configurebootdisk.service
rm /lib/systemd/system/multi-user.target.wants/configurebootdisk.service
unlink /lib/systemd/system/configurebootdisk.service
shutdown --poweroff now
EOF


chmod a+x $BASHFILE
# schedule $BASHFILE to automatically run once after a reboot
# See https://vmware.github.io/photon/assets/files/html/3.0/photon_admin/creating-a-startup-service.html
cat << EOF1 >> /lib/systemd/system/configurebootdisk.service
[Unit]
Description=Configure datadisk as ESXi bootdisk
After=waagent.service
Wants=waagent.service

[Service]
ExecStart=$BASHFILE
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF1
cd /lib/systemd/system/multi-user.target.wants/
ln -s ../configurebootdisk.service configurebootdisk.service


# create kickstart file to be copied to the ESXi data disk
KICKSTARTFILE="/root/ks.cfg"
cat > $KICKSTARTFILE <<'EOF2'
# Kickstart file

# Accept the VMware End User License Agreement
vmaccepteula

# Set the root password for the DCUI and ESXi Shell
rootpw VMware1!

# Clear any partitions on all disks
clearpart --alldrives --overwritevmfs
 
# Install on the first local disk
install --firstdisk=local --overwritevmfs
 
# Reboot the host after the scripted installation is completed
reboot

%pre --interpreter=busybox
   
%post --interpreter=busybox

%firstboot --interpreter=busybox
 
# enable & start remote ESXi Shell (SSH)
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
 
# enable & start ESXi Shell (TSM)
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell

# enable High Performance
esxcli system settings advanced set --option=/Power/CpuPolicy --string-value="High Performance" 
 
# supress ESXi Shell shell warning
esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1

# ESXi Shell interactive idle time logout
esxcli system settings advanced set -o /UserVars/ESXiShellInteractiveTimeOut -i 3600

/sbin/chkconfig ntpd on

# Restart a last time
reboot
EOF2


# Step #4: reboot, afterwards start the configurebootdisk.service created (see Step 4.1)
# --------------------------------------------------------------------------------------
reboot --reboot --force
