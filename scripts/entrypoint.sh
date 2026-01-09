#!/bin/bash
# =============================================================================
# Antigravity Docker - Entrypoint Script
# =============================================================================
# This script initializes the container environment and starts all services
# =============================================================================

set -e

echo "==========================================="
echo "  Antigravity Remote Docker"
echo "  Starting container initialization..."
echo "==========================================="

# =============================================================================
# Validate VNC Password
# =============================================================================
if [ -z "${VNC_PASSWORD}" ]; then
    echo "ERROR: VNC_PASSWORD environment variable is not set!"
    echo "Please set a secure password in your .env file or docker-compose.yml"
    exit 1
fi

if [ ${#VNC_PASSWORD} -lt 8 ]; then
    echo "WARNING: VNC password is shorter than 8 characters!"
    echo "This is considered weak. Please use a stronger password."
    echo "Continuing in 5 seconds..."
    sleep 5
fi

# =============================================================================
# Set VNC Password
# =============================================================================
echo "Setting VNC password..."
mkdir -p ~/.vnc
echo "${VNC_PASSWORD}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# =============================================================================
# Create VNC xstartup
# =============================================================================
echo "Configuring VNC xstartup..."
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Set up XDG directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_RUNTIME_DIR="/tmp/runtime-$USER"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start XFCE4 desktop
# Antigravity is auto-launched by supervisor after desktop is ready
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

chmod +x ~/.vnc/xstartup

# =============================================================================
# Initialize Configuration
# =============================================================================
echo "Initializing configuration..."
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml

# Apply default panel configuration if not present
if [ ! -f ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml ]; then
    echo "Applying custom panel configuration..."
    if [ -f /opt/defaults/xfce4-panel.xml ]; then
        cp /opt/defaults/xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
    else
        echo "Warning: Default panel config not found at /opt/defaults/xfce4-panel.xml"
    fi
fi

# =============================================================================
# Configure devilspie2 for auto-maximize windows
# =============================================================================
echo "Configuring devilspie2 for window maximization..."
mkdir -p ~/.config/devilspie2

# Copy devilspie2 config if not present
if [ ! -f ~/.config/devilspie2/maximize.lua ]; then
    if [ -d /opt/defaults/devilspie2 ]; then
        cp -r /opt/defaults/devilspie2/* ~/.config/devilspie2/
    else
        # Create a default maximize config if defaults not available
        cat > ~/.config/devilspie2/maximize.lua << 'DEVILSPIE_EOF'
-- Auto-maximize all windows on open
maximize()
DEVILSPIE_EOF
    fi
fi

# Add devilspie2 to XFCE autostart
mkdir -p ~/.config/autostart
if [ ! -f ~/.config/autostart/devilspie2.desktop ]; then
    cat > ~/.config/autostart/devilspie2.desktop << 'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Devilspie2
Comment=Window matching daemon for auto-maximize
Exec=devilspie2
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOSTART_EOF
fi

# =============================================================================
# Create directories
# =============================================================================
echo "Creating workspace directories..."
mkdir -p ~/workspace ~/.config ~/.antigravity

# =============================================================================
# Fix permissions
# =============================================================================
echo "Fixing permissions..."
sudo chown -R $(id -u):$(id -g) ~ 2>/dev/null || true

# =============================================================================
# Check for Antigravity updates (if enabled)
# =============================================================================
if [ "${ANTIGRAVITY_AUTO_UPDATE}" = "true" ]; then
    echo "Checking for Antigravity updates..."
    /opt/scripts/update-antigravity.sh || true
fi

# =============================================================================
# Display GPU information
# =============================================================================
echo ""
echo "==========================================="
echo "  GPU Information"
echo "==========================================="
if [ -f /opt/scripts/verify-gpu.sh ]; then
    /opt/scripts/verify-gpu.sh || echo "Warning: GPU verification failed"
else
    # Fallback for older images or if script missing
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "No NVIDIA GPU detected"
fi
echo ""

# =============================================================================
# Display connection information
# =============================================================================
echo "==========================================="
echo "  Connection Information"
echo "==========================================="
echo "  noVNC Web Access: http://localhost:${NOVNC_PORT:-6080}"
echo "  VNC Direct:       localhost:${VNC_PORT:-5901}"
echo "  Password:         (as configured)"
echo ""
echo "  Resolution will auto-adjust to browser"
echo "  Default: ${DISPLAY_WIDTH:-1920}x${DISPLAY_HEIGHT:-1080}"
echo "==========================================="
echo ""

# =============================================================================
# Execute the main command
# =============================================================================
if [ "$1" = "supervisord" ]; then
    echo "Starting Supervisor..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
else
    exec "$@"
fi
