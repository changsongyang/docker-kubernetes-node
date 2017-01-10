#!/bin/bash

echo "Stopping Docker..."
systemctl stop docker

echo "Make sure Fan Networking is installed."
echo "apt-get update && apt-get install -y ubuntu-fan"
echo 

# Find primary interface 
PRIMARY=`ip route get 1 | awk '{print $NF;exit}'`
UNDERLAY="${PRIMARY}/16"
OVERLAY="250.0.0.0/8"
IFS=. read ip1 ip2 ip3 ip4 <<< "$PRIMARY"
DOCKER_CIDR="250.$ip3.$ip4.0/24"

# Name of the bridge (should match /etc/default/docker).
DOCKER_BRIDGE=kbr0

echo "PRIMARY=$PRIMARY"
echo "UNDERLAY=$UNDERLAY"
echo "OVERLAY=$OVERLAY"
echo "DOCKER_BRIDGE=$DOCKER_BRIDGE"
echo "DOCKER_CIDR=$DOCKER_CIDR"

# Fan bridge
fanctl down -e
fanctl up -u $UNDERLAY -o $OVERLAY --bridge=$DOCKER_BRIDGE
fanctl show
rm -r /var/lib/docker/network/files/local-kv.db

# Restart Docker daemon to use the new DOCKER_BRIDGE
DOCKER_OPTS="--bridge=kbr0 --fixed-cidr=$DOCKER_CIDR --mtu=1450 --iptables=false --insecure-registry=0.0.0.0/0 --storage-driver=zfs"

#/etc/systemd/system/docker.service.d/docker.conf
mkdir -p /etc/systemd/system/docker.service.d
printf "[Service]\nExecStart=\nExecStart=/usr/bin/dockerd $DOCKER_OPTS" > /etc/systemd/system/docker.service.d/docker.conf

echo "Restarting Docker..."
systemctl daemon-reload
systemctl restart docker
docker info