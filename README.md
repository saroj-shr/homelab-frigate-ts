# frigate-ts (Compose setup)

This repository contains a Docker Compose setup for running Frigate video surveillance with Tailscale remote access, comprehensive monitoring via OpenObserve, and system metrics collection via cAdvisor.

## What is included

- `docker-compose.yml` - Docker Compose configuration for `frigate`, `tailscale`, `openobserve-collector`, and `cadvisor` services
- `config/tailscale/serve-config.json` - Tailscale HTTPS routing configuration
- `config/otel-collector/config.yaml` - OpenObserve collector pipeline configuration

## Services

### Frigate
Video surveillance system with object detection support:
- 4x 1080p camera streams
- Intel GPU acceleration (`/dev/dri/renderD128`)
- USB Coral TPU for AI inference
- 1GB tmpfs cache for performance
- Persistent storage for recordings

### Tailscale
Secure remote access via VPN:
- HTTPS proxy to Frigate web UI
- Uses `serve-config.json` for routing
- Healthcheck via `tailscale status`

### OpenObserve Collector
Centralized log and metrics aggregation:
- Collects Docker container metrics
- Scrapes cAdvisor metrics
- Ingests systemd journal logs
- Exports to OpenObserve instance

### cAdvisor
Container and system monitoring:
- Real-time container resource metrics (CPU, memory, network, disk I/O)
- Disk I/O statistics
- Health status available on port `8080`

## Config & recommended layout

```
config/
  tailscale/
    serve-config.json         # Tailscale HTTPS routing
  otel-collector/
    config.yaml               # OpenObserve collector pipeline
.env                          # local environment variables (not committed)
docker-compose.yml
README.md
```

## .env and secrets

Put sensitive values in a `.env` file and add it to `.gitignore`. Keys used in the compose file:

- `TS_AUTHKEY` - Tailscale authentication key
- `OPENOBSERVE_ENDPOINT` - OpenObserve API endpoint (e.g., `https://openobserve.example.com:5080/api/default`)
- `OPENOBSERVE_AUTH` - OpenObserve authentication header (e.g., `Basic base64_encoded_username:password`)

Example `.env` snippet:

```env
# .env (example)
TS_AUTHKEY=tskey_xxx
OPENOBSERVE_ENDPOINT=https://openobserve.example.com:5080/api/default
OPENOBSERVE_AUTH=Basic dXNlcm5hbWU6cGFzc3dvcmQ=
```

## Resource Requirements (4x 1080p cameras)

- **CPU:** 4+ cores (with Coral TPU for inference)
- **Memory:** 6-8 GB RAM
- **Storage:** 300-500 GB (SSD recommended for reliability)
- **Network:** 20-30 Mbps local bandwidth
- **GPU:** Intel iGPU + USB Coral TPU (recommended)

## Quick start

### 1. Create directories and .env file

```bash
mkdir -p ./config/tailscale ./config/otel-collector
mkdir -p /mnt/frigate/frigate-config /mnt/frigate/frigate-storage
mkdir -p /mnt/jellyfin/tailscale-state

# Create .env with your credentials
cp .env-example .env
# Edit .env and add TS_AUTHKEY, OPENOBSERVE_ENDPOINT, OPENOBSERVE_AUTH
```

### 2. Start services in detached mode

```bash
docker compose up -d
```

### 3. Verify services are healthy

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Expected output:
```
frigate-ts              Up (healthy)
openobserve-collector   Up (healthy)
cadvisor                Up (healthy)
frigate                 Up (healthy)
```

### 4. Follow logs

```bash
# Follow all logs
docker compose logs -f

# Follow specific service
docker compose logs -f frigate
docker compose logs -f openobserve-collector
```

## Accessing Services

### Frigate Web UI
- **Via Tailscale:** Access through your Tailscale network (configured in `serve-config.json`)
- **Local access:** Add `ports: ["5000:5000"]` to frigate service in compose

### cAdvisor Metrics
- **Local:** `http://localhost:8080`
- **API:** `http://localhost:8080/api/v1.3/machine`

### OpenObserve Collector Health
- **Health endpoint:** `http://localhost:13133/healthz`

## Configuration Files

### serve-config.json
Routes HTTPS traffic from Tailscale to Frigate. Example:

```json
{
  "routes": {
    "frigate.example.com:443": {
      "backend": "http://127.0.0.1:8096"
    }
  }
}
```

### otel-collector/config.yaml
Defines metrics and log pipelines. Collects:
- Docker container stats
- Prometheus metrics from cAdvisor
- Systemd journal logs

## Troubleshooting

### Frigate won't start
- Check GPU device accessibility: `ls -la /dev/dri/renderD128`
- Verify USB Coral is connected: `lsusb | grep Coral`
- Check logs: `docker compose logs frigate`

### OpenObserve Collector unhealthy
- Verify endpoint in `.env` is reachable
- Check OpenObserve instance is running
- View logs: `docker compose logs openobserve-collector`

### cAdvisor metrics missing
- Verify Docker socket mount is accessible: `ls -la /var/run/docker.sock`
- Check systemd journal permissions: `sudo journalctl -n 1`

### Tailscale connection issues
- Verify auth key in `.env` is valid
- Check Tailscale status: `docker compose exec frigate-ts tailscale status`

## Notes

- Health checks are configured for all services with 30s intervals and 60s startup grace period
- Bind mounts use `/mnt/` paths; adjust if your storage layout differs
- On macOS, file permission semantics differ; test mounts and adjust ownership as needed
- Sensitive data (auth keys, passwords) should never be committed to version control
- For production use, consider using a secrets manager instead of `.env`

---

For more information:
- [Frigate Documentation](https://docs.frigate.video)
- [Tailscale Serve Documentation](https://tailscale.com/kb/1312/serve)
- [OpenObserve Documentation](https://docs.openobserve.ai)
- [cAdvisor Documentation](https://github.com/google/cadvisor)