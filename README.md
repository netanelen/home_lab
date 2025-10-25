# Proxmox Kubernetes Infrastructure

This project provides a complete infrastructure-as-code solution for deploying Kubernetes clusters on Proxmox using Terraform and Ansible.

## Features

- **Multi-node Kubernetes cluster** with configurable master and worker nodes
- **Automated infrastructure provisioning** using Terraform
- **Automated Kubernetes installation** using Ansible
- **High availability support** for master nodes
- **CNI networking** with Flannel
- **Container runtime** with containerd
- **Backward compatibility** with single VM deployments

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Host                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Master Node   │  │   Master Node   │  │ Master Node │ │
│  │   (Control     │  │   (Control     │  │ (Control    │ │
│  │    Plane)      │  │    Plane)      │  │  Plane)     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Worker Node   │  │   Worker Node   │  │ Worker Node │ │
│  │                 │  │                 │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Proxmox VE 6.0+ with API access
- Terraform 1.0+
- Ansible 2.9+
- kubectl (optional, for cluster management)
- SSH access to Proxmox host

## Quick Start

### 1. Configure Variables

Edit `terraform.tfvars` to set your Proxmox credentials and cluster configuration:

```hcl
# Proxmox Configuration
proxmox_api_token = "your-token@realm!token-name"
endpoint = "https://your-proxmox-host:8006/api2/json"

# Kubernetes Cluster Configuration
k8s_cluster_name = "my-k8s-cluster"
k8s_master_nodes = 1
k8s_worker_nodes = 2
k8s_master_cpu = 2
k8s_master_memory = 4096
k8s_worker_cpu = 2
k8s_worker_memory = 4096
```

### 2. Deploy Infrastructure

```bash
# Make the setup script executable
chmod +x scripts/k8s-setup.sh

# Deploy complete infrastructure and Kubernetes cluster
./scripts/k8s-setup.sh deploy
```

### 3. Access Your Cluster

```bash
# Get cluster information
terraform output k8s_master_ip

# Configure kubectl (if not already done by Ansible)
export KUBECONFIG=~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Manual Deployment

If you prefer to run commands manually:

### 1. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### 2. Deploy Kubernetes

```bash
# Run Ansible playbook
ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml
```

## Configuration Options

### Terraform Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `k8s_cluster_name` | Name of the Kubernetes cluster | `proxmox-k8s` | No |
| `k8s_master_nodes` | Number of master nodes | `1` | No |
| `k8s_worker_nodes` | Number of worker nodes | `2` | No |
| `k8s_pod_cidr` | CIDR for pods | `10.244.0.0/16` | No |
| `k8s_service_cidr` | CIDR for services | `10.96.0.0/12` | No |
| `k8s_version` | Kubernetes version | `1.28` | No |
| `k8s_master_cpu` | CPU cores for masters | `2` | No |
| `k8s_master_memory` | Memory for masters (MB) | `4096` | No |
| `k8s_worker_cpu` | CPU cores for workers | `2` | No |
| `k8s_worker_memory` | Memory for workers (MB) | `4096` | No |

### High Availability Configuration

For production environments, configure multiple master nodes:

```hcl
k8s_master_nodes = 3  # Must be odd number
k8s_worker_nodes = 3
```

## Project Structure

```
proxmox/
├── ansible/
│   ├── inventory.ini          # Auto-generated inventory
│   └── playbook.yaml          # Kubernetes installation playbook
├── config/                    # Configuration files
├── docs/                      # Documentation
├── examples/                  # Kubernetes manifests and examples
│   ├── nginx-deployment.yaml
│   ├── dashboard-deployment.yaml
│   └── README.md
├── scripts/
│   └── k8s-setup.sh          # Deployment automation script
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── output.tf                  # Output definitions
├── providers.tf               # Provider configurations
├── terraform.tfvars           # Variable values
└── README.md                  # This file
```

## Examples

### Deploy Sample Applications

```bash
# Deploy nginx
kubectl apply -f examples/nginx-deployment.yaml

# Deploy Kubernetes Dashboard
kubectl apply -f examples/dashboard-deployment.yaml

# Get dashboard token
kubectl -n kubernetes-dashboard create token admin-user
```

### Scale Applications

```bash
# Scale nginx deployment
kubectl scale deployment nginx-deployment --replicas=5

# Check status
kubectl get deployments
kubectl get pods
```

## Troubleshooting

### Common Issues

1. **VMs not getting IP addresses**
   - Check Proxmox network configuration
   - Verify template VM has proper network settings

2. **Ansible connection failures**
   - Ensure SSH keys are properly configured
   - Check inventory file for correct IP addresses

3. **Kubernetes nodes not joining**
   - Check firewall rules on Proxmox host
   - Verify network connectivity between nodes

### Useful Commands

```bash
# Check Terraform state
terraform show

# Check Ansible inventory
ansible all -i ansible/inventory.ini -m ping

# Check Kubernetes cluster status
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Cleanup

To destroy all resources:

```bash
# Using the script
./scripts/k8s-setup.sh cleanup

# Or manually
terraform destroy
```

## Security Considerations

- Change default passwords and tokens
- Configure proper RBAC policies
- Use network policies for pod-to-pod communication
- Regularly update Kubernetes and container images
- Enable audit logging for production clusters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review Kubernetes and Terraform documentation
