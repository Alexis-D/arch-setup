# Various notes about setting up an arch VM running QEMU w/ [`mkinitcpio-tinyssh`](https://github.com/grazzolini/mkinitcpio-tinyssh) (remote LUKS unlock)

* [`parts.sh`](parts.sh): partitions a disk with a dedicated `/boot` + sets up [LVM](https://en.wikipedia.org/wiki/Logical_Volume_Manager_(Linux))-on-[LUKS](https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup) (with separates root/data LVs). It uses a [loop device](https://en.wikipedia.org/wiki/Loop_device) to make running the script easy/harmless, in practice it would run against something like `/dev/vda` (in [QEMU](https://www.qemu.org/)). Requires root privileges, and the `gdisk` package.

  Goal is to get something like this:

  ```
  [root@arch arch-setup]# sgdisk -p /dev/loop0
  Disk /dev/loop0: 2097152 sectors, 1024.0 MiB
  Sector size (logical/physical): 512/512 bytes
  Disk identifier (GUID): 501D0F88-BB04-406E-9E36-5165FB44094A
  Partition table holds up to 128 entries
  Main partition table begins at sector 2 and ends at sector 33
  First usable sector is 34, last usable sector is 2097118
  Partitions will be aligned on 2048-sector boundaries
  Total free space is 2014 sectors (1007.0 KiB)
  
  Number  Start (sector)    End (sector)  Size       Code  Name
     1            2048            4095   1024.0 KiB  EF02  BIOS boot partition
     2            4096          266239   128.0 MiB   8300  /boot
     3          266240         2097118   894.0 MiB   8300  /
  [root@arch arch-setup]# lsblk /dev/loop0
  NAME                MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
  loop0                 7:0    0    1G  0 loop
  ├─loop0p1           259:1    0    1M  0 part
  ├─loop0p2           259:3    0  128M  0 part
  └─loop0p3           259:4    0  894M  0 part
    └─luks            253:3    0  878M  0 crypt
      ├─lvmonluks-root 253:4    0  100M  0 lvm
      └─lvmonluks-data 253:5    0  776M  0 lvm
  ```
* First create a disk image with `qemu-img create -f qcow2 arch.qcow2 16G` then run a VM like this: `qemu-system-x86_64 -smp 3 -m 2048 -nic user,hostfwd=tcp::2222-:22,model=virtio -drive file=arch.qcow2,media=disk,if=virtio [-cdrom archlinux-2024.07.01-x86_64.iso]`. This will give the VM 3 cores, 2G of RAM, and importantly forward that guest's SSH port (22) on the host's at port 2222. `-cdrom` is only useful when installing arch and can be omitted on subsequent boots.
* The `cryptdevice` kernel params needs to be set to the device on which the luks device is created, so in our example it would be something like `blkid /dev/loop0p3` (since we want the third partition on the loop device), not `blkid /dev/mapper/luks`. Root should be set to something like `/dev/mapper/lvmonluks-root`.
* Make sure to `mount` the devices (`/`, then `/boot`, then `/home`) and call `genfstab -U /,mnt >> /mnt/etc/fstab`)
* When starting the VM, press `e` to tweak grub/kernel params. It's probably a good idea to disable `quiet`.
* If the config is messed up, the rescue shell is useful, from there you can mount devices manually, and then `chroot` into your install. See [Using chroot](https://wiki.archlinux.org/title/Chroot#Using_chroot).
* Partly due to <https://github.com/grazzolini/mkinitcpio-tinyssh/issues/10>, I chose to use different keys for tinyssh and OpenSSH. This can be done by calling <https://github.com/grazzolini/mkinitcpio-tinyssh/blob/bd73e32a1685bb843cdfe1300abcad58faba6e88/tinyssh_install#L11> (make sure to do it in the `/etc` where arch is installed!).
  
  You can accept different keys for reboot/regular SSH by doing something like this in your client's `~/.ssh/config`:

  ```
  Host reboot
      User root
      Hostname 127.0.0.1
      Port 2222
      HostKeyAlias reboot  # and make sure to have the right key in ~/.ssh/known_hosts
  ```

  Then `ssh reboot` when rebooting, or simply `ssh -p 2222 user@127.0.0.1` after that.
* Ensure you setup `~/.ssh/authorized_keys` for your user (and disable root ssh in `/etc/ssh/sshd_config`, `PermitRootLogin no` -this won't affect tinyssh-).
* `pacman -Syu sudo`, `useradd -d /home/alexis -G wheel -m -s $SHELL alexis`, uncomment `%wheel ALL=(ALL:ALL) NOPASSWD: ALL` in `/etc/sudoers`
* Make sure to rerun `mkinitcpio -P` when updating hooks in `/etc/mkinitcpio.conf`, and `grub-mkconfig -o /boot/grub/grub.cfg` after updating `/etc/default/grub`.
* Once setup is working [`rootwait`/`rootdelay` kernel params](https://unix.stackexchange.com/questions/67199/whats-the-point-of-rootwait-rootdelay) might be worth tuning as to not drop into a rescue shell to quickly (and if you want a rescue shell as a one off, then remove them at startup from GRUB!).
* When in doubt, go back to [ArchWiki](https://wiki.archlinux.org/title/Main_page), in particular: [dm-crypt/Specialties](https://title/Dm-crypt/Specialties) and [dm-crypt/Encrypting an entire system, 4. LVM on LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS).
