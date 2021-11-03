#!/bin/sh
#

# Runs on Photon 4.0 revision 1

# download required packages. parted and dosfstools are for Ventoy2Disk.sh
tdnf install -y tar wget curl parted dosfstools

# download and install Ventoy
cd /root
curl -O -J -L https://github.com/ventoy/Ventoy/releases/download/v1.0.57/ventoy-1.0.57-linux.tar.gz
tar -xzvf ./ventoy-1.0.57-linux.tar.gz
cd ./ventoy-1.0.57
echo y > ./y
echo y >> ./y

# specify second disk through 16GB detection
export DEVICE=/dev/$(lsblk -l | grep 16G | grep disk | awk '{ print $1 }' | tail -1)

cat ./y | ./Ventoy2Disk.sh -I -s -g $DEVICE
mkdir /root/exfat

# mount partition 1
./tool/x86_64/mount.exfat-fuse ${DEVICE}1 /root/exfat


cd /root/exfat

# download customized ESXi ISO from a Google Drive Download Link
ISOFILENAME="ESXi70-customized.iso"
GOOGLEDRIVEFILEID="1tKKQX6xZMOk710OyQb8RvpN0U6QZG6kS"
GOOGLEDRIVEURL="https://docs.google.com/uc?export=download&id=$GOOGLEDRIVEFILEID"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate $GOOGLEDRIVEURL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$GOOGLEDRIVEFILEID" -O $ISOFILENAME && rm -rf /tmp/cookies.txt

# set compatible mark https://www.ventoy.net/en/doc_compatible_mark.html
echo ventoy > ./ventoy.dat

# set Ventoy parameters for console
mkdir /root/exfat/ventoy
cd /root/exfat/ventoy
cat << EOF1 >> ./ventoy.json
{
    "theme": {
        "display_mode": "serial",
        "serial_param": "--unit=0 --speed=115200 --word=8 --parity=no --stop=1"
    },
    "theme_legacy": {
        "display_mode": "serial",
        "serial_param": "--unit=0 --speed=115200 --word=8 --parity=no --stop=1"
    },
    "theme_uefi": {
        "display_mode": "serial",
        "serial_param": "--unit=0 --speed=115200 --word=8 --parity=no --stop=1"
    }
}
EOF1

# unmount partition 1
cd /root
umount /root/exfat

# clear existing data
sgdisk /dev/sdb --zap-all
# clear existing data
sgdisk /dev/sda --zap-all

reboot
