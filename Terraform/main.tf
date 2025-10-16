# génération de la clé SSH pour les conteneurs LXC
resource "tls_private_key" "lxc_ssh_key" {
  for_each = var.lxc_linux
  algorithm = "ED25519"
}

# Enregistrement de la clé privée SSH dans un fichier local
resource "local_file" "private_key" {

  for_each = var.lxc_linux

 content  = tls_private_key.lxc_ssh_key[each.key].private_key_openssh
 filename = pathexpand("~/.ssh/${each.value.name}-ed25519")
 file_permission = "0600"
}





# Création des conteneurs LXC avec les configurations définies dans la variable lxc_linux
resource "proxmox_lxc" "lxc_linux" {

  for_each = var.lxc_linux

  target_node      = var.target_node
  hostname         = each.value.name
  vmid             = each.value.lxc_id
  ostemplate       = var.chemin_cttemplate
  password         = each.value.password
  unprivileged     = true
  onboot           = true
  start            = true
  cores            = each.value.cores
  memory           = each.value.memory
  ssh_public_keys  = tls_private_key.lxc_ssh_key[each.key].public_key_openssh
  dns              = each.value.dns
  service          = each.value.service
  ostype           = each.value.ostype

  rootfs {
    storage = each.value.storage
    size    = each.value.disk_size
  }

  network {
   name     = "eth0"
   bridge   = each.value.network_bridge
   dhcp     = each.value.dhcp    
   ip       = each.value.ipconfig0
   gw       = each.value.gw
   firewall = false
  }


  features {
    nesting = true
  }
}




resource "proxmox_vm_qemu" "winsrv" {

  for_each = var.win_srv

  name        = each.value.name
  vmid        = each.value.vmid

  clone       = "WinTemplate"
  full_clone  = true
  onboot      = true
  agent = 1
  agent_timeout = 300
  bios        = "ovmf"
  scsihw      = "virtio-scsi-single"
  boot        = "order=scsi0;ide1"
  target_node = var.target_node
  service     = each.value.service
  ostype     = each.value.ostype 


  memory      = each.value.memory

  cpu {
    cores   = each.value.cores
    sockets = 1
  }

  # Disque principal SCSI (slot = scsi0)
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = each.value.storage
    size    = each.value.disk_size
    cache   = "writeback"
  }

  # Disque Cloud-Init 
  disk {
    slot    = "ide1"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = each.value.network_bridge
  }

  serial {
      id   = 0
      type = "socket"
    }

  ipconfig0  = each.value.ipconfig0
  dns        = each.value.dns 

output "vms" {
  value = merge(
    { for name, vm in proxmox_lxc.lxc_linux : name => {
        ip      = vm.network[0].ip
        os      = vm.ostype
        service = vm.service
        user    = "root"
        ssh_key = pathexpand("~/.ssh/${vm.hostname}-ed25519")
      }
    },
    { for name, vm in proxmox_vm_qemu.winsrv : name => {
        ip      = vm.ipconfig0
        os      = vm.ostype
        service = vm.service
        user    = "Administrator"
      }
    }
  )
}
