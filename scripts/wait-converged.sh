#!/usr/bin/env bash
# Runs ON the Swarm manager: waits until every service of a stack finished its rolling update.
# usage: wait-converged.sh <stack> [timeout-seconds]
stack="$1"; timeout="${2:-240}"; end=$((SECONDS + timeout))
while [ "$SECONDS" -lt "$end" ]; do
  ok=1
  while read -r name repl; do
    cur="${repl%%/*}"; want="${repl##*/}"
    state=$(docker service inspect --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{else}}none{{end}}' "$name")
    echo "$name replicas=$repl update=$state"
    [ "$cur" = "$want" ] || ok=0
    case "$state" in
      updating) ok=0 ;;
      rollback_*|paused) echo "FAILED: $name ended in state $state"; exit 1 ;;
    esac
  done < <(docker stack services "$stack" --format '{{.Name}} {{.Replicas}}')
  [ "$ok" = 1 ] && { echo "All services converged."; exit 0; }
  echo "--- waiting..."; sleep 5
done
echo "Timed out waiting for stack $stack"; exit 1
