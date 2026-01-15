#!/bin/bash
 
set -e
 
echo "=== Installation de TwentyCRM ==="
 
# Détection de l'IP principale de la machine
# On essaie plusieurs méthodes pour être robuste
detect_ip() {
    # Méthode 1: IP de l'interface réseau principale (exclut loopback et docker)
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | grep -v '172.1[6-9].' | grep -v '172.2[0-9].' | grep -v '172.3[0-1].' | head -n1)
 
    if [ -z "$IP" ]; then
        # Méthode 2: via hostname -I
        IP=$(hostname -I | awk '{print $1}')
    fi
 
    if [ -z "$IP" ]; then
        # Méthode 3: via ip route
        IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null)
    fi
 
    if [ -z "$IP" ]; then
        echo "❌ Impossible de détecter l'IP de la machine"
        exit 1
    fi
 
    echo "$IP"
}
 
# Génération d'un secret aléatoire sécurisé
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}
 
echo "🔍 Détection de l'IP de la machine..."
MACHINE_IP=$(detect_ip)
echo "✅ IP détectée: $MACHINE_IP"
 
echo "🔐 Génération du secret d'application..."
APP_SECRET=$(generate_secret)
 
echo "📝 Création du fichier .env..."
cat > .env << EOF
# Configuration TwentyCRM
DOMAIN=$MACHINE_IP
PORT=3023
APP_SECRET=$APP_SECRET
POSTGRES_PASSWORD=postgres
EOF
 
echo "✅ Fichier .env créé avec succès"
echo ""
echo "📋 Configuration:"
echo "   - Domaine: $MACHINE_IP"
echo "   - Port: 3023"
echo "   - Secret: [généré]"
echo ""
echo "🚀 Pour démarrer TwentyCRM, exécutez:"
echo "   docker compose up -d"
echo ""
echo "🌐 Accès à l'application:"
echo "   - http://$MACHINE_IP:3023"
echo "   - http://localhost:3023 (local)"
 

