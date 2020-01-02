#!/bin/sh
#
# Prepare a vhd data disk device as bootable VMware ESXi Hypervisor
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
#    4.6. In the context of Azure, enable serial console redirection and add virtualization extension compatibility setting.
#         This is an important step to make run serial console for the setup phase of ESXi VM on Azure, as well as providing the compatibility setting like iovDisableIR=TRUE, ignoreHeadless=TRUE and noIOMMU to be passed for grub.
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
export DEVICE1="/dev/sdc1"
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
cd /root

ISOFILENAME="ESXi-6.5.0-20191204001-standard-customized.iso"

export DEVICE="/dev/sdc"
export DEVICE1="/dev/sdc1"


tdnf install -y tar wget curl sed syslinux

# Step #4.1: download an ESXi ISO
# -------------------------------
# Option #1: ESXi Customizer (UNFINISHED!)
# tdnf install -y powershell
# pwsh -c "install-module VMware.PowerCLI -force"
# TODO VMware.Imagebuilder compatibility
# TODO download and inject Mellanox offline bundle
# https://www.mellanox.com/page/products_dyn?product_family=29&mtag=vmware_driver
# For ESXi 6.0 See https://my.vmware.com/group/vmware/details?downloadGroup=DT-ESX60-MELLANOX-NMLX4_EN-31555&productId=491
# wget http://vibsdepot.v-front.de/tools/ESXi-Customizer-PS-v2.6.0.ps1
# mkdir ./driver-offline-bundle
# ./ESXi-Customizer-PS-v2.6.0.ps1 -ozip -v65
# ./ESXi-Customizer-PS-v2.6.0.ps1 -izip ./ESXi-6.5.0-20191203001-standard.zip -v65 -pkgDir ./driver-offline-bundle
# tdnf remove -y powershell

# Option #2: Download from Vendor URL
# VENDORURL=inserthere
# curl -O -J -L $VENDORURL

# Option #3: Download from a Google Drive Download Link
GOOGLEDRIVEFILEID="1Y9PYIXLab9akG_hlLgEUSiDFfPP8UYAG"
GOOGLEDRIVEURL="https://docs.google.com/uc?export=download&id=$GOOGLEDRIVEFILEID"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate $GOOGLEDRIVEURL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$GOOGLEDRIVEFILEID" -O $ISOFILENAME && rm -rf /tmp/cookies.txt


# Step #4.2: partition the data disk attached
# -------------------------------------------
# Press [d] to delete any existing primary partition.
echo -e "d\nw" | fdisk $DEVICE
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


# Step #4.3: format the data disk partition as FAT32
# --------------------------------------------------
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
rm ./mtools-4.0.23.tar.gz


# Step #4.4: install syslinux bootloader
# --------------------------------------
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


# Step #4.5: mount and copy ESXi content to the data disk
# -------------------------------------------------------
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

# Step #4.6: Enable serial console redirection and add virtualization extension compatibility setting
#----------------------------------------------------------------------------------------------------
#  copy these two files as they are necessary for boot.cfg
cp /usr/share/syslinux/libcom32.c32 $VHDMOUNT/libcom32.c32
cp /usr/share/syslinux/libutil.c32 $VHDMOUNT/libutil.c32
# On Azure install ESXi via serial port, see weblinks about installing ESXi over serial console
# http://www.vmwareadmins.com/installing-esxi-serial-console-headless-video-card/ and
# https://pcengines.ch/ESXi_6.5.0_installation.txt and
# https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.esxi.install.doc/GUID-B67A3552-CECA-4BF7-9487-4F36507CD99E.html
# Add line "serial 0 115200" after "DEFAULT menu.c32" in syslinux.cfg
mv $VHDMOUNT/isolinux.cfg $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
sed 's/DEFAULT menu.c32/&\nserial 0 115200/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg
cp $VHDMOUNT/syslinux.cfg $VHDMOUNT/syslinux.cfg.0
# replace line "APPEND -c boot.cfg" with "APPEND -c boot.cfg text gdbPort=none logPort=none tty2Port=com1 iovDisableIR=TRUE ignoreHeadless=TRUE noIOMMU noipmiEnabled ACPI=FALSE powerManagement=FALSE" in syslinux.cfg
sed 's/APPEND -c boot.cfg/APPEND -c boot.cfg text gdbPort=none logPort=none tty2Port=com1 iovDisableIR=TRUE ignoreHeadless=TRUE noIOMMU noipmiEnabled ACPI=FALSE powerManagement=FALSE/' $VHDMOUNT/syslinux.cfg.0 > $VHDMOUNT/syslinux.cfg

# replace line "kernelopt=" with "kernelopt=iovDisableIR=TRUE ignoreHeadless=TRUE noIOMMU noipmiEnabled ACPI=FALSE powerManagement=FALSE text nofb com1_baud=115200 com1_Port=0x3f8 tty2Port=com1 gdbPort=none logPort=none" in boot.cfg
# virtualization extension compatibility setting to install ESXi on more Azure VM offerings successfully:
# 'com1_baud=115200 com1_Port=0x3f8 tty2Port=com1 gdbPort=none logPort=none' see weblinks above about installing ESXi over serial console
# iovDisableIR=TRUE disables interrupt remapping as PCI devices may stop responding when using interrupt remapping. See https://kb.vmware.com/s/article/1030265
# ignoreHeadless=TRUE is for passing correctly the network adapter in a nested virtualization environment.
# See weblinks http://www.garethjones294.com/running-esxi-6-on-server-2016-hyper-v/ and https://communities.vmware.com/thread/600995
# noIOMMU see https://communities.vmware.com/thread/515358
cp $VHDMOUNT/boot.cfg $VHDMOUNT/boot.cfg.0
sed 's/kernelopt=/kernelopt=iovDisableIR=TRUE ignoreHeadless=TRUE noIOMMU noipmiEnabled ACPI=FALSE powerManagement=FALSE text nofb com1_baud=115200 com1_Port=0x3f8 tty2Port=com1 gdbPort=none logPort=none /' $VHDMOUNT/boot.cfg.0 > $VHDMOUNT/boot.cfg
# same setting for EFI
cp $VHDMOUNT/EFI/boot/boot.cfg $VHDMOUNT/EFI/boot/boot.cfg.0
cp $VHDMOUNT/boot.cfg $VHDMOUNT/EFI/boot/boot.cfg
#cleanup
cd /root
umount $VHDMOUNT
rm -r $VHDMOUNT
# Step #4.7: power down the VM
#-----------------------------
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

# Step #4: reboot, afterwards start the configurebootdisk.service created (see Step 4.1)
# --------------------------------------------------------------------------------------
reboot --reboot --force
