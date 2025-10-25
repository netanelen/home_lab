#!/bin/bash

# Wait for VMs to get IP addresses
# This script helps resolve the IP address assignment timing issue

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if all VMs have IP addresses
check_vm_ips() {
    local all_ready=true
    
    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        print_error "Terraform state file not found. Run 'terraform apply' first."
        return 1
    fi
    
    # Get VM information from terraform state
    local masters=$(terraform output -json k8s_master_nodes 2>/dev/null | jq -r 'to_entries[] | select(.value.ip != "IP not yet assigned") | .key' 2>/dev/null || echo "")
    local workers=$(terraform output -json k8s_worker_nodes 2>/dev/null | jq -r 'to_entries[] | select(.value.ip != "IP not yet assigned") | .key' 2>/dev/null || echo "")
    
    # Count expected vs ready VMs
    local expected_masters=$(terraform output -json k8s_cluster_info 2>/dev/null | jq -r '.master_count' 2>/dev/null || echo "0")
    local expected_workers=$(terraform output -json k8s_cluster_info 2>/dev/null | jq -r '.worker_count' 2>/dev/null || echo "0")
    
    local ready_masters=$(echo "$masters" | wc -l)
    local ready_workers=$(echo "$workers" | wc -l)
    
    print_status "Expected masters: $expected_masters, Ready: $ready_masters"
    print_status "Expected workers: $expected_workers, Ready: $ready_workers"
    
    if [ "$ready_masters" -lt "$expected_masters" ] || [ "$ready_workers" -lt "$expected_workers" ]; then
        all_ready=false
    fi
    
    if [ "$all_ready" = true ]; then
        print_status "All VMs have IP addresses assigned!"
        return 0
    else
        return 1
    fi
}

# Function to refresh terraform state
refresh_terraform() {
    print_status "Refreshing Terraform state..."
    terraform refresh
}

# Main waiting loop
wait_for_ips() {
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for VMs to get IP addresses..."
    print_warning "This may take several minutes as VMs boot and get DHCP addresses."
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt/$max_attempts"
        
        # Refresh terraform state to get latest VM information
        refresh_terraform
        
        # Check if all VMs have IPs
        if check_vm_ips; then
            print_status "All VMs are ready with IP addresses!"
            
            # Show the inventory
            print_status "Current inventory:"
            cat ansible/inventory.ini
            
            return 0
        fi
        
        print_warning "Not all VMs have IP addresses yet. Waiting 30 seconds..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    print_error "Timeout waiting for VMs to get IP addresses after $max_attempts attempts."
    print_error "You may need to:"
    print_error "1. Check your Proxmox network configuration"
    print_error "2. Ensure DHCP is working properly"
    print_error "3. Check if VMs are actually running"
    
    return 1
}

# Function to show current status
show_status() {
    print_status "Current VM status:"
    terraform output k8s_master_nodes 2>/dev/null || echo "No master nodes found"
    terraform output k8s_worker_nodes 2>/dev/null || echo "No worker nodes found"
    
    print_status "Current inventory:"
    if [ -f "ansible/inventory.ini" ]; then
        cat ansible/inventory.ini
    else
        echo "No inventory file found"
    fi
}

# Main script logic
case "${1:-wait}" in
    wait)
        wait_for_ips
        ;;
    status)
        show_status
        ;;
    refresh)
        refresh_terraform
        show_status
        ;;
    help|--help|-h)
        echo "Wait for VMs to get IP addresses"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  wait      Wait for all VMs to get IP addresses (default)"
        echo "  status    Show current VM status"
        echo "  refresh   Refresh terraform state and show status"
        echo "  help      Show this help message"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
