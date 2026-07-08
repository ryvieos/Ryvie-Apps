#!/bin/bash
#
# Installation Twenty CRM pour Ryvie — exécuté UNE fois au premier install.
# - Calcule l'URL externe (IP NetBird de préférence, repli IP LAN) pour SERVER_URL :
#   Twenty l'utilise pour le front, les liens et la config CORS ; si elle ne correspond
#   pas à l'URL d'accès, l'auth casse.
# - Génère ENCRYPTION_KEY + APP_SECRET UNE seule fois (persistés dans .env) : régénérer
#   ces clés rendrait illisibles les données chiffrées existantes.
# - Démarre la stack (quand un install.sh existe, Ryvie ne lance PAS docker compose).
#
set -euo pipefail

TWENTY_DIR="/data/apps/twenty"
NETBIRD_INTERFACE="wt0"
PORT="3030"

mkdir -p "$TWENTY_DIR/pg_data" "$TWENTY_DIR/server-local-data"

# IP LAN (repli) et IP NetBird (URL externe canonique, comme n8n)
lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
netbird_ip=$(ip addr show "$NETBIRD_INTERFACE" 2>/dev/null \
             | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
if [ -z "$netbird_ip" ]; then
  netbird_ip="$lan_ip"
fi

server_url="http://${netbird_ip}:${PORT}"

# Préserve les secrets déjà générés (rejouer install.sh ne doit pas les changer).
enc_key=""
app_secret=""
if [ -f "$TWENTY_DIR/.env" ]; then
  enc_key=$(grep -E '^ENCRYPTION_KEY=' "$TWENTY_DIR/.env" | head -n1 | cut -d= -f2- || true)
  app_secret=$(grep -E '^APP_SECRET=' "$TWENTY_DIR/.env" | head -n1 | cut -d= -f2- || true)
fi
[ -z "$enc_key" ] && enc_key=$(openssl rand -base64 32)
[ -z "$app_secret" ] && app_secret=$(openssl rand -base64 32)

# UID/GID propriétaire de /data (= utilisateur applicatif ryvie, quel que soit son
# UID selon la machine). server/worker tournent avec cet UID et écrivent le bind-mount
# server-local-data → sans alignement c'est EACCES. Fallback 1000 si illisible.
puid="$(stat -c '%u' /data 2>/dev/null || echo 1000)"
pgid="$(stat -c '%g' /data 2>/dev/null || echo 1000)"

cat > "$TWENTY_DIR/.env" << ENVEOF
# Généré automatiquement par install.sh — ne pas modifier
LOCAL_IP=${lan_ip}
TAG=v2.14.0
SERVER_URL=${server_url}
ENCRYPTION_KEY=${enc_key}
APP_SECRET=${app_secret}
PUID=${puid}
PGID=${pgid}
ENVEOF

echo "[twenty install] .env écrit (SERVER_URL=${server_url})"

# Démarrer la stack : quand un install.sh existe, Ryvie ne lance PAS docker compose
# lui-même — c'est à ce script de le faire (comme n8n/affine).
cd "$TWENTY_DIR"
docker compose up -d
echo "[twenty install] stack Twenty CRM démarrée"
