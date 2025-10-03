variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token" {
  type = string
}

variable "target_node" {
  type = string  
}

variable "chemin_cttemplate" {
  description = "chemin iso ct template"
  type = string
  
}

variable "lxc_linux" {
  type = map(object({
    name = string
    lxc_id = number
    password = string
    cores = number
    memory = number
    nameserver = string
    storage = string
    disk_size = string
    dhcp = optional (bool)
    ipconfig0 = optional (string)
    gw = optional (string)
    network_bridge = string
  }))
  
}

variable "win_srv" {
  type = map(object({
    name = string
    vmid = number
    memory = number
    cores = number
    storage = string
    size = string
    network_bridge = string
    ipconfig0 = optional (string)
    dns = optional (string)
    dhcp = optional (bool)
  }))
  
}
