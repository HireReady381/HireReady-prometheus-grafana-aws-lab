#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

retry() {
  local attempts=10
  local sleep_seconds=10
  local n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [ "$n" -ge "$attempts" ]; then
      echo "Command failed after $attempts attempts: $*" >&2
      return 1
    fi
    echo "Retry $n/$attempts failed, sleeping $${sleep_seconds}s: $*" >&2
    n=$((n + 1))
    sleep "$sleep_seconds"
  done
}

retry apt-get update
retry apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
retry curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list

retry apt-get update
retry apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

retry docker pull prom/node-exporter:latest

if ! docker ps -a --format '{{.Names}}' | grep -qx 'node-exporter'; then
  docker run -d \
    --name node-exporter \
    --restart unless-stopped \
    --net=host \
    --pid=host \
    -v /:/host:ro,rslave \
    prom/node-exporter:latest \
    --path.rootfs=/host
else
  docker start node-exporter || true
fi
