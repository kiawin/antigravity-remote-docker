# Refactoring Guide: Multi-GPU Support for Antigravity Remote Docker

## Overview

This document outlines the complete refactoring needed to add AMD GPU (ROCm), Intel GPU, and CPU-only support to the existing NVIDIA-focused antigravity-remote-docker project.

### Current State
- Only supports NVIDIA GPUs via NVIDIA Container Toolkit
- Uses `runtime: nvidia` in docker-compose
- Base image likely uses `nvidia/cuda`

### Target State
- Support for NVIDIA, AMD, Intel GPUs, and CPU-only mode
- Auto-detection of GPU type (optional)
- User-configurable GPU selection
- Maintain backward compatibility with existing NVIDIA setup

---

## File Structure Changes

### New Files to Create

```
antigravity-remote-docker/
├── .env.nvidia          # NVIDIA-specific configuration
├── .env.amd             # AMD-specific configuration
├── .env.intel           # Intel-specific configuration
├── .env.cpu             # CPU-only configuration
├── scripts/
│   ├── detect-gpu.sh    # Auto-detect GPU type
│   └── verify-gpu.sh    # Verify GPU access in container
└── docs/
    └── GPU-SETUP.md     # GPU-specific setup instructions
```

### Files to Modify

- `Dockerfile` - Add multi-stage build for different GPU types
- `docker-compose.yml` - Add conditional GPU configuration
- `.env.example` - Update with GPU type options
- `README.md` - Add GPU selection instructions
- `scripts/startup.sh` (if exists) - Add GPU verification

---

## Detailed Implementation

### 1. Dockerfile Modifications

**File:** `Dockerfile`

```dockerfile
# Multi-stage Dockerfile supporting NVIDIA, AMD, Intel, and CPU

ARG GPU_TYPE=nvidia

###########################################
# NVIDIA Base Image
###########################################
FROM nvidia/cuda:12.4.0-base-ubuntu22.04 AS nvidia-base

# NVIDIA-specific environment
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# Install NVIDIA utilities (optional)
RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-toolkit-12-4 \
    && rm -rf /var/lib/apt/lists/*

###########################################
# AMD/ROCm Base Image
###########################################
FROM rocm/rocm-terminal:6.2.2 AS amd-base

# AMD-specific environment
ENV AMD_VISIBLE_DEVICES=all \
    ROCm_VERSION=6.2.2

# Install ROCm utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    rocm-smi \
    rocminfo \
    && rm -rf /var/lib/apt/lists/*

###########################################
# Intel GPU Base Image
###########################################
FROM ubuntu:22.04 AS intel-base

# Install Intel GPU drivers and compute runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gpg-agent \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add Intel GPU repository
RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
    tee /etc/apt/sources.list.d/intel-gpu-jammy.list

# Install Intel GPU packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    intel-opencl-icd \
    intel-level-zero-gpu \
    level-zero \
    intel-media-va-driver-non-free \
    libmfx1 \
    libmfxgen1 \
    libvpl2 \
    libegl-mesa0 \
    libegl1-mesa \
    libegl1-mesa-dev \
    libgbm1 \
    libgl1-mesa-dev \
    libgl1-mesa-dri \
    libglapi-mesa \
    libgles2-mesa-dev \
    libglx-mesa0 \
    libigdgmm12 \
    libxatracker2 \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    mesa-vulkan-drivers \
    va-driver-all \
    vainfo \
    && rm -rf /var/lib/apt/lists/*

# Intel-specific environment
ENV LIBVA_DRIVER_NAME=iHD

###########################################
# CPU-Only Base Image
###########################################
FROM ubuntu:22.04 AS cpu-base

# No GPU-specific packages needed

###########################################
# Final Stage - Common Setup
###########################################
FROM ${GPU_TYPE}-base AS final

# Set working directory
WORKDIR /root

# Install common packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop environment
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    dbus-x11 \
    # VNC server
    tigervnc-standalone-server \
    tigervnc-common \
    # noVNC for web access
    novnc \
    websockify \
    # Supervisor for process management
    supervisor \
    # Utilities
    wget \
    curl \
    vim \
    net-tools \
    # Chrome dependencies
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && \
    apt-get install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p \
    /root/.vnc \
    /root/.config/xfce4 \
    /var/log/supervisor \
    /opt/novnc/utils/websockify

# Copy configuration files
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/xfce4-panel.xml /root/.config/xfce4/xfce4-panel.xml
COPY scripts/startup.sh /opt/startup.sh
COPY scripts/verify-gpu.sh /opt/verify-gpu.sh

# Make scripts executable
RUN chmod +x /opt/startup.sh /opt/verify-gpu.sh

# Expose VNC and noVNC ports
EXPOSE 5901 6080

# Set GPU type environment variable
ARG GPU_TYPE
ENV GPU_TYPE=${GPU_TYPE}

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

---

### 2. Docker Compose Configuration

**File:** `docker-compose.yml`

```yaml
version: '3.8'

services:
  antigravity-remote:
    container_name: antigravity-remote
    build:
      context: .
      args:
        GPU_TYPE: ${GPU_TYPE:-nvidia}
      dockerfile: Dockerfile
    
    # Runtime configuration (NVIDIA or AMD)
    runtime: ${DOCKER_RUNTIME:-runc}
    
    # Device mappings for AMD and Intel GPUs
    devices: ${GPU_DEVICES:-[]}
    
    # GPU environment variables
    environment:
      # Common settings
      - GPU_TYPE=${GPU_TYPE:-nvidia}
      - VNC_PASSWORD=${VNC_PASSWORD:-antigravity}
      - DISPLAY_WIDTH=${DISPLAY_WIDTH:-1920}
      - DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-1080}
      - AUTOSTART_ANTIGRAVITY=${AUTOSTART_ANTIGRAVITY:-true}
      - IDLE_TIMEOUT=${IDLE_TIMEOUT:-60}
      
      # NVIDIA-specific
      - NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
      - NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-all}
      
      # AMD-specific
      - AMD_VISIBLE_DEVICES=${AMD_VISIBLE_DEVICES:-all}
      - ROCm_VISIBLE_DEVICES=${ROCm_VISIBLE_DEVICES:-all}
      
      # Intel-specific
      - LIBVA_DRIVER_NAME=${LIBVA_DRIVER_NAME:-iHD}
      - ONEAPI_DEVICE_SELECTOR=${ONEAPI_DEVICE_SELECTOR:-*}
    
    # Group memberships for GPU access
    group_add: ${GPU_GROUPS:-[]}
    
    # Security options
    security_opt: ${SECURITY_OPTS:-[]}
    
    # Port mappings
    ports:
      - "${VNC_PORT:-5901}:5901"
      - "${NOVNC_PORT:-6080}:6080"
    
    # Volume mappings
    volumes:
      - ./data:/root/workspace:rw
      - /etc/localtime:/etc/localtime:ro
    
    # Restart policy
    restart: unless-stopped
    
    # Resource limits (optional)
    deploy:
      resources:
        reservations:
          # This section is used when GPU_TYPE is nvidia and you want fine-grained control
          devices: ${DEPLOY_DEVICES:-[]}
```

---

### 3. Environment Configuration Files

**File:** `.env.nvidia`

```bash
# NVIDIA GPU Configuration
GPU_TYPE=nvidia
DOCKER_RUNTIME=nvidia

# NVIDIA-specific settings
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=all

# These are empty for NVIDIA (uses runtime instead)
GPU_DEVICES=
GPU_GROUPS=
SECURITY_OPTS=
DEPLOY_DEVICES=

# VNC Configuration
VNC_PASSWORD=antigravity
VNC_PORT=5901
NOVNC_PORT=6080

# Display Configuration
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080

# Application Settings
AUTOSTART_ANTIGRAVITY=true
IDLE_TIMEOUT=60
```

**File:** `.env.amd`

```bash
# AMD GPU Configuration
GPU_TYPE=amd
DOCKER_RUNTIME=amd

# AMD-specific settings
AMD_VISIBLE_DEVICES=all
ROCm_VISIBLE_DEVICES=all

# Device mappings for AMD
GPU_DEVICES=["/dev/kfd:/dev/kfd", "/dev/dri:/dev/dri"]
GPU_GROUPS=["video", "render"]
SECURITY_OPTS=["seccomp=unconfined"]
DEPLOY_DEVICES=

# NVIDIA settings (unused but kept for compatibility)
NVIDIA_VISIBLE_DEVICES=
NVIDIA_DRIVER_CAPABILITIES=

# VNC Configuration
VNC_PASSWORD=antigravity
VNC_PORT=5901
NOVNC_PORT=6080

# Display Configuration
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080

# Application Settings
AUTOSTART_ANTIGRAVITY=true
IDLE_TIMEOUT=60
```

**File:** `.env.intel`

```bash
# Intel GPU Configuration
GPU_TYPE=intel
DOCKER_RUNTIME=runc

# Intel-specific settings
LIBVA_DRIVER_NAME=iHD
ONEAPI_DEVICE_SELECTOR=*

# Device mappings for Intel
GPU_DEVICES=["/dev/dri:/dev/dri"]
GPU_GROUPS=["video", "render"]
SECURITY_OPTS=
DEPLOY_DEVICES=

# NVIDIA settings (unused but kept for compatibility)
NVIDIA_VISIBLE_DEVICES=
NVIDIA_DRIVER_CAPABILITIES=

# AMD settings (unused but kept for compatibility)
AMD_VISIBLE_DEVICES=
ROCm_VISIBLE_DEVICES=

# VNC Configuration
VNC_PASSWORD=antigravity
VNC_PORT=5901
NOVNC_PORT=6080

# Display Configuration
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080

# Application Settings
AUTOSTART_ANTIGRAVITY=true
IDLE_TIMEOUT=60
```

**File:** `.env.cpu`

```bash
# CPU-Only Configuration (No GPU)
GPU_TYPE=cpu
DOCKER_RUNTIME=runc

# No GPU settings needed
GPU_DEVICES=
GPU_GROUPS=
SECURITY_OPTS=
DEPLOY_DEVICES=

# All GPU-specific variables empty
NVIDIA_VISIBLE_DEVICES=
NVIDIA_DRIVER_CAPABILITIES=
AMD_VISIBLE_DEVICES=
ROCm_VISIBLE_DEVICES=
LIBVA_DRIVER_NAME=
ONEAPI_DEVICE_SELECTOR=

# VNC Configuration
VNC_PASSWORD=antigravity
VNC_PORT=5901
NOVNC_PORT=6080

# Display Configuration
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080

# Application Settings
AUTOSTART_ANTIGRAVITY=true
IDLE_TIMEOUT=60
```

**File:** `.env.example` (Updated)

```bash
# ========================================
# GPU Configuration
# ========================================
# Choose your GPU type: nvidia, amd, intel, or cpu
# Copy the corresponding .env.{type} file to .env
# Or manually set the values below

GPU_TYPE=nvidia

# Quick setup:
# cp .env.nvidia .env  # For NVIDIA GPUs
# cp .env.amd .env     # For AMD GPUs
# cp .env.intel .env   # For Intel GPUs
# cp .env.cpu .env     # For CPU-only

# ========================================
# Advanced GPU Settings
# ========================================
# See the respective .env.{type} files for detailed configurations
# Generally, you should copy one of those files instead of editing this manually

DOCKER_RUNTIME=runc
GPU_DEVICES=
GPU_GROUPS=
SECURITY_OPTS=

# ========================================
# VNC Configuration
# ========================================
VNC_PASSWORD=antigravity
VNC_PORT=5901
NOVNC_PORT=6080

# ========================================
# Display Configuration
# ========================================
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080

# ========================================
# Application Settings
# ========================================
AUTOSTART_ANTIGRAVITY=true
IDLE_TIMEOUT=60
```

---

### 4. GPU Detection Script

**File:** `scripts/detect-gpu.sh`

```bash
#!/bin/bash

# GPU Auto-Detection Script
# This script detects the available GPU type on the host system

set -e

echo "========================================="
echo "GPU Auto-Detection"
echo "========================================="

GPU_TYPE="cpu"

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "✓ NVIDIA GPU detected"
        GPU_TYPE="nvidia"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    fi
fi

# Check for AMD GPU
if [ "$GPU_TYPE" = "cpu" ]; then
    if [ -d "/sys/module/amdgpu" ] && [ -c "/dev/kfd" ]; then
        echo "✓ AMD GPU detected"
        GPU_TYPE="amd"
        if command -v rocm-smi &> /dev/null; then
            rocm-smi --showproductname 2>/dev/null || echo "  (rocm-smi not available for details)"
        fi
    fi
fi

# Check for Intel GPU
if [ "$GPU_TYPE" = "cpu" ]; then
    if [ -d "/dev/dri" ]; then
        if lspci 2>/dev/null | grep -i "VGA.*Intel" &> /dev/null; then
            echo "✓ Intel GPU detected"
            GPU_TYPE="intel"
            lspci | grep -i "VGA.*Intel"
        fi
    fi
fi

# No GPU found
if [ "$GPU_TYPE" = "cpu" ]; then
    echo "ℹ No GPU detected, will use CPU-only mode"
fi

echo "========================================="
echo "Detected GPU Type: $GPU_TYPE"
echo "========================================="

# Copy the appropriate .env file
if [ -f ".env.${GPU_TYPE}" ]; then
    echo "Copying .env.${GPU_TYPE} to .env"
    cp ".env.${GPU_TYPE}" .env
    echo "✓ Configuration file ready"
else
    echo "⚠ Warning: .env.${GPU_TYPE} not found"
    echo "  Using default configuration"
fi

echo ""
echo "To build and run the container:"
echo "  docker-compose up -d --build"
```

---

### 5. GPU Verification Script

**File:** `scripts/verify-gpu.sh`

```bash
#!/bin/bash

# GPU Verification Script (runs inside container)
# Verifies that the GPU is accessible from within the container

set -e

GPU_TYPE="${GPU_TYPE:-cpu}"

echo "========================================="
echo "GPU Verification (Type: $GPU_TYPE)"
echo "========================================="

case "$GPU_TYPE" in
    nvidia)
        echo "Checking NVIDIA GPU..."
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi
            if [ $? -eq 0 ]; then
                echo "✓ NVIDIA GPU is accessible"
                exit 0
            else
                echo "✗ NVIDIA GPU is NOT accessible"
                exit 1
            fi
        else
            echo "✗ nvidia-smi not found"
            exit 1
        fi
        ;;
    
    amd)
        echo "Checking AMD GPU..."
        
        # Check for ROCm devices
        if [ ! -c "/dev/kfd" ]; then
            echo "✗ /dev/kfd not found"
            exit 1
        fi
        
        if [ ! -d "/dev/dri" ]; then
            echo "✗ /dev/dri not found"
            exit 1
        fi
        
        echo "✓ ROCm devices found"
        
        # Check rocm-smi if available
        if command -v rocm-smi &> /dev/null; then
            rocm-smi
            if [ $? -eq 0 ]; then
                echo "✓ AMD GPU is accessible"
            fi
        fi
        
        # Check rocminfo if available
        if command -v rocminfo &> /dev/null; then
            echo "Running rocminfo..."
            rocminfo | head -n 20
        fi
        
        exit 0
        ;;
    
    intel)
        echo "Checking Intel GPU..."
        
        # Check for DRI devices
        if [ ! -d "/dev/dri" ]; then
            echo "✗ /dev/dri not found"
            exit 1
        fi
        
        echo "✓ DRI devices found:"
        ls -l /dev/dri/
        
        # Check vainfo if available
        if command -v vainfo &> /dev/null; then
            echo "Running vainfo..."
            LIBVA_DRIVER_NAME=iHD vainfo 2>&1 | head -n 20
            if [ $? -eq 0 ]; then
                echo "✓ Intel GPU is accessible"
            fi
        fi
        
        exit 0
        ;;
    
    cpu)
        echo "ℹ Running in CPU-only mode (no GPU)"
        exit 0
        ;;
    
    *)
        echo "✗ Unknown GPU type: $GPU_TYPE"
        exit 1
        ;;
esac
```

---

### 6. Updated Startup Script

**File:** `scripts/startup.sh` (modifications to add GPU verification)

Add this section to the existing startup script:

```bash
#!/bin/bash

# ... existing startup code ...

# Verify GPU access
echo "========================================="
echo "Verifying GPU Access"
echo "========================================="
/opt/verify-gpu.sh || echo "Warning: GPU verification failed, but continuing..."

# ... rest of existing startup code ...
```

---

### 7. GPU Setup Documentation

**File:** `docs/GPU-SETUP.md`

```markdown
# GPU Setup Guide

This guide covers GPU setup for different hardware configurations.

## Quick Start

1. **Auto-detect your GPU:**
   ```bash
   chmod +x scripts/detect-gpu.sh
   ./scripts/detect-gpu.sh
   ```

2. **Or manually select your configuration:**
   ```bash
   # For NVIDIA
   cp .env.nvidia .env
   
   # For AMD
   cp .env.amd .env
   
   # For Intel
   cp .env.intel .env
   
   # For CPU-only
   cp .env.cpu .env
   ```

3. **Build and run:**
   ```bash
   docker-compose up -d --build
   ```

---

## NVIDIA GPU Setup

### Prerequisites

1. **NVIDIA GPU Driver:**
   ```bash
   # Check if driver is installed
   nvidia-smi
   ```

2. **NVIDIA Container Toolkit:**
   ```bash
   # Add NVIDIA package repository
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
       sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   
   curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   
   # Install nvidia-container-toolkit
   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   
   # Configure Docker
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

3. **Verify setup:**
   ```bash
   docker run --rm --runtime=nvidia nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
   ```

### Configuration

Use the `.env.nvidia` configuration file.

---

## AMD GPU Setup

### Prerequisites

1. **AMD GPU Driver (AMDGPU-PRO or ROCm):**
   ```bash
   # Install ROCm
   wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/amdgpu-install_*.deb
   sudo dpkg -i amdgpu-install_*.deb
   sudo amdgpu-install --usecase=graphics,rocm
   
   # Verify installation
   rocm-smi
   ```

2. **AMD Container Toolkit (Optional but recommended):**
   ```bash
   # Download and install
   wget https://github.com/ROCm/container-toolkit/releases/download/v0.1.0/amd-ctk_0.1.0_amd64.deb
   sudo dpkg -i amd-ctk_0.1.0_amd64.deb
   
   # Configure Docker
   sudo amd-ctk install
   sudo systemctl restart docker
   ```

3. **Verify setup:**
   ```bash
   docker run --rm \
       --device=/dev/kfd \
       --device=/dev/dri \
       --security-opt seccomp=unconfined \
       rocm/rocm-terminal:latest \
       rocm-smi
   ```

### Configuration

Use the `.env.amd` configuration file.

### Troubleshooting

- **Permission denied on /dev/kfd or /dev/dri:**
  ```bash
  # Add your user to video and render groups
  sudo usermod -a -G video,render $USER
  # Log out and log back in
  ```

- **Container can't see GPU:**
  - Ensure `--security-opt seccomp=unconfined` is set
  - Verify both `/dev/kfd` and `/dev/dri` are mounted

---

## Intel GPU Setup

### Prerequisites

1. **Intel GPU Driver:**
   ```bash
   # For modern Ubuntu systems, drivers are usually included
   # Verify GPU is detected
   lspci | grep -i "VGA.*Intel"
   ls /dev/dri/
   ```

2. **Install Intel GPU compute packages (optional, for compute workloads):**
   ```bash
   wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
       sudo gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
   
   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
       sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
   
   sudo apt-get update
   sudo apt-get install -y \
       intel-opencl-icd \
       intel-level-zero-gpu \
       level-zero
   ```

3. **Verify setup:**
   ```bash
   docker run --rm \
       --device=/dev/dri \
       ubuntu:22.04 \
       ls -l /dev/dri/
   ```

### Configuration

Use the `.env.intel` configuration file.

### Troubleshooting

- **Permission denied on /dev/dri:**
  ```bash
  # Add your user to video and render groups
  sudo usermod -a -G video,render $USER
  # Log out and log back in
  ```

- **Check device permissions:**
  ```bash
  ls -l /dev/dri/
  # Should show devices owned by root:video or root:render
  ```

---

## CPU-Only Mode

No special setup required. Use `.env.cpu` configuration.

---

## Verification

After starting the container, check the logs:

```bash
docker logs antigravity-remote
```

Look for the GPU verification section. You should see output confirming GPU access.

To manually verify inside the container:

```bash
docker exec -it antigravity-remote /opt/verify-gpu.sh
```

---

## Advanced Configuration

### Limiting GPU Access

**NVIDIA - Select specific GPUs:**
```bash
# In .env file
NVIDIA_VISIBLE_DEVICES=0,1  # Use GPUs 0 and 1
```

**AMD - Select specific GPUs:**
```bash
# In .env file
AMD_VISIBLE_DEVICES=0,1  # Use GPUs 0 and 1
```

**Intel - Select specific render device:**
```bash
# In docker-compose.yml, modify devices
devices:
  - /dev/dri/renderD128:/dev/dri/renderD128
```

### Mixed GPU Systems

If you have multiple GPU types, choose one configuration. The container can only use one GPU type at a time.

---

## Common Issues

### Issue: "runtime not found"

**For NVIDIA:**
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**For AMD:**
```bash
sudo amd-ctk install
sudo systemctl restart docker
```

### Issue: "device not found"

Check that the device exists on the host:
```bash
# For NVIDIA
nvidia-smi

# For AMD
ls -l /dev/kfd /dev/dri/

# For Intel
ls -l /dev/dri/
```

### Issue: "permission denied"

Add your user to the necessary groups:
```bash
sudo usermod -a -G video,render $USER
newgrp video  # Or log out and log back in
```

### Issue: GPU not detected in container

1. Check host GPU access works
2. Verify correct runtime is configured
3. Ensure device mapping is correct in docker-compose.yml
4. Check container logs: `docker logs antigravity-remote`
5. Run verification: `docker exec -it antigravity-remote /opt/verify-gpu.sh`
```

---

### 8. Updated README.md

**File:** `README.md` (Add new sections)

Add the following sections to the existing README:

````markdown
## GPU Support

This project supports multiple GPU types:

- ✅ **NVIDIA GPUs** (CUDA)
- ✅ **AMD GPUs** (ROCm)
- ✅ **Intel GPUs** (Integrated and Discrete)
- ✅ **CPU-only mode** (No GPU required)

### Quick Setup

#### Option 1: Auto-Detection (Recommended)

```bash
chmod +x scripts/detect-gpu.sh
./scripts/detect-gpu.sh
docker-compose up -d --build
```

#### Option 2: Manual Selection

Choose your GPU type and copy the corresponding configuration:

```bash
# For NVIDIA GPUs
cp .env.nvidia .env

# For AMD GPUs
cp .env.amd .env

# For Intel GPUs
cp .env.intel .env

# For CPU-only
cp .env.cpu .env
```

Then build and run:

```bash
docker-compose up -d --build
```

### Prerequisites by GPU Type

#### NVIDIA GPUs
- NVIDIA GPU drivers installed
- NVIDIA Container Toolkit installed
- See [docs/GPU-SETUP.md](docs/GPU-SETUP.md#nvidia-gpu-setup) for detailed instructions

#### AMD GPUs
- AMDGPU driver or ROCm installed
- AMD Container Toolkit (recommended)
- See [docs/GPU-SETUP.md](docs/GPU-SETUP.md#amd-gpu-setup) for detailed instructions

#### Intel GPUs
- Intel GPU drivers (usually pre-installed on modern Linux)
- Docker user in `video` and `render` groups
- See [docs/GPU-SETUP.md](docs/GPU-SETUP.md#intel-gpu-setup) for detailed instructions

#### CPU-Only
- No special requirements
- All dependencies included in container

### Verifying GPU Access

After starting the container, verify GPU access:

```bash
# Check container logs
docker logs antigravity-remote

# Manual verification
docker exec -it antigravity-remote /opt/verify-gpu.sh
```

For detailed troubleshooting, see [docs/GPU-SETUP.md](docs/GPU-SETUP.md).

## Configuration

The container can be configured via the `.env` file:

| Variable | Description | Default | GPU Types |
|----------|-------------|---------|-----------|
| `GPU_TYPE` | GPU type to use | `nvidia` | All |
| `VNC_PASSWORD` | Password for VNC | `antigravity` | All |
| `DISPLAY_WIDTH` | Display width | `1920` | All |
| `DISPLAY_HEIGHT` | Display height | `1080` | All |
| `NVIDIA_VISIBLE_DEVICES` | NVIDIA GPUs to use | `all` | NVIDIA |
| `AMD_VISIBLE_DEVICES` | AMD GPUs to use | `all` | AMD |
| `LIBVA_DRIVER_NAME` | Intel VA-API driver | `iHD` | Intel |

See the respective `.env.{type}` files for complete configuration options.
````

---

## Implementation Checklist

Use this checklist when implementing the refactoring:

### Phase 1: Core Files
- [ ] Create multi-stage Dockerfile with all GPU types
- [ ] Update docker-compose.yml with conditional GPU support
- [ ] Create .env.nvidia configuration
- [ ] Create .env.amd configuration
- [ ] Create .env.intel configuration
- [ ] Create .env.cpu configuration
- [ ] Update .env.example with GPU options

### Phase 2: Scripts
- [ ] Create scripts/detect-gpu.sh
- [ ] Create scripts/verify-gpu.sh
- [ ] Update scripts/startup.sh to include GPU verification
- [ ] Make all scripts executable

### Phase 3: Documentation
- [ ] Create docs/GPU-SETUP.md
- [ ] Update README.md with GPU setup instructions
- [ ] Update README.md with configuration table
- [ ] Add troubleshooting section

### Phase 4: Testing
- [ ] Test NVIDIA GPU configuration
- [ ] Test AMD GPU configuration (if hardware available)
- [ ] Test Intel GPU configuration (if hardware available)
- [ ] Test CPU-only configuration
- [ ] Test auto-detection script
- [ ] Test GPU verification script
- [ ] Verify backward compatibility with existing NVIDIA setup

### Phase 5: Final Touches
- [ ] Add .gitignore entries for .env (but not .env.*)
- [ ] Update any CI/CD configurations
- [ ] Create release notes
- [ ] Tag new version

---

## Testing Strategy

### Unit Tests

Test each component individually:

1. **Dockerfile builds:**
   ```bash
   docker build --build-arg GPU_TYPE=nvidia -t test-nvidia .
   docker build --build-arg GPU_TYPE=amd -t test-amd .
   docker build --build-arg GPU_TYPE=intel -t test-intel .
   docker build --build-arg GPU_TYPE=cpu -t test-cpu .
   ```

2. **GPU detection script:**
   ```bash
   ./scripts/detect-gpu.sh
   ```

3. **GPU verification (in container):**
   ```bash
   docker run --rm test-nvidia /opt/verify-gpu.sh
   ```

### Integration Tests

Test full docker-compose workflows:

1. **NVIDIA:**
   ```bash
   cp .env.nvidia .env
   docker-compose up -d --build
   docker logs antigravity-remote | grep "GPU Verification"
   docker exec antigravity-remote /opt/verify-gpu.sh
   ```

2. **AMD:**
   ```bash
   cp .env.amd .env
   docker-compose down
   docker-compose up -d --build
   docker logs antigravity-remote | grep "GPU Verification"
   docker exec antigravity-remote /opt/verify-gpu.sh
   ```

3. **Intel:**
   ```bash
   cp .env.intel .env
   docker-compose down
   docker-compose up -d --build
   docker logs antigravity-remote | grep "GPU Verification"
   docker exec antigravity-remote /opt/verify-gpu.sh
   ```

4. **CPU:**
   ```bash
   cp .env.cpu .env
   docker-compose down
   docker-compose up -d --build
   docker logs antigravity-remote | grep "CPU-only"
   ```

### Backward Compatibility Test

Ensure existing NVIDIA setups still work:

```bash
# Use old .env configuration (if exists)
docker-compose up -d --build
# Should work without any changes
```

---

## Migration Guide for Existing Users

For users already using the NVIDIA-only version:

### Automatic Migration

```bash
# Run auto-detection
./scripts/detect-gpu.sh
# This will create a new .env file
```

### Manual Migration

If you have custom settings in your old `.env` file:

1. Copy the appropriate new template:
   ```bash
   cp .env.nvidia .env.new
   ```

2. Transfer your custom settings from `.env` to `.env.new`:
   - VNC_PASSWORD
   - DISPLAY_WIDTH/HEIGHT
   - Custom ports
   - Any other customizations

3. Backup old config and use new one:
   ```bash
   mv .env .env.backup
   mv .env.new .env
   ```

4. Rebuild:
   ```bash
   docker-compose up -d --build
   ```

---

## Performance Considerations

### NVIDIA
- CUDA provides best performance for compute workloads
- Hardware acceleration for Chrome rendering

### AMD
- ROCm performance is comparable to CUDA for supported workloads
- Ensure latest ROCm version for best compatibility

### Intel
- Good for video encoding/decoding
- Lower compute performance than dedicated GPUs
- Excellent for integrated graphics workloads

### CPU-Only
- No GPU acceleration
- Suitable for non-graphics-intensive workloads
- Consider reducing DISPLAY_WIDTH/HEIGHT for better performance

---

## Troubleshooting Common Issues

### 1. Container fails to start

**Check logs:**
```bash
docker-compose logs
```

**Common causes:**
- Incorrect GPU_TYPE in .env
- Missing device mappings
- Runtime not configured

### 2. GPU not detected in container

**Run verification:**
```bash
docker exec -it antigravity-remote /opt/verify-gpu.sh
```

**Fixes:**
- Ensure GPU_TYPE matches your hardware
- Check device permissions on host
- Verify runtime is properly configured

### 3. Permission denied errors

**For AMD/Intel:**
```bash
sudo usermod -a -G video,render $USER
newgrp video
```

### 4. Chrome won't start

**Check logs for:**
- `--no-sandbox` flag (required for containerized Chrome)
- GPU acceleration errors

**Workaround:**
Set `--disable-gpu` in Chrome launch options if GPU causes issues.

---

## Additional Notes

### Security Considerations

- `seccomp=unconfined` is required for AMD GPUs but reduces container isolation
- Consider security implications before exposing VNC/noVNC ports publicly
- Use strong VNC passwords
- Consider VPN or SSH tunneling for remote access

### Resource Management

GPU resource limits can be set in docker-compose.yml:

```yaml
deploy:
  resources:
    limits:
      # For NVIDIA
      nvidia.com/gpu: 1
```

### Future Enhancements

Possible future improvements:

- [ ] Support for multiple GPU types simultaneously
- [ ] Dynamic GPU switching
- [ ] GPU resource monitoring dashboard
- [ ] Automated performance benchmarks
- [ ] Container orchestration examples (Kubernetes, Docker Swarm)

---

## Support and Contribution

### Getting Help

1. Check [docs/GPU-SETUP.md](docs/GPU-SETUP.md)
2. Review troubleshooting section
3. Check existing GitHub issues
4. Create a new issue with:
   - Your GPU type
   - Output of `./scripts/detect-gpu.sh`
   - Container logs
   - Host system information

### Contributing

Contributions welcome! Please:

1. Test on your hardware configuration
2. Update documentation
3. Add your hardware to compatibility list
4. Submit pull request with detailed description

---

## License

[Original license applies]

---

## Acknowledgments

- NVIDIA for CUDA and Container Toolkit
- AMD for ROCm
- Intel for GPU compute runtime
- Original antigravity-remote-docker contributors
