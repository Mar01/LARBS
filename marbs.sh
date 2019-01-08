#!/bin/sh
# vim:set tabstop=4

#--BEGIN CORE--#

DLCHROOT() { # download chroot script
_PLACE="https://raw.githubusercontent.com/Mar01/marbs/organize/chroot.sh"
curl -s $_PLACE > ~/chroot.sh &&
[ $? != 0 ] && echo "Can't get chroot file" && exit 1
unset _PLACE ;}

DLLARBS() { # download LARBS script
_PLACE="https://raw.githubusercontent.com/Mar01/marbs/organize/larbs.sh"
curl -s $_PLACE > ~/larbs.sh &&
[ $? != 0 ] && echo "Can't get larbs file" && exit 2
unset _PLACE ;}

ENCPWD() { # Encryption password
echo -e "\n Enter encryption password:\n"
read -s ep1
echo -e "\n Reenter password:\n"
read -s ep2
while [[ ${ep1} = "" || ${ep1} != ${ep2} ]]
do	echo -e "\n Error. Enter password:\n"
	read -s ep1
	echo -e "\n Reenter password:\n"
	read -s ep2 ;done;}

BIGQ() { # The big question
echo -e "\n ====\n Are you SURE you wish to continue?\n ====\n"
read -s -n 1 -p "(y/N): " choice
case "$choice" in
y|Y)	echo -e "\n" ;;
*)	echo "Operation canceled by user." && exit 0 ;;esac;}

PARTIT() { # Partitioning
parted -s /dev/sda mklabel gpt mkpart primary 1MiB 36MiB set 1 esp on \
mkpart primary 36MiB 135MiB mkpart primary 135MiB 100%FREE ;}

ENCIT() { # Encryption
echo -n $ep1 | cryptsetup luksFormat /dev/sda2 -
echo -n $ep1 | cryptsetup luksFormat /dev/sda3 -
echo -n $ep1 | cryptsetup open /dev/sda2 luks-boot -
echo -n $ep1 | cryptsetup open /dev/sda3 luks-lvm - ;}

VOLIT() { # Volumes
pvcreate /dev/mapper/luks-lvm
vgcreate vg1 /dev/mapper/luks-lvm
lvcreate -L 20GB vg1 -n root
lvcreate -L 4.5GB vg1 -n swap
lvcreate -l 100%FREE vg1 -n home ;}

FMATIT() { # Format
mkfs.fat -F32 /dev/sda1
mkfs.ext2 /dev/mapper/luks-boot
mkfs.ext4 /dev/vg1/root
mkfs.ext4 /dev/vg1/home
mkswap /dev/vg1/swap ;}

MNTIT() { # Mount
mount /dev/vg1/root /mnt
mkdir /mnt/boot && mount /dev/mapper/luks-boot /mnt/boot
mkdir /mnt/boot/efi && mount /dev/sda1 /mnt/boot/efi
mkdir /mnt/home && mount /dev/vg1/home /mnt/home
swapon /dev/vg1/swap ;}

SEDPAC() { # Set my fav options for pacman via sed fin' magic
_SEDP=':a;N;$!ba;s/#Color\n#TotalDownload/Color\nTotalDownload\nILoveCandy/g'
sed -i "$_SEDP" /etc/pacman.conf
unset _SEDP ;}

ENCFILE() { # Create keyfile and add it
dd bs=512 count=8 if=/dev/urandom of=/mnt/keyfile
chmod 600 /mnt/keyfile
echo -n $ep1 | cryptsetup luksAddKey /dev/sda2 /mnt/keyfile -
echo -n $ep1 | cryptsetup luksAddKey /dev/sda3 /mnt/keyfile - ;}

CRYPTTAB() { # /etc/crypttab
_BLKID=$(blkid -s UUID -o value /dev/sda2)
echo -e "luks-boot\tUUID=$_BLKID\t/keyfile" >> /mnt/etc/crypttab
unset _BLKID ;}

CPIO() { # Fixin' up mkinitcpio.conf with more sed fin' magic
sed -i 's/^FILES.*$/FILES=(\/keyfile)/g' /mnt/etc/mkinitcpio.conf
sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 resume filesystems fsck)/g' /mnt/etc/mkinitcpio.conf ;}

#---END CORE---#

#---BEGIN RUN---#

DLCHROOT

DLLARBS

# Set clock
timedatectl set-ntp true

ENCPWD

BIGQ

PARTIT

ENCIT

VOLIT

FMATIT

MNTIT

SEDPAC

# Pacstrap
pacstrap /mnt base base-devel vim networkmanager grub efibootmgr

# Generate File System Tab
genfstab -U /mnt >> /mnt/etc/fstab

ENCFILE

CRYPTTAB

CPIO

# Even more gorram sed fin' magic for /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=/#GRUB_TIMEOUT/g' /mnt/etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=""/' /mnt/etc/default/grub
sed -i "s/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value \/dev\/sda3):luks-lvm cryptkey=rootfs:\/keyfile root=\/dev\/vg1\/root resume=UUID=$(blkid -s UUID -o value \/dev\/vg1\/swap)\"/" /mnt/etc/default/grub
sed -i 's/^#GRUB_ENABLE_CRYPTODISK=.*$/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub
sed -i 's/^#GRUB_HIDDEN_TIMEOUT=.*$/GRUB_HIDDEN_TIMEOUT=1/' /mnt/etc/default/grub
sed -i 's/#GRUB_HIDDEN_TIMEOUT_QUIET=.*$/GRUB_HIDDEN_TIMEOUT_QUIET=true/' /mnt/etc/default/grub

# an update to lvm borked grub-mkconfig: https://bbs.archlinux.org/viewtopic.php?id=242594

mkdir /mnt/hostrun
mount --bind /run /mnt/hostrun

	# Chroot
	cp ~/chroot.sh /mnt/chroot.sh
	chmod +x /mnt/chroot.sh
	arch-chroot /mnt /chroot.sh
	# Continues in chroot.sh

# upon return from chroot.sh, clean up and undo lvm bork workaround

rm /mnt/chroot.sh

umount /mnt/hostrun
rm -r /mnt/hostrun

cp ~/larbs.sh /mnt/root/larbs.sh

echo -e "\n Done. LARBS is ready to run after reboot.\n"

