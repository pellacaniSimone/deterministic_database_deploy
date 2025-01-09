#!/usr/bin/bash

# Configuration variables
PG_PIDFILE="/var/lib/postgresql16/data/postmaster.pid"
PG_DATA="/var/lib/postgresql16/data"
PG_LOG="/var/log/postgresql16.log" 
PG_MASTER="/IM_THE_MASTER"
CLUSTER_STATE_FILE="/var/lib/postgresql16/data/cls_state.shared"

# Wrapper for pg_ctl
function pg_switch_state() {
    su - postgres -c "/usr/bin/pg_ctl -D $PG_DATA -l $PG_LOG $1"
}

# Etcd master provided
function determine_master() {
    LOCAL_HOSTNAME=$(hostname)
    LOCAL_IP=$(grep "$LOCAL_HOSTNAME" /etc/hosts | awk '{print $1}')
    ETCDCTL_API=3 etcdctl --endpoints=http://${LOCAL_IP}:2380 \
        endpoint status --write-out=table | cut -d '|' -f2,6 | grep true
    if [[ $? -eq 0 ]]; then
        touch "$PG_MASTER" || true
        chmod 777 "$PG_MASTER"
    else
        rm -f "$PG_MASTER" || true
    fi
}

# Check PostgreSQL running state
# 0=master, 1=all down, 2=master ready, 3=slave
function postgresql_running_status() {
    # Using shared pidfile
    if [[ -f "$PG_PIDFILE" ]]; then
        pg_switch_state status
        return $? # 0 master, 3 slave
    fi
    if [[ -f "$PG_MASTER" ]]; then  # Master rump up
        chown -R postgres:postgres  $PG_DATA
        chown postgres:postgres /tmp
        return 2 # Master rump up
    fi
    return 1 # Cluster all down (no pg_pidfile and no pg_master)
}


# Change cluster running state
function mod_cls_state() {
    if ! grep -q juice /etc/mtab; then
        [[ -f "$PG_MASTER" ]] && rm "$PG_MASTER"
        sleep 3
        mount -a
    fi
}

# Check cluster running state
function check_cluster_state() {
    if [[ ! -f "$CLUSTER_STATE_FILE" ]]; then
        echo "ERROR: File $CLUSTER_STATE_FILE non trovato."
        exit 1
    fi

    local CLS_WSTATE=$(cat "$CLUSTER_STATE_FILE")
    postgresql_running_status

    case "$CLS_WSTATE" in
        STOP)
            case "$?" in # 0=master, 1=all down, 2=master ready, 3=slave
                0|2) echo "INFO: Stopping cluster with STOP signal."
                     pg_switch_state stop
                     exit 0 ;;
                3)   exit 0 ;; # slave is already stopped, do nothing
                1)   echo "INFO: All nodes down, desired state."
                     sleep 3 # slow check
                     exit 0 ;;
                *)   echo "ERROR: Unknown state during STOP."
                     exit 1 ;;
            esac ;;
        START)
            case "$?" in # 0=master, 1=all down, 2=master ready, 3=slave
                0)   echo "INFO: Master started, state ok."
                     exit 0 ;;
                1)   echo "INFO: Non-compliant state, Cluster all Down, wanted Start."
                     exit 0 ;; # pass to rump up
                2)   echo "INFO: Starting master in START state."
                     pg_switch_state start
                     exit 0 ;;
                3)   exit 0 ;; # slave is already stopped, do nothing
                *)   echo "INFO: Cluster state compliant with START."
                     exit 0 ;;
            esac ;;
        *)
            echo "ERROR: Unrecognized state $CLS_WSTATE."
            exit 1 ;;
    esac
}

# Main function
function send_keepalive_signal() {
    mod_cls_state
    determine_master
    check_cluster_state
}

# Start main function
send_keepalive_signal
