# Crafty Controller 4 Installer for Amazon Linux 2023

Automated installation script for [Crafty Controller 4](https://craftycontrol.com/) on Amazon Linux 2023 (ARM64/Graviton2).

## Overview

This installer automates the manual installation process for Crafty Controller 4 on Amazon Linux 2023, which is not officially supported by the standard installer script.

## Features

- ✅ Full Amazon Linux 2023 support with `dnf` package management
- ✅ ARM64/Graviton2 optimized
- ✅ Creates dedicated `crafty` service user
- ✅ Installs to `/var/opt/minecraft/crafty`
- ✅ Python virtual environment setup
- ✅ Systemd service configuration for auto-start
- ✅ Configurable web interface port (default: 8443)
- ✅ Detects existing Minecraft servers
- ✅ Firewall configuration support
- ✅ Comprehensive error checking

## Prerequisites

Before running the installer, ensure you have:

- Amazon Linux 2023 (ARM64)
- Python 3.9 or higher
- `python3-pip` and `python3-devel` installed
- Java 21 (recommended: Amazon Corretto) for Minecraft servers
- Root/sudo access
- Active internet connection

## Installation

### Quick Install

```bash
# Download the installer
wget https://raw.githubusercontent.com/Viper5579/crafty-test/main/install-crafty-al2023.sh

# Make it executable
chmod +x install-crafty-al2023.sh

# Run with sudo
sudo ./install-crafty-al2023.sh
```

### Manual Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/Viper5579/crafty-test.git
   cd crafty-test
   ```

2. Make the script executable:
   ```bash
   chmod +x install-crafty-al2023.sh
   ```

3. Run the installer with sudo:
   ```bash
   sudo ./install-crafty-al2023.sh
   ```

4. Follow the on-screen prompts

## What the Installer Does

1. **System Checks**: Verifies OS, architecture, Python, and Java installations
2. **Dependencies**: Installs required system packages via `dnf`:
   - git, wget, tar, openssl
   - python3-devel, gcc, gcc-c++, make
   - libffi-devel, openssl-devel
3. **User Creation**: Creates the `crafty` service user
4. **Directory Setup**: Creates `/var/opt/minecraft/crafty`
5. **Repository Clone**: Clones Crafty 4 from GitLab and checks out latest stable version
6. **Python Environment**: Creates virtual environment and installs requirements
7. **Systemd Service**: Creates and configures the service file
8. **Permissions**: Sets appropriate ownership and permissions
9. **Firewall**: Optionally configures firewalld rules
10. **Detection**: Identifies existing Minecraft servers for import

## Post-Installation

After the installer completes, run these commands:

### Start Crafty
```bash
sudo systemctl start crafty
```

### Enable Auto-Start on Boot
```bash
sudo systemctl enable crafty
```

### Check Status
```bash
sudo systemctl status crafty
```

### View Logs
```bash
sudo journalctl -u crafty -f
```

## Accessing Crafty

Once started, access the web interface at:

```
https://YOUR_SERVER_IP:8443
```

On first access, you'll be prompted to create an admin account.

## AWS EC2 Security Group Configuration

If running on EC2, ensure your Security Group allows inbound traffic:

- **Type**: Custom TCP
- **Port**: 8443
- **Source**: Your IP or 0.0.0.0/0 (for public access - use with caution)

## Importing Existing Minecraft Server

If you have an existing Minecraft server (e.g., at `~/minecraft`):

1. Stop the existing systemd service:
   ```bash
   sudo systemctl stop minecraft
   ```

2. Access Crafty web interface
3. Navigate to **Servers** → **Create New Server**
4. Choose **Import Existing Server**
5. Point to your server directory (e.g., `/home/ec2-user/minecraft`)

## File Locations

- **Installation Directory**: `/var/opt/minecraft/crafty`
- **Application**: `/var/opt/minecraft/crafty/app`
- **Virtual Environment**: `/var/opt/minecraft/crafty/venv`
- **Systemd Service**: `/etc/systemd/system/crafty.service`
- **Service User**: `crafty`

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u crafty -n 50

# Check permissions
sudo ls -la /var/opt/minecraft/crafty

# Verify Python environment
sudo -u crafty /var/opt/minecraft/crafty/venv/bin/python3 --version
```

### Can't access web interface
```bash
# Check if service is running
sudo systemctl status crafty

# Check if port is listening
sudo ss -tlnp | grep 8443

# Check firewall
sudo firewall-cmd --list-all
```

### Permission errors
```bash
# Reset permissions
sudo chown -R crafty:crafty /var/opt/minecraft/crafty
sudo chmod -R 755 /var/opt/minecraft/crafty
```

## Uninstallation

To remove Crafty Controller:

```bash
# Stop and disable service
sudo systemctl stop crafty
sudo systemctl disable crafty

# Remove service file
sudo rm /etc/systemd/system/crafty.service
sudo systemctl daemon-reload

# Remove installation directory
sudo rm -rf /var/opt/minecraft/crafty

# Remove user (optional)
sudo userdel -r crafty
```

## Additional Resources

- [Crafty Controller Official Documentation](https://docs.craftycontrol.com/)
- [Crafty Controller GitLab](https://gitlab.com/crafty-controller/crafty-4)
- [Amazon Linux 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/)

## License

This installer script is provided as-is for use with Crafty Controller 4.

## Support

For Crafty Controller issues, visit:
- [Crafty Discord](https://discord.gg/9VJPhCE)
- [Crafty GitLab Issues](https://gitlab.com/crafty-controller/crafty-4/-/issues)

For issues with this installer script, please open an issue in this repository.
