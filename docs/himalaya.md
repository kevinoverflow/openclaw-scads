# Himalaya Email CLI Module

This optional module installs the Himalaya email CLI inside the OpenClaw Docker container and mounts a separate email configuration directory.

It covers two account types:

* TU Dresden Exchange / mailbox account
* Gmail account

## Docker Image

Create `Dockerfile` in the repository root:

```Dockerfile
FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && curl -sSL https://raw.githubusercontent.com/pimalaya/himalaya/master/install.sh | sh

USER node
```

Update `docker-compose.yml`:

```yaml
services:
  openclaw:
    build: .
    image: openclaw-himalaya:latest
    container_name: openclaw
    restart: unless-stopped

    ports:
      - "${RESEARCH_CLOUD_IP}:18789:18789"

    environment:
      SCADS_API_KEY: ${SCADS_API_KEY}
      RESEARCH_CLOUD_IP: ${RESEARCH_CLOUD_IP}
      OPENCLAW_GATEWAY_BIND: lan
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}

    volumes:
      - ./config:/home/node/.openclaw
      - ./workspace:/home/node/.openclaw/workspace
      - ./himalaya:/home/node/.config/himalaya
```

## Himalaya Config

Create the config directory:

```bash
cd ~/openclaw
mkdir -p himalaya/passwords
nano himalaya/config.toml
```

Paste this template:

```toml
[accounts.tud]
email = "YOUR_TUD_EMAIL"

folder.aliases.inbox = "INBOX"
folder.aliases.sent = "Sent Items"
folder.aliases.drafts = "Drafts"
folder.aliases.trash = "Deleted Items"

backend.type = "imap"
backend.host = "msx.tu-dresden.de"
backend.port = 143
backend.encryption.type = "start-tls"
backend.login = "YOUR_ZIH_LOGIN"
backend.auth.type = "password"
backend.auth.cmd = "cat /home/node/.config/himalaya/passwords/tud"

message.send.backend.type = "smtp"
message.send.backend.host = "msx.tu-dresden.de"
message.send.backend.port = 587
message.send.backend.encryption.type = "start-tls"
message.send.backend.login = "YOUR_ZIH_LOGIN"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "cat /home/node/.config/himalaya/passwords/tud"


[accounts.gmail]
default = true
email = "YOUR_GMAIL_ADDRESS"

folder.aliases.inbox = "INBOX"
folder.aliases.sent = "[Gmail]/Sent Mail"
folder.aliases.drafts = "[Gmail]/Drafts"
folder.aliases.trash = "[Gmail]/Trash"

backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "YOUR_GMAIL_ADDRESS"
backend.auth.type = "password"
backend.auth.cmd = "cat /home/node/.config/himalaya/passwords/gmail"

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.gmail.com"
message.send.backend.port = 465
message.send.backend.encryption.type = "tls"
message.send.backend.login = "YOUR_GMAIL_ADDRESS"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "cat /home/node/.config/himalaya/passwords/gmail"
```

Replace:

* `YOUR_TUD_EMAIL` with your TU Dresden mailbox address
* `YOUR_ZIH_LOGIN` with your ZIH login
* `YOUR_GMAIL_ADDRESS` with your Gmail address

## Password Files

Create one password file per account:

```bash
nano himalaya/passwords/tud
nano himalaya/passwords/gmail
```

For Gmail, use a Google app password, not your normal Google password.

Keep these files out of Git. They should be ignored by `.gitignore`.

## Permissions

OpenClaw needs to own mounted runtime directories so its exec tool can `chmod` them. The VM user still gets access through ACLs.

```bash
cd ~/openclaw
sudo apt install -y acl
sudo chown -R 1000:1000 config workspace himalaya
sudo setfacl -R -m u:$(id -u):rwX config workspace himalaya
sudo setfacl -R -d -m u:$(id -u):rwX config workspace himalaya
```

If you keep password files mode-restricted, also grant the container user read access:

```bash
chmod 640 himalaya/passwords/*
sudo setfacl -m u:1000:r himalaya/passwords/*
```

## Build And Start

```bash
cd ~/openclaw
docker compose down
docker compose build --no-cache
docker compose up -d --force-recreate
```

## Verify

Check that Himalaya is installed:

```bash
docker compose exec openclaw himalaya --version
```

Check that the config is mounted and readable:

```bash
docker compose exec openclaw sh -lc 'cat /home/node/.config/himalaya/config.toml >/dev/null && echo himalaya-config-readable'
```

List accounts:

```bash
docker compose exec openclaw himalaya account list
```

List inbox messages:

```bash
docker compose exec openclaw himalaya envelope list --account gmail --folder INBOX
docker compose exec openclaw himalaya envelope list --account tud --folder INBOX
```

Check that OpenClaw exec is not blocked:

```bash
docker compose exec openclaw sh -lc 'chmod u+rwx /home/node/.openclaw && echo chmod-ok'
docker compose exec openclaw sh -lc 'echo test'
```

## Troubleshooting

If Himalaya says it cannot find `config.toml`, verify the volume:

```bash
docker compose config | grep -A12 -n "volumes:"
docker compose exec openclaw ls -l /home/node/.config/himalaya/config.toml
```

If reading `config.toml` returns `Permission denied`, reapply the permissions:

```bash
sudo chown -R 1000:1000 himalaya
sudo setfacl -R -m u:$(id -u):rwX himalaya
sudo setfacl -R -d -m u:$(id -u):rwX himalaya
```

If OpenClaw says `exec` is blocked with `EPERM`, reapply ownership for all mounted runtime directories:

```bash
sudo chown -R 1000:1000 config workspace himalaya
sudo setfacl -R -m u:$(id -u):rwX config workspace himalaya
sudo setfacl -R -d -m u:$(id -u):rwX config workspace himalaya
docker compose down
docker compose up -d --force-recreate
```
