#!/bin/sh
#
# Prepare a vhd data disk device as bootable VMware ESXi Hypervisor
# 
#
# History
# 0.1  10.12.2019   dcasota  UNFINISHED! WORK IN PROGRES!
#
# Prerequisites:
#    - VMware Photon OS 3.0
#    - Run as root
#
#

cd /root

export DEVICE="/dev/sdc"
export DEVICE1="/dev/sdc1"


tdnf install -y tar wget curl sed syslinux

# download VMware ESXi installable
#---------------------------------
# Option #1: ESXi Customizer
# tdnf install -y powershell
# pwsh -c "install-module VMware.PowerCLI -force"
# wget http://vibsdepot.v-front.de/tools/ESXi-Customizer-PS-v2.6.0.ps1
# .\ESXi-Customizer-PS-v2.6.0.ps1 -ozip -v65
# TODO download and inject Mellanox offline bundle
# .\ESXi-Customizer-PS-v2.6.0.ps1 -izip ./ESXi-6.5.0-20191203001-standard.zip -v65 -pkgDir ./driver-offline-bundle
# tdnf remove -y powershell

# Option #2: Download from Vendor URL
# ISOFILENAME="VMware-VMvisor-Installer-6.5.0.update03-14320405.x86_64-DellEMC_Customized-A03.iso"
# curl -O -J -L https://dl.dell.com/FOLDER05925371M/1/$ISOFILENAME

# Option #3: Download from a Google Drive Download Link
ISOFILENAME="ESXi-6.5.0-20191203001-standard-customized.iso"
GOOGLEDRIVEFILEID="1wRj3kdFvKG_2n_YiDkShVn9-_JeJxPWb"
GOOGLEDRIVEURL="https://docs.google.com/uc?export=download&id=$GOOGLEDRIVEFILEID"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate $GOOGLEDRIVEURL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$GOOGLEDRIVEFILEID" -O $ISOFILENAME && rm -rf /tmp/cookies.txt


# disk partitioning
#------------------
# delete partitions
# export DEVICE2="/dev/sdc2"
# export DEVICE3="/dev/sdc3"
# umount $DEVICE1
# umount $DEVICE2
# umount $DEVICE3
# Press [d] to delete existing partitions. d 1 d 2 d
echo -e "d\n1\nd\n2\nd\nw" | fdisk $DEVICE
# create partition
# Press [o] to create a new empty DOS partition table.
# Press [n], [p] and press Enter 3 times to accept the default settings. This step creates a primary partition for you.
echo -e "o\nn\np\n1\n\n\nw" | fdisk $DEVICE
# configure an active and bootable FAT32 partition
# Press [t] to toggle the partition file system type.
# Press [c] to set the file system type to FAT32
# Press [a] to make the partition active.
# Press [w] to write the changes to disk.
echo -e "t\nc\nc\na\nw" | fdisk $DEVICE


# format partition as FAT32
#--------------------------
cd /root
# First configure packages to make run Msdos tools for Linux
tdnf install -y dosfstools glibc-iconv autoconf automake binutils diffutils gcc glib-devel glibc-devel linux-api-headers make ncurses-devel util-linux-devel zlib-devel
wget ftp://ftp.gnu.org/gnu/mtools/mtools-4.0.23.tar.gz
tar -xzvf mtools-4.0.23.tar.gz
cd ./mtools-4.0.23
./configure --disable-floppyd
make
make install
# format
/sbin/mkfs.vfat -F 32 -n ESXI $DEVICE1
# cleanup
cd /root
rm -r ./mtools-4.0.23
rm mtools-4.0.23.tar.gz


# install bootloader
#-------------------
# ESXi uses Syslinux 3.86. See https://pubs.vmware.com/vsphere-50/index.jsp?topic=%2Fcom.vmware.vsphere.upgrade.doc_50%2FGUID-33C3E7D5-20D0-4F84-B2E3-5CD33D32EAA8.html
cd /root
curl -O -J -L https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/3.xx/syslinux-3.86.tar.xz
tar xf syslinux-3.86.tar.xz
cd ./syslinux-3.86
make installer
./linux/syslinux $DEVICE1
cat ./mbr/mbr.bin > $DEVICE
# cleanup
cd /root
rm -r ./syslinux-3.86
rm syslinux-3.86.tar.xz
tdnf remove -y dosfstools glibc-iconv autoconf automake binutils diffutils gcc glib-devel glibc-devel linux-api-headers make ncurses-devel util-linux-devel zlib-devel

# Download ESXi ISO, mount and copy content to disk
#--------------------------------------------------
cd /root
VHDMOUNT=/vhdmount
mkdir $VHDMOUNT
mount $DEVICE1 $VHDMOUNT
ESXICD=/esxicd
mkdir $ESXICD

# Copy ISO data
mount -o loop ./$ISOFILENAME $ESXICD
cp -r $ESXICD/* $VHDMOUNT
# Cleanup
umount $ESXICD
rm -r $ESXICD
rm ./$ISOFILENAME

# Enable serial console redirection
#----------------------------------
#  copy these two files as they are necessary for boot.cfg
cp /usr/share/syslinux/libcom32.c32 $VHDMOUNT/libcom32.c32
cp /usr/share/syslinux/libutil.c32 $VHDMOUNT/libutil.c32
# On Azure install ESXi via serial port.
# See installing ESXi over serial console http://www.vmwareadmins.com/installing-esxi-serial-console-headless-video-card/ and
# https://pcengines.ch/ESXi_6.5.0_installation.txt and
# https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.esxi.install.doc/GUID-B67A3552-CECA-4BF7-9487-4F36507CD99E.html
# Add line "serial 0 115200" after "DEFAULT menu.c32" in syslinux.cfg
mv $VHDMOUNT/isolinux.cfg $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
sed 's/DEFAULT menu.c32/&\nserial 0 115200/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
# replace line "APPEND -c boot.cfg" with "APPEND -c boot.cfg text gdbPort=none logPort=none tty2Port=com1" in syslinux.cfg
sed 's/APPEND -c boot.cfg/APPEND -c boot.cfg text gdbPort=none logPort=none tty2Port=com1/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg
# replace line "kernelopt=cdromBoot runweasel" with "kernelopt=runweasel text nofb com1_baud=115200 com1_Port=0x3f8 tty2Port=com1 gdbPort=none logPort=none cdromBoot" in boot.cfg
cp $VHDMOUNT/boot.cfg $VHDMOUNT/boot.cfg.0
sed 's/kernelopt=cdromBoot runweasel/kernelopt=runweasel text nofb com1_baud=115200 com1_Port=0x3f8 tty2Port=com1 gdbPort=none logPort=none cdromBoot/' $VHDMOUNT/boot.cfg.0 > $VHDMOUNT/boot.cfg
#cleanup
cd /root
umount $VHDMOUNT
rm -r $VHDMOUNT

