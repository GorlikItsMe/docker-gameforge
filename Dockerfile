# Docker Gameforge - VNC Image with Wine, Corefonts and Gameforge Installer
FROM scottyhardy/docker-wine:latest

USER root

# Enable 32-bit architecture for Wine 32-bit support
# OPTIONAL
# RUN dpkg --add-architecture i386 && apt-get update
RUN apt-get update

# Install VNC, noVNC, desktop environment and tools
RUN apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    tigervnc-viewer \
    websockify \
    novnc \
    xfce4 \
    xfce4-terminal \
    dbus-x11 \
    x11-apps \
    imagemagick \
    xdotool \
    curl \
    && rm -rf /var/lib/apt/lists/*

# If you want you can add this to command above
    # region OPTIONAL STUFF
    # OpenGL and graphics libraries for Wine Direct3D support (64-bit and 32-bit)
    # libgl1 \
    # libgl1:i386 \
    # libgl1-mesa-dri \
    # libgl1-mesa-dri:i386 \
    # libegl1 \
    # libegl1:i386 \
    # libvulkan1 \
    # libvulkan1:i386 \
    # mesa-vulkan-drivers \
    # mesa-vulkan-drivers:i386 \
    # # GStreamer plugins for H.264 video support (64-bit and 32-bit)
    # gstreamer1.0-plugins-good \
    # gstreamer1.0-plugins-good:i386 \
    # gstreamer1.0-plugins-bad \
    # gstreamer1.0-plugins-bad:i386 \
    # gstreamer1.0-plugins-ugly \
    # gstreamer1.0-plugins-ugly:i386 \
    # gstreamer1.0-libav \
    # gstreamer1.0-libav:i386 \
    # gstreamer1.0-vaapi \
    #endregion OPTIONAL STUFF

# Configure VNC
RUN mkdir -p /root/.vnc && \
    echo "#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4" > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup && \
    touch /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create noVNC symlink
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Download Gameforge Installer at build time
# To change URL, modify the URL below and rebuild
RUN mkdir -p /app && \
    curl -L -o /app/GameforgeInstaller.exe \
    "https://install.gameforge.com/download?download_id=7ec0f5a5-21a3-41c6-8b4d-df8831ead6a8&game_id=df8661d6-a76e-417f-82dc-9fada569615e&locale=pl" \
    && chmod 644 /app/GameforgeInstaller.exe

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# Initialize Wine and install corefonts during build (not runtime)
ENV WINEPREFIX=/root/.wine32
ENV WINEARCH=win32
RUN wine wineboot --init && \
    winetricks -q corefonts

EXPOSE 5901 6080

ENV DISPLAY=:1
ENV VNC_SERVER=yes

ENTRYPOINT ["/usr/local/bin/entrypoint"]
