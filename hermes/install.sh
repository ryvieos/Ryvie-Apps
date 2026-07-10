#!/bin/bash
#
# Installation Hermes (Web NATIVE) pour Ryvie — exécuté UNE fois au premier install.
# Prépare l'espace de travail, démarre la stack, puis construit le dashboard web
# natif (comme n8n/affine : quand un install.sh existe, Ryvie ne lance PAS docker
# compose lui-même — c'est à ce script de le faire).
#
# Le dashboard natif (`hermes dashboard`) n'a PAS d'authentification par mot de
# passe : il tourne en mode --insecure (cf. docker-compose.yml). L'accès est
# protégé par la couche réseau/accès de Ryvie.
#
set -euo pipefail

HERMES_DIR="/data/apps/hermes"

mkdir -p "$HERMES_DIR/workspace"
cd "$HERMES_DIR"

# Identifiants + clé de session du dashboard (basic auth), stockés dans .env (lu
# automatiquement par docker compose). Le mot de passe est ensuite modifiable
# depuis Ryvie « Gérer les comptes ». Idempotent : on n'écrase pas les valeurs
# déjà présentes (sinon on réinitialiserait le mot de passe / déconnecterait tout
# le monde à chaque réinstall).
touch .env
# UID/GID propriétaire de /data (= utilisateur applicatif ryvie, quel que soit son
# UID selon la machine). L'image chowne son home + le bind-mount ./workspace sur cet
# UID (HERMES_UID/GID dans le compose). Fallback 1000 si /data illisible.
puid="$(stat -c '%u' /data 2>/dev/null || echo 1000)"
pgid="$(stat -c '%g' /data 2>/dev/null || echo 1000)"
grep -q '^PUID=' .env || echo "PUID=${puid}" >> .env
grep -q '^PGID=' .env || echo "PGID=${pgid}" >> .env
grep -q '^HERMES_DASHBOARD_BASIC_AUTH_USERNAME=' .env || \
  echo "HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin" >> .env
grep -q '^HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=' .env || \
  echo "HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=Changeme1234!" >> .env
grep -q '^HERMES_DASHBOARD_BASIC_AUTH_SECRET=' .env || \
  echo "HERMES_DASHBOARD_BASIC_AUTH_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '\n')" >> .env
echo "[hermes install] identifiants + clé de session du dashboard initialisés dans .env"

# Démarrer la stack
docker compose up -d
echo "[hermes install] stack Hermes démarrée"

# Le dashboard web natif a besoin de son build (hermes_cli/web_dist), absent de
# l'image. On le construit UNE fois en root (/opt/hermes appartient à root) ; il
# persiste ensuite dans le volume hermes-agent-src et le service s6 du dashboard
# le sert sans rebuild.
echo "[hermes install] attente du conteneur agent…"
for _ in $(seq 1 60); do
  if docker exec app-hermes-agent test -d /opt/hermes/web 2>/dev/null; then
    break
  fi
  sleep 2
done

echo "[hermes install] build du dashboard web natif (≈15s)…"
if docker exec -u 0 -w /opt/hermes/web app-hermes-agent npm run build; then
  echo "[hermes install] build du dashboard terminé"
else
  echo "[hermes install] (avertissement) build du dashboard échoué — à refaire manuellement"
fi

# Redémarrer l'agent pour que le service dashboard serve le build fraîchement créé.
docker restart app-hermes-agent >/dev/null
echo "[hermes install] interface web native disponible sur le port 9119"
echo "[hermes install] login par défaut : admin / Changeme1234!"
