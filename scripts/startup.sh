#!/bin/bash
set -euo pipefail

# OpenClaw VM Startup Script
# This script runs on VM boot via cloud-init

LOG_FILE="/var/log/openclaw-startup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== OpenClaw Startup Script ==="
echo "Started at: $(date)"

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
echo "Installing dependencies..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Install Docker
echo "Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create openclaw user
echo "Creating openclaw user..."
if ! id -u openclaw &>/dev/null; then
    useradd -m -s /bin/bash openclaw
    usermod -aG docker openclaw
fi

# Create directories
OPENCLAW_HOME="/home/openclaw"
mkdir -p "$OPENCLAW_HOME/.openclaw"
mkdir -p "$OPENCLAW_HOME/docker"
mkdir -p "$OPENCLAW_HOME/config"

# Write environment file
echo "Writing environment configuration..."
cat > "$OPENCLAW_HOME/.env" <<'ENVEOF'
ANTHROPIC_API_KEY=${anthropic_api_key}
GATEWAY_TOKEN=${gateway_token}
TELEGRAM_BOT_TOKEN=${telegram_bot_token}
ENVEOF

# Write OpenClaw configuration
echo "Writing OpenClaw configuration..."
cat > "$OPENCLAW_HOME/config/openclaw.json" <<'CONFIGEOF'
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-20250514"
  },
  "channels": {
    "whatsapp": {
      "enabled": true
    },
    "telegram": {
      "enabled": true
    }
  }
}
CONFIGEOF

# Write Dockerfile
echo "Writing Dockerfile..."
cat > "$OPENCLAW_HOME/docker/Dockerfile" <<'DOCKEREOF'
FROM node:22-bookworm-slim

RUN npm install -g openclaw@latest

RUN useradd -m -s /bin/bash openclaw

WORKDIR /home/openclaw

USER openclaw

EXPOSE 18789

CMD ["openclaw", "gateway", "--port", "18789"]
DOCKEREOF

# Write docker-compose.yml
echo "Writing docker-compose.yml..."
cat > "$OPENCLAW_HOME/docker/docker-compose.yml" <<'COMPOSEEOF'
services:
  gateway:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: openclaw-gateway
    ports:
      - "18789:18789"
    volumes:
      - openclaw-data:/home/openclaw/.openclaw
      - ../config/openclaw.json:/home/openclaw/.openclaw/config.json:ro
    env_file:
      - ../.env
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:18789/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  openclaw-data:
COMPOSEEOF

# Set ownership
chown -R openclaw:openclaw "$OPENCLAW_HOME"

# Create systemd service for auto-start
echo "Creating systemd service..."
cat > /etc/systemd/system/openclaw.service <<'SERVICEEOF'
[Unit]
Description=OpenClaw Gateway
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=openclaw
WorkingDirectory=/home/openclaw/docker
ExecStart=/usr/bin/docker compose up -d --build
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start the service
systemctl daemon-reload
systemctl enable openclaw.service
systemctl start openclaw.service

echo "=== OpenClaw Startup Complete ==="
echo "Finished at: $(date)"
echo "Gateway should be available at port 18789"
