# Database Cluster Setup with JuiceFS and PostgreSQL


I needed a solid database for my personal lab that was more robust than a single node. This project is absolutely not production-ready, but if you want, you are free to use this deployment method, draw inspiration for your personal projects, contribute, or redesign the setup by modifying its components. Every constructive contribution is welcome.


## Project Overview

This project sets up a deterministic database cluster using a replicated filesystem and a NoSQL service. The architecture consists of:

- **JuiceFS**: A distributed filesystem that provides synchronization for database folders.
- **etcd**: A distributed key-value store that serves as the NoSQL service, optimized for stability rather than speed.
- **PostgreSQL**: A robust SQL database management system (DBMS) that will be used for data storage.

The overall architecture can be summarized as:
**DATABASE** over **Replicated Filesystem** over **NoSQL**.

## Prerequisites

Before starting the installation, ensure you have the following:

- A fully working **Proxmox VE 8.3** or above.
- Automatic DNS dynamic add for direct and reverse DNS to ensure that `get_vmid` in `main.tf` works.
- SSH access to the Proxmox VE with the public key added to the `authorized_keys` on the host.
- Network access to download all required software packages.
- A voidlinux in your PVE template folder downloadable from [here](https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20240314.tar.xz)

## Installation Process

The installation process is defined in the `procedura` variable within the Terraform configuration files. Below are the steps involved in the installation:

1. **Update System Packages**:
   - The system is updated to ensure all packages are current.

2. **Install Required Packages**:
   - Essential packages such as `nano`, `etcd`, `curl`, `openssl`, `screen`, `sqlite`, and `sqlite-devel` are installed.

3. **Setup Filesystem**:
   - The JuiceFS filesystem is initialized and mounted.

4. **Install PostgreSQL**:
   - PostgreSQL and its client are installed.

5. **Configure Keepalived**:
   - Keepalived is set up for high availability (HA) of the PostgreSQL service.

6. **Run Post-Installation Scripts**:
   - Various scripts are executed to finalize the setup, including configuring the database and setting up synchronization.

## Modifying `terraform.tfvars`

To customize your setup, you may need to modify the `terraform.tfvars` file. Here are the key variables you can change:

- **Change the Proxmox Node**:
  - Update the `endpoint` and `pve_target_host` variables to point to your desired Proxmox node.

- **Change the Number of Deployed Containers**:
  - Adjust the `container_count` variable to specify how many containers you want to deploy.

- **Change the Cluster Hostname**:
  - Modify the `hostname` variable to set a new cluster hostname. 
  - **Note**: Search for this hostname throughout the project files to ensure consistency. 
  - **To Do**: Implement a script or tool to automate the search and replace of the hostname across all relevant files.

- **Change the Front-End IP Network**:
  - Update the IP address in the `keepalived.conf` file (e.g., change `172.16.1.4`).
  - **To Do**: Create a script to automate the update of the IP address in the configuration files.

## Project Structure

The project consists of several key files and directories:

- **Terraform Files**:
  - `client.tf`: Configuration for the Proxmox provider and login structure.
  - `vars.tf`: Definition of input variables used in the Terraform setup.
  - `main.tf`: Main configuration for setting up LXC containers and resources.

- **Post-Installation Scripts**:
  - `file_post_install/`: Contains scripts for setting up the environment, including database initialization, filesystem setup, and service management.

## To Do Checklist

- [ ] Review and test the installation process.
- [ ] Ensure all scripts are executable and have the correct permissions.
- [ ] Validate the configuration files for correctness.
- [ ] Set up monitoring for the PostgreSQL service.
- [ ] Document any additional configurations or customizations made.
- [ ] Create a backup strategy for the database and filesystem.
- [ ] Test failover scenarios with Keepalived.
- [ ] Optimize performance settings for PostgreSQL and JuiceFS.
- [ ] Implement a script to automate the replace of the hostname across all project files.
- [ ] Write a YouTube video documentation.
- [ ] Create a script to automate the update of the front-end IP address in configuration files.
- [ ] Add gracefully start and stop with something like function below, do it manually for each node in events like migrations.

```sh
# Stopping safetely
function secure_stop() {
    pg_switch_state stop && \
    sv stop keepalived && \
    umount $PG_DATA && \
    sv stop etcd
}

# Starting safetely
function secure_start() {
    sv start etcd && sleep 1 && sv status etcd && \
    mount $PG_DATA && \
    sv stop keepalived && \
    pg_switch_state start
}

```



# Visualization schema

```lua
           +-----------+   +-----------+   +-----------+
           | Node 1    |   | Node 2    |   | Node 3    |
           |  (LXC)    |   |  (LXC)    |   |  (LXC)    |
           +-----------+   +-----------+   +-----------+
                   |               |                |
                   +---------------+----------------+
                                   |
                 +-----------------v-----------------+
                 |         Etcd Cluster              |
                 |      (Non-relational DB)          |
                 |  +-----------+  +-----------+     |
                 |  |  Etcd 1   |  |  Etcd 2   |     |
                 |  +-----------+  +-----------+     |
                 |                 +-----------+     |
                 |                 |  Etcd 3   |     |
                 |                 +-----------+     |
                 +-----------------+-----------------+
                                   |
                                   v
                    +---------------------------+
                    |        JuiceFS            |
                    | (Distributed Filesystem)  |
                    +---------------------------+
                                   |
                                   v
                        +-------------------+
                        |  PostgreSQL (Pg)  |
                        |(Relational Engine)|
                        +-------------------+


```


## Licenses

This project and its components are subject to the following licenses:

- **JuiceFS**: [JuiceFS License](https://juicefs.com/docs/juicefs-license)
- **etcd**: [etcd License](https://github.com/etcd-io/etcd/blob/main/LICENSE)
- **PostgreSQL**: [PostgreSQL License](https://www.postgresql.org/about/licence/)
- **Terraform**: [Terraform License](https://github.com/hashicorp/terraform/blob/main/LICENSE)

Please ensure compliance with these licenses when using or modifying the software.

## Conclusion

This project provides a robust setup for a database cluster using a replicated filesystem and a NoSQL service. By leveraging JuiceFS and PostgreSQL, the architecture ensures data stability and synchronization across multiple nodes. Follow the installation process outlined above to set up your environment.

For any issues or contributions, please feel free to open an issue or submit a pull request.

---

# Reference Guides
## terraform
- https://www.alexdarbyshire.com/2024/02/automating-vm-creation-on-proxmox-terraform-bpg/
- https://registry.terraform.io/providers/Telmate/proxmox/2.9.11/docs/resources/lxc
- https://pve.proxmox.com/pve-docs/pve-admin-guide.html#pct_startup_and_shutdown
- https://www.slingacademy.com/article/terraform-how-to-execute-shell-bash-scripts/
- https://github.com/trfore/terraform-telmate-proxmox/blob/main/README.md
- https://tcude.net/using-terraform-with-proxmox/

## juicefs
- https://juicefs.com/docs/community/getting-started/installation/
- https://juicefs.com/docs/community/etcd_best_practices/
- https://juicefs.com/docs/community/mount_juicefs_at_boot_time/
- https://juicefs.com/docs/community/security/trash/
- https://juicefs.com/docs/community/command_reference/
- https://juicefs.com/en/blog/usage-tips/how-to-implement-a-distributed-etc-directory-using-etcd-and-juicefs

## postgresql
- https://www.postgresql.org/docs/current/recovery-config.html
- https://www.postgresql.org/docs/current/different-replication-solutions.html
- https://www.postgresql.org/docs/current/app-initdb.html
- https://www.postgresql.org/docs/current/runtime-config-resource.html
- https://www.postgresql.org/docs/current/runtime-config-replication.html
- https://www.postgresql.org/docs/current/runtime-config-wal.html
- https://www.postgresql.org/docs/current/config-setting.html
- https://www.postgresql.org/docs/current/storage-file-layout.html

## etcd
- https://etcd.io/docs/v3.6/tuning/
- https://etcd.io/docs/v3.6/dev-guide/limit/
- https://etcd.io/docs/v3.6/op-guide/clustering/
- https://etcd.io/docs/v3.6/tutorials/how-to-setup-cluster/
- https://github.com/etcd-io/etcd/blob/release-3.5/etcd.conf.yml.sample
- https://etcd.io/docs/v3.6/op-guide/configuration/
- https://etcd.io/docs/v3.6/op-guide/hardware
- https://etcd.io/docs/v3.6/benchmarks/etcd-storage-memory-benchmark/


## voidLinux
- https://docs.voidlinux.org/config/network/index.html
- https://docs.voidlinux.org/xbps/index.html
- https://docs.voidlinux.org/config/services/index.html

## Proxmox
- https://sweworld.net/cheatsheets/proxmox/
- https://ochoaprojects.github.io/posts/DeployingVMsWithTerraformInProxMox/