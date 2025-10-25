#!/bin/bash

# Wait for VMs to be ready for SSH connections
# This script helps ensure VMs are fully booted before running Ansible

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

# Function to check if a single VM is reachable
check_vm_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Checking SSH connectivity to $host..."
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null netanele@$host "echo 'SSH connection successful'" 2>/dev/null; then
            print_status "$host is ready for SSH connections!"
            return 0
        fi
        
        print_warning "Attempt $attempt/$max_attempts: $host not ready yet. Waiting 30 seconds..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    print_error "$host is not reachable after $max_attempts attempts."
    return 1
}

# Function to check all VMs in inventory
check_all_vms() {
    local inventory_file="ansible/inventory.ini"
    local all_ready=true
    
    if [ ! -f "$inventory_file" ]; then
        print_error "Inventory file not found: $inventory_file"
        return 1
    fi
    
    print_status "Checking all VMs from inventory..."
    
    # Extract IP addresses from inventory
    local ips=$(grep "ansible_host=" "$inventory_file" | grep -v "^#" | sed 's/.*ansible_host=\([0-9.]*\).*/\1/' | sort -u)
    
    if [ -z "$ips" ]; then
        print_error "No IP addresses found in inventory file"
        return 1
    fi
    
    for ip in $ips; do
        if ! check_vm_ssh "$ip"; then
            all_ready=false
        fi
    done
    
    if [ "$all_ready" = true ]; then
        print_status "All VMs are ready for Ansible!"
        return 0
    else
        print_error "Some VMs are not ready"
        return 1
    fi
}

# Function to show current status
show_status() {
    print_status "Current VM status:"
    terraform output k8s_master_nodes 2>/dev/null || echo "No master nodes found"
    terraform output k8s_worker_nodes 2>/dev/null || echo "No worker nodes found"
    
    print_status "Testing SSH connectivity:"
    ansible all -i ansible/inventory.ini -m ping --timeout=10 || echo "Some VMs not ready yet"
}

# Main script logic
case "${1:-check}" in
    check)
        check_all_vms
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        echo "Wait for VMs to be ready for SSH connections"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  check     Check if all VMs are ready for SSH (default)"
        echo "  status    Show current VM status and test connectivity"
        echo "  help      Show this help message"
        echo ""
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
