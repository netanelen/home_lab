variable "proxmox_api_token" {
  description = "Proxmox API token in the format 'user@realm!token'"
  type        = string
  sensitive   = true
}
variable "endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  sensitive   = true
}
variable "file4_id" {
  description = "The file ID of the ISO image to use for the VM"
  type        = string
  default     = "local:iso/ubuntu-20.04.6-live-server-amd64.iso"
}
variable "node_name" {
  description = "The name of the Proxmox node where the VM will be created"
  type        = string
  default     = "Pprox" # Change this to your actual node name
}
variable "template_vm_id" {
  description = "The VM ID of the template to clone"
  type        = number
  default = 102
}

variable "template_node" {
  description = "The Proxmox node where the template resides"
  type        = string
  default     = "Pprox"
}

variable "vm_name" {
  description = "The name of the VM to create (optional, leave empty for Kubernetes-only deployment)"
  type        = string
  default     = ""
}

variable "cpu_cores" {
  type = number
  default = 2
  validation {
    condition = var.cpu_cores > 0
    error_message = "CPU cores must be greater than 0."
  }
}
variable "cpu_model" {
  type = string
  default = "x86-64-v2-AES"
}


variable "network_device" {
  type = string
  default = "vmbr0"
}


variable "memory_size" {
  type = number
  default = 4096
}

# Kubernetes cluster configuration
variable "k8s_cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "proxmox-k8s"
}

variable "k8s_master_nodes" {
  description = "Number of master/control plane nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.k8s_master_nodes > 0 && var.k8s_master_nodes % 2 == 1
    error_message = "Master nodes must be odd number and greater than 0 for HA."
  }
}

variable "k8s_worker_nodes" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.k8s_worker_nodes >= 0
    error_message = "Worker nodes must be 0 or greater."
  }
}

variable "k8s_pod_cidr" {
  description = "CIDR block for Kubernetes pods"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "k8s_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28"
}

variable "k8s_master_cpu" {
  description = "CPU cores for master nodes"
  type        = number
  default     = 2
}

variable "k8s_master_memory" {
  description = "Memory in MB for master nodes"
  type        = number
  default     = 4096
}

variable "k8s_worker_cpu" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 2
}

variable "k8s_worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 4096
}