#!/bin/bash

# Configuration
DEFAULT_BASE_DIR="/home/kali/ZAP-Reports"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check Docker installation
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Docker daemon is not running. Please start Docker service."
        return 1
    }
    
    return 0
}

# Function to check and set up directories
setup_directories() {
    local base_dir="$1"
    
    # Create reports directory if it doesn't exist
    if [ ! -d "$base_dir" ]; then
        echo "Creating reports directory: $base_dir"
        mkdir -p "$base_dir"
        chmod 755 "$base_dir"
    fi
    
    # Check if directory is writable
    if [ ! -w "$base_dir" ]; then
        echo "Warning: Reports directory is not writable. Please check permissions."
        return 1
    }
    
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
    
    # Check Docker installation
    echo "Checking Docker installation..."
    if ! check_docker; then
        exit 1
    fi
    
    # Ask for reports directory
    read -p "Enter path for reports directory [$DEFAULT_BASE_DIR]: " base_dir
    base_dir="${base_dir:-$DEFAULT_BASE_DIR}"
    
    # Setup directories
    echo "Setting up directories..."
    if ! setup_directories "$base_dir"; then
        exit 1
    fi
    
    # Update paths if needed
    update_paths "$base_dir"
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/run_scan.sh"
    
    # Pull ZAP Docker image
    echo "Pulling latest ZAP Docker image..."
    docker pull ghcr.io/zaproxy/zaproxy:stable
    
    echo -e "\nSetup completed successfully!"
    echo "You can now run scans using: $SCRIPT_DIR/run_scan.sh"
    echo "Example: $SCRIPT_DIR/run_scan.sh -u URLs.txt -n custom-report-name"
}

# Run main setup
main 