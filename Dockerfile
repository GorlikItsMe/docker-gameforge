# Remote desktop (Webtop / Selkies) + umu-launcher + Gameforge autostart helpers
FROM lscr.io/linuxserver/webtop:debian-xfce

ENV TITLE="Gameforge Client"

USER root

# https://github.com/Open-Wine-Components/umu-launcher — official .deb for Debian 13 (Trixie)
# python3-umu-launcher depends on 32-bit Mesa userspace libs.
RUN \
  dpkg --add-architecture i386 && \
  apt-get update && \
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" | debconf-set-selections && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fonts-croscore \
    fonts-liberation \
    fonts-noto-color-emoji \
    libegl-mesa0 \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386 \
    libglx-mesa0 \
    libglx-mesa0:i386 \
    libgles2 \
    libvulkan1 \
    mesa-vulkan-drivers \
    ttf-mscorefonts-installer \
    wine \
    wine32 \
    winetricks \
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
      /usr/local/bin/run-wine-explorer.sh \
      /usr/local/bin/resolve-proton-wine.sh \
      /usr/local/bin/run-winetricks.sh \
      /usr/local/bin/xfce-panel-autostart.sh \
      /etc/chromium.d/gameforge-webgl && \
    chmod +x /usr/local/bin/gameforge-autostart.sh \
      /usr/local/bin/run-gameforge-client.sh \
      /usr/local/bin/run-wine-explorer.sh \
      /usr/local/bin/resolve-proton-wine.sh \
      /usr/local/bin/run-winetricks.sh \
      /usr/local/bin/xfce-panel-autostart.sh && \
    chmod 644 /etc/xdg/autostart/gameforge-autostart.desktop \
      /etc/xdg/autostart/xfce-panel.desktop \
      /etc/chromium.d/gameforge-webgl
