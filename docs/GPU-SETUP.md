# GPU Setup Guide

This guide covers GPU setup for different hardware configurations supported by Antigravity Remote Docker.

## Quick Start
1. **Auto-detect your GPU:**
   ```bash
   chmod +x scripts/detect-gpu.sh
   ./scripts/detect-gpu.sh
   # This will attempt to detect your GPU and verify if Docker is configured correctly
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
   Ensure `nvidia-smi` works on your host.

2. **NVIDIA Container Toolkit:**
   Required for GPU passthrough.
   [Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

3. **Verify Host Setup:**
   ```bash
   docker run --rm --runtime=nvidia nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
   ```

### Configuration
Use the `.env.nvidia` configuration.
- `DOCKER_RUNTIME=nvidia`
- `GPU_TYPE=nvidia`

---

## AMD GPU Setup

### Prerequisites
1. **AMD GPU Driver (ROCm):**
   Ensure `rocm-smi` works or `/dev/kfd` and `/dev/dri` exist.

2. **Device Permissions:**
   Your user (and the container) needs access to `/dev/kfd` and `/dev/dri`.
   Usually requires adding your user to `video` and `render` groups.

### Configuration
Use the `.env.amd` configuration.
- `GPU_TYPE=amd`
- `SECURITY_OPTS=["seccomp=unconfined"]` (Required for ROCm to work inside container)
- Devices mapped: `/dev/kfd` and `/dev/dri`

---

## Intel GPU Setup

### Prerequisites
1. **Intel GPU Driver:**
   Modern Linux kernels (Ubuntu 22.04+) usually include `i915`/`xe` drivers.
   Verify with `ls -l /dev/dri/`.

2. **Device Permissions:**
   Ensure you have permissions for `/dev/dri/renderD128` (or similar).
   Add your user to `render` group: `sudo usermod -a -G render $USER`.

### Configuration
Use the `.env.intel` configuration.
- `GPU_TYPE=intel`
- Devices mapped: `/dev/dri`
- `LIBVA_DRIVER_NAME=iHD` (Default, supports Gen8+ graphics)

### Older Intel GPUs (Gen7 and older)
If you have a very old Intel GPU (Ivy Bridge, Haswell, etc.), you might need to override the driver:
In `.env` or `docker-compose.yml`:
```bash
LIBVA_DRIVER_NAME=i965
```

---

## CPU-Only Mode

### Configuration
Use the `.env.cpu` configuration.
- No GPU requirements.
- Uses software rendering (llvmpipe).
- Lower performance for heavy graphics/video.

---

## Troubleshooting

### "runtime: nvidia not found"
You haven't installed or configured the NVIDIA Container Toolkit.
If you don't have an NVIDIA GPU, verify you are not using `.env.nvidia`.

### "Permission denied" for /dev/dri or /dev/kfd
The user inside the container matches the UID/GID specified in `.env` (default 1000:1000).
Ensure the host devices allow access to this user/group.
Host fix: `sudo chmod 666 /dev/dri/renderD128` (Temporary) or fix group membership.

### Chrome won't start or shows black screen
Try disabling GPU usage in Chrome (not ideal):
Pass `--disable-gpu` to Chrome manually.
Or verify `verify-gpu.sh` passes inside the container.

### Verification
Run the verification script inside the container:
```bash
docker exec -it antigravity-remote /opt/scripts/verify-gpu.sh
```
