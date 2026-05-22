# gcalcli Google Calendar Module

This optional module installs `gcalcli` inside the OpenClaw Docker container
and persists Google OAuth tokens outside the container.

Use this for Google Calendar access from OpenClaw tools.

## Docker Image

Create or extend `Dockerfile` in the repository root:

```Dockerfile
FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-venv ca-certificates curl \
  && python3 -m venv /opt/gcalcli \
  && /opt/gcalcli/bin/pip install --upgrade pip gcalcli \
  && ln -sf /opt/gcalcli/bin/gcalcli /usr/local/bin/gcalcli \
  && rm -rf /var/lib/apt/lists/*

USER node
```

If you also use the Himalaya module, combine both install blocks into one
Dockerfile instead of creating two separate images.

Update `docker-compose.yml`:

```yaml
services:
  openclaw:
    build: .
    image: openclaw-tools:latest
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
      - ./gcalcli-config:/home/node/.config/gcalcli
      - ./gcalcli-data:/home/node/.local/share/gcalcli
```

## Google OAuth Setup

Create a Google Cloud OAuth client:

1. Open Google Cloud Console.
2. Enable the Google Calendar API.
3. Configure the OAuth consent screen.
4. Keep the app in testing mode for personal use.
5. Add your Google accounts as test users.
6. Create OAuth credentials with application type `Desktop app`.

Use your Desktop app client ID and client secret with `gcalcli`.

If Google shows an unverified-app warning, add the account as a test user. For
personal use, you usually do not need to publish the app to production.

## Persistent Directories

Create local directories for gcalcli config and OAuth data:

```bash
cd ~/openclaw
mkdir -p gcalcli-config gcalcli-data
```

Apply permissions. OpenClaw needs to own mounted runtime directories so its exec
tool can `chmod` them. The VM user still gets access through ACLs.

```bash
sudo apt install -y acl
sudo chown -R 1000:1000 config workspace gcalcli-config gcalcli-data
sudo setfacl -R -m u:$(id -u):rwX config workspace gcalcli-config gcalcli-data
sudo setfacl -R -d -m u:$(id -u):rwX config workspace gcalcli-config gcalcli-data
```

## Build And Start

```bash
cd ~/openclaw
docker compose down
docker compose build --no-cache
docker compose up -d --force-recreate
```

Verify installation:

```bash
docker exec -it openclaw gcalcli --version
```

## Authenticate

Run:

```bash
docker exec -it openclaw gcalcli \
  --client-id=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com \
  --client-secret='YOUR_CLIENT_SECRET' \
  init
```

Open the Google authorization URL in your Mac browser.

Because `gcalcli` runs inside a remote Docker container, the final redirect to
`http://localhost:RANDOM_PORT/...` may fail in your browser. That is expected:
your Mac's `localhost` is not the container's `localhost`.

When the browser shows `localhost refused to connect`, copy the full URL from
the browser address bar, then run this on the server while `gcalcli init` is
still waiting:

```bash
docker exec openclaw python3 -c 'import sys, urllib.request; print(urllib.request.urlopen(sys.argv[1].replace("localhost", "127.0.0.1")).read().decode())' 'PASTE_FULL_LOCALHOST_URL_HERE'
```

Example shape:

```bash
docker exec openclaw python3 -c 'import sys, urllib.request; print(urllib.request.urlopen(sys.argv[1].replace("localhost", "127.0.0.1")).read().decode())' 'http://localhost:45353/?state=...&code=...&scope=...'
```

The original `gcalcli init` terminal should then complete and store the OAuth
token in `gcalcli-data`.

## Verify Calendar Access

```bash
docker exec -it openclaw gcalcli list
docker exec -it openclaw gcalcli agenda
```

## Re-authenticate Another Google Account

Run `init` again with the same Desktop app client:

```bash
docker exec -it openclaw gcalcli \
  --client-id=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com \
  --client-secret='YOUR_CLIENT_SECRET' \
  init
```

If you use multiple Google accounts, make sure each one is added as a test user
in the OAuth consent screen while the app is in testing mode.

## Troubleshooting

If Google says `redirect_uri_mismatch`, the OAuth client is probably the wrong
type. Create a new OAuth client with application type `Desktop app`.

If Google says app verification is not complete, keep the app in testing mode
and add your Gmail address as a test user.

If the browser fails on `localhost`, use the callback replay command from the
Authenticate section. The port changes every run, so copy the full URL each
time.

If `gcalcli` tokens disappear after recreating the container, verify the data
volume:

```bash
docker compose config | grep -A14 -n "volumes:"
docker exec openclaw sh -lc 'ls -la /home/node/.local/share/gcalcli'
```

If OpenClaw says `exec` is blocked with `EPERM`, reapply ownership for mounted
runtime directories:

```bash
sudo chown -R 1000:1000 config workspace gcalcli-config gcalcli-data
sudo setfacl -R -m u:$(id -u):rwX config workspace gcalcli-config gcalcli-data
sudo setfacl -R -d -m u:$(id -u):rwX config workspace gcalcli-config gcalcli-data
docker compose down
docker compose up -d --force-recreate
```
