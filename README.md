# Headless Arch Deployer

![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-Latest-1793D1?logo=arch-linux&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white)

A robust, interactive shell script for deploying minimalist Arch Linux installations with BTRFS filesystem and proper subvolume layout. The script automates the entire installation process while maintaining flexibility through interactive configuration options. Designed to work specifically with UEFI boot mode.

## 🚀 Features

- **Streamlined Installation**: Fully automated Arch Linux setup from live environment
- **Filesystem Optimization**: BTRFS with optimal subvolume layout (@, @home, @var, @snapshots)
- **UEFI Required**: Optimized specifically for systems with UEFI firmware
- **Storage Flexibility**: Interactive disk selection with safety confirmations
- **Network Ready**: DHCP configuration and optional SSH server setup
- **User-Friendly**: Interactive prompts with sensible defaults
- **Enhanced Security**: Proper user creation with sudo privileges
- **System Maintenance**: Automatic mirror optimization with reflector
- **Performance Tuning**: BTRFS compression with zstd and noatime options

## 🔧 Usage

1. Boot into an Arch Linux live environment with UEFI mode enabled
2. Download the script:
```bash
curl -LO https://github.com/T-7219/headless-arch-deployer/raw/main/archinstall.en.sh
```

3. Make it executable:
```bash
chmod +x archinstall.en.sh
```

4. Run the script:
```bash
./archinstall.en.sh
```

5. Follow the interactive prompts to configure your installation

## ⚙️ Configuration Options

- Target disk selection
- Timezone and locale settings
- Hostname configuration
- Username and password setup
- SSH server enablement
- Additional package installation

## 🛠️ Technical Details

The script implements a comprehensive installation workflow:
- System requirement validation
- Storage preparation with UEFI-compatible partition scheme
- BTRFS subvolume creation with compression
- Base system installation with selected packages
- System configuration including localization and networking
- Bootloader installation and optimization for BTRFS
- User and security setup

## 🔒 Security Considerations

- Root SSH access is enabled by default for initial setup (can be disabled manually)
- Strong password validation with confirmation checks
- Proper user privileges through wheel group

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

Developed with ❤️ for Arch Linux enthusiasts who prefer minimal headless setups.
