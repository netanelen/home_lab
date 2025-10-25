# outputs.tf

# Legacy VM outputs (for backward compatibility)
output "vm_id" {
  description = "The unique ID of the virtual machine."
  value       = var.vm_name != "" ? proxmox_virtual_environment_vm.ubuntu_vm[0].vm_id : null
}

output "vm_name" {
  description = "The name of the virtual machine."
  value       = var.vm_name != "" ? proxmox_virtual_environment_vm.ubuntu_vm[0].name : null
}

output "vm_ip" {
  value = var.vm_name != "" && length(proxmox_virtual_environment_vm.ubuntu_vm) > 0 && length(proxmox_virtual_environment_vm.ubuntu_vm[0].ipv4_addresses) > 1 && length(proxmox_virtual_environment_vm.ubuntu_vm[0].ipv4_addresses[1]) > 0 ? proxmox_virtual_environment_vm.ubuntu_vm[0].ipv4_addresses[1][0] : null
}

# Kubernetes cluster outputs
output "k8s_master_nodes" {
  description = "Kubernetes master node information"
  value = {
    for idx, master in proxmox_virtual_environment_vm.k8s_masters : 
    master.name => {
      vm_id = master.vm_id
      ip    = length(master.ipv4_addresses) > 1 && length(master.ipv4_addresses[1]) > 0 ? master.ipv4_addresses[1][0] : "IP not yet assigned"
      name  = master.name
    }
  }
}

output "k8s_worker_nodes" {
  description = "Kubernetes worker node information"
  value = {
    for idx, worker in proxmox_virtual_environment_vm.k8s_workers : 
    worker.name => {
      vm_id = worker.vm_id
      ip    = length(worker.ipv4_addresses) > 1 && length(worker.ipv4_addresses[1]) > 0 ? worker.ipv4_addresses[1][0] : "IP not yet assigned"
      name  = worker.name
    }
  }
}

output "k8s_cluster_info" {
  description = "Kubernetes cluster summary"
  value = {
    cluster_name = var.k8s_cluster_name
    master_count = var.k8s_master_nodes
    worker_count = var.k8s_worker_nodes
    pod_cidr     = var.k8s_pod_cidr
    service_cidr = var.k8s_service_cidr
    k8s_version  = var.k8s_version
  }
}

output "k8s_master_ip" {
  description = "Primary master node IP (for kubectl access)"
  value       = length(proxmox_virtual_environment_vm.k8s_masters) > 0 && length(proxmox_virtual_environment_vm.k8s_masters[0].ipv4_addresses) > 1 && length(proxmox_virtual_environment_vm.k8s_masters[0].ipv4_addresses[1]) > 0 ? proxmox_virtual_environment_vm.k8s_masters[0].ipv4_addresses[1][0] : null
}
