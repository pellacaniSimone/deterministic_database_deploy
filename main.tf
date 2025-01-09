#####################################################################
#                      lxc setup
#####################################################################
resource "proxmox_lxc" "basic" {
    count               = var.container_count
    target_node         = var.pve_target_host      
    hostname            = "${var.hostname}${count.index + 1}"             
    description         = "terraform provisioned on ${timestamp()}"    
    ostemplate          = var.target_os_image
    ostype              = var.type_os_image
    #password            = "terraform"
    unprivileged        = true
    memory              = 1024
    swap                = 50
    vmid                = null
    start               = true
    onboot              = false

    ssh_public_keys = var.key_list

  rootfs {
    storage = "drive"
    size    = "8G"
  }

  # intranet "management WEB UI"
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
    ip6     = "dhcp"
  }


  # cluster network "host internal"
  network {
    name   = "eth1"
    bridge = "vmbr3"
    ip     = "10.133.133.${count.index + 1}/24"
    gw     = "10.133.133.254"
  }


  # DMZ
  network {
    name   = "eth2"
    bridge = "vmbr2"
    ip     = "dhcp"
    ip6     = "dhcp"
  }


    features {
        fuse    = true
        #nesting = true
        mount   = "nfs;cifs"
        #nesting = true
    }
}

#####################################################################
#                      Setup SSH for each container
#####################################################################


data "external" "get_vmid" {
    count      = var.container_count
    depends_on = [proxmox_lxc.basic]
    program = [
        "bash", 
        "-c", 
        "VMID=$(ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct list | grep '${var.hostname}${count.index + 1}' | cut -f1 -d' ' | tr -d '\\n')&&  echo -n \"{\\\"vmid\\\": \\\"$VMID\\\"}\""
    ]
}

resource "null_resource" "wait1_openssh" {
  count      = var.container_count
  depends_on = [data.external.get_vmid]  
  provisioner "local-exec" {
    command = "sleep 8"
  }
}

resource "null_resource" "wait1_din_var" {
  count      = var.container_count
  depends_on = [null_resource.wait1_openssh]  
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} mkdir -p /tmp/variabile_count "
  }
}

resource "null_resource" "add_openssh" {
  count      = var.container_count
  depends_on = [null_resource.wait1_openssh]  
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- xbps-install openssh  || true"
  }
}

resource "null_resource" "wait2_openssh_dhcp_configure" {
  count      = var.container_count
  depends_on = [null_resource.add_openssh] 
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- sed -i 's/^#hostname/hostname/' /etc/dhcpcd.conf "
  }
}

resource "null_resource" "run_network_dhcp" {
  count      = var.container_count
  depends_on = [null_resource.wait2_openssh_dhcp_configure] 
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- ln -s /etc/sv/dhcpcd-eth0 /var/service/dhcpcd-eth0"
  }
}

resource "null_resource" "start_openssh" {
  count      = var.container_count
  depends_on = [null_resource.run_network_dhcp] 
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- ln -s /etc/sv/sshd /var/service/ && sleep 4"
  }
}

# not provided by proxmox here on void
resource "null_resource" "create_ssh_dir" {
  count = var.container_count
  depends_on = [null_resource.start_openssh]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N '' -q "
  }
}

resource "null_resource" "add_authorized_keys" {
  count = var.container_count
  depends_on = [null_resource.create_ssh_dir]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint} pct exec ${data.external.get_vmid[count.index].result.vmid} -- mkdir -p /root/variabile_count && sleep 2" # on cnt
  }
}

resource "null_resource" "set_authorized_keys" {
  count = var.container_count
  depends_on = [null_resource.add_authorized_keys]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint}  pct push ${data.external.get_vmid[count.index].result.vmid} /root/.ssh/authorized_keys /root/.ssh/authorized_keys  "
  }
}


resource "null_resource" "sshd_restart" {
  count = var.container_count
  depends_on = [null_resource.set_authorized_keys]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint}  pct exec  ${data.external.get_vmid[count.index].result.vmid} -- sv restart sshd "
  }
}


resource "null_resource" "create_file" {
  count      = var.container_count
  depends_on = [null_resource.sshd_restart] 
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint}  touch /tmp/variabile_count/${var.container_count} "
  }
}

resource "null_resource" "push_count" {
  count = var.container_count
  depends_on = [null_resource.create_file]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.endpoint}  pct push ${data.external.get_vmid[count.index].result.vmid} /tmp/variabile_count/${var.container_count} /root/variabile_count/${var.container_count}  "
  }
}

resource "null_resource" "move_files" {
  count      = var.container_count
  depends_on = [null_resource.push_count] 
  provisioner "local-exec" {
    command = "sleep 2 && scp -o StrictHostKeyChecking=no ./file_post_install/* root@${var.hostname}${count.index + 1}.local.lan:/root/"
  }
}


#####################################################################
#           Run post install script named "procedura"
#####################################################################


resource "null_resource" "post_install" {
    count      = var.container_count
    depends_on = [null_resource.move_files]

    provisioner "remote-exec" {
        inline = var.procedura

        connection {
            agent       = false
            type        = "ssh"
            user        = "root"
            private_key = file("~/.ssh/id_rsa")
            host        = "${var.hostname}${count.index + 1}.local.lan"
        }
    }
}







