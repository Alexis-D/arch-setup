#!/usr/bin/env bash

set -eu

[[ -f dev ]] && rm dev
truncate -s 1G dev

LOOP=$(losetup -f)
losetup --partscan "$LOOP" dev

sgdisk -o "$LOOP"
sgdisk -n 1:0:+1M --align-end -c1:"BIOS boot partition" -t1:ef02 "$LOOP"
sgdisk -n 2:0:+128M --align-end -c2:/boot -t2:8300 "$LOOP"
sgdisk --largest-new 3 -c3:/ -t3:8300 "$LOOP"

echo "###########"
sgdisk -p "$LOOP"
echo "###########"

echo -n password | cryptsetup luksFormat "${LOOP}p3"
echo -n password | cryptsetup open "${LOOP}p3" luks
pvcreate /dev/mapper/luks
vgcreate vgonluks /dev/mapper/luks
lvcreate vgonluks -n root -L 100M
lvcreate vgonluks -n data -l 100%FREE

mkfs.ext4 "${LOOP}p2"
mkfs.ext4 /dev/vgonluks/root
mkfs.ext4 /dev/vgonluks/data

echo "###########"
lsblk "$LOOP"
