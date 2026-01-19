#!/bin/bash

# Script d'installation de Ryvie rDrop

# path des apps
DATA_ROOT="/data"
CONFIG_DIR="$DATA_ROOT/config"
APPS_DIR="$DATA_ROOT/apps"
RPICTURES_DIR="$APPS_DIR/rpictures"
EXEC_USER="${SUDO_USER:-$USER}"

echo "lancement du script d'installation de Ryvie rPictures..."
# Créer le répertoire rPictures s'il n'existe pas
mkdir -p "$RPICTURES_DIR"
cd "$RPICTURES_DIR"

Créer le fichier .env avec les variables nécessaires
echo "📝 Création du fichier .env..."

# Charger le mot de passe LDAP depuis le fichier .env
if [ -f "$CONFIG_DIR/ldap/.env" ]; then
+
  source "$CONFIG_DIR/ldap/.env"
else
  echo "❌ Fichier $CONFIG_DIR/ldap/.env introuvable"
  exit 1
fi

cat <<EOF > .env
# The location where your uploaded files are stored
UPLOAD_LOCATION=./library

# The location where your database files are stored. Network shares are not supported for the database
DB_DATA_LOCATION=./postgres

# To set a timezone, uncomment the next line and change Etc/UTC to a TZ identifier from this list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
# TZ=Etc/UTC

# The Immich version to use. You can pin this to a specific version like "v2.1.0"
IMMICH_VERSION=v2

# Connection secret for postgres. You should change it to a random password
# Please use only the characters \`A-Za-z0-9\`, without special characters or spaces
DB_PASSWORD=postgres

# The values below this line do not need to be changed
###################################################################################
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

LDAP_URL= ldap://openldap:1389
LDAP_BIND_DN=cn=admin,dc=example,dc=org
LDAP_BIND_PASSWORD=$LDAP_ADMIN_PASSWORD
LDAP_BASE_DN=dc=example,dc=org
LDAP_USER_BASE_DN=ou=users,dc=example,dc=org
LDAP_USER_FILTER=(objectClass=inetOrgPerson)
LDAP_ADMIN_GROUP=admins
LDAP_EMAIL_ATTRIBUTE=mail
LDAP_NAME_ATTRIBUTE=cn
LDAP_PASSWORD_ATTRIBUTE=userPassword
EOF

echo "✅ Fichier .env créé."

# 5. Lancer les services Immich en mode production
echo "🚀 Lancement de rPictures avec Docker Compose..."
sudo docker compose -f docker-compose.yml up -d

# 6. Attente du démarrage du service (optionnel : tester avec un port ouvert)
echo "⏳ Attente du démarrage de rPictures (port 3013)..."
until curl -s http://localhost:3013 > /dev/null; do
    sleep 2
    echo -n "."
done
echo ""
echo "✅ rPictures est lancé."
echo "ℹ️ Note: La synchronisation LDAP se fera après la création du premier utilisateur."
echo "Installation de Ryvie rPictures terminée."
