#!/bin/bash

# Script d'installation de Ryvie rDrop

# path des apps
DATA_ROOT="/data"
APPS_DIR="$DATA_ROOT/apps"
RDROP_DIR="$APPS_DIR/rDrop"
EXEC_USER="${SUDO_USER:-$USER}"

cd "$RDROP_DIR"

# cloner le dépôt Ryvie-rdrop s'il n'existe pas
if [ -d "Ryvie-rdrop" ]; then
    echo "✅ Le dépôt Ryvie-rdrop existe déjà."
else
    echo "📥 Clonage du dépôt Ryvie-rdrop..."
    sudo -H -u "$EXEC_USER" git clone https://github.com/ryvieos/Ryvie-rdrop.git
    if [ $? -ne 0 ]; then
        echo "❌ Échec du clonage du dépôt Ryvie-rdrop."
        exit 1
    fi
fi

cd Ryvie-rdrop/rDrop-main

echo "✅ Répertoire atteint : $(pwd)"

# Rendre le script create.sh exécutable
if [ -f docker/openssl/create.sh ]; then
    chmod +x docker/openssl/create.sh
    echo "✅ Script create.sh rendu exécutable."
else
    echo "❌ Script docker/openssl/create.sh introuvable."
    exit 1
fi

# lancer le docker compose
echo "📦 Suppression des conteneurs orphelins..."
sudo docker compose down --remove-orphans
sudo docker compose up -d

echo "✅ Ryvie rDrop installé et démarré avec succès."