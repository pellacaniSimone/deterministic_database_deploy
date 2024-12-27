#!/usr/bin/bash

# Various setup
chsh -s /usr/bin/bash
chmod +x /root/*.sh
mkdir -p /root/OUT/

# Variable passing
ls /root/variabile_count/ | echo  >> /etc/cluster_count.conf

# Static network
mv /root/rc.runnet /etc/rc.runnet
chmod +x /etc/rc.runnet

# etcd setup
mv /root/etcd.yaml /etc/etcd.yaml
mkdir -p /var/lib/etcd
chown etcd:etcd -R /var/lib/etcd
rm -rf /var/lib/etcd/* # Security clean state
cat <<'EOF' > /etc/sv/etcd/run 
#!/bin/sh
exec 2>&1

export ETCD_DATA_DIR=/var/lib/etcd
export ETCD_NAME=etcd

[ -r conf ] && . ./conf
exec chpst -u etcd:etcd etcd --config-file=/etc/etcd.yaml --quota-backend-bytes=8589934592 --max-txn-ops=10000 --max-request-bytes=4194304
EOF

# Juicefs mount and various
mkdir -p /var/lib/juicefs/cache
mv /root/juice_mount_manual   /usr/bin/juice_mount_manual
chmod +x /usr/bin/juice_mount_manual

# PostgreSQL setup
mkdir -p /var/lib/postgresql16/
rm -rf /var/lib/postgresql16/*
chmod 0700 /var/lib/postgresql16
# mv /root/recovery.conf /var/lib/postgresql16/data/recovery.conf # Post sync fs PG <=12

# Keepalived setup
mkdir -p /etc/keepalived/
mv /root/check_pgsql.sh /etc/keepalived/check_pgsql.sh
mv /root/keepalived.conf /etc/keepalived/keepalived.conf
chmod +x /etc/keepalived/check_pgsql.sh

# Cluster manager (personalized script for cluster management)
mv /root/cluster_manager   /usr/bin/cluster_manager
chmod +x /usr/bin/cluster_manager

# Generate dynamic configuration for runnet, SQLite, hosts, etcd
hostname=$(hostname)
NUM=$(ls /root/variabile_count/)
MAX_NODES=$NUM

function configure_cluster() {
  if [[ $hostname =~ [^0-9]*([0-9]{1,3})$ ]]; then
    numero="${BASH_REMATCH[1]}"
    if (( numero >= 1 && numero <= 250 )); then

      # Update /etc/rc.runnet
      sed -i "s|10\.133\.133\.NUM/24|10.133.133.$numero/24|g" /etc/rc.runnet # internal
      sed -i "s|192\.168\.32\.NUM/24|192.168.32.$numero/24|g" /etc/rc.runnet # dmz

      # Update /etc/hosts
      echo "Updating /etc/hosts..."
      for i in $(seq 1 $NUM); do
        riga="10.133.133.${i} prodVoidPGcls${i}.local.lan prodVoidPGcls${i}"
        grep -q "^${riga}$" /etc/hosts || echo "$riga" >> /etc/hosts # avoid duplicates
      done

      # Configure etcd
      echo "Configuring etcd..."
      sed -i "s|prodVoidPGclsNUM|prodVoidPGcls$numero|g" /etc/etcd.yaml
      sed -i "s|10\.133\.133\.NUM|10.133.133.$numero|g" /etc/etcd.yaml

      initial_cluster=""
      for i in $(seq 1 $MAX_NODES); do
        initial_cluster+="prodVoidPGcls${i}=http://10.133.133.${i}:2380"
        if [ "$i" -ne "$MAX_NODES" ]; then
          initial_cluster+=","
        fi
      done
      sed -i "s|LISTA_NODI|$initial_cluster|g" /etc/etcd.yaml
    fi
  fi
}
configure_cluster

function setup_static_ip(){
  cat /etc/rc.runnet | grep ip | while read -r line; do eval "$line"; done
}
setup_static_ip
# Now we can enable etcd in next script

function set_rc_local(){
  mv /root/rc.local /etc/rc.local
  chmod +x /etc/rc.local
  echo "rc.local ok" >> /var/log/install_cluster.log
}

set_rc_local

echo "0-moving-files ok" >> /var/log/install_cluster.log

# Successful execution
mv /root/0-moving-files_perm.sh /root/OUT/0-moving-files_perm.sh