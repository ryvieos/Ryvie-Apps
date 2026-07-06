#!/bin/sh
# Hook de déconnexion IA d'OpenClaw : retire le provider « ryvie » de la config,
# puis redémarre la gateway. Best-effort (idempotent).
set -e

docker exec app-openclaw node /app/openclaw.mjs config unset models.providers.ryvie \
  >/dev/null 2>&1 || true
docker restart app-openclaw >/dev/null 2>&1 || true
echo "[openclaw] provider « Ryvie AI » retiré."
