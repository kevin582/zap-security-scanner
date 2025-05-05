#!/bin/bash

# Configuration
DEFAULT_BASE_DIR="/home/kali/ZAP-Reports"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check and fix Docker permissions
setup_docker_permissions() {
    echo "Setting up Docker permissions..."
    
    # Check if Docker socket exists
    if [ ! -S /var/run/docker.sock ]; then
        echo "Docker socket not found. Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # Check Docker socket permissions
    SOCKET_PERMS=$(stat -c "%a" /var/run/docker.sock)
    if [ "$SOCKET_PERMS" != "666" ]; then
        echo "Fixing Docker socket permissions..."
        sudo chmod 666 /var/run/docker.sock
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        echo "Adding current user to docker group..."
        sudo usermod -aG docker $USER
        echo "NOTE: You may need to log out and back in for group changes to take effect"
        echo "For now, we'll try to apply changes in current session"
        newgrp docker
    fi
}

# Function to check Docker installation
check_docker() {
    echo "Checking Docker installation..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        setup_docker_permissions
    fi
    
    # Verify Docker is working
    if ! docker ps &> /dev/null; then
        echo "Docker is not running properly. Attempting to fix permissions..."
        setup_docker_permissions
        
        # Test again after fixing permissions
        if ! docker ps &> /dev/null; then
            echo "ERROR: Docker is still not working. Please try logging out and back in,"
            echo "or restart your system to apply group changes."
            return 1
        fi
    fi
    
    echo "Docker is installed and running correctly."
    return 0
}

# Function to check and set up directories
setup_directories() {
    local base_dir="$1"
    
    echo "Setting up directories..."
    # Create reports directory if it doesn't exist
    if [ ! -d "$base_dir" ]; then
        echo "Creating reports directory: $base_dir"
        mkdir -p "$base_dir"
        chmod 755 "$base_dir"
    fi
    
    # Create subdirectories
    mkdir -p "$base_dir/current"
    mkdir -p "$base_dir/archive"
    mkdir -p "$base_dir/logs"
    
    # Set permissions
    chmod -R 755 "$base_dir"
    
    # Check if directory is writable
    if [ ! -w "$base_dir" ]; then
        echo "Warning: Reports directory is not writable. Please check permissions."
        return 1
    fi
    
    echo "Directories setup completed."
    return 0
}

# Function to update script paths if needed
update_paths() {
    local base_dir="$1"
    local script_path="$SCRIPT_DIR/run_scan.sh"
    
    # Update BASE_REPORTS_DIR in run_scan.sh if different from default
    if [ "$base_dir" != "$DEFAULT_BASE_DIR" ]; then
        echo "Updating reports directory path in run_scan.sh..."
        sed -i "s|BASE_REPORTS_DIR=\"/home/kali/ZAP-Reports\"|BASE_REPORTS_DIR=\"$base_dir\"|" "$script_path"
    fi
}

# Main setup process
main() {
    echo "ZAP Security Scanner Setup"
    echo "========================="
    
    # Check and setup Docker
    if ! check_docker; then
        echo "ERROR: Docker setup failed. Please fix the issues and try again."
        exit 1
    fi
    
    # Ask for reports directory
    read -p "Enter path for reports directory [$DEFAULT_BASE_DIR]: " base_dir
    base_dir="${base_dir:-$DEFAULT_BASE_DIR}"
    
    # Setup directories
    if ! setup_directories "$base_dir"; then
        echo "ERROR: Directory setup failed. Please check permissions and try again."
        exit 1
    fi
    
    # Update paths if needed
    update_paths "$base_dir"
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/run_scan.sh"
    
    # Pull ZAP Docker image
    echo "Pulling latest ZAP Docker image..."
    if ! docker pull ghcr.io/zaproxy/zaproxy:stable; then
        echo "ERROR: Failed to pull ZAP Docker image. Please check your internet connection."
        exit 1
    fi
    
    echo -e "\nSetup completed successfully!"
    echo "You can now run scans using: $SCRIPT_DIR/run_scan.sh"
    echo "Example: $SCRIPT_DIR/run_scan.sh -u URLs.txt -n custom-report-name"
}

# Run main setup
main 