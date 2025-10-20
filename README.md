# frigate-ts (Compose setup)

This repository contains a Docker Compose setup for running Frigate video surveillance with Tailscale remote access for secure VPN connectivity.

## What is included

- `docker-compose.yml` - Docker Compose configuration for `frigate` and `tailscale` services
- `config/tailscale/serve-config.json` - Tailscale HTTPS routing configuration
- `.env-example` - Template for environment variables
- `init.sh` - Initialization script to create required directories

## Services

### Frigate
Video surveillance system with object detection support:
- 4x 1080p camera streams
- Intel GPU acceleration (`/dev/dri/renderD128`)
- USB Coral TPU for AI inference
- 256MB shared memory for processing
- 1GB tmpfs cache for performance
- Persistent storage for recordings
- Timezone: Asia/Kathmandu

### Tailscale
Secure remote access via VPN:
- HTTPS proxy to Frigate web UI
- Uses `serve-config.json` for routing
- Healthcheck via `tailscale status` (30s interval)
- Persistent state storage
- Secure remote access without port forwarding

## Architecture

```
Frigate (video surveillance)
    ↓
Tailscale (secure VPN access)
    ↓
Remote access to Frigate UI
```

## Directory Structure

```
.
├── config/
│   └── tailscale/
│       └── serve-config.json         # Tailscale HTTPS routing
├── .env                              # local environment variables (not committed)
├── .env-example                      # template for .env
├── docker-compose.yml
├── init.sh                           # initialization script
└── README.md
```

## .env and secrets

Put sensitive values in a `.env` file and add it to `.gitignore`. Required keys:

- `TS_AUTHKEY` - Tailscale authentication key (generate at https://login.tailscale.com/admin/settings/keys)

Example `.env` file:

```env
TS_AUTHKEY=tskey_xxxxxxxxxxxxx
```

## Resource Requirements (4x 1080p cameras)

- **CPU:** 4+ cores (with Coral TPU for inference offloading)
- **Memory:** 6-8 GB RAM
- **Storage:** 300-500 GB (SSD recommended for reliability and I/O performance)
- **Network:** 20-30 Mbps local bandwidth
- **GPU:** Intel iGPU (`/dev/dri/renderD128`) + USB Coral TPU (recommended)

## Quick Start

### 1. Initialize directories

```bash
chmod +x init.sh
./init.sh
```

This creates:
- `./config/tailscale/`
- `/mnt/frigate/frigate-config`
- `/mnt/frigate/frigate-storage`
- `/mnt/jellyfin/tailscale-state`

### 2. Configure environment

```bash
cp .env-example .env
# Edit .env with your Tailscale auth key
nano .env
```

Get your Tailscale auth key from: https://login.tailscale.com/admin/settings/keys

### 3. Update Tailscale routing (optional)

Edit `config/tailscale/serve-config.json` to customize the domain:

```json
{
  "routes": {
    "frigate.yourdomain.com:443": {
      "backend": "http://127.0.0.1:5000"
    }
  }
}
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Verify services are running

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Expected output:
```
NAMES           STATUS
frigate-ts      Up (healthy)
frigate         Up
```

### 6. Check logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f frigate
docker compose logs -f frigate-ts
```

## Accessing Services

### Frigate Web UI
- **Via Tailscale:** Connect to your Tailscale network, then access `https://frigate.yourdomain.com` (or configured domain in `serve-config.json`)
- **Local (if exposed):** `http://localhost:5000` (requires adding `ports: ["5000:5000"]` to frigate service)

### Tailscale Status
```bash
docker compose exec frigate-ts tailscale status
```

## Configuration Files

### serve-config.json
Routes HTTPS traffic from Tailscale to Frigate. Update the domain to match your setup:

```json
{
  "routes": {
    "frigate.example.com:443": {
      "backend": "http://127.0.0.1:5000"
    }
  }
}
```

- **frigate.example.com** - Your custom domain (accessible via Tailscale)
- **5000** - Frigate web UI port (default)

## Troubleshooting

### Frigate won't start
```bash
# Check GPU device
ls -la /dev/dri/renderD128

# Verify Coral TPU is connected
lsusb | grep Coral

# View Frigate logs
docker compose logs frigate
```

### Tailscale connection failing
```bash
# Check Tailscale status
docker compose exec frigate-ts tailscale status

# View Tailscale logs
docker compose logs frigate-ts

# Verify auth key is valid
grep TS_AUTHKEY .env
```

### Can't access Frigate via Tailscale
```bash
# Verify Tailscale IP
docker compose exec frigate-ts tailscale ip -4

# Check if Frigate is responding locally
curl http://localhost:5000

# Verify serve-config.json syntax
docker compose logs frigate-ts | grep -i route
```

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart a specific service
docker compose restart frigate

# View service logs
docker compose logs -f frigate

# Execute command in container
docker compose exec frigate cat /config/frigate.conf

# Check Tailscale connection
docker compose exec frigate-ts tailscale status

# Get Tailscale IP
docker compose exec frigate-ts tailscale ip -4
```

## Compose File Breakdown

### Services

**frigate-ts** (Tailscale sidecar):
- Image: `tailscale/tailscale:latest`
- Mounts: Docker socket for networking
- Environment: Auth key from `.env`
- Healthcheck: Validates Tailscale connection
- Network: `frigate-net` bridge

**frigate** (Video surveillance):
- Image: `ghcr.io/blakeblackshear/frigate:stable`
- Devices: Intel GPU + USB Coral TPU
- Memory: 256MB shared memory, 1GB tmpfs cache
- Volumes: Persistent storage for config and recordings
- Network: `frigate-net` bridge
- Timezone: Asia/Kathmandu

### Volumes

All volumes use bind mounts to `/mnt/`:
- `frigate-config` → `/mnt/frigate/frigate-config`
- `frigate-storage` → `/mnt/frigate/frigate-storage`
- `tailscale-state` → `/mnt/jellyfin/tailscale-state`

## Notes

- Health checks are configured for all services (30s interval, 60s startup grace period)
- Bind mounts use `/mnt/` paths; adjust if your storage layout differs
- On macOS, adjust mount paths and file permissions as needed
- Sensitive data (auth keys) should never be committed to version control
- Use `.gitignore` to exclude `.env` and `/mnt/` directories
- Frigate is only exposed via Tailscale VPN (secure by default, no port forwarding needed)

## Security Considerations

- Frigate is not directly exposed on the network (only via Tailscale VPN)
- All Tailscale traffic is encrypted and authenticated
- Sensitive credentials stored in `.env` (gitignored)
- No inbound ports required (Tailscale handles NAT traversal)

---

## References

- [Frigate Documentation](https://docs.frigate.video)
- [Tailscale Serve Documentation](https://tailscale.com/kb/1312/serve)
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys)
- [Docker Compose Documentation](https://docs.docker.com/compose/)