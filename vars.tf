#####################################################################
#                      input var
#####################################################################

# Input variables

# Define password variable
variable "proxmox_password_input" {
  description = "Enter the password for root@pam account on Proxmox"
  type        = string
  sensitive   = true
}

#####################################################################
#                      Var tfvars
#####################################################################

variable "endpoint" {
    type=string
  }

variable "pve_target_host" {
    type=string
  }

variable "username" {
    type=string
  }


variable "hostname" {
    type=string
  }

variable "target_os_image" {
    type=string
  }

variable "type_os_image" {
    type=string
  }

variable "key_list" {
    type=string
  }

variable "procedura" {
    type=list
  }

variable "container_count" {
    type = number
    description = "Number of containers to deploy"
}