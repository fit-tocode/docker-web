FROM --platform=linux/amd64 ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# ── Desktop + VNC + noVNC ─────────────────────────────────────────────────────
RUN apt-get update && apt-get install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    sudo \
    xterm \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    software-properties-common \
    gnupg \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# ── Firefox via Mozilla PPA ───────────────────────────────────────────────────
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' \
        | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox && \
    apt-get update -y && apt-get install -y firefox xubuntu-icon-theme \
    && rm -rf /var/lib/apt/lists/*

# ── VNC setup ─────────────────────────────────────────────────────────────────
RUN mkdir -p /root/.vnc && \
    touch /root/.Xauthority && \
    printf '#!/bin/bash\nexec startxfce4\n' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# ── Entrypoint ────────────────────────────────────────────────────────────────
RUN cat > /start.sh << 'SCRIPT'
#!/bin/bash
set -e

# Clean up stale locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC on display :1 (port 5901)
vncserver :1 \
    -localhost no \
    -SecurityTypes None \
    -geometry 1280x768 \
    -depth 24 \
    --I-KNOW-THIS-IS-INSECURE

# Self-signed cert for websockify SSL
openssl req -new -subj "/C=JP" -x509 -days 365 -nodes \
    -out /self.pem -keyout /self.pem 2>/dev/null

# Railway injects $PORT — MUST bind to this port
LISTEN_PORT="${PORT:-6080}"
echo "[start] websockify binding to 0.0.0.0:${LISTEN_PORT}"

# Run websockify in FOREGROUND (keeps container alive)
exec websockify \
    --web=/usr/share/novnc/ \
    --cert=/self.pem \
    --heartbeat=30 \
    0.0.0.0:${LISTEN_PORT} \
    localhost:5901
SCRIPT
RUN chmod +x /start.sh

EXPOSE 6080

CMD ["/start.sh"]
