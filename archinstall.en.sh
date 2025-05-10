#!/bin/bash
#
# Arch Linux Installation Script
# - Minimal installation without GUI
# - BTRFS as main filesystem
# - Disk selection from list
# - DHCP network configuration
# - SSH server setup
# - User creation with sudo privileges
# - Base tools installation
# - Automatic time synchronization
# - Works only when booted with UEFI

set -e  # Stop script execution on error
clear

#########################
# Colored output
#########################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

#########################
# System check
#########################
check_requirements() {
    log_section "System Check"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "Script must be run as root"
    fi
    
    # Check if booted in UEFI mode
    if [ -d /sys/firmware/efi/efivars ]; then
        BOOT_MODE="uefi"
        log_info "UEFI boot mode detected"
    else
        BOOT_MODE="bios"
        log_info "BIOS boot mode detected"
    fi
    
    # Check internet connection
    if ping -c 1 archlinux.org >/dev/null 2>&1; then
        log_info "Internet connection: OK"
    else
        log_error "No internet connection. Check your network settings and try again."
    fi
}

#########################
# Configuration collection
#########################
collect_configuration() {
    log_section "Configuration Collection"
    
    # Disk selection
    select_disk
    
    # Timezone setup
    echo -e "\nAvailable timezones:"
    timedatectl list-timezones | grep -E "Europe|Asia" | head -n 10
    echo "..."
    read -p "Enter timezone (e.g., Europe/London): " TIMEZONE
    TIMEZONE=${TIMEZONE:-"Europe/London"}
    
    # Locale setup
    echo -e "\nAvailable locales:"
    cat /etc/locale.gen | grep -E "en_US|en_GB" | sed 's/#//g'
    read -p "Select locale (e.g., en_US.UTF-8): " LOCALE
    LOCALE=${LOCALE:-"en_US.UTF-8"}
    
    # Hostname setup
    read -p "Enter hostname: " HOSTNAME
    HOSTNAME=${HOSTNAME:-"archlinux"}
    
    # User setup
    read -p "Enter username: " USERNAME
    while [[ -z "$USERNAME" ]]; do
        log_warning "Username cannot be empty"
        read -p "Enter username: " USERNAME
    done
    
    # User password setup
    read -s -p "Enter user password: " USER_PASSWORD
    echo
    read -s -p "Confirm user password: " USER_PASSWORD_CONFIRM
    echo
    
    while [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" || -z "$USER_PASSWORD" ]]; do
        log_warning "Passwords do not match or are empty. Try again."
        read -s -p "Enter user password: " USER_PASSWORD
        echo
        read -s -p "Confirm user password: " USER_PASSWORD_CONFIRM
        echo
    done
    
    # Root password setup
    read -s -p "Enter root password: " ROOT_PASSWORD
    echo
    read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo
    
    while [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" || -z "$ROOT_PASSWORD" ]]; do
        log_warning "Passwords do not match or are empty. Try again."
        read -s -p "Enter root password: " ROOT_PASSWORD
        echo
        read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo
    done
    
    # Enable SSH server?
    read -p "Enable SSH server? (y/n): " ENABLE_SSH
    ENABLE_SSH=${ENABLE_SSH:-"y"}
    
    # Additional packages
    read -p "Enter additional packages separated by space (leave empty if none): " ADDITIONAL_PACKAGES
    
    # Configuration confirmation
    log_section "Configuration Confirmation"
    echo -e "Disk: ${YELLOW}$INSTALL_DEVICE${NC} (will be completely formatted!)"
    echo -e "Boot mode: ${YELLOW}$BOOT_MODE${NC}"
    echo -e "Hostname: ${YELLOW}$HOSTNAME${NC}"
    echo -e "Timezone: ${YELLOW}$TIMEZONE${NC}"
    echo -e "Locale: ${YELLOW}$LOCALE${NC}"
    echo -e "Username: ${YELLOW}$USERNAME${NC}"
    echo -e "SSH server: ${YELLOW}$ENABLE_SSH${NC}"
    echo -e "Additional packages: ${YELLOW}$ADDITIONAL_PACKAGES${NC}"
    
    read -p "Continue installation? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        log_error "Installation canceled by user"
    fi
}

#########################
# Disk selection
#########################
select_disk() {
    log_info "Available disks:"
    
    # List disks with size
    lsblk -pno NAME,SIZE,MODEL,TYPE | grep -E "disk"
    
    # Get list of disks for selection
    AVAILABLE_DISKS=($(lsblk -pno NAME | grep -E "^/dev/[vs]d[a-z]|^/dev/nvme[0-9]n[0-9]"))
    
    if [ ${#AVAILABLE_DISKS[@]} -eq 0 ]; then
        log_error "No available disks detected"
    fi
    
    echo -e "\nAvailable disks:"
    for i in "${!AVAILABLE_DISKS[@]}"; do
        echo "[$i] ${AVAILABLE_DISKS[$i]}"
    done
    
    while true; do
        read -p "Select disk for installation (number): " DISK_INDEX
        
        if [[ "$DISK_INDEX" =~ ^[0-9]+$ ]] && [ "$DISK_INDEX" -ge 0 ] && [ "$DISK_INDEX" -lt ${#AVAILABLE_DISKS[@]} ]; then
            INSTALL_DEVICE="${AVAILABLE_DISKS[$DISK_INDEX]}"
            log_info "Selected disk: $INSTALL_DEVICE"
            
            read -p "WARNING: All data on disk $INSTALL_DEVICE will be destroyed! Continue? (y/n): " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                break
            else
                log_warning "Disk selection canceled, please choose another disk"
            fi
        else
            log_warning "Invalid choice, try again"
        fi
    done
}

#########################
# Disk preparation
#########################
prepare_disk() {
    log_section "Disk Preparation"
    
    log_info "Cleaning disk $INSTALL_DEVICE..."
    # Clean partition table
    sgdisk --zap-all "$INSTALL_DEVICE"
    
    # Creating partitions
    if [ "$BOOT_MODE" == "uefi" ]; then
        log_info "Creating partitions for UEFI"
        # Create GPT partition table
        parted -s "$INSTALL_DEVICE" mklabel gpt
        
        # Create EFI partition (512 MB)
        parted -s "$INSTALL_DEVICE" mkpart ESP fat32 1MiB 513MiB
        parted -s "$INSTALL_DEVICE" set 1 boot on
        
        # Create root BTRFS partition (remaining space)
        parted -s "$INSTALL_DEVICE" mkpart primary btrfs 513MiB 100%
        
        # Determine partition names
        if [[ "$INSTALL_DEVICE" =~ "nvme" ]]; then
            BOOT_PARTITION="${INSTALL_DEVICE}p1"
            ROOT_PARTITION="${INSTALL_DEVICE}p2"
        else
            BOOT_PARTITION="${INSTALL_DEVICE}1"
            ROOT_PARTITION="${INSTALL_DEVICE}2"
        fi
    else
        log_info "Creating partitions for BIOS"
        # Create MBR partition table
        parted -s "$INSTALL_DEVICE" mklabel msdos
        
        # Create boot partition (1 MB)
        parted -s "$INSTALL_DEVICE" mkpart primary 1MiB 2MiB
        parted -s "$INSTALL_DEVICE" set 1 bios_grub on
        
        # Create root BTRFS partition (remaining space)
        parted -s "$INSTALL_DEVICE" mkpart primary btrfs 2MiB 100%
        
        # Determine partition names
        if [[ "$INSTALL_DEVICE" =~ "nvme" ]]; then
            ROOT_PARTITION="${INSTALL_DEVICE}p2"
        else
            ROOT_PARTITION="${INSTALL_DEVICE}2"
        fi
    fi
    
    log_info "Formatting partitions..."
    # Format EFI partition
    if [ "$BOOT_MODE" == "uefi" ]; then
        mkfs.fat -F32 "$BOOT_PARTITION"
    fi
    
    # Format and mount root BTRFS partition
    mkfs.btrfs -f "$ROOT_PARTITION"
    
    # Mount root partition
    mount "$ROOT_PARTITION" /mnt
    
    # Create BTRFS subvolumes
    log_info "Creating BTRFS subvolumes..."
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@snapshots
    
    # Unmount and remount with options
    umount /mnt
    
    # Mount subvolumes
    mount -o subvol=@,compress=zstd,noatime "$ROOT_PARTITION" /mnt
    mkdir -p /mnt/{home,var,boot,.snapshots}
    mount -o subvol=@home,compress=zstd,noatime "$ROOT_PARTITION" /mnt/home
    mount -o subvol=@var,compress=zstd,noatime "$ROOT_PARTITION" /mnt/var
    mount -o subvol=@snapshots,compress=zstd,noatime "$ROOT_PARTITION" /mnt/.snapshots
    
    # Mount EFI partition
    if [ "$BOOT_MODE" == "uefi" ]; then
        mkdir -p /mnt/boot/efi
        mount "$BOOT_PARTITION" /mnt/boot/efi
    fi
    
    log_info "Disk preparation completed"
}

#########################
# Base system installation
#########################
install_base_system() {
    log_section "Base System Installation"
    
    # Update mirrors
    log_info "Updating mirror list..."
    reflector --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
    
    # Install base system
    log_info "Installing base packages..."
    pacstrap /mnt base base-devel linux linux-firmware btrfs-progs \
        networkmanager dhcpcd vim nano sudo wget git reflector \
        grub fish bash-completion
    
    # Additional packages for UEFI
    if [ "$BOOT_MODE" == "uefi" ]; then
        pacstrap /mnt efibootmgr
    fi
    
    # Install SSH server if selected
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        pacstrap /mnt openssh
    fi
    
    # Additional packages
    if [ ! -z "$ADDITIONAL_PACKAGES" ]; then
        log_info "Installing additional packages..."
        pacstrap /mnt $ADDITIONAL_PACKAGES
    fi
    
    # Generate fstab
    log_info "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    log_info "Base system installed successfully"
}

#########################
# System configuration
#########################
configure_system() {
    log_section "System Configuration"
    
    # Set timezone
    log_info "Setting timezone ($TIMEZONE)..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Set locale
    log_info "Setting locale ($LOCALE)..."
    arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    
    # Set hostname
    log_info "Setting hostname ($HOSTNAME)..."
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF
    
    # Configure network
    log_info "Configuring network..."
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable dhcpcd
    
    # Configure time synchronization
    log_info "Setting up time synchronization..."
    arch-chroot /mnt systemctl enable systemd-timesyncd
    
    # Configure SSH server if selected
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        log_info "Configuring SSH server..."
        arch-chroot /mnt systemctl enable sshd
        # Allow root login via SSH (insecure but convenient for initial setup)
        arch-chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    fi
    
    # Set root password
    log_info "Setting root password..."
    echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd
    
    # Create user
    log_info "Creating user $USERNAME..."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | arch-chroot /mnt chpasswd
    
    # Configure sudo
    log_info "Configuring sudo..."
    arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    
    # Configure Mirror List
    log_info "Configuring mirror list..."
    cat > /mnt/etc/pacman.d/mirrorlist.hook << EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating mirrorlist with reflector
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c 'reflector --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist'
EOF
    
    log_info "System configuration completed"
}

#########################
# Bootloader installation
#########################
install_bootloader() {
    log_section "Bootloader Installation"
    
    # Install GRUB
    if [ "$BOOT_MODE" == "uefi" ]; then
        log_info "Installing GRUB for UEFI..."
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    else
        log_info "Installing GRUB for BIOS..."
        arch-chroot /mnt grub-install --target=i386-pc "$INSTALL_DEVICE"
    fi
    
    # Configure boot parameters for BTRFS
    log_info "Configuring bootloader parameters..."
    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="rootflags=subvol=@"/' /mnt/etc/default/grub
    
    # Generate GRUB config
    log_info "Generating GRUB configuration..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    log_info "Bootloader installed successfully"
}

#########################
# Finalize installation
#########################
finalize_installation() {
    log_section "Finalizing Installation"
    
    # Unmount all partitions
    log_info "Unmounting partitions..."
    umount -R /mnt
    
    log_info "Arch Linux installation completed successfully!"
    log_info "System is ready to reboot. After reboot:"
    log_info "1. Login with 'root' username and the password you specified"
    log_info "2. Or login with '$USERNAME' and your password"
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        log_info "3. SSH server is enabled, you can connect remotely"
    fi
    
    read -p "Reboot now? (y/n): " REBOOT
    if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
        log_info "Rebooting..."
        reboot
    else
        log_info "Don't forget to reboot manually"
    fi
}

#########################
# Main function
#########################
main() {
    log_section "Starting Arch Linux Installation"
    
    check_requirements
    collect_configuration
    prepare_disk
    install_base_system
    configure_system
    install_bootloader
    finalize_installation
}

# Run main function
main
