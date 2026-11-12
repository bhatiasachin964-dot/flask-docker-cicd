#!/bin/bash
# EC2 start-up script for the flask-docker-cicd demo (Amazon Linux 2023, x86_64).
# Installs Docker, starts the app behind Nginx, and re-pulls the newest image every 2 minutes.
# No SSH keys or secrets are needed.
# Status: syntax-checked only. Not yet run end to end on a live EC2 instance.
set -euxo pipefail

dnf install -y docker git
systemctl enable --now docker

mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

git clone https://github.com/bhatiasachin964-dot/flask-docker-cicd.git /opt/flask-docker-cicd
cd /opt/flask-docker-cicd
echo "APP_IMAGE=ghcr.io/bhatiasachin964-dot/flask-docker-cicd:latest" > .env

cat > /usr/local/bin/flask-update.sh <<'SCRIPT'
#!/bin/bash
# Pull the newest code and image, then (re)start the stack. Safe to run repeatedly.
cd /opt/flask-docker-cicd || exit 1
git pull --ff-only || true
docker compose pull || true      # if the image is not public yet, compose falls back to building locally
docker compose up -d --remove-orphans
docker image prune -f
SCRIPT
chmod +x /usr/local/bin/flask-update.sh

cat > /etc/systemd/system/flask-update.service <<'UNIT'
[Unit]
Description=Update and start the flask-docker-cicd stack
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/flask-update.sh
UNIT

cat > /etc/systemd/system/flask-update.timer <<'UNIT'
[Unit]
Description=Run the flask-docker-cicd update every 2 minutes

[Timer]
OnBootSec=30s
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now flask-update.timer
systemctl start flask-update.service
