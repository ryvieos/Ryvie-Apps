#!/bin/bash
#
# Installation n8n pour Ryvie — exécuté UNE fois au premier install.
# Écrit l'URL externe (IP NetBird) dans .env pour que les liens d'invitation
# et de setup n8n soient accessibles (sinon n8n utilise http://localhost:5678,
# inatteignable depuis un autre appareil).
#
set -euo pipefail

N8N_DIR="/data/apps/n8n"
NETBIRD_INTERFACE="wt0"
PORT="5678"

mkdir -p "$N8N_DIR"

# IP LAN (repli) et IP NetBird (URL externe canonique, comme affine)
lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
netbird_ip=$(ip addr show "$NETBIRD_INTERFACE" 2>/dev/null \
             | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
# NB: un `[ -z ] && ...` casserait avec `set -e` quand le test est faux. On utilise un if.
if [ -z "$netbird_ip" ]; then
  netbird_ip="$lan_ip"
fi

base_url="http://${netbird_ip}:${PORT}"

cat > "$N8N_DIR/.env" << ENVEOF
# Généré automatiquement par install.sh — ne pas modifier
LOCAL_IP=${lan_ip}
N8N_EDITOR_BASE_URL=${base_url}
ENVEOF

echo "[n8n install] .env écrit (N8N_EDITOR_BASE_URL=${base_url})"

# Démarrer la stack : quand un install.sh existe, Ryvie ne lance PAS docker compose
# lui-même — c'est à ce script de le faire (comme affine/paperclip).
cd "$N8N_DIR"
docker compose up -d
echo "[n8n install] stack n8n démarrée"
