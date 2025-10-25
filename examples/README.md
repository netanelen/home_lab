# Kubernetes Examples

This directory contains example Kubernetes manifests and configurations for your Proxmox Kubernetes cluster.

## Examples Included

### 1. nginx-deployment.yaml
A simple nginx deployment with 3 replicas and a LoadBalancer service.

**Usage:**
```bash
kubectl apply -f nginx-deployment.yaml
kubectl get pods
kubectl get services
```

### 2. dashboard-deployment.yaml
Kubernetes Dashboard deployment with admin user configuration.

**Usage:**
```bash
kubectl apply -f dashboard-deployment.yaml
kubectl get pods -n kubernetes-dashboard
kubectl get services -n kubernetes-dashboard
```

**Access Dashboard:**
```bash
# Get the token for admin user
kubectl -n kubernetes-dashboard create token admin-user

# Access via NodePort (replace <master-ip> with your master node IP)
# https://<master-ip>:30443
```

## Common kubectl Commands

### Cluster Information
```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes

# Get all pods
kubectl get pods --all-namespaces
```

### Deployments
```bash
# Create deployment
kubectl create deployment nginx --image=nginx

# Scale deployment
kubectl scale deployment nginx --replicas=3

# Get deployments
kubectl get deployments

# Delete deployment
kubectl delete deployment nginx
```

### Services
```bash
# Expose deployment as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get services
kubectl get services

# Get service details
kubectl describe service nginx
```

### Namespaces
```bash
# Create namespace
kubectl create namespace my-namespace

# Get namespaces
kubectl get namespaces

# Set default namespace
kubectl config set-context --current --namespace=my-namespace
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Check Node Status
```bash
kubectl get nodes
kubectl describe node <node-name>
```

### Check Cluster Events
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Useful Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)
