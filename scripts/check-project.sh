#!/bin/bash

# Project Health Check Script
# This script validates that your Proxmox Kubernetes infrastructure is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local all_good=true
    
    # Check Terraform
    if command -v terraform &> /dev/null; then
        print_status "Terraform: $(terraform version | head -n1)"
    else
        print_error "Terraform not found"
        all_good=false
    fi
    
    # Check Ansible
    if command -v ansible &> /dev/null; then
        print_status "Ansible: $(ansible --version | head -n1)"
    else
        print_error "Ansible not found"
        all_good=false
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        print_status "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    else
        print_warning "kubectl not found (optional, will be installed during deployment)"
    fi
    
    if [ "$all_good" = true ]; then
        print_status "All prerequisites are installed"
        return 0
    else
        print_error "Some prerequisites are missing"
        return 1
    fi
}

# Function to check Terraform state
check_terraform_state() {
    print_info "Checking Terraform state..."
    
    if [ ! -f "terraform.tfstate" ]; then
        print_error "Terraform state file not found. Run 'terraform apply' first."
        return 1
    fi
    
    # Check if resources exist
    local master_count=$(terraform output -json k8s_master_nodes 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    local worker_count=$(terraform output -json k8s_worker_nodes 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$master_count" -gt 0 ] && [ "$worker_count" -gt 0 ]; then
        print_status "Terraform state is valid: $master_count master(s), $worker_count worker(s)"
        
        # Show cluster info
        print_info "Cluster information:"
        terraform output k8s_cluster_info
        
        return 0
    else
        print_error "No Kubernetes resources found in Terraform state"
        return 1
    fi
}

# Function to check VM connectivity
check_vm_connectivity() {
    print_info "Checking VM connectivity..."
    
    if [ ! -f "ansible/inventory.ini" ]; then
        print_error "Ansible inventory not found"
        return 1
    fi
    
    # Test SSH connectivity
    local unreachable_count=0
    local total_count=0
    
    while IFS= read -r line; do
        if [[ $line =~ ansible_host=([0-9.]+) ]]; then
            local ip="${BASH_REMATCH[1]}"
            total_count=$((total_count + 1))
            
            if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null netanele@$ip "echo 'SSH OK'" 2>/dev/null; then
                print_warning "Cannot reach $ip"
                unreachable_count=$((unreachable_count + 1))
            else
                print_status "SSH connection to $ip successful"
            fi
        fi
    done < ansible/inventory.ini
    
    if [ $unreachable_count -eq 0 ]; then
        print_status "All VMs are reachable via SSH"
        return 0
    else
        print_warning "$unreachable_count out of $total_count VMs are not reachable"
        return 1
    fi
}

# Function to check Kubernetes cluster
check_kubernetes_cluster() {
    print_info "Checking Kubernetes cluster..."
    
    # Check if kubectl config exists
    if [ ! -f ~/.kube/config ]; then
        print_warning "kubectl config not found. Kubernetes may not be deployed yet."
        return 1
    fi
    
    # Test kubectl connectivity
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    print_status "Kubernetes cluster is accessible"
    
    # Get cluster information
    print_info "Cluster nodes:"
    kubectl get nodes -o wide
    
    print_info "System pods:"
    kubectl get pods -n kube-system
    
    print_info "All namespaces:"
    kubectl get namespaces
    
    return 0
}

# Function to check deployed applications
check_applications() {
    print_info "Checking deployed applications..."
    
    if ! kubectl get pods --all-namespaces &>/dev/null; then
        print_warning "Cannot check applications - cluster not accessible"
        return 1
    fi
    
    local app_count=0
    
    # Check for nginx deployment
    if kubectl get deployment nginx-deployment &>/dev/null; then
        print_status "nginx-deployment found"
        app_count=$((app_count + 1))
    fi
    
    # Check for dashboard
    if kubectl get pods -n kubernetes-dashboard &>/dev/null; then
        print_status "Kubernetes Dashboard found"
        app_count=$((app_count + 1))
    fi
    
    # Show all deployments
    print_info "Current deployments:"
    kubectl get deployments --all-namespaces
    
    if [ $app_count -gt 0 ]; then
        print_status "Found $app_count application(s) deployed"
        return 0
    else
        print_warning "No applications deployed yet"
        return 1
    fi
}

# Function to run a quick test deployment
test_deployment() {
    print_info "Running test deployment..."
    
    # Create a simple test pod
    kubectl run test-pod --image=nginx:alpine --restart=Never
    
    # Wait for pod to be ready
    print_info "Waiting for test pod to be ready..."
    kubectl wait --for=condition=Ready pod/test-pod --timeout=60s
    
    if kubectl get pod test-pod | grep -q "Running"; then
        print_status "Test pod is running successfully"
        
        # Clean up
        kubectl delete pod test-pod
        print_status "Test pod cleaned up"
        return 0
    else
        print_error "Test pod failed to start"
        return 1
    fi
}

# Function to show project status summary
show_status_summary() {
    print_info "=== PROJECT STATUS SUMMARY ==="
    
    echo ""
    print_info "Infrastructure Status:"
    if check_terraform_state; then
        print_status "✓ Infrastructure deployed"
    else
        print_error "✗ Infrastructure not ready"
    fi
    
    echo ""
    print_info "VM Connectivity:"
    if check_vm_connectivity; then
        print_status "✓ All VMs reachable"
    else
        print_warning "! Some VMs not reachable"
    fi
    
    echo ""
    print_info "Kubernetes Status:"
    if check_kubernetes_cluster; then
        print_status "✓ Kubernetes cluster running"
    else
        print_warning "! Kubernetes not deployed or not accessible"
    fi
    
    echo ""
    print_info "Applications:"
    if check_applications; then
        print_status "✓ Applications deployed"
    else
        print_warning "! No applications deployed"
    fi
}

# Function to show next steps
show_next_steps() {
    print_info "=== NEXT STEPS ==="
    echo ""
    
    if ! check_terraform_state &>/dev/null; then
        echo "1. Deploy infrastructure:"
        echo "   terraform apply"
        echo ""
    fi
    
    if ! check_vm_connectivity &>/dev/null; then
        echo "2. Wait for VMs to be ready:"
        echo "   ./scripts/wait-for-vms.sh check"
        echo ""
    fi
    
    if ! check_kubernetes_cluster &>/dev/null; then
        echo "3. Deploy Kubernetes:"
        echo "   ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml"
        echo "   OR: ./scripts/k8s-setup.sh deploy"
        echo ""
    fi
    
    if ! check_applications &>/dev/null; then
        echo "4. Deploy sample applications:"
        echo "   kubectl apply -f examples/nginx-deployment.yaml"
        echo "   kubectl apply -f examples/dashboard-deployment.yaml"
        echo ""
    fi
    
    echo "5. Access your cluster:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods --all-namespaces"
    echo ""
}

# Main script logic
case "${1:-all}" in
    prereq|prerequisites)
        check_prerequisites
        ;;
    terraform|infra)
        check_terraform_state
        ;;
    vms|connectivity)
        check_vm_connectivity
        ;;
    k8s|kubernetes)
        check_kubernetes_cluster
        ;;
    apps|applications)
        check_applications
        ;;
    test)
        test_deployment
        ;;
    status|summary)
        show_status_summary
        ;;
    next|steps)
        show_next_steps
        ;;
    all)
        print_info "Running comprehensive project health check..."
        echo ""
        check_prerequisites
        echo ""
        check_terraform_state
        echo ""
        check_vm_connectivity
        echo ""
        check_kubernetes_cluster
        echo ""
        check_applications
        echo ""
        show_status_summary
        echo ""
        show_next_steps
        ;;
    help|--help|-h)
        echo "Project Health Check Script"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  all          Run all checks (default)"
        echo "  prereq       Check prerequisites"
        echo "  terraform    Check Terraform state"
        echo "  vms          Check VM connectivity"
        echo "  k8s          Check Kubernetes cluster"
        echo "  apps         Check deployed applications"
        echo "  test         Run test deployment"
        echo "  status       Show status summary"
        echo "  next         Show next steps"
        echo "  help         Show this help"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
