# Security Policy

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues.

If you believe you have found a security vulnerability in this project, please report it via email to `security@example.com` (replace with actual contact). You will receive a response within 48 hours.

## Security Best Practices

### Authentication

*   **Weak Passwords**: The container enforces a minimum password length of 8 characters. However, we strongly recommend using a random password of at least 16 characters.
*   **Rotation**: Change your VNC password regularly by updating the `.env` file and restarting the container.
*   **No Default Password**: This image does not ship with a default password. You **must** set `VNC_PASSWORD` environment variable for the container to start.

### Network Exposure

*   **VNC Port (5901)**: By default, the VNC port is exposed. In production or on public networks, verify that this port is:
    *   Blocked by a firewall
    *   Only bound to `127.0.0.1` (localhost)
    *   Tunneled via SSH or VPN
*   **noVNC Port (6080)**: The web interface uses unencrypted HTTP/WebSocket.
    *   **Do not** expose this directly to the internet.
    *   Use a reverse proxy (Nginx, Traefik, Caddy) with HTTPS termination.

### Container Privileges

*   **Sudo Access**: The default `antigravity` user has restricted sudo access. Only specific commands (like system updates) are allowed.
*   **Root User**: Avoid running applications as the root user inside the container.
*   **Seccomp**: For GPU support, this container may run with reduced seccomp profiles. Be aware of the implications for container isolation.

### Updates

*   **Base Image**: Regularly pull the latest version of the Docker image to ensure you have the latest system security patches.
*   **Antigravity Updates**: The container includes an auto-updater for the Antigravity IDE. Ensure the container has internet access to receive these updates.
