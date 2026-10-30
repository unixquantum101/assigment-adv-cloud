#!/bin/bash
# cloud-init: install Docker on every node (retries because mirrors can be briefly out of sync).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Wait for the apt lock that first-boot updates may hold instead of failing.
echo 'DPkg::Lock::Timeout "600";' > /etc/apt/apt.conf.d/99lock-timeout

retry() {
  for i in 1 2 3 4 5 6; do
    "$@" && return 0
    echo "Attempt $i failed: $*"
    rm -rf /var/lib/apt/lists/*
    sleep 20
  done
  return 1
}

retry apt-get update -y
retry apt-get install -y ca-certificates curl

curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
retry sh /tmp/get-docker.sh

usermod -aG docker ubuntu
systemctl enable --now docker
docker --version