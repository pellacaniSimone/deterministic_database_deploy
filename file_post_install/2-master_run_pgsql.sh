#!/usr/bin/bash

# Check if JuiceFS is mounted
if ! grep -q 'juice' /etc/mtab ; then
    sleep 1
    mount -a
fi

# Initialize database if master node
if cat /etc/mtab | grep juice  ; then
  if [[ -f /IM_THE_MASTER   ]]; then
    bash /root/manual_init_db.sh
    mv /root/2-master_run_pgsql.sh /root/OUT/2-master_run_pgsql.sh # only on successful run
  else
    touch /var/log/postgresql16.log
    chown postgres:postgres -R /var/lib/postgresql16 /tmp /var/log/postgresql16.log
    mv /root/2-master_run_pgsql.sh /root/OUT/2-master_run_pgsql.sh
  fi
else
  echo "PLEASE INITIALIZE DB MANUALLY with manual_init_db.sh" >> /var/log/postgresql16.log
fi 

echo "2-master_run_pgsql ok" >> /var/log/install_cluster.log