#!/usr/bin/bash


#################################
#         PostgreSQL
#################################


function db_file_and_folder() {
  mkdir -p /var/lib/postgresql16/data
  touch /var/log/postgresql16.log
}


function db_permission() {
  chmod 0700 /var/lib/postgresql16/data
  chown postgres:postgres -R /var/lib/postgresql16/data /tmp /var/log/postgresql16.log  
}


function db_initialize() {
  #rsync -avc --progress --bwlimit=50 /tmp/DB/* /var/lib/postgresql16/data/
  su - postgres -c "/usr/lib/psql16/bin/initdb -D /var/lib/postgresql16/data/"
}


function build_config() {

# EOF reads $(statements) as variables
# To read as a literal, please use 'EOF' instead
cat <<'EOF' >> /var/lib/postgresql16/data/pg_hba.conf

# custom config
host     all      all    10.133.133.0/24   trust
host     all      all    172.16.1.0/24     trust
host     all      all    10.0.0.0/24       trust

EOF

# EOF reads $(statements) as variables
# To read as a literal, please use 'EOF' instead
cat <<'EOF' >> /var/lib/postgresql16/data/postgresql.conf

# custom config

# cache setup
shared_buffers = 1GB             # approximately 25-40% of total RAM
work_mem = 16MB                  # memory for each intermediate operation
maintenance_work_mem = 512MB     # memory for maintenance operations like VACUUM or CREATE INDEX
effective_cache_size = 3GB       # estimate of total RAM available for cache

EOF

echo "STOP" > /var/lib/postgresql16/data/cls_state.shared # Initial cluster state: STOP
chown postgres:postgres -R /var/lib/postgresql16/data

}


# Check if JuiceFS is mounted
db_file_and_folder
db_permission
db_initialize
build_config

echo "initdb ok" >> /var/log/install_cluster.log

#mv /root/manual_init_db.sh /root/OUT/manual_init_db.sh