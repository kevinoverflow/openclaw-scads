FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    poppler-utils \
    python3 \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/tools \
  && /opt/tools/bin/pip install --upgrade pip \
  && /opt/tools/bin/pip install gcalcli pdfplumber \
  && ln -sf /opt/tools/bin/gcalcli /usr/local/bin/gcalcli \
  && ln -sf /opt/tools/bin/python /usr/local/bin/tool-python

RUN curl -sSL https://raw.githubusercontent.com/pimalaya/himalaya/master/install.sh | sh

USER node
