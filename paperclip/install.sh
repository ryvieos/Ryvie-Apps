#!/bin/bash
set -euo pipefail

PAPERCLIP_DIR="/data/apps/paperclip"
LOG_FILE="/data/logs/install-paperclip-$(date +%Y%m%d-%H%M%S).log"
NETBIRD_INTERFACE="wt0"
RYVIE_EMAIL="ryvie@ryvie.fr"
RYVIE_PASSWORD="changeme1234"
RYVIE_NAME="ryvie"

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
cat > "$PAPERCLIP_DIR/.env" << ENVEOF
PAPERCLIP_URL_BASE="http://$netbird_ip"
BETTER_AUTH_SECRET="$secret"
DATABASE_URL="postgres://paperclip:paperclip@db:5432/paperclip"
ENVEOF
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
until sudo docker exec app-paperclip-server curl -sf http://localhost:3100/api/health &>/dev/null; do
    sleep 3
    retries=$((retries-1))
    if [ $retries -eq 0 ]; then
        log "❌ Le serveur Paperclip n'a pas démarré à temps"
        exit 1
    fi
done
log "✅ Serveur Paperclip prêt"

# 12. Bootstrap CEO (récupérer le token d'invite)
log "-----------------------------------------------------"
log "🔑 Génération du token d'invitation admin..."
log "-----------------------------------------------------"
invite_output=$(sudo docker exec app-paperclip-server sh -c \
    "cd /app && node cli/node_modules/tsx/dist/cli.mjs cli/src/index.ts auth bootstrap-ceo --base-url http://$netbird_ip:3100")
invite_url=$(echo "$invite_output" | grep -oP 'http://\S+')
invite_token=$(echo "$invite_url" | grep -oP 'pcp_bootstrap_\S+')
if [ -z "$invite_token" ]; then
    log "❌ Impossible d'extraire le token bootstrap"
    exit 1
fi
log "   Token d'invite: $invite_token"

# 13. Créer le compte ryvie (ignoré si déjà existant)
log "👤 Création du compte ryvie..."
signup_http=$(sudo docker exec app-paperclip-server curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://localhost:3100/api/auth/sign-up/email \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$RYVIE_NAME\",\"email\":\"$RYVIE_EMAIL\",\"password\":\"$RYVIE_PASSWORD\"}")
if [ "$signup_http" = "200" ]; then
    log "   ✅ Compte créé (HTTP $signup_http)"
elif [ "$signup_http" = "422" ]; then
    log "   ℹ️  Compte déjà existant, on continue (HTTP $signup_http)"
else
    log "   ⚠️  Réponse inattendue du sign-up : HTTP $signup_http"
fi

# 14. Se connecter et récupérer la valeur du cookie de session
# FIX: le regex extrait uniquement la VALEUR du cookie (après le =), pas "nom=valeur"
log "🔐 Connexion au compte ryvie..."
session_cookie=$(sudo docker exec app-paperclip-server curl -s -i \
    -X POST http://localhost:3100/api/auth/sign-in/email \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$RYVIE_EMAIL\",\"password\":\"$RYVIE_PASSWORD\"}" \
    2>/dev/null | grep -i "set-cookie" | grep -oP '(?<=paperclip-default\.session_token=)[^;]+' || true)

if [ -z "$session_cookie" ]; then
    log "❌ Impossible de récupérer le cookie de session (mauvais mot de passe ?)"
    exit 1
fi
log "   ✅ Session récupérée"

# 15. Accepter l'invite bootstrap (devient CEO)
log "👑 Attribution du rôle CEO..."
accept_response=$(sudo docker exec app-paperclip-server curl -s \
    -X POST "http://localhost:3100/api/invites/$invite_token/accept" \
    -H "Content-Type: application/json" \
    -H "Origin: http://$netbird_ip:3100" \
    -H "Cookie: paperclip-default.session_token=$session_cookie" \
    -d '{"requestType":"human"}')
log "   Réponse accept: $accept_response"

if echo "$accept_response" | grep -q "bootstrapAccepted"; then
    log "   ✅ Compte ryvie configuré comme CEO"
else
    log "   ❌ Échec de l'attribution CEO — réponse: $accept_response"
    exit 1
fi

# 16. Écrire l'URL principale dans setup.json
SETUP_JSON="$PAPERCLIP_DIR/setup.json"
echo "{\"setupUrl\": \"http://$netbird_ip:3100\", \"appId\": \"paperclip\"}" > "$SETUP_JSON"
log "📝 URL principale écrite dans $SETUP_JSON"

# 17. Résumé
log "═══════════════════════════════════════════════════════════════"
log "✅ INSTALLATION TERMINÉE"
log "═══════════════════════════════════════════════════════════════"
log "📁 Répertoire Paperclip : $PAPERCLIP_DIR"
log "🌐 IP NetBird           : $netbird_ip"
log "👤 Compte               : $RYVIE_EMAIL / $RYVIE_PASSWORD"
log "📋 Log complet          : $LOG_FILE"
log "═══════════════════════════════════════════════════════════════"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Paperclip est installé et prêt !"
echo ""
echo "   Interface : http://$netbird_ip:3100"
echo "   Compte    : $RYVIE_EMAIL / $RYVIE_PASSWORD"
echo "📋 Log complet : $LOG_FILE"
echo "═══════════════════════════════════════════════════════════════"
echo ""