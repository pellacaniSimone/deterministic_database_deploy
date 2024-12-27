#!/usr/bin/bash


#################################
#         juicefs
#################################

# for whaiting etcd
function determine_master(){
  if ip a | grep -q "192.168.32.1/24" ; then 
    touch /IM_THE_MASTER
    chmod 777 /IM_THE_MASTER
  fi
}

determine_master


function initialize_juicefs_service() {
  # Building synchronization string
  MAX_NODES=$(ls /root/variabile_count/)
  sync_string=""
  for i in $(seq 1 $MAX_NODES); do
    sync_string+="10.133.133.$i:2379"
    if [ "$i" -ne "$MAX_NODES" ]; then
      sync_string+=","
    fi
  done
  ip a | grep 192.168.32.1/24
  TEST=$?
  if [[ "$TEST" -eq 0 ]] ; then
    # noup execute in a separate session job 
    nohup /usr/local/bin/juicefs format \
      etcd://$sync_string/jfs --block-size=1M --storage etcd \
      --compress=lz4 --capacity=0 --inodes=0 --trash-days=0  --enable-acl=true \
      --bucket etcd://$sync_string/data postgresql16 >> /var/log/juicefs_format.log 2>&1 &
  fi

  # mount fstab
  echo  "etcd://$sync_string/jfs  /var/lib/postgresql16  juicefs  _netdev  0 0" >> /root/fstab
  nohup /usr/local/bin/juicefs mount \
    --update-fstab etcd://$sync_string/jfs \
    /var/lib/postgresql16 >> /var/log/juicefs_format.log 2>&1 &

  if ! cat /etc/mtab | grep juice ; then     sleep 3;     mount -a; fi
}


initialize_juicefs_service

echo "1-setup_filesystem ok" >> /var/log/install_cluster.log

mv /root/1-setup_filesystem.sh /root/OUT/1-setup_filesystem.sh
