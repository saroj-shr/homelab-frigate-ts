#!/bin/sh

echo " Creating  necessary directories..."

DIRS=(
  "/mnt/frigate/frigate-config"
  "/mnt/frigate/frigate-storage"
  "/mnt/frigate/tailscale-state"
)

for DIR in "${DIRS[@]}"; do
  mkdir -p "$DIR"
done