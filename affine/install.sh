#!/bin/bash
#
# Installation automatisée d'AFFiNE pour Ryvie.
# Exécuté UNE SEULE FOIS par le backend lors d'une nouvelle installation
# (les mises à jour passent par `docker compose` et ignorent ce script).
#
# Ce script :
#   1. détermine l'URL d'accès (IP NetBird) et l'écrit dans .env
#      (AFFINE_SERVER_EXTERNAL_URL — indispensable, sinon CORS bloque la synchro) ;
#   2. démarre la stack (db + redis + migration + web + proxy nginx) ;
#   3. crée le compte admin par défaut « ryvie » ;
#   4. force le cloud auto-hébergé (désactive le workspace local de démo).
# Le masquage du bandeau « données locales » est assuré par le proxy nginx
# (voir nginx.conf), indépendamment de ce script.
#
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
AFFINE_DIR="/data/apps/affine"
LOG_FILE="/data/logs/install-affine-$(date +%Y%m%d-%H%M%S).log"
NETBIRD_INTERFACE="wt0"
AFFINE_PORT="3015"                       # port hôte exposé par le proxy nginx
API_BASE="http://localhost:${AFFINE_PORT}"
COOKIE_JAR="$(mktemp /tmp/affine-cookies.XXXXXX)"

# Compte admin par défaut (à changer après la première connexion)
RYVIE_EMAIL="ryvie@ryvie.fr"
RYVIE_PASSWORD="changeme1234"
RYVIE_NAME="ryvie"

# ─── Utilitaires ────────────────────────────────────────────────────────────
mkdir -p /data/logs "$AFFINE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
cleanup() { rm -f "$COOKIE_JAR" 2>/dev/null || true; }
trap cleanup EXIT

gql() { # exécute une requête GraphQL ($1 = corps JSON), avec session si dispo
  curl -s -b "$COOKIE_JAR" -X POST "${API_BASE}/graphql" \
    -H "Content-Type: application/json" -d "$1"
}

log "═══════════════════════════════════════════════════════════════"
log "🚀 INSTALLATION D'AFFINE"
log "═══════════════════════════════════════════════════════════════"

# ─── 1. URL d'accès (IP NetBird, repli sur l'IP locale) ─────────────────────
log "🌐 Détermination de l'URL d'accès..."
netbird_ip=$(ip addr show "$NETBIRD_INTERFACE" 2>/dev/null \
             | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
if [ -z "$netbird_ip" ]; then
    netbird_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    log "   ⚠️ NetBird ($NETBIRD_INTERFACE) introuvable, repli sur l'IP locale : $netbird_ip"
else
    log "   IP NetBird : $netbird_ip"
fi
base_url="http://${netbird_ip}:${AFFINE_PORT}"

# ─── 2. Écrire .env (URL externe lue par le service web via le compose) ─────
# Sans AFFINE_SERVER_EXTERNAL_URL, AFFiNE garde « localhost » comme origine
# autorisée et BLOQUE en CORS les requêtes venant de http://<ip>:3015 :
# la synchro des workspaces cloud échoue alors silencieusement.
cat > "$AFFINE_DIR/.env" << ENVEOF
# Généré automatiquement par install.sh — ne pas modifier
AFFINE_SERVER_EXTERNAL_URL=${base_url}
ENVEOF
log "📝 .env écrit (AFFINE_SERVER_EXTERNAL_URL=${base_url})"

# ─── 3. Démarrer la stack ───────────────────────────────────────────────────
cd "$AFFINE_DIR"
log "🐳 Téléchargement des images Docker..."
sudo docker compose pull || true
log "🐳 Démarrage d'AFFiNE (db, redis, migration, web, proxy)..."
sudo docker compose up -d

# ─── 4. Attendre que le serveur réponde ─────────────────────────────────────
# (la migration s'achève avant le démarrage du web ; on interroge via le proxy)
log "⏳ Attente du serveur AFFiNE..."
retries=90
until [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "${API_BASE}/graphql" \
            -H "Content-Type: application/json" \
            -d '{"query":"query{serverConfig{initialized}}"}' 2>/dev/null)" = "200" ]; do
    sleep 2
    retries=$((retries-1))
    if [ "$retries" -le 0 ]; then
        log "❌ Le serveur AFFiNE n'a pas démarré à temps"
        exit 1
    fi
done
log "✅ Serveur AFFiNE prêt"

# ─── 5. Créer le compte admin (uniquement au tout premier démarrage) ────────
initialized=$(gql '{"query":"query{serverConfig{initialized}}"}' \
              | grep -o '"initialized":[a-z]*' | cut -d: -f2)

if [ "$initialized" = "true" ]; then
    log "ℹ️  Serveur déjà initialisé — création du compte admin ignorée"
else
    log "👤 Création du compte admin « ${RYVIE_NAME} »..."
    create_http=$(curl -s -o /tmp/affine-create.out -w "%{http_code}" \
        -X POST "${API_BASE}/api/setup/create-admin-user" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${RYVIE_EMAIL}\",\"name\":\"${RYVIE_NAME}\",\"password\":\"${RYVIE_PASSWORD}\"}")
    case "$create_http" in
        200|201) log "   ✅ Compte admin créé (HTTP $create_http)" ;;
        *)       log "   ⚠️ Réponse inattendue (HTTP $create_http) : $(head -c 300 /tmp/affine-create.out 2>/dev/null)" ;;
    esac
    rm -f /tmp/affine-create.out 2>/dev/null || true
fi

# ─── 6. Connexion (session requise pour la config serveur) ──────────────────
log "🔐 Connexion au compte admin..."
signin_http=$(curl -s -c "$COOKIE_JAR" -o /dev/null -w "%{http_code}" \
    -X POST "${API_BASE}/api/auth/sign-in" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${RYVIE_EMAIL}\",\"password\":\"${RYVIE_PASSWORD}\"}")

if [ "$signin_http" != "200" ]; then
    log "   ⚠️ Connexion échouée (HTTP $signin_http) — configuration serveur ignorée"
else
    log "   ✅ Session obtenue"

    # ─── 7. Forcer le cloud auto-hébergé ────────────────────────────────────
    # Désactive le workspace local de démo : les nouveaux utilisateurs sont
    # dirigés vers la connexion (données stockées sur le serveur, non fragiles).
    log "🔧 Désactivation du workspace local de démo (cloud par défaut)..."
    flag_resp=$(gql '{"query":"mutation u($u:[UpdateAppConfigInput!]!){updateAppConfig(updates:$u)}","variables":{"u":[{"module":"flags","key":"allowGuestDemoWorkspace","value":false}]}}')
    if echo "$flag_resp" | grep -q '"allowGuestDemoWorkspace":false'; then
        log "   ✅ Cloud auto-hébergé défini par défaut"
    else
        log "   ⚠️ Échec : $flag_resp"
    fi
fi

# ─── 8. URL principale pour Ryvie ───────────────────────────────────────────
echo "{\"setupUrl\": \"${base_url}\", \"appId\": \"affine\"}" > "$AFFINE_DIR/setup.json"
log "📝 URL principale écrite dans setup.json"

# ─── 9. Résumé ──────────────────────────────────────────────────────────────
log "═══════════════════════════════════════════════════════════════"
log "✅ INSTALLATION TERMINÉE"
log "   📁 Répertoire : $AFFINE_DIR"
log "   🌐 URL        : $base_url"
log "   👤 Compte     : $RYVIE_EMAIL / $RYVIE_PASSWORD"
log "   📋 Log        : $LOG_FILE"
log "═══════════════════════════════════════════════════════════════"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ AFFiNE est installé et prêt !"
echo "   Interface : $base_url"
echo "   Compte    : $RYVIE_EMAIL / $RYVIE_PASSWORD"
echo "═══════════════════════════════════════════════════════════════"
echo ""
