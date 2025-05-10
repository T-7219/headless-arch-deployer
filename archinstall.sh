#!/bin/bash
#
# Скрипт установки Arch Linux
# - Минимальная установка без графики
# - BTRFS как основная файловая система
# - Выбор диска из списка
# - Настройка сети по DHCP
# - Настройка SSH сервера
# - Создание пользователя с sudo
# - Установка базовых инструментов
# - Автоматическая синхронизация времени
# - Работает только при загрузке с UEFI

set -e  # Прекратить выполнение скрипта при ошибке
clear

#########################
# Цветной вывод
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
# Проверка системы
#########################
check_requirements() {
    log_section "Проверка системы"
    
    # Проверка запуска от root
    if [ "$EUID" -ne 0 ]; then
        log_error "Скрипт должен быть запущен с правами root"
    fi
    
    # Проверка загрузки в режиме UEFI
    if [ -d /sys/firmware/efi/efivars ]; then
        BOOT_MODE="uefi"
        log_info "Обнаружена загрузка в режиме UEFI"
    else
        BOOT_MODE="bios"
        log_info "Обнаружена загрузка в режиме BIOS"
    fi
    
    # Проверка подключения к интернету
    if ping -c 1 archlinux.org >/dev/null 2>&1; then
        log_info "Подключение к интернету: ОК"
    else
        log_error "Нет подключения к интернету. Проверьте настройки сети и попробуйте снова."
    fi
}

#########################
# Сбор конфигурации
#########################
collect_configuration() {
    log_section "Сбор конфигурации"
    
    # Выбор диска
    select_disk
    
    # Настройка времени
    echo -e "\nДоступные временные зоны:"
    timedatectl list-timezones | grep -E "Europe|Asia" | head -n 10
    echo "..."
    read -p "Введите временную зону (например, Europe/Moscow): " TIMEZONE
    TIMEZONE=${TIMEZONE:-"Europe/Moscow"}
    
    # Настройка локали
    echo -e "\nДоступные локали:"
    cat /etc/locale.gen | grep -E "en_US|ru_RU" | sed 's/#//g'
    read -p "Выберите локаль (например, ru_RU.UTF-8): " LOCALE
    LOCALE=${LOCALE:-"ru_RU.UTF-8"}
    
    # Настройка имени хоста
    read -p "Введите имя хоста: " HOSTNAME
    HOSTNAME=${HOSTNAME:-"archlinux"}
    
    # Настройка пользователя
    read -p "Введите имя пользователя: " USERNAME
    while [[ -z "$USERNAME" ]]; do
        log_warning "Имя пользователя не может быть пустым"
        read -p "Введите имя пользователя: " USERNAME
    done
    
    # Настройка пароля пользователя
    read -s -p "Введите пароль пользователя: " USER_PASSWORD
    echo
    read -s -p "Повторите пароль пользователя: " USER_PASSWORD_CONFIRM
    echo
    
    while [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" || -z "$USER_PASSWORD" ]]; do
        log_warning "Пароли не совпадают или пустые. Попробуйте снова."
        read -s -p "Введите пароль пользователя: " USER_PASSWORD
        echo
        read -s -p "Повторите пароль пользователя: " USER_PASSWORD_CONFIRM
        echo
    done
    
    # Настройка пароля root
    read -s -p "Введите пароль для root: " ROOT_PASSWORD
    echo
    read -s -p "Повторите пароль для root: " ROOT_PASSWORD_CONFIRM
    echo
    
    while [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" || -z "$ROOT_PASSWORD" ]]; do
        log_warning "Пароли не совпадают или пустые. Попробуйте снова."
        read -s -p "Введите пароль для root: " ROOT_PASSWORD
        echo
        read -s -p "Повторите пароль для root: " ROOT_PASSWORD_CONFIRM
        echo
    done
    
    # Включить SSH-сервер?
    read -p "Включить SSH-сервер? (y/n): " ENABLE_SSH
    ENABLE_SSH=${ENABLE_SSH:-"y"}
    
    # Дополнительные пакеты
    read -p "Введите дополнительные пакеты через пробел (оставьте пустым, если не нужно): " ADDITIONAL_PACKAGES
    
    # Подтверждение
    log_section "Подтверждение конфигурации"
    echo -e "Диск: ${YELLOW}$INSTALL_DEVICE${NC} (будет полностью отформатирован!)"
    echo -e "Режим загрузки: ${YELLOW}$BOOT_MODE${NC}"
    echo -e "Имя хоста: ${YELLOW}$HOSTNAME${NC}"
    echo -e "Временная зона: ${YELLOW}$TIMEZONE${NC}"
    echo -e "Локаль: ${YELLOW}$LOCALE${NC}"
    echo -e "Имя пользователя: ${YELLOW}$USERNAME${NC}"
    echo -e "SSH-сервер: ${YELLOW}$ENABLE_SSH${NC}"
    echo -e "Дополнительные пакеты: ${YELLOW}$ADDITIONAL_PACKAGES${NC}"
    
    read -p "Продолжить установку? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        log_error "Установка отменена пользователем"
    fi
}

#########################
# Выбор диска
#########################
select_disk() {
    log_info "Доступные диски:"
    
    # Вывод списка дисков с размером
    lsblk -pno NAME,SIZE,MODEL,TYPE | grep -E "disk"
    
    # Получение списка дисков для выбора
    AVAILABLE_DISKS=($(lsblk -pno NAME | grep -E "^/dev/[vs]d[a-z]|^/dev/nvme[0-9]n[0-9]"))
    
    if [ ${#AVAILABLE_DISKS[@]} -eq 0 ]; then
        log_error "Не обнаружено доступных дисков"
    fi
    
    echo -e "\nДоступные диски:"
    for i in "${!AVAILABLE_DISKS[@]}"; do
        echo "[$i] ${AVAILABLE_DISKS[$i]}"
    done
    
    while true; do
        read -p "Выберите диск для установки (номер): " DISK_INDEX
        
        if [[ "$DISK_INDEX" =~ ^[0-9]+$ ]] && [ "$DISK_INDEX" -ge 0 ] && [ "$DISK_INDEX" -lt ${#AVAILABLE_DISKS[@]} ]; then
            INSTALL_DEVICE="${AVAILABLE_DISKS[$DISK_INDEX]}"
            log_info "Выбран диск: $INSTALL_DEVICE"
            
            read -p "ВНИМАНИЕ: Все данные на диске $INSTALL_DEVICE будут уничтожены! Продолжить? (y/n): " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                break
            else
                log_warning "Выбор диска отменен, выберите другой диск"
            fi
        else
            log_warning "Неверный выбор, попробуйте снова"
        fi
    done
}

#########################
# Подготовка диска
#########################
prepare_disk() {
    log_section "Подготовка диска"
    
    log_info "Очистка диска $INSTALL_DEVICE..."
    # Очистка таблицы разделов
    sgdisk --zap-all "$INSTALL_DEVICE"
    
    # Создание разделов
    if [ "$BOOT_MODE" == "uefi" ]; then
        log_info "Создание разделов для UEFI"
        # Создание GPT таблицы разделов
        parted -s "$INSTALL_DEVICE" mklabel gpt
        
        # Создание EFI раздела (512 МБ)
        parted -s "$INSTALL_DEVICE" mkpart ESP fat32 1MiB 513MiB
        parted -s "$INSTALL_DEVICE" set 1 boot on
        
        # Создание корневого раздела BTRFS (оставшееся пространство)
        parted -s "$INSTALL_DEVICE" mkpart primary btrfs 513MiB 100%
        
        # Определение имен разделов
        if [[ "$INSTALL_DEVICE" =~ "nvme" ]]; then
            BOOT_PARTITION="${INSTALL_DEVICE}p1"
            ROOT_PARTITION="${INSTALL_DEVICE}p2"
        else
            BOOT_PARTITION="${INSTALL_DEVICE}1"
            ROOT_PARTITION="${INSTALL_DEVICE}2"
        fi
    else
        log_info "Создание разделов для BIOS"
        # Создание MBR таблицы разделов
        parted -s "$INSTALL_DEVICE" mklabel msdos
        
        # Создание загрузочного раздела (1 МБ)
        parted -s "$INSTALL_DEVICE" mkpart primary 1MiB 2MiB
        parted -s "$INSTALL_DEVICE" set 1 bios_grub on
        
        # Создание корневого раздела BTRFS (оставшееся пространство)
        parted -s "$INSTALL_DEVICE" mkpart primary btrfs 2MiB 100%
        
        # Определение имен разделов
        if [[ "$INSTALL_DEVICE" =~ "nvme" ]]; then
            ROOT_PARTITION="${INSTALL_DEVICE}p2"
        else
            ROOT_PARTITION="${INSTALL_DEVICE}2"
        fi
    fi
    
    log_info "Форматирование разделов..."
    # Форматирование EFI раздела
    if [ "$BOOT_MODE" == "uefi" ]; then
        mkfs.fat -F32 "$BOOT_PARTITION"
    fi
    
    # Форматирование и монтирование корневого раздела BTRFS
    mkfs.btrfs -f "$ROOT_PARTITION"
    
    # Монтирование корневого раздела
    mount "$ROOT_PARTITION" /mnt
    
    # Создание подтомов BTRFS
    log_info "Создание подтомов BTRFS..."
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@snapshots
    
    # Отмонтирование и повторное монтирование с опциями
    umount /mnt
    
    # Монтирование подтомов
    mount -o subvol=@,compress=zstd,noatime "$ROOT_PARTITION" /mnt
    mkdir -p /mnt/{home,var,boot,.snapshots}
    mount -o subvol=@home,compress=zstd,noatime "$ROOT_PARTITION" /mnt/home
    mount -o subvol=@var,compress=zstd,noatime "$ROOT_PARTITION" /mnt/var
    mount -o subvol=@snapshots,compress=zstd,noatime "$ROOT_PARTITION" /mnt/.snapshots
    
    # Монтирование EFI раздела
    if [ "$BOOT_MODE" == "uefi" ]; then
        mkdir -p /mnt/boot/efi
        mount "$BOOT_PARTITION" /mnt/boot/efi
    fi
    
    log_info "Подготовка диска завершена"
}

#########################
# Установка базовой системы
#########################
install_base_system() {
    log_section "Установка базовой системы"
    
    # Обновление зеркал
    log_info "Обновление списка зеркал..."
    reflector --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
    
    # Установка базовой системы
    log_info "Установка базовых пакетов..."
    pacstrap /mnt base base-devel linux linux-firmware btrfs-progs \
        networkmanager dhcpcd vim nano sudo wget git reflector \
        grub fish bash-completion
    
    # Дополнительные пакеты для UEFI
    if [ "$BOOT_MODE" == "uefi" ]; then
        pacstrap /mnt efibootmgr
    fi
    
    # Установка SSH-сервера, если выбрано
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        pacstrap /mnt openssh
    fi
    
    # Дополнительные пакеты
    if [ ! -z "$ADDITIONAL_PACKAGES" ]; then
        log_info "Установка дополнительных пакетов..."
        pacstrap /mnt $ADDITIONAL_PACKAGES
    fi
    
    # Генерация fstab
    log_info "Генерация fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    log_info "Базовая система установлена успешно"
}

#########################
# Настройка системы
#########################
configure_system() {
    log_section "Настройка системы"
    
    # Установка часового пояса
    log_info "Настройка часового пояса ($TIMEZONE)..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Настройка локали
    log_info "Настройка локали ($LOCALE)..."
    arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    
    # Настройка имени хоста
    log_info "Настройка имени хоста ($HOSTNAME)..."
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF
    
    # Настройка сети
    log_info "Настройка сети..."
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable dhcpcd
    
    # Синхронизация времени
    log_info "Настройка синхронизации времени..."
    arch-chroot /mnt systemctl enable systemd-timesyncd
    
    # Настройка SSH-сервера, если выбрано
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        log_info "Настройка SSH-сервера..."
        arch-chroot /mnt systemctl enable sshd
        # Разрешаем подключение root по SSH (небезопасно, но удобно для начальной настройки)
        arch-chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    fi
    
    # Настройка пароля root
    log_info "Настройка пароля root..."
    echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd
    
    # Создание пользователя
    log_info "Создание пользователя $USERNAME..."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | arch-chroot /mnt chpasswd
    
    # Настройка sudo
    log_info "Настройка sudo..."
    arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    
    # Настройка Mirror List
    log_info "Настройка списка зеркал..."
    cat > /mnt/etc/pacman.d/mirrorlist.hook << EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Обновление списка зеркал с помощью reflector
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c 'reflector --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist'
EOF
    
    log_info "Основные настройки системы завершены"
}

#########################
# Установка загрузчика
#########################
install_bootloader() {
    log_section "Установка загрузчика"
    
    # Установка GRUB
    if [ "$BOOT_MODE" == "uefi" ]; then
        log_info "Установка GRUB для UEFI..."
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    else
        log_info "Установка GRUB для BIOS..."
        arch-chroot /mnt grub-install --target=i386-pc "$INSTALL_DEVICE"
    fi
    
    # Настройка параметров загрузки для BTRFS
    log_info "Настройка параметров загрузчика..."
    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="rootflags=subvol=@"/' /mnt/etc/default/grub
    
    # Генерация конфигурации GRUB
    log_info "Генерация конфигурации GRUB..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    log_info "Загрузчик установлен успешно"
}

#########################
# Завершение установки
#########################
finalize_installation() {
    log_section "Завершение установки"
    
    # Отмонтирование всех разделов
    log_info "Отмонтирование разделов..."
    umount -R /mnt
    
    log_info "Установка Arch Linux завершена успешно!"
    log_info "Система готова к перезагрузке. После перезагрузки:"
    log_info "1. Войдите с именем пользователя 'root' и паролем, который вы указали"
    log_info "2. Или войдите с именем '$USERNAME' и вашим паролем"
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        log_info "3. SSH-сервер включен, вы можете подключиться удаленно"
    fi
    
    read -p "Перезагрузить систему сейчас? (y/n): " REBOOT
    if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
        log_info "Перезагрузка..."
        reboot
    else
        log_info "Не забудьте перезагрузить систему вручную"
    fi
}

#########################
# Основная функция
#########################
main() {
    log_section "Начало установки Arch Linux"
    
    check_requirements
    collect_configuration
    prepare_disk
    install_base_system
    configure_system
    install_bootloader
    finalize_installation
}

# Запуск основной функции
main