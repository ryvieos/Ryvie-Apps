#!/bin/bash
# Script d'installation LibreChat pour Ryvie.
# Exécuté UNIQUEMENT à la première installation (ignoré lors des mises à jour).
# Rôle : générer le .env avec des secrets stables aux bonnes longueurs, puis
# démarrer la stack via docker compose.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

# Récupérer l'IP locale (comme le fait Ryvie pour les autres apps).
LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -z "${LOCAL_IP}" ] && LOCAL_IP="127.0.0.1"

# Générateur de secrets hexadécimaux (openssl si présent, sinon /dev/urandom).
gen_hex() {
  local bytes="$1"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "${bytes}"
  else
    head -c "${bytes}" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

if [ ! -f "${ENV_FILE}" ]; then
  echo "[librechat] Génération du fichier .env (secrets stables)…"
  # CREDS_KEY = 32 octets (64 hex) ; CREDS_IV = 16 octets (32 hex) — requis par LibreChat.
  CREDS_KEY="$(gen_hex 32)"
  CREDS_IV="$(gen_hex 16)"
  JWT_SECRET="$(gen_hex 32)"
  JWT_REFRESH_SECRET="$(gen_hex 32)"
  MEILI_MASTER_KEY="$(gen_hex 16)"

  cat > "${ENV_FILE}" <<EOF
# Fichier .env généré automatiquement par Ryvie (LibreChat)
# Ne pas modifier manuellement - contient des secrets stables.

# IP locale du serveur
LOCAL_IP=${LOCAL_IP}

# Secrets LibreChat (générés une seule fois)
CREDS_KEY=${CREDS_KEY}
CREDS_IV=${CREDS_IV}
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}

# Clé maître Meilisearch (partagée entre l'API et le service de recherche)
MEILI_MASTER_KEY=${MEILI_MASTER_KEY}

# Point central IA Ryvie — renseigné automatiquement à la connexion (Réglages → IA)
RYVIE_AI_KEY=
RYVIE_AI_BASE_URL=

# Providers externes : l'utilisateur saisit SA propre clé dans l'UI LibreChat
OPENAI_API_KEY=user_provided
ANTHROPIC_API_KEY=user_provided
GOOGLE_KEY=user_provided
EOF
  echo "[librechat] .env créé."
else
  echo "[librechat] .env déjà présent, conservation des secrets existants."
fi

# Démarrage de la stack.
echo "[librechat] Démarrage via docker compose…"
if docker compose version >/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi
echo "[librechat] ✅ Installation terminée."
