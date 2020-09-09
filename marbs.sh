#!/bin/sh

# NOTE: I switched to BIOS boot

#--Functions

error()
{
	clear; printf "ERROR:\\n%s\\n" "$1"; exit
}

TIME()
{ # Set clock
	timedatectl set-ntp true
}

ENCPWD()
{ # Encryption password
	echo -e "\n Enter encryption password:\n"
	read -s ep1
	echo -e "\n Reenter password:\n"
	read -s ep2
	while [[ ${ep1} = "" || ${ep1} != ${ep2} ]]
	do
		echo -e "\n Error. Enter password:\n"
		read -s ep1
		echo -e "\n Reenter password:\n"
		read -s ep2
	done
}

BIGQ()
{ # The big question
	echo -e "\n ====\n Are you SURE you wish to continue?\n ====\n"
	read -s -n 1 -p "(y/N): " choice
	case "$choice" in
	y|Y)
		echo -e "\n" ;;
	*)
		echo "Operation canceled by user." && exit 0 ;;
	esac
}

SEDPAC()
{ # Set my fav options for pacman via sed fin' magic
	_SEDP=':a;N;$!ba;s/#Color\n#TotalDownload/Color\nTotalDownload\nILoveCandy/g'
	sed -i "$_SEDP" /etc/pacman.conf
}

REFKEYS()
{ # Refresh arch keyring
	pacman --noconfirm -Sy archlinux-keyring
}

REFLECTOR()
{ # Use reflector to optimize mirrorlist
	pacman --noconfirm -S reflector
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
	printf "\n Mirrorlist backed up\n\n"
	reflector --verbose --country "United States" --protocol https \
	--latest 10 --sort rate --save /etc/pacman.d/mirrorlist
	printf "\n Mirrorlist updated\n\n"
}

#PARTIT()
#{ # Partitioning
#	parted -s /dev/sda mklabel gpt mkpart primary 1MiB 36MiB set 1 esp on \
#	mkpart primary 36MiB 135MiB mkpart primary 135MiB 100%FREE
#}

PARTIT()
{ # Partitioning
	printf "g\nn\n\n\n+1M\nt\n4\nn\n\n\n+100M\nn\n\n\n\nw\n" | fdisk /dev/sda
}

ENCIT()
{ # Encryption
	echo -n $ep1 | cryptsetup luksFormat --type luks1 /dev/sda2 -
	echo -n $ep1 | cryptsetup luksFormat --type luks1 /dev/sda3 -
	echo -n $ep1 | cryptsetup open /dev/sda2 luks-boot -
	echo -n $ep1 | cryptsetup open /dev/sda3 luks-lvm -
}

VOLIT()
{ # Volumes
	pvcreate /dev/mapper/luks-lvm
	vgcreate vg1 /dev/mapper/luks-lvm
	lvcreate -L 20GB vg1 -n root
	lvcreate -L 4.5GB vg1 -n swap
	lvcreate -l 100%FREE vg1 -n home
}

FMATIT()
{ # Format
#	mkfs.fat -F32 /dev/sda1
	mkfs.ext2 /dev/mapper/luks-boot
	mkfs.ext4 /dev/vg1/root
	mkfs.ext4 /dev/vg1/home
	mkswap /dev/vg1/swap
}

MNTIT()
{ # Mount
	mount /dev/vg1/root /mnt
	mkdir /mnt/boot && mount /dev/mapper/luks-boot /mnt/boot
#	mkdir /mnt/boot/efi && mount /dev/sda1 /mnt/boot/efi
	mkdir /mnt/home && mount /dev/vg1/home /mnt/home
	swapon /dev/vg1/swap
}

PACSTRAP()
{
	pacstrap /mnt base base-devel linux neovim networkmanager grub #efibootmgr
}

GFSTAB()
{ # Generate File System Tab
	genfstab -U /mnt >> /mnt/etc/fstab
}

ENCFILE()
{ # Create keyfile and add it
	dd bs=512 count=8 if=/dev/urandom of=/mnt/kf
	chmod 600 /mnt/kf
	echo -n $ep1 | cryptsetup luksAddKey /dev/sda2 /mnt/kf -
	echo -n $ep1 | cryptsetup luksAddKey /dev/sda3 /mnt/kf -
}

CRYPTTAB()
{ # /etc/crypttab
	echo -e "luks-boot\tUUID=$(blkid -s UUID -o value /dev/sda2)\t/kf" >> \
	/mnt/etc/crypttab
}

SEDCPIO()
{ # Fixin' up mkinitcpio.conf with more sed fin' magic
	sed -i 's/^FILES.*$/FILES=(\/kf)/g' /mnt/etc/mkinitcpio.conf
	sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 resume filesystems fsck)/g' /mnt/etc/mkinitcpio.conf
}

SEDGRUB()
{ # Even more gorram sed fin' magic for /etc/default/grub
	sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/g' /mnt/etc/default/grub
	sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT="" # use `quiet` to hide boot mesages/' /mnt/etc/default/grub
	sed -i "s/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value \/dev\/sda3):luks-lvm cryptkey=rootfs:\/kf root=\/dev\/vg1\/root resume=UUID=$(blkid -s UUID -o value \/dev\/vg1\/swap)\"/" /mnt/etc/default/grub
	sed -i 's/^#GRUB_ENABLE_CRYPTODISK=.*$/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub
	sed -i 's/^GRUB_TIMEOUT_STYLE=.*$/GRUB_TIMEOUT_STYLE=hidden/' /mnt/etc/default/grub
}

DLCHROOT()
{ # Download chroot script
	curl  https://raw.githubusercontent.com/Mar01/MARBS/master/chroot.sh > chroot.sh
	cp chroot.sh /mnt/chroot.sh
	chmod +x /mnt/chroot.sh
}

CHROOT()
{ # Run chroot
	arch-chroot /mnt /chroot.sh
}

RMCHROOT()
{ # Remove chroot script
	rm /mnt/chroot.sh
}

#GETLARBS()
#{ # Download my version of Luke's script
#	curl  https://raw.githubusercontent.com/Mar01/MARBS/master/larbs.sh > /mnt/root/larbs.sh
#	chmod +x /mnt/root/larbs.sh
#}
GETLARBS()
{ # Grab Luke's script
	curl -L larbs.xyz/larbs.sh > /mnt/root/larbs.sh
	chmod +x /mnt/root/larbs.sh
}

#---Script

TIME || error "TIME"

ENCPWD || error "ENCPWD"

BIGQ || error "BIGQ"

SEDPAC || error "SEDPAC"

REFKEYS || error "REFKEYS"

REFLECTOR || error "REFLECTOR"

PARTIT || error "PARTIT"

ENCIT || error "ENCIT"

VOLIT || error "VOLIT"

FMATIT || error "FMATIT"

MNTIT || error "MNTIT"

PACSTRAP || error "PACSTRAP"

GFSTAB || error "GFSTAB"

ENCFILE || error "ENCFILE"

CRYPTTAB || error "CRYPTTAB"

SEDCPIO || error "SEDCPIO"

SEDGRUB || error "SEDGRUB"

DLCHROOT || error "DLCHROOT"

CHROOT || error "CHROOT"
# Continues in chroot.sh

RMCHROOT || error "RMCHROOT"

GETLARBS || error "GETLARBS"
