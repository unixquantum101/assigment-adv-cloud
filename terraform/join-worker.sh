#!/usr/bin/env bash
# usage: join-worker.sh <private-key> <manager-public-ip> <worker-public-ip> <manager-private-ip>
set -euo pipefail
KEY="$1"; MGR="$2"; WRK="$3"; MGR_PRIV="$4"
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

echo "Waiting for $WRK to accept SSH and finish cloud-init..."
until $SSH "ubuntu@$WRK" 'cloud-init status --wait >/dev/null 2>&1; true'; do sleep 5; done

TOKEN=$($SSH "ubuntu@$MGR" 'sudo docker swarm join-token -q worker')
$SSH "ubuntu@$WRK" "sudo docker swarm join --token $TOKEN $MGR_PRIV:2377 || true"
echo "Worker $WRK joined the swarm."
