#!/bin/bash
# Script d'installation OpenClaw pour Ryvie.
# Exécuté UNIQUEMENT à la première installation (ignoré lors des mises à jour).
# Rôle : préparer les dossiers de données, configurer l'auth de la gateway
# (mode mot de passe + accès HTTP LAN), puis démarrer la stack.
set -euo pipefail

cd "$(dirname "$0")"

# Mot de passe par défaut de l'UI de contrôle (convention Ryvie, à changer).
DEFAULT_PASSWORD="Changeme1234!"

# Détermine la commande docker compose disponible.
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
else
  DC="docker-compose"
fi

# Dossiers de données (config/workspace + secrets d'auth). L'image tourne en
# utilisateur non-root : on aligne le propriétaire sur PUID/PGID = propriétaire de
# /data (utilisateur ryvie, quel que soit son UID) pour éviter les EACCES.
# Fallback 1000 si /data illisible → inchangé sur les appliances.
puid="$(stat -c '%u' /data 2>/dev/null || echo 1000)"
pgid="$(stat -c '%g' /data 2>/dev/null || echo 1000)"
mkdir -p ./data/openclaw ./data/auth
chown -R "$puid:$pgid" ./data 2>/dev/null || true

# PUID/PGID lus par docker compose (user:) via le .env du dossier de l'app.
touch .env
grep -q '^PUID=' .env || echo "PUID=${puid}" >> .env
grep -q '^PGID=' .env || echo "PGID=${pgid}" >> .env

# Configuration de l'authentification de la gateway (persistée dans openclaw.json,
# lue au démarrage ; idempotent). On applique :
#  - gateway.auth.mode=password + un mot de passe → connexion à l'UI par mot de
#    passe simple (plutôt qu'un long jeton) ;
#  - dangerouslyDisableDeviceAuth + allowInsecureAuth → l'UI de contrôle exige
#    normalement un contexte sécurisé (HTTPS/localhost) pour créer une identité
#    d'appareil ; en accès HTTP direct sur le LAN (launcher Ryvie, http://ip:18789)
#    le navigateur ne peut pas la générer, donc on désactive cette exigence.
#    ⚠️ Baisse de sécurité assumée, à réserver à un réseau de confiance
#    (pour un accès public, préférer HTTPS et retirer ces flags).
echo "[openclaw] Configuration de l'auth de la gateway (mode mot de passe, accès HTTP LAN)…"
${DC} run --rm --no-deps --entrypoint node openclaw \
  openclaw.mjs config set --batch-json \
  "[{\"path\":\"gateway.auth.mode\",\"value\":\"password\"},{\"path\":\"gateway.auth.password\",\"value\":\"${DEFAULT_PASSWORD}\"},{\"path\":\"gateway.controlUi.dangerouslyDisableDeviceAuth\",\"value\":true},{\"path\":\"gateway.controlUi.allowInsecureAuth\",\"value\":true}]" 2>/dev/null \
  || echo "[openclaw] (config set non appliqué, à vérifier)"

# Démarrage de la stack.
echo "[openclaw] Démarrage via docker compose…"
${DC} up -d
echo "[openclaw] ✅ Installation terminée. Ouvrez l'app et connectez-vous (mot de passe par défaut : ${DEFAULT_PASSWORD})."
