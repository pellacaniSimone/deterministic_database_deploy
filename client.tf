#####################################################################
#                      client
#####################################################################


terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9.11"
    }
  }
}


#####################################################################
#                      login struct
#####################################################################


# Client configuration

# Proxmox provider configured to request password
provider "proxmox" {
  pm_api_url       = "https://${var.endpoint}:8006/api2/json"
  pm_user          = var.username
  pm_password      = var.proxmox_password_input  # Usa la variabile della password
  pm_tls_insecure  = true  
}

