# OpenClaw + ScaDS.AI Setup on TUD Research Cloud

This repository contains a complete setup for running OpenClaw in Docker on a Debian 13 VM in the TUD Research Cloud using the ScaDS.AI OpenAI-compatible API.

Default model:

- `Qwen/Qwen3-Coder-30B-A3B-Instruct`

All configured models:

- google/gemma-4-31B-it
- meta-llama/Llama-3.1-8B-Instruct
- meta-llama/Llama-3.3-70B-Instruct
- MiniMaxAI/MiniMax-M2.5
- moonshotai/Kimi-K2.6
- openai/gpt-oss-120b
- openGPT-X/Teuken-7B-instruct-v0.6
- Qwen/Qwen3-Coder-30B-A3B-Instruct
- Qwen/Qwen3-VL-8B-Instruct

---

# Architecture

```text
MacBook
   │
   │ eduVPN
   ▼
TUD Research Cloud VM (Debian 13)
   │
   ├── Docker
   │     └── OpenClaw
   │
   └── ScaDS.AI Gateway
         https://llm.scads.ai/v1
```

---

# Requirements

## Local Machine

- eduVPN installed and connected to TUD
- Browser

## VM

- Debian 13
- Docker
- Docker Compose Plugin

Recommended:

- 2–4 vCPUs
- 4–8 GB RAM
- 20 GB storage

No GPU required.

---

# Install Docker

Update system:

```bash
sudo apt update && sudo apt upgrade -y
```

Install dependencies:

```bash
sudo apt install -y ca-certificates curl gnupg lsb-release
```

Add Docker GPG key:

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Add Docker repository:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker:

```bash
sudo apt update

sudo apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin
```

Enable Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Optional: Docker without sudo

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Verify installation:

```bash
docker --version
docker compose version
```

---

# Project Structure

```text
openclaw/
├── config/
│   └── openclaw.json
├── workspace/
├── docker-compose.yml
├── .env.example
├── .env
├── .gitignore
└── README.md
```

---

# Quick Setup

From the VM:

```bash
cd ~/openclaw
mkdir -p config workspace
cp .env.example .env
nano .env
```

Set:

```env
SCADS_API_KEY=your_scads_api_key_here
OPENCLAW_GATEWAY_TOKEN=your_secure_random_token
RESEARCH_CLOUD_IP=YOUR_VM_PRIVATE_IP
```

Find the VM IP with:

```bash
hostname -I
```

Generate the gateway token with:

```bash
openssl rand -hex 32
```

Before starting Docker, let both your VM user and the container user write the
mounted config and workspace. This keeps ownership with your VM user while
granting OpenClaw's container user access:

```bash
sudo apt install -y acl
sudo chown -R $(id -u):$(id -g) .
sudo setfacl -R -m u:1000:rwX -m u:$(id -u):rwX config workspace
sudo setfacl -R -d -m u:1000:rwX -m u:$(id -u):rwX config workspace
```

Start OpenClaw:

```bash
docker compose up -d
```

Verify that OpenClaw is reading this repository's config:

```bash
docker compose exec openclaw sh -lc 'ls -l /home/node/.openclaw/openclaw.json'
docker compose logs --tail=80 openclaw | grep -i "agent model\|scads\|qwen\|openai"
```

The logs should show a ScaDS model such as:

```text
agent model: tud-scads/Qwen/Qwen3-Coder-30B-A3B-Instruct
```

---

# Environment Variables

`.env` contains:

```env
SCADS_API_KEY=your_scads_api_key_here
OPENCLAW_GATEWAY_TOKEN=your_secure_random_token
RESEARCH_CLOUD_IP=YOUR_VM_PRIVATE_IP
```

You can set the VM IP automatically:

```bash
echo "RESEARCH_CLOUD_IP=$(hostname -I | awk '{print $1}')" >> .env
```

---

# OpenClaw Configuration

The ScaDS model configuration lives at:

```text
config/openclaw.json
```

Docker mounts `./config` to `/home/node/.openclaw` inside the container, so
OpenClaw reads this host file as:

```text
/home/node/.openclaw/openclaw.json
```

---

# Docker Compose

Create:

```bash
nano docker-compose.yml
```

Contents:

```yaml
services:
   openclaw:
      image: ghcr.io/openclaw/openclaw:latest

      container_name: openclaw

      restart: unless-stopped

      ports:
         - '${RESEARCH_CLOUD_IP}:18789:18789'

      environment:
         SCADS_API_KEY: ${SCADS_API_KEY}
         RESEARCH_CLOUD_IP: ${RESEARCH_CLOUD_IP}
         OPENCLAW_GATEWAY_BIND: lan
         OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}

      volumes:
         - ./config:/home/node/.openclaw
         - ./workspace:/home/node/.openclaw/workspace
```

Do not mount the config to `/opt/openclaw/config` or `/home/openclaw/config`;
OpenClaw will start, but it will ignore this ScaDS configuration and fall back
to the default OpenAI model list.

---

# Start OpenClaw

```bash
sudo chown -R $(id -u):$(id -g) .
sudo setfacl -R -m u:1000:rwX -m u:$(id -u):rwX config workspace
sudo setfacl -R -d -m u:1000:rwX -m u:$(id -u):rwX config workspace
docker compose up -d
```

Check logs:

```bash
docker compose logs -f
```

Check running containers:

```bash
docker ps
```

---

# Access OpenClaw

Connect to eduVPN on your Mac.

Find VM IP:

```bash
hostname -I
```

Open in browser:

```text
http://YOUR_VM_PRIVATE_IP:18789
```

Example:

```text
http://10.42.17.23:18789
```

Enter your `OPENCLAW_GATEWAY_TOKEN`.

Alternatively, keep the gateway reachable only through SSH from your Mac:

```bash
ssh -N -L 18789:YOUR_VM_PRIVATE_IP:18789 service@YOUR_VM_PRIVATE_IP
```

Then open:

```text
http://127.0.0.1:18789
```

After changing `RESEARCH_CLOUD_IP`, recreate OpenClaw so the container
receives the updated environment:

```bash
docker compose down
docker compose up -d --force-recreate
```

---

# Firewall

Recommended with UFW:

```bash
sudo apt install -y ufw
```

Allow only private/VPN access:

```bash
sudo ufw allow from 10.0.0.0/8 to any port 18789
```

Enable firewall:

```bash
sudo ufw enable
```

---

# Update OpenClaw

```bash
docker compose pull
docker compose up -d
```

---

# Restart

```bash
docker compose restart
```

---

# Stop

```bash
docker compose down
```

---

# Troubleshooting

## Cannot access UI

Check:

- eduVPN connected
- Docker container running
- Correct VM IP
- Firewall allows port 18789
- If using SSH tunneling, open `http://127.0.0.1:18789`, not the VM IP URL

Useful checks:

```bash
docker compose ps
ss -ltnp | grep 18789
docker compose logs --tail=80 openclaw
```

---

## Browser-Origin not allowed

The gateway rejected the Control UI before token auth because the browser URL
does not exactly match `gateway.controlUi.allowedOrigins`.

Fix:

1. Copy the origin from the browser address bar. Include `http://` or
   `https://` and the port if one is shown. Do not include a path.
2. Add that exact origin to `config/openclaw.json` under
   `gateway.controlUi.allowedOrigins`.
3. Recreate the gateway so config and environment changes are applied:

```bash
docker compose up -d --force-recreate openclaw
```

Examples:

```json
"allowedOrigins": [
  "http://localhost:18789",
  "http://127.0.0.1:18789",
  "http://${RESEARCH_CLOUD_IP}:18789"
]
```

---

## Gateway connection fails with EACCES

If logs contain:

```text
EACCES: permission denied, mkdir '/home/node/.openclaw/devices'
```

the container cannot write runtime state into the mounted config directory.

Fix:

```bash
cd ~/openclaw
sudo apt install -y acl
sudo chown -R $(id -u):$(id -g) .
sudo setfacl -R -m u:1000:rwX -m u:$(id -u):rwX config workspace
sudo setfacl -R -d -m u:1000:rwX -m u:$(id -u):rwX config workspace
docker compose down
docker compose up -d --force-recreate
```

Verify:

```bash
docker compose exec openclaw sh -lc 'test -w /home/node/.openclaw && echo writable'
```

---

# Notes

- Models are executed remotely via ScaDS.AI.
- No local GPU inference required.
- Qwen3-Coder-30B is configured as the default model due to strong coding and reasoning performance.
- The gateway is exposed only on the VM private interface for secure eduVPN access.

---

# Useful Links

- OpenClaw:
  https://github.com/openclaw/openclaw

- ScaDS.AI:
  https://llm.scads.ai/

- Docker:
  https://docs.docker.com/

- eduVPN:
  https://eduvpn.org/
