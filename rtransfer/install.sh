#!/bin/bash

# Script d'installation de Ryvie rDrop

# path des apps
DATA_ROOT="/data"
CONFIG_DIR="$DATA_ROOT/config"
APPS_DIR="$DATA_ROOT/apps"
RTRANSFER_DIR="$APPS_DIR/rtransfer"
EXEC_USER="${SUDO_USER:-$USER}"

# Vérifier que jq est installé, sinon l'installer
if ! command -v jq &> /dev/null; then
    echo "❌ jq n'est pas installé. Installation en cours..."
    sudo apt-get update && sudo apt-get install -y jq
    if ! command -v jq &> /dev/null; then
        echo "❌ Échec de l'installation de jq."
        exit 1
    fi
    echo "✅ jq installé avec succès."
fi

echo "lancement du script d'installation de Ryvie rtransfer..."
# Créer le répertoire rtransfer s'il n'existe pas
mkdir -p "$RTRANSFER_DIR"
cd "$RTRANSFER_DIR"

Créer le fichier .env avec les variables nécessaires
echo "📝 Création du fichier .env..."

# Charger le mot de passe LDAP depuis le fichier .env
if [ -f "$CONFIG_DIR/ldap/.env" ]; then
  source "$CONFIG_DIR/ldap/.env"
else
  echo "❌ Fichier $CONFIG_DIR/ldap/.env introuvable"
  exit 1
fi


# Extraire l'URL NetBird pour rtransfer depuis le fichier JSON
if [ -f "$CONFIG_DIR/netbird/netbird-data.json" ]; then
  NETBIRD_URL=$(jq -r '.domains.rtransfer' "$CONFIG_DIR/netbird/netbird-data.json")
else
  echo "❌ Fichier $CONFIG_DIR/netbird/netbird-data.json introuvable"
  exit 1
fi


cat <<EOF > .env
APP_URL=$NETBIRD_URL
LDAP_BIND_PASSWORD=$LDAP_ADMIN_PASSWORD
EOF

echo "✅ Fichier .env créé."

# 5. Lancer les services Immich en mode production
echo "🚀 Lancement de rtransfer avec Docker Compose..."
sudo docker compose -f docker-compose.yml up -d

# 6. Attente du démarrage du service (optionnel : tester avec un port ouvert)
echo "⏳ Attente du démarrage de rtransfer (port 3011)..."
until curl -s http://localhost:3011 > /dev/null; do
    sleep 2
    echo -n "."
done
echo ""
echo "✅ rtransfer est lancé."
echo "✅ Installation de Ryvie rtransfer terminée!"