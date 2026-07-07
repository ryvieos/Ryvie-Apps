#!/bin/sh
# Hook de dé-exposition d'OpenClaw, exécuté par Ryvie quand l'app perd son adresse
# publique. Symétrique de expose.sh : on vide les origines autorisées et le proxy
# de confiance (retour à l'accès local seul, où la gateway traite le client comme
# local et n'applique pas le contrôle d'origine).
set -e

docker exec app-openclaw node /app/openclaw.mjs config set \
  gateway.controlUi.allowedOrigins '[]' --strict-json >/dev/null 2>&1 \
  || echo "[openclaw] (allowedOrigins non vidé)"
docker exec app-openclaw node /app/openclaw.mjs config set \
  gateway.trustedProxies '[]' --strict-json >/dev/null 2>&1 \
  || echo "[openclaw] (trustedProxies non vidé)"

docker restart app-openclaw >/dev/null 2>&1 || true
echo "[openclaw] adresse publique retirée des origines autorisées"
