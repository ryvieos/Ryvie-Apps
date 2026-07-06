#!/bin/sh
# Hook de déconnexion IA de LibreChat, exécuté par Ryvie AVANT le retrait des
# variables d'env et le redémarrage du conteneur (composeUp). Rôle : retirer
# l'endpoint "Ryvie AI" de librechat.yaml. Pas de restart ici : Ryvie relance
# le conteneur juste après, qui rechargera la config sans l'endpoint.
set -e

APP_DIR="${RYVIE_APP_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
YAML="${APP_DIR}/librechat.yaml"

[ -f "$YAML" ] || { echo "[librechat] librechat.yaml introuvable: $YAML"; exit 0; }

sed -i '/# >>> RYVIE-AI/,/# <<< RYVIE-AI/d' "$YAML" 2>/dev/null || true
echo "[librechat] endpoint « Ryvie AI » retiré"
