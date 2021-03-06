#!/bin/bash

# Convert kernel/rootfs images generated by build-yocto-qemux86
# into:
# - A VDI_IMAGE suitable to be executed inside QEMU and VirtualBox
# - A VMDK_IMAGE suitable to be executed inside VMware Player

# BIG FAT WARNING
# A few dangerous commands are executed as sudo and may destroy your host filesystem if buggy.
# USE AT YOUR OWN RISK - YOU HAVE BEEN WARNED!!!

# Prerequisites:
#    grub-install
#    kpartx
#    parted
#    qemu-img
#    sudo

# CONFIGURATION ITEMS

TOPDIR=$PWD/tmp/my-genivi-build

IMAGENAME=horizon-image
MACHINE=qemux86
FSTYPE=tar.bz2
KERNEL=$TOPDIR/tmp/deploy/images/$MACHINE/bzImage-$MACHINE.bin
ROOTFS=$TOPDIR/tmp/deploy/images/$MACHINE/${IMAGENAME}-${MACHINE}.${FSTYPE}

RAW_IMAGE=$PWD/test.raw
VDI_IMAGE=$PWD/test.vdi
VMDK_IMAGE=$PWD/test.vmdk

MNT_ROOTFS=/tmp/rootfs

DISK_SIZE_MB=256

set -e
#set -x

#Check if all required commands exist
cmd_exists() {
    while [ -n "$1" ]
    do
	#echo "DBG: Checking for $1"
        command -v $1 >/dev/null 2>&1 || { \
	    echo >&2 "ERROR: command '$1' is required but not installed"; \
	    notOK=1; \
	}
        shift
    done
    if [ -n "$notOK" ]; then
	echo "Aborting."
        exit 1
    fi
}
cmd_exists grub-install kpartx parted qemu-img sudo


# Create QEMU image
# See http://en.wikibooks.org/wiki/QEMU/Images

qemu-img create -f raw ${RAW_IMAGE} ${DISK_SIZE_MB}M


echo "DBG: Use parted to create partition table and partition(s) on RAW_IMAGE"
parted $RAW_IMAGE mklabel msdos
parted $RAW_IMAGE mkpart primary ext3 1 ${DISK_SIZE_MB}
parted $RAW_IMAGE set 1 boot on
parted $RAW_IMAGE print free


LOOP_IMAGE=`sudo losetup -f --show $RAW_IMAGE`
TEMP_MAJ=`ls -l $LOOP_IMAGE | cut -d ' ' -f 5`

MAJOR=${TEMP_MAJ%?} #remove comma from major
MINOR=`ls -l $LOOP_IMAGE | cut -d ' ' -f 6`
SIZE=$((`ls -l $RAW_IMAGE | cut -d ' ' -f 5`/512))

echo "0 $SIZE linear $MAJOR:$MINOR 0" | sudo dmsetup create hda # this creates /dev/mapper/hda


TMPFILE1=/tmp/kpartx-$$.tmp
sudo kpartx -v -a /dev/mapper/hda >$TMPFILE1
echo "DBG: Contents of $TMPFILE1:"
cat $TMPFILE1

BLOCKDEV=`cut -d' ' -f8 $TMPFILE1`
ROOTPART=/dev/mapper/`cut -d' ' -f3 $TMPFILE1`
echo "DBG: BLOCKDEV=$BLOCKDEV"
echo "DBG: ROOTPART=$ROOTPART"

sleep 1 # wait for node creation

sudo mkfs -t ext3 -L "GENIVI" $ROOTPART

mkdir -p $MNT_ROOTFS
sudo mount $ROOTPART $MNT_ROOTFS


# Copy kernel to $MNT_ROOTFS/boot
sudo install -m755 -d $MNT_ROOTFS/boot
sudo install -m644 -o 0 -v $KERNEL $MNT_ROOTFS/boot

echo "DBG: Extracting rootfs to $MNT_ROOTFS"
sudo tar xvfj $ROOTFS -C $MNT_ROOTFS

#echo "DBG: Listing all disks IDs"
#ls -la /dev/disk/by-id/

#echo "DBG: Listing all disks labels"
#ls -la /dev/disk/by-label/


sudo install -m 755 -d $MNT_ROOTFS/boot/grub

REAL_DEVICE=`readlink -f /dev/mapper/hda`
TMPFILE4=device.map
cat >$TMPFILE4 <<__END__
# Begin /boot/grub/device.map
#
(hd0) $REAL_DEVICE
#(hd0,msdos1) $BLOCKDEV
#(hd0,1) $ROOTPART
__END__
sudo install -m644 -o 0 -v $TMPFILE4 $MNT_ROOTFS/boot/grub/device.map

echo "DBG: Installing grub"
sudo grub-install --root-directory=$MNT_ROOTFS $REAL_DEVICE


TMPFILE3=/tmp/grubcfg-$$.tmp
cat > $TMPFILE3 <<__END__
# Begin /boot/grub/grub.cfg
#
set default=0
set timeout=1
#
insmod ext2
#set prefix=(hd0,1)/boot/grub
set root=(hd0,1)
#
menuentry "Yocto-GENIVI, Linux" {
        linux   /boot/bzImage-qemux86.bin root=/dev/hda1
}
#
#menuentry "GNU/Linux, Linux 3.13.6-lfs-SVN-20140404" {
#        linux   /boot/vmlinuz-3.13.6-lfs-SVN-20140404 root=/dev/sda2 ro
#}
__END__
sudo install -m644 -o 0 -v $TMPFILE3 $MNT_ROOTFS/boot/grub/grub.cfg

echo "DBG: Contents of $MNT_ROOTFS:"
ls -la $MNT_ROOTFS

if [ -e $MNT_ROOTFS/boot ]; then
    echo "DBG: Contents of $MNT_ROOTFS/boot:"
    #du -sh $MNT_ROOTFS/boot
    #ls -la $MNT_ROOTFS/boot
    ls -laR $MNT_ROOTFS/boot
fi

if [ -e $MNT_ROOTFS/boot/grub/device.map ]; then
    echo "DBG: Contents of $MNT_ROOTFS/boot/grub/device.map:"
    cat $MNT_ROOTFS/boot/grub/device.map
fi

echo "DBG: Disk space on $MNT_ROOTFS:"
df -h $MNT_ROOTFS

echo "DBG: Cleanup"

sudo umount $MNT_ROOTFS

sudo kpartx -d $BLOCKDEV

sudo dmsetup remove hda

sudo losetup -d $LOOP_IMAGE

rm -f $TMPFILE1
rm -f $TMPFILE2
rm -f $TMPFILE3
rm -f $TMPFILE4

#echo "DBG: Checking $RAW_IMAGE:"
#parted $RAW_IMAGE print free

qemu-img convert -f raw -O vdi $RAW_IMAGE $VDI_IMAGE

cat <<__END__

INFO: To execute the VDI_IMAGE under QEMU:

$ qemu-system-i386 -hda $VDI_IMAGE
__END__

cat <<__END__

INFO: To execute the VDI_IMAGE under VirtualBox:

Launch Oracle VM VirtualBox Manager

VirtualBox: Machine > New...

  Name and operating system
  * Name: <choose a name for your VM>
  * Type: Linux
  * Version: Other Linux (32 bit)
    then select "Next"

  Memory size: 1024 MB
    then select "Next"

  Hard drive
    * Use an existing virtual hard drive file
      file:$VDI_IMAGE
    then select "Create"

VirtualBox: Machine > Start
__END__

qemu-img convert -f raw -O vmdk $RAW_IMAGE $VMDK_IMAGE

cat <<__END__

INFO: To execute the VMDK_IMAGE under VMware Player:

Download VMware Player 6.0 from https://www.vmware.com/

Install VMware Player on your host OS

Player: File > New Virtual Machine...

Welcome to the New Virtual Machine Wizard

  Install from: I will install the operating system later.
  then select "Next >"

Select a Guest Operating System

* Guest operating system: Linux
* Version: Other Linux 3.x kernel

Name the Virtual Macine

* Virtual machine name: <choose a name for your VM>
* Location: <choose directory or accept defaults>

Specify Disk Capacity

* Maximum disk size: 1.0 GB
* Store virtual disk as a single file

Customize Hardware... (none so far)

Select "Finish"

Edit virtual machine settings

* Hard Disk (SCSI) > Remove

Add > Hard Disk

* Virtual disk type: IDE
* Disk: Use an existing virtual disk

Disk file: $VMDK_IMAGE

If the question "Convert existing virtual disk to newer format?" is asked,
select "Keep existing format"

Select "OK"

Start VM
__END__

exit 0;

# EOF
