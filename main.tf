provider "proxmox" {
  endpoint  = var.endpoint
  api_token = var.proxmox_api_token
}

provider "random" {
  # Configuration options
}

resource "random_integer" "id4vm" {
  min = 1000
  max = 9999
}


# Master/Control Plane Nodes
resource "proxmox_virtual_environment_vm" "k8s_masters" {
  count       = var.k8s_master_nodes
  name        = "${var.k8s_cluster_name}-master-${count.index + 1}"
  description = "Kubernetes Master Node ${count.index + 1} - Managed by Terraform"
  tags        = ["terraform", "kubernetes", "master"]

  node_name = var.node_name
  vm_id     = var.template_vm_id + 100 + count.index
  template  = false

  clone {
    vm_id    = var.template_vm_id
    node_name = var.template_node
    full     = true
  }

  agent {
    enabled = true
    timeout = "5m"
  }
  stop_on_destroy = true

  cpu {
    cores = var.k8s_master_cpu
    type  = var.cpu_model
  }

  memory {
    dedicated = var.k8s_master_memory
  }

  network_device {
    bridge = var.network_device
  }
}

# Worker Nodes
resource "proxmox_virtual_environment_vm" "k8s_workers" {
  count       = var.k8s_worker_nodes
  name        = "${var.k8s_cluster_name}-worker-${count.index + 1}"
  description = "Kubernetes Worker Node ${count.index + 1} - Managed by Terraform"
  tags        = ["terraform", "kubernetes", "worker"]

  node_name = var.node_name
  vm_id     = var.template_vm_id + 200 + count.index
  template  = false

  clone {
    vm_id    = var.template_vm_id
    node_name = var.template_node
    full     = true
  }

  agent {
    enabled = true
    timeout = "5m"
  }
  stop_on_destroy = true

  cpu {
    cores = var.k8s_worker_cpu
    type  = var.cpu_model
  }

  memory {
    dedicated = var.k8s_worker_memory
  }

  network_device {
    bridge = var.network_device
  }
}

# Legacy single VM support (for backward compatibility)
resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  count       = var.vm_name != "" ? 1 : 0
  name        = var.vm_name
  description = "Managed by Terraform"
  tags        = ["terraform", "ByAPI"]

  node_name = var.node_name
  vm_id     = random_integer.id4vm.id
  template  = false

  clone {
    vm_id    = var.template_vm_id
    node_name = var.template_node
    full     = true
  }

  agent {
    enabled = true
    timeout = "5m"
  }
  stop_on_destroy = true

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_model
  }

  memory {
    dedicated = var.memory_size
  }

  network_device {
    bridge = var.network_device
  }
}

resource "local_file" "ansible_inventory" {
  content = <<-EOT
[all]
%{ for master in proxmox_virtual_environment_vm.k8s_masters ~}
%{ if length(master.ipv4_addresses) > 1 && length(master.ipv4_addresses[1]) > 0 ~}
${master.name} ansible_host=${master.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${master.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}
%{ for worker in proxmox_virtual_environment_vm.k8s_workers ~}
%{ if length(worker.ipv4_addresses) > 1 && length(worker.ipv4_addresses[1]) > 0 ~}
${worker.name} ansible_host=${worker.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${worker.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}
%{ for vm in proxmox_virtual_environment_vm.ubuntu_vm ~}
%{ if length(vm.ipv4_addresses) > 1 && length(vm.ipv4_addresses[1]) > 0 ~}
${vm.name} ansible_host=${vm.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${vm.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}

[k8s_masters]
%{ for master in proxmox_virtual_environment_vm.k8s_masters ~}
%{ if length(master.ipv4_addresses) > 1 && length(master.ipv4_addresses[1]) > 0 ~}
${master.name} ansible_host=${master.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${master.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}

[k8s_workers]
%{ for worker in proxmox_virtual_environment_vm.k8s_workers ~}
%{ if length(worker.ipv4_addresses) > 1 && length(worker.ipv4_addresses[1]) > 0 ~}
${worker.name} ansible_host=${worker.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${worker.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}

[k8s_cluster:children]
k8s_masters
k8s_workers

[vms]
%{ for vm in proxmox_virtual_environment_vm.ubuntu_vm ~}
%{ if length(vm.ipv4_addresses) > 1 && length(vm.ipv4_addresses[1]) > 0 ~}
${vm.name} ansible_host=${vm.ipv4_addresses[1][0]} ansible_user=netanele ansible_ssh_private_key_file=~/.ssh/id_rsa-key
%{ else ~}
# ${vm.name} - IP address not yet assigned
%{ endif ~}
%{ endfor ~}
EOT
  filename = "${path.module}/ansible/inventory.ini"
}
