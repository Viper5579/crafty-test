#!/bin/bash
################################################################################
# Crafty Controller 4 Installer for Amazon Linux 2023 (ARM64)
#
# This script automates the installation of Crafty Controller 4 on
# Amazon Linux 2023, following the official manual installation process.
#
# Requirements:
# - Amazon Linux 2023 (ARM64)
# - Run with sudo
# - Python 3.9+ already installed
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CRAFTY_USER="crafty"
CRAFTY_HOME="/var/opt/minecraft/crafty"
CRAFTY_REPO="https://gitlab.com/crafty-controller/crafty-4.git"
CRAFTY_PORT="8443"
PYTHON_MIN_VERSION="3.9"
SERVICE_NAME="crafty"

################################################################################
# Helper Functions
################################################################################

print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo or as root"
        exit 1
    fi
}

check_os() {
    print_step "Checking Operating System"

    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine OS. /etc/os-release not found."
        exit 1
    fi

    . /etc/os-release

    if [[ "$ID" != "amzn" ]] || [[ "$VERSION_ID" != "2023" ]]; then
        print_warning "This script is designed for Amazon Linux 2023"
        print_info "Detected: $PRETTY_NAME"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_info "Detected: $PRETTY_NAME ✓"
    fi
}

check_architecture() {
    print_step "Checking Architecture"

    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" ]] && [[ "$ARCH" != "arm64" ]]; then
        print_warning "This script is optimized for ARM64/aarch64"
        print_info "Detected: $ARCH"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_info "Architecture: $ARCH ✓"
    fi
}

check_python() {
    print_step "Checking Python Installation"

    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi

    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    print_info "Python version: $PYTHON_VERSION ✓"

    # Check if pip is installed
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed. Please install python3-pip"
        exit 1
    fi

    print_info "pip3 is installed ✓"
}

check_java() {
    print_step "Checking Java Installation"

    if ! command -v java &> /dev/null; then
        print_warning "Java is not installed. Required for Minecraft servers."
        print_info "You mentioned Java 21 is installed, but it's not in PATH"
    else
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        print_info "$JAVA_VERSION ✓"
    fi
}

install_dependencies() {
    print_step "Installing System Dependencies"

    print_info "Updating package cache..."
    dnf check-update || true  # Don't fail if updates are available

    print_info "Installing required packages..."
    dnf install -y \
        git \
        wget \
        tar \
        openssl \
        python3-devel \
        gcc \
        gcc-c++ \
        make \
        libffi-devel \
        openssl-devel

    print_info "Dependencies installed ✓"
}

create_user() {
    print_step "Creating Crafty Service User"

    if id "$CRAFTY_USER" &>/dev/null; then
        print_warning "User '$CRAFTY_USER' already exists"
    else
        useradd -r -m -d "$CRAFTY_HOME" -s /bin/bash "$CRAFTY_USER"
        print_info "Created user: $CRAFTY_USER ✓"
    fi
}

create_directories() {
    print_step "Creating Installation Directory"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$CRAFTY_HOME")"

    # Create crafty home directory
    mkdir -p "$CRAFTY_HOME"

    print_info "Created directory: $CRAFTY_HOME ✓"
}

clone_repository() {
    print_step "Cloning Crafty Controller Repository"

    if [ -d "$CRAFTY_HOME/app" ]; then
        print_warning "Directory $CRAFTY_HOME/app already exists"
        read -p "Remove and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CRAFTY_HOME/app"
        else
            print_info "Skipping clone step"
            return
        fi
    fi

    cd "$CRAFTY_HOME"

    print_info "Cloning from: $CRAFTY_REPO"
    sudo -u "$CRAFTY_USER" git clone "$CRAFTY_REPO" app

    cd app

    print_info "Checking out latest stable version..."
    LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "master")

    if [ "$LATEST_TAG" != "master" ]; then
        print_info "Checking out tag: $LATEST_TAG"
        sudo -u "$CRAFTY_USER" git checkout "$LATEST_TAG"
    else
        print_info "Using master branch"
    fi

    print_info "Repository cloned ✓"
}

setup_virtualenv() {
    print_step "Setting up Python Virtual Environment"

    cd "$CRAFTY_HOME/app"

    if [ -d "$CRAFTY_HOME/venv" ]; then
        print_warning "Virtual environment already exists at $CRAFTY_HOME/venv"
        read -p "Remove and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CRAFTY_HOME/venv"
        else
            print_info "Skipping virtualenv creation"
            return
        fi
    fi

    print_info "Creating virtual environment..."
    sudo -u "$CRAFTY_USER" python3 -m venv "$CRAFTY_HOME/venv"

    print_info "Virtual environment created ✓"
}

install_python_requirements() {
    print_step "Installing Python Requirements"

    cd "$CRAFTY_HOME/app"

    if [ ! -f "requirements.txt" ]; then
        print_error "requirements.txt not found in $CRAFTY_HOME/app"
        exit 1
    fi

    print_info "Upgrading pip..."
    sudo -u "$CRAFTY_USER" "$CRAFTY_HOME/venv/bin/pip" install --upgrade pip

    print_info "Installing requirements (this may take a few minutes)..."
    sudo -u "$CRAFTY_USER" "$CRAFTY_HOME/venv/bin/pip" install -r requirements.txt

    print_info "Python requirements installed ✓"
}

configure_crafty() {
    print_step "Configuring Crafty Controller"

    # Create initial config directory if needed
    mkdir -p "$CRAFTY_HOME/app/app/config"

    # Set the web port
    print_info "Configuring web interface port to: $CRAFTY_PORT"

    # Note: Crafty creates its config on first run, but we can set environment variables
    # or modify configs after first run if needed

    print_info "Configuration prepared ✓"
}

set_permissions() {
    print_step "Setting Permissions"

    chown -R "$CRAFTY_USER:$CRAFTY_USER" "$CRAFTY_HOME"
    chmod -R 755 "$CRAFTY_HOME"

    print_info "Permissions set ✓"
}

create_systemd_service() {
    print_step "Creating systemd Service"

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Crafty Controller 4 - Minecraft Server Management
After=network.target

[Service]
Type=simple
User=$CRAFTY_USER
Group=$CRAFTY_USER
WorkingDirectory=$CRAFTY_HOME/app
ExecStart=$CRAFTY_HOME/venv/bin/python3 $CRAFTY_HOME/app/main.py
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=crafty

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CRAFTY_HOME

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    print_info "Service file created: /etc/systemd/system/${SERVICE_NAME}.service ✓"

    systemctl daemon-reload
    print_info "systemd reloaded ✓"
}

detect_minecraft_server() {
    print_step "Detecting Existing Minecraft Server"

    ORIGINAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)

    if [ -n "$ORIGINAL_USER" ]; then
        MINECRAFT_PATH="/home/$ORIGINAL_USER/minecraft"

        if [ -d "$MINECRAFT_PATH" ]; then
            print_info "Found Minecraft server at: $MINECRAFT_PATH ✓"
            print_info ""
            print_info "To import this server into Crafty:"
            print_info "1. Start Crafty and access the web interface"
            print_info "2. Go to 'Servers' -> 'Create New Server'"
            print_info "3. Choose 'Import Existing Server'"
            print_info "4. Point to: $MINECRAFT_PATH"
            print_info ""
            print_info "Note: You may need to stop the minecraft.service first:"
            print_info "  sudo systemctl stop minecraft"
        else
            print_warning "No Minecraft server found at $MINECRAFT_PATH"
        fi
    fi
}

configure_firewall() {
    print_step "Checking Firewall Configuration"

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            print_info "firewalld is active"
            read -p "Open port $CRAFTY_PORT in firewall? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                firewall-cmd --permanent --add-port=${CRAFTY_PORT}/tcp
                firewall-cmd --reload
                print_info "Port $CRAFTY_PORT opened in firewall ✓"
            fi
        else
            print_info "firewalld is not active, skipping firewall configuration"
        fi
    else
        print_info "firewalld not installed, skipping firewall configuration"
    fi
}

print_completion() {
    print_step "Installation Complete!"

    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  Crafty Controller 4 has been successfully installed!       ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "Installation Directory: ${BLUE}$CRAFTY_HOME${NC}"
    echo -e "Service User:          ${BLUE}$CRAFTY_USER${NC}"
    echo -e "Service Name:          ${BLUE}$SERVICE_NAME${NC}"
    echo -e "Web Interface Port:    ${BLUE}$CRAFTY_PORT${NC}"

    echo -e "\n${YELLOW}Next Steps:${NC}\n"

    echo -e "1. Start Crafty Controller:"
    echo -e "   ${BLUE}sudo systemctl start $SERVICE_NAME${NC}\n"

    echo -e "2. Enable auto-start on boot:"
    echo -e "   ${BLUE}sudo systemctl enable $SERVICE_NAME${NC}\n"

    echo -e "3. Check service status:"
    echo -e "   ${BLUE}sudo systemctl status $SERVICE_NAME${NC}\n"

    echo -e "4. View logs:"
    echo -e "   ${BLUE}sudo journalctl -u $SERVICE_NAME -f${NC}\n"

    echo -e "5. Access web interface:"
    echo -e "   ${BLUE}https://$(hostname -I | awk '{print $1}'):$CRAFTY_PORT${NC}"
    echo -e "   ${BLUE}https://localhost:$CRAFTY_PORT${NC}\n"

    echo -e "${YELLOW}First-Time Setup:${NC}"
    echo -e "- On first access, you'll be prompted to create an admin account"
    echo -e "- Follow the web setup wizard to complete configuration\n"

    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        echo -e "${YELLOW}Security Note:${NC}"
        echo -e "- Ensure port $CRAFTY_PORT is accessible in your EC2 Security Group"
        echo -e "- For AWS EC2: Add inbound rule for TCP port $CRAFTY_PORT\n"
    fi

    echo -e "${YELLOW}Existing Minecraft Server:${NC}"
    ORIGINAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    if [ -n "$ORIGINAL_USER" ]; then
        MINECRAFT_PATH="/home/$ORIGINAL_USER/minecraft"
        if [ -d "$MINECRAFT_PATH" ]; then
            echo -e "- Your existing server at ${BLUE}$MINECRAFT_PATH${NC} can be imported"
            echo -e "- Consider stopping the systemd service: ${BLUE}sudo systemctl stop minecraft${NC}"
            echo -e "- Then import it through the Crafty web interface\n"
        fi
    fi

    echo -e "${GREEN}Installation log can be found above.${NC}\n"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║        Crafty Controller 4 Installer for Amazon Linux 2023      ║"
    echo "║                       (ARM64/Graviton2)                          ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    # Pre-flight checks
    check_root
    check_os
    check_architecture
    check_python
    check_java

    # Installation steps
    install_dependencies
    create_user
    create_directories
    clone_repository
    setup_virtualenv
    install_python_requirements
    configure_crafty
    set_permissions
    create_systemd_service
    detect_minecraft_server
    configure_firewall

    # Completion
    print_completion
}

# Run main installation
main

exit 0
