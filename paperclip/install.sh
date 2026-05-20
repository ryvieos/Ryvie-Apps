#!/bin/bash
set -euo pipefail

PAPERCLIP_DIR="/data/apps/paperclip"
LOG_FILE="/data/logs/install-paperclip-$(date +%Y%m%d-%H%M%S).log"
NETBIRD_INTERFACE="wt0"

mkdir -p /data/logs
mkdir -p "$PAPERCLIP_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "═══════════════════════════════════════════════════════════════"
log "🚀 INSTALLATION DE PAPERCLIP"
log "═══════════════════════════════════════════════════════════════"

# 1. Récupérer l'IP NetBird
log "🌐 Récupération de l'adresse IP NetBird..."
netbird_ip=$(ip addr show "$NETBIRD_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
if [ -z "$netbird_ip" ]; then
    log "❌ Interface NetBird $NETBIRD_INTERFACE introuvable. Vérifiez la connexion NetBird."
    exit 1
fi
log "   IP NetBird: $netbird_ip"

# 2. Générer le secret
log "🔑 Génération du secret d'authentification..."
secret=$(openssl rand -base64 32)
log "   ✅ Secret généré"

# 3. Créer le .env
log "📝 Création du fichier .env..."
cat > "$PAPERCLIP_DIR/.env" << EOF
PAPERCLIP_URL_BASE="http://$netbird_ip"
BETTER_AUTH_SECRET="$secret"
DATABASE_URL="postgres://paperclip:paperclip@db:5432/paperclip"
EOF
log "   ✅ Fichier .env créé"

# 4. Permissions avant démarrage
log "🔐 Application des permissions..."
mkdir -p "$PAPERCLIP_DIR/data/paperclip"
sudo chown -R 1000:1000 "$PAPERCLIP_DIR/data/paperclip"
log "   ✅ Permissions appliquées"

# 5. Pull des images
log "-----------------------------------------------------"
log "🐳 Téléchargement des images Docker..."
log "-----------------------------------------------------"
cd "$PAPERCLIP_DIR"
sudo docker compose pull || true

# 6. Démarrer uniquement la DB
log "🐳 Démarrage de la base de données..."
sudo docker compose up -d db

# 7. Attendre que la DB soit healthy
log "⏳ Attente de la base de données..."
retries=60
while [ $retries -gt 0 ]; do
    container_id=$(sudo docker compose ps -q db 2>/dev/null || true)
    if [ -n "$container_id" ]; then
        health=$(sudo docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "")
        if [ "$health" = "healthy" ]; then
            log "✅ Base de données healthy"
            break
        fi
    fi
    sleep 2
    retries=$((retries-1))
done
if [ $retries -eq 0 ]; then
    log "❌ Timeout - la base de données n'a pas démarré"
    exit 1
fi

# 8. Onboard non-interactif en background
log "⚙️  Configuration de Paperclip (onboard)..."
sudo docker compose run --rm \
    -e PAPERCLIP_HOME=/paperclip \
    -e CI=true \
    server \
    sh -c "cd /app && node cli/node_modules/tsx/dist/cli.mjs cli/src/index.ts onboard --yes --bind lan" &
ONBOARD_PID=$!

# Attendre que le config.json soit créé et valide
log "⏳ Attente de la configuration..."
retries=60
while [ $retries -gt 0 ]; do
    if [ -f "$PAPERCLIP_DIR/data/paperclip/instances/default/config.json" ] && \
       grep -q '"deploymentMode"' "$PAPERCLIP_DIR/data/paperclip/instances/default/config.json" 2>/dev/null; then
        log "✅ Configuration créée"
        break
    fi
    sleep 2
    retries=$((retries-1))
done
if [ $retries -eq 0 ]; then
    log "❌ Timeout - la configuration n'a pas été créée"
    exit 1
fi

# Tuer le container temporaire
sudo docker compose kill server 2>/dev/null || true
sudo docker compose rm -f server 2>/dev/null || true
wait $ONBOARD_PID 2>/dev/null || true
log "   ✅ Onboard terminé"

# 9. Permissions après onboard
log "🔐 Correction des permissions post-onboard..."
sudo chown -R 1000:1000 "$PAPERCLIP_DIR/data/paperclip"
log "   ✅ Permissions corrigées"

# 10. Démarrer le vrai serveur
log "🐳 Démarrage du serveur Paperclip..."
sudo docker compose up -d server

# 11. Attendre que le serveur soit prêt
log "⏳ Attente du serveur Paperclip..."
retries=30
until sudo docker exec paperclip-server-1 curl -sf http://localhost:3100/api/health &>/dev/null; do
    sleep 3
    retries=$((retries-1))
    if [ $retries -eq 0 ]; then
        log "❌ Le serveur Paperclip n'a pas démarré à temps"
        exit 1
    fi
done
log "✅ Serveur Paperclip prêt"

# 12. Bootstrap CEO
log "-----------------------------------------------------"
log "🔑 Génération du lien d'invitation admin..."
log "-----------------------------------------------------"
invite_output=$(sudo docker exec paperclip-server-1 sh -c \
    "cd /app && node cli/node_modules/tsx/dist/cli.mjs cli/src/index.ts auth bootstrap-ceo --base-url http://$netbird_ip:3100")
invite_url=$(echo "$invite_output" | grep -oP 'http://\S+')
log "   Invite URL: $invite_url"

# 13. Link à la bonne adresse
SETUP_JSON="$PAPERCLIP_DIR/setup.json"
echo "{\"setupUrl\": \"$invite_url\", \"appId\": \"paperclip\"}" > "$SETUP_JSON"
log "📝 Setup URL écrit dans $SETUP_JSON"

# 14. Résumé
log "═══════════════════════════════════════════════════════════════"
log "✅ INSTALLATION TERMINÉE"
log "═══════════════════════════════════════════════════════════════"
log "📁 Répertoire Paperclip : $PAPERCLIP_DIR"
log "🌐 IP NetBird           : $netbird_ip"
log "📋 Log complet          : $LOG_FILE"
log "═══════════════════════════════════════════════════════════════"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Paperclip est installé et prêt !"
echo ""
echo "   👉 Ouvre ce lien pour créer ton compte admin :"
echo "   $invite_url"
echo ""
echo "   Interface : http://$netbird_ip:3100"
echo "📋 Log complet : $LOG_FILE"
echo "═══════════════════════════════════════════════════════════════"
echo ""