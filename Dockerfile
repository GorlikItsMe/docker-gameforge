# Remote desktop (Webtop / Selkies) + umu-launcher + Gameforge autostart helpers
FROM lscr.io/linuxserver/webtop:debian-xfce

ENV TITLE="Remote desktop"

USER root

# https://github.com/Open-Wine-Components/umu-launcher — official .deb for Debian 13 (Trixie)
# python3-umu-launcher depends on 32-bit Mesa userspace libs.
RUN \
  dpkg --add-architecture i386 && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libegl-mesa0 \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386 \
    libglx-mesa0 \
    libglx-mesa0:i386 \
    libgles2 \
    libvulkan1 \
    mesa-vulkan-drivers \
    && \
  UMU_VER=$(curl -fsSL https://api.github.com/repos/Open-Wine-Components/umu-launcher/releases/latest \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -fsSL -o /tmp/umu-launcher.deb \
    "https://github.com/Open-Wine-Components/umu-launcher/releases/download/${UMU_VER}/umu-launcher_${UMU_VER}-1_all_debian-13.deb" && \
  curl -fsSL -o /tmp/python3-umu-launcher.deb \
    "https://github.com/Open-Wine-Components/umu-launcher/releases/download/${UMU_VER}/python3-umu-launcher_${UMU_VER}-1_amd64_debian-13.deb" && \
  apt-get install -y /tmp/umu-launcher.deb /tmp/python3-umu-launcher.deb && \
  rm -f /tmp/*.deb && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Gameforge installer autostart via /etc/xdg/autostart (.desktop must not be executable). Strip CRLF for Windows checkouts.
COPY root/ /
RUN sed -i 's/\r$//' \
      /usr/local/bin/gameforge-autostart.sh \
      /usr/local/bin/run-gameforge-client.sh \
      /etc/chromium.d/gameforge-webgl && \
    chmod +x /usr/local/bin/gameforge-autostart.sh /usr/local/bin/run-gameforge-client.sh && \
    chmod 644 /etc/xdg/autostart/gameforge-autostart.desktop /etc/chromium.d/gameforge-webgl
