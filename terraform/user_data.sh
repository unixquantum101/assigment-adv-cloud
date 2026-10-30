#!/bin/bash
# cloud-init: install Docker on every node.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable --now docker
