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

mkdir -p /opt/monitoring/prometheus /opt/monitoring/grafana
mkdir -p /etc/environment.d

cat >/opt/monitoring/docker-compose.yml <<'COMPOSE'
${docker_compose_yml}
COMPOSE

cat >/opt/monitoring/prometheus/prometheus.yml <<'PROMCFG'
${prometheus_yml}
PROMCFG

cat >/etc/environment.d/99-grafana.env <<EOF
GF_SECURITY_ADMIN_USER=${grafana_admin_user}
GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_pass}
EOF

export GF_SECURITY_ADMIN_USER="${grafana_admin_user}"
export GF_SECURITY_ADMIN_PASSWORD="${grafana_admin_pass}"

cd /opt/monitoring
retry docker compose pull
retry docker compose up -d
