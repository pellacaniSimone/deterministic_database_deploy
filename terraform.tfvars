#####################################################################
#                      setup target
#####################################################################

# IP4 and hostname target with proxmox server
endpoint = "172.16.0.70"
pve_target_host = "pvenas07"

# Login username target @ domain
username = "root@pam"

# Number of containers to deploy
container_count = 2

# VM/container name
hostname = "prodVoidPGcls"

# VM/container template
target_os_image = "template:vztmpl/void-x86_64-ROOTFS-20240314.tar.xz" # glibc
type_os_image = "unmanaged"

# SSH access
key_list = <<-EOT
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJvc8QXxsFIkCCx9c9xs574xJgMGZFaRI4OO6zvnnkOb6A48qBqNSfARLK6WvK9Fo0Cx2rbyzDHKRVfv/X8Nph7iaduC6mgiEjK9bXSce17CKgqFvBVn4zkPnfPmUL/6WAMag+MRSyaDzYWBVF6VZOyw2eKSCdKnwf4DvxfULiqvNVSm46Q9/Lxq3fcdC7Mjvu7gcH1OG28mGAngWNqG97XH7sXKz53SC/Vbyay1npMUVsX8wOXnWs5494KbD+TKmyAg7UznRId/d1WTxiTEu2uKIKmpxwfIc4i0x+tnqnTMXice2KVPURp0OBXXB0ATgdrvGH58zQG9x9Q1ZCKA57kfv2AKI87r30sx1ZnkLVrVObCb4fz7C2ScUwa8l9RW4q7HuxbV8dpAepSx+3jxDjJKxdbDcsqUIzFBW3dIZkD3EQvoqPLpDJCZFHx/QxzdSSELg2R5Xp6MOa9gledhfoNTxNxxSEvtDYt/AE7a3YRsSiTvQTSglh/AUfB10Klj0= unigithub@xps9510
  EOT

# Installation procedure
procedura = [
    "xbps-install -Syu",
    "xbps-install -Syu  nano etcd curl openssl screen sqlite sqlite-devel",
    "bash /root/0-moving-files_perm.sh",
    "ln -s /etc/sv/etcd /var/service", # etcd up and running
    "xbps-install -y  curl openssl ",
    "curl -sSL https://d.juicefs.com/install | sh -",
    "bash /root/1-setup_filesystem.sh",
    "if ! cat /etc/mtab | grep juice ; then     sleep 3;     mount -a; fi",
    "xbps-install -y  postgresql postgresql-client",
    "bash /root/2-master_run_pgsql.sh",
    "xbps-install -y keepalived ",
    "ln -s /etc/sv/keepalived /var/service ", # use with cluster_manager <Wanted state> to start o stop, initially stop
    "sv restart sshd", # avoid error "kex_exchange_identification",
]

