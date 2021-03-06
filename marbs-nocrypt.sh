#!/bin/sh

# Set clock

timedatectl set-ntp true

# The big question

echo -e "\n ===="
echo -e " Are you SURE you wish to continue?"
echo -e " ====\n"
read -s -n 1 -p "(y/N): " choice
case "$choice" in 
	y|Y ) echo -e "\n";;
	* ) echo "Operation canceled by user." && exit 0;;
esac


# Partitioning

parted -s /dev/sda mklabel gpt mkpart primary 1MiB 36MiB set 1 esp on mkpart primary 36MiB 135MiB mkpart primary 135MiB 100%FREE

# Volumes

pvcreate /dev/sda3
vgcreate vg1 /dev/sda3
lvcreate -L 20GB vg1 -n root
lvcreate -L 4.5GB vg1 -n swap
lvcreate -l 100%FREE vg1 -n home

# Format

mkfs.fat -F32 /dev/sda1
mkfs.ext2 /dev/sda2
mkfs.ext4 /dev/vg1/root
mkfs.ext4 /dev/vg1/home
mkswap /dev/vg1/swap

# Mount

mount /dev/vg1/root /mnt
mkdir /mnt/boot && mount /dev/sda2 /mnt/boot
mkdir /mnt/boot/efi && mount /dev/sda1 /mnt/boot/efi
mkdir /mnt/home && mount /dev/vg1/home /mnt/home
swapon /dev/vg1/swap

# Set my fav options for pacman via sed fin' magic

sed -i ':a;N;$!ba;s/#Color\n#TotalDownload/Color\nTotalDownload\nILoveCandy/g' /etc/pacman.conf

# Pacstrap

pacstrap /mnt base base-devel vim networkmanager grub efibootmgr

# Generate File System Tab

genfstab -U /mnt >> /mnt/etc/fstab

# Fixin' up mkinitcpio.conf with more sed fin' magic

sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard modconf block lvm2 resume filesystems fsck)/g' /mnt/etc/mkinitcpio.conf

# Even more gorram sed fin' magic for /etc/default/grub

sed -i 's/^GRUB_TIMEOUT=/#GRUB_TIMEOUT/g' /mnt/etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=""/' /mnt/etc/default/grub
sed -i "s/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"root=\/dev\/vg1\/root resume=UUID=$(blkid -s UUID -o value \/dev\/vg1\/swap)\"/" /mnt/etc/default/grub
sed -i 's/^#GRUB_HIDDEN_TIMEOUT=.*$/GRUB_HIDDEN_TIMEOUT=1/' /mnt/etc/default/grub
sed -i 's/#GRUB_HIDDEN_TIMEOUT_QUIET=.*$/GRUB_HIDDEN_TIMEOUT_QUIET=true/' /mnt/etc/default/grub

# create chroot script

echo "#!/bin/sh

# Set timezone

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# Run hwclock(8) to generate /etc/adjtime

hwclock --systohc

# Set locale

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo \"LANG=en_US.UTF-8\" > /etc/locale.conf

# Network

echo mar-arch-vm > /etc/hostname
echo -e \"127.0.1.1\\tmar-arch-vm.localdomain\\tmar-arch-vm\" >> /etc/hosts

# Make initial RAM disk

mkinitcpio -p linux

# Activate grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub

  # lvm bork workaround continues
  mkdir /run/lvm
  mount --bind /hostrun/lvm /run/lvm

grub-mkconfig -o /boot/grub/grub.cfg

  # undo bork workaround
  umount /run/lvm
  rm -r /run/lvm

# For VirtualBox

echo \"\\EFI\\grub\\grubx64.efi\" > /boot/efi/startup.nsh

# done

exit 0" > /mnt/chroot.sh && chmod 700 /mnt/chroot.sh

# an update to lvm borked grub-mkconfig: https://bbs.archlinux.org/viewtopic.php?id=242594

mkdir /mnt/hostrun
mount --bind /run /mnt/hostrun

	# Chroot

	arch-chroot /mnt /chroot.sh
	rm /mnt/chroot.sh

	# Continues in chroot.sh

# upon return from chroot.sh, undo lvm bork workaround

umount /mnt/hostrun
rm -r /mnt/hostrun

echo -e "\ndone\n"

