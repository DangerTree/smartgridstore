#!/bin/bash

: ${CLUSTER:=ceph}
: ${CEPH_CLUSTER_NETWORK:=${CEPH_PUBLIC_NETWORK}}
: ${CEPH_DAEMON:=${1}} # default daemon to first argument
: ${CEPH_GET_ADMIN_KEY:=0}
: ${HOSTNAME:=$(hostname -s)}
: ${MON_NAME:=${HOSTNAME}}
: ${NETWORK_AUTO_DETECT:=0}
: ${MDS_NAME:=mds-${HOSTNAME}}
: ${OSD_FORCE_ZAP:=0}
: ${OSD_JOURNAL_SIZE:=100}
: ${CRUSH_LOCATION:=root=default host=${HOSTNAME}}
: ${CEPHFS_CREATE:=0}
: ${CEPHFS_NAME:=cephfs}
: ${CEPHFS_DATA_POOL:=${CEPHFS_NAME}_data}
: ${CEPHFS_DATA_POOL_PG:=8}
: ${CEPHFS_METADATA_POOL:=${CEPHFS_NAME}_metadata}
: ${CEPHFS_METADATA_POOL_PG:=8}
: ${RGW_NAME:=${HOSTNAME}}
: ${RGW_ZONEGROUP:=}
: ${RGW_ZONE:=}
: ${RGW_CIVETWEB_PORT:=8080}
: ${RGW_REMOTE_CGI:=0}
: ${RGW_REMOTE_CGI_PORT:=9000}
: ${RGW_REMOTE_CGI_HOST:=0.0.0.0}
: ${RESTAPI_IP:=0.0.0.0}
: ${RESTAPI_PORT:=5000}
: ${RESTAPI_BASE_URL:=/api/v0.1}
: ${RESTAPI_LOG_LEVEL:=warning}
: ${RESTAPI_LOG_FILE:=/var/log/ceph/ceph-restapi.log}
: ${KV_TYPE:=etcd} # valid options: consul, etcd or none
: ${KV_PORT:=4001} # PORT 8500 for Consul
: ${CLUSTER_PATH:=ceph-config/${CLUSTER}}
export KV_IP=$(netstat -nr | grep '^0\.0\.0\.0' | awk '{print $2}')

function log {
  if [ -z "$*" ]; then
    return 1
  fi

  TIMESTAMP=$(date '+%F %T')
  echo "${TIMESTAMP}  $0: $*"
  return 0
}

echo "$KV_IP mongo.local" >> /etc/hosts
echo "$KV_IP btrdb.local" >> /etc/hosts

#inherited from ceph container
source /config.kv.sh

# pull config and ceph key
get_config
get_admin_key

ETCDCTL_ENDPOINT=""
for srv in $CLUSTER_INFO
do
  arr=(${srv//,/ })
  nodename=${arr[0]}
  eip=${arr[1]}
  iip=${arr[2]}
  if [ -n "$ETCDCTL_ENDPOINT" ]; then
    ETCDCTL_ENDPOINT=${ETCDCTL_ENDPOINT},
  fi
  ETCDCTL_ENDPOINT=${ETCDCTL_ENDPOINT}http://$iip:2379
done
export ETCDCTL_ENDPOINT
set +ex
touch /etc/sync/upmuconfig.ini
ln -s /etc/sync/upmuconfig.ini

: ${BTRDB_HTTP_ENABLED:=true}
: ${BTRDB_HTTP_PORT:=9000}
: ${BTRDB_CAPNP_ENABLED:=true}
: ${BTRDB_CAPNP_PORT:=4410}
: ${BTRDB_BLOCK_CACHE:=500000}
: ${BTRDB_MONGO_COLLECTION:=btrdb}
: ${BTRDB_EARLY_TRIP:=16384}
: ${BTRDB_INTERVAL:=5000}
: ${BTRDB_STORAGE_PROVIDER:=ceph}
: ${BTRDB_FILEPATH:=/srv/btrdb}
: ${BTRDB_CEPHCONF:=/etc/ceph/ceph.conf}
: ${BTRDB_CEPHPOOL:=btrdb}

if [ -z "$BTRDB_MONGO_SERVER" ]
then
  echo "Using default BTRDB_MONGO_SERVER"
  BTRDB_MONGO_SERVER=$KV_IP:27017
fi

cat >btrdb.conf <<EOF
[storage]
provider=${BTRDB_STORAGE_PROVIDER}
filepath=${BTRDB_FILEPATH}
cephconf=${BTRDB_CEPHCONF}
cephpool=${BTRDB_CEPHPOOL}

[http]
enabled=${BTRDB_HTTP_ENABLED}
port=${BTRDB_HTTP_PORT}
address=0.0.0.0

[capnp]
enabled=${BTRDB_CAPNP_ENABLED}
port=${BTRDB_CAPNP_PORT}
address=0.0.0.0

[mongo]
server=${BTRDB_MONGO_SERVER}
collection=${BTRDB_MONGO_COLLECTION}

[cache]
blockcache=${BTRDB_BLOCK_CACHE}

radosreadcache=256
radoswritecache=256

[coalescence]
earlytrip=${BTRDB_EARLY_TRIP}
interval=${BTRDB_INTERVAL}
EOF

if [[ $1 = "makedb" ]]
then
  echo "making database"
  btrdbd -makedb
  exit 0
fi

if [[ $1 = "ceph" ]]
then
  shift 1
  ceph --cluster $CLUSTER $@
  exit 0
fi
if [[ $1 = "adm" ]]
then
  ./upmu-adm
  ./manager2lite.py
  exit 0
fi
if [[ $1 = "etcdctl" ]]
then
  shift 1
  etcdctl $@
  exit 0
fi
bash -i
