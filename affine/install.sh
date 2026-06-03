#!/bin/bash
set -euo pipefail

AFFINE_DIR="/data/apps/affine"
LOG_FILE="/data/logs/install-affine-$(date +%Y%m%d-%H%M%S).log"
NETBIRD_INTERFACE="wt0"
AFFINE_PORT="3015"                 # port hôte (le compose mappe 3015:3010)
API_BASE="http://localhost:${AFFINE_PORT}"
COOKIE_JAR="$(mktemp /tmp/affine-cookies.XXXXXX)"

# Compte admin par défaut (à changer après la première connexion)
RYVIE_EMAIL="ryvie@ryvie.fr"
RYVIE_PASSWORD="changeme1234"
RYVIE_NAME="ryvie"

mkdir -p /data/logs
mkdir -p "$AFFINE_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cleanup() { rm -f "$COOKIE_JAR" 2>/dev/null || true; }
trap cleanup EXIT

log "═══════════════════════════════════════════════════════════════"
log "🚀 INSTALLATION D'AFFINE"
log "═══════════════════════════════════════════════════════════════"

# 1. Récupérer l'IP NetBird (repli sur l'IP locale si indisponible)
log "🌐 Récupération de l'adresse IP..."
netbird_ip=$(ip addr show "$NETBIRD_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
if [ -z "$netbird_ip" ]; then
    netbird_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    log "   ⚠️ Interface NetBird $NETBIRD_INTERFACE introuvable, repli sur IP locale: $netbird_ip"
else
    log "   IP NetBird: $netbird_ip"
fi
base_url="http://${netbird_ip}:${AFFINE_PORT}"

# 2. Télécharger les images
log "-----------------------------------------------------"
log "🐳 Téléchargement des images Docker..."
log "-----------------------------------------------------"
cd "$AFFINE_DIR"
sudo docker compose pull || true

# 3. Démarrer la stack (db + redis + migration -> puis web)
log "🐳 Démarrage d'AFFiNE (base de données, migration, serveur)..."
sudo docker compose up -d

# 4. Attendre que le serveur réponde (la migration est terminée quand le web démarre)
log "⏳ Attente du serveur AFFiNE..."
retries=90
until curl -s -o /dev/null -w "%{http_code}" -X POST "${API_BASE}/graphql" \
        -H "Content-Type: application/json" \
        -d '{"query":"query{serverConfig{initialized}}"}' 2>/dev/null | grep -q "200"; do
    sleep 2
    retries=$((retries-1))
    if [ $retries -eq 0 ]; then
        log "❌ Le serveur AFFiNE n'a pas démarré à temps"
        exit 1
    fi
done
log "✅ Serveur AFFiNE prêt"

# 5. État d'initialisation (un seul admin possible au premier démarrage)
initialized=$(curl -s -X POST "${API_BASE}/graphql" \
    -H "Content-Type: application/json" \
    -d '{"query":"query{serverConfig{initialized}}"}' \
    | grep -o '"initialized":[a-z]*' | cut -d: -f2)

# 6. Créer le compte admin ryvie (uniquement si pas déjà initialisé)
if [ "$initialized" = "true" ]; then
    log "ℹ️  Serveur déjà initialisé — création du compte admin ignorée"
else
    log "👤 Création du compte admin ryvie..."
    create_http=$(curl -s -o /tmp/affine-create.out -w "%{http_code}" \
        -X POST "${API_BASE}/api/setup/create-admin-user" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${RYVIE_EMAIL}\",\"name\":\"${RYVIE_NAME}\",\"password\":\"${RYVIE_PASSWORD}\"}")
    if [ "$create_http" = "201" ] || [ "$create_http" = "200" ]; then
        log "   ✅ Compte admin créé (HTTP $create_http)"
    else
        log "   ⚠️ Réponse inattendue à la création de l'admin : HTTP $create_http"
        log "      $(cat /tmp/affine-create.out 2>/dev/null | head -c 300)"
    fi
    rm -f /tmp/affine-create.out 2>/dev/null || true
fi

# 7. Connexion pour obtenir une session (nécessaire pour la config serveur)
log "🔐 Connexion au compte admin..."
signin_http=$(curl -s -c "$COOKIE_JAR" -o /dev/null -w "%{http_code}" \
    -X POST "${API_BASE}/api/auth/sign-in" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${RYVIE_EMAIL}\",\"password\":\"${RYVIE_PASSWORD}\"}")
if [ "$signin_http" != "200" ]; then
    log "   ⚠️ Connexion échouée (HTTP $signin_http) — configuration serveur ignorée"
else
    log "   ✅ Session obtenue"

    # 8. Désactiver le workspace local de démo (supprime le bandeau rouge
    #    "Vos données locales sont enregistrées sur le navigateur et peuvent être perdues")
    #    -> retire la feature "LocalWorkspace" et force la connexion au cloud auto-hébergé.
    log "🧹 Désactivation du workspace local de démo (suppression du bandeau d'avertissement)..."
    flag_resp=$(curl -s -b "$COOKIE_JAR" -X POST "${API_BASE}/graphql" \
        -H "Content-Type: application/json" \
        -d '{"query":"mutation u($updates:[UpdateAppConfigInput!]!){updateAppConfig(updates:$updates)}","variables":{"updates":[{"module":"flags","key":"allowGuestDemoWorkspace","value":false}]}}')
    if echo "$flag_resp" | grep -q '"allowGuestDemoWorkspace":false'; then
        log "   ✅ Workspace local désactivé (bandeau supprimé)"
    else
        log "   ⚠️ Échec de la désactivation : $flag_resp"
    fi
fi

# 9. Écrire l'URL principale dans setup.json
SETUP_JSON="$AFFINE_DIR/setup.json"
echo "{\"setupUrl\": \"${base_url}\", \"appId\": \"affine\"}" > "$SETUP_JSON"
log "📝 URL principale écrite dans $SETUP_JSON"

# 10. Résumé
log "═══════════════════════════════════════════════════════════════"
log "✅ INSTALLATION TERMINÉE"
log "═══════════════════════════════════════════════════════════════"
log "📁 Répertoire AFFiNE : $AFFINE_DIR"
log "🌐 URL               : $base_url"
log "👤 Compte admin      : $RYVIE_EMAIL / $RYVIE_PASSWORD"
log "📋 Log complet       : $LOG_FILE"
log "═══════════════════════════════════════════════════════════════"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ AFFiNE est installé et prêt !"
echo ""
echo "   Interface : $base_url"
echo "   Compte    : $RYVIE_EMAIL / $RYVIE_PASSWORD"
echo "📋 Log complet : $LOG_FILE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
