#!/bin/sh
# Hook d'exposition publique d'OpenClaw, exécuté par Ryvie (publicExposureService)
# quand l'app gagne une adresse publique. La Control UI de la gateway contrôle
# l'`Origin` des WebSockets : derrière le proxy NetBird/Caddy, elle refuse la
# connexion (« origin not allowed », code WS 1008) tant que le domaine public
# n'est pas dans gateway.controlUi.allowedOrigins. Et comme le trafic arrive via
# le proxy, la gateway ne considère plus le client comme local → il faut aussi
# déclarer le proxy dans gateway.trustedProxies.
# Reçoit en env : RYVIE_PUBLIC_URL (https://<domaine>), RYVIE_PUBLIC_DOMAIN.
set -e

[ -n "${RYVIE_PUBLIC_URL:-}" ] || { echo "[openclaw] RYVIE_PUBLIC_URL absent, hook ignoré"; exit 0; }

# Plage CGNAT NetBird (100.64.0.0/10) d'où proviennent les requêtes proxifiées.
docker exec app-openclaw node /app/openclaw.mjs config set \
  gateway.controlUi.allowedOrigins "[\"${RYVIE_PUBLIC_URL}\"]" --strict-json >/dev/null 2>&1 \
  || echo "[openclaw] (allowedOrigins non appliqué)"
docker exec app-openclaw node /app/openclaw.mjs config set \
  gateway.trustedProxies '["100.64.0.0/10"]' --strict-json >/dev/null 2>&1 \
  || echo "[openclaw] (trustedProxies non appliqué)"

# La gateway ne relit sa config qu'au démarrage.
docker restart app-openclaw >/dev/null 2>&1 || true
echo "[openclaw] adresse publique autorisée: ${RYVIE_PUBLIC_URL}"
