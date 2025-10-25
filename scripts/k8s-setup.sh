#!/bin/bash

# Kubernetes Cluster Setup Script
# This script helps you deploy and manage your Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. Installing..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    print_status "Prerequisites check completed."
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd "$(dirname "$0")/.."
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the plan
    terraform apply tfplan
    
    print_status "Infrastructure deployment completed."
    
    print_warning "Waiting 60 seconds for VMs to boot and initialize network..."
    sleep 180
    
    # Wait for VMs to get IP addresses
   
    print_status "Waiting for VMs to get IP addresses..."
    ./scripts/wait-for-ips.sh wait
}

# Deploy Kubernetes cluster
deploy_kubernetes() {
    print_status "Deploying Kubernetes cluster with Ansible..."
    
    cd "$(dirname "$0")/.."
    
    # Wait for VMs to be ready for SSH
    print_status "Waiting for VMs to be ready for SSH connections..."
    ./scripts/wait-for-vms.sh check
    
    # Run Ansible playbook
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml
    
    print_status "Kubernetes cluster deployment completed."
}

# Get cluster information
get_cluster_info() {
    print_status "Getting cluster information..."
    
    cd "$(dirname "$0")/.."
    
    # Get master IP
    MASTER_IP=$(terraform output -raw k8s_master_ip)
    
    print_status "Kubernetes cluster is ready!"
    print_status "Master node IP: $MASTER_IP"
    print_status "To access the cluster, run:"
    echo "  export KUBECONFIG=~/.kube/config"
    echo "  kubectl get nodes"
}

# Clean up resources
cleanup() {
    print_warning "This will destroy all resources. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Destroying infrastructure..."
        cd "$(dirname "$0")/.."
        terraform destroy -auto-approve
        print_status "Cleanup completed."
    else
        print_status "Cleanup cancelled."
    fi
}

# Show help
show_help() {
    echo "Kubernetes Cluster Setup Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     Deploy the complete infrastructure and Kubernetes cluster"
    echo "  infra      Deploy only the infrastructure (VMs)"
    echo "  k8s        Deploy only Kubernetes on existing VMs"
    echo "  info       Show cluster information"
    echo "  cleanup    Destroy all resources"
    echo "  help       Show this help message"
    echo ""
}

# Main script logic
case "${1:-help}" in
    deploy)
        check_prerequisites
        deploy_infrastructure
        deploy_kubernetes
        get_cluster_info
        ;;
    infra)
        check_prerequisites
        deploy_infrastructure
        ;;
    k8s)
        deploy_kubernetes
        get_cluster_info
        ;;
    info)
        get_cluster_info
        ;;
    cleanup)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
