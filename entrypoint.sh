#!/bin/bash
set -e

# Docker Gameforge - Entrypoint

echo "=========================================="
echo "🎮 Docker Gameforge"
echo "=========================================="


# Start VNC
if [ "$VNC_SERVER" = "yes" ]; then
    echo "🖥️  Starting VNC..."
    vncserver :1 -geometry 1024x768 -depth 24 -SecurityTypes None 2>&1 || true
    sleep 2
    websockify --web=/usr/share/novnc --cert=none 6080 localhost:5901 &
    echo "✅ http://localhost:6080/vnc.html"
    export DISPLAY=:1
fi

# Run Gameforge Installer
echo ""
echo "🚀 Starting Gameforge Installer..."
echo "=========================================="

# Create logs directory (mounted as volume)
mkdir -p /app/logs

# Run installer with Wine logs redirected to file
exec wine "/app/GameforgeInstaller.exe" >>/app/logs/wine-gameforge-installer.log 2>&1
