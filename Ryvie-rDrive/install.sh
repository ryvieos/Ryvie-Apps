#!/usr/bin/env bash
#==========================================
# Ryvie rDrive Installation Script
#==========================================
# Description: Standalone installation script for Ryvie rDrive
# Author: Ryvie Project
# Version: 1.0
#==========================================

set -e

# Détecter l'utilisateur réel même si le script est lancé avec sudo
EXEC_USER="${SUDO_USER:-$USER}"
EXEC_HOME="$(getent passwd "$EXEC_USER" | cut -d: -f6)"
if [ -z "$EXEC_HOME" ]; then
    EXEC_HOME="/home/$EXEC_USER"
fi

echo ""
echo "  ____  ____       _           "
echo " |  _ \|  _ \ _ __(_)_   _____ "
echo " | |_) | | | | '__| \ \ / / _ \\"
echo " |  _ <| |_| | |  | |\ V /  __/"
echo " |_| \_\____/|_|  |_| \_/ \___|"
echo ""
echo "Installation de Ryvie rDrive 🚀"
echo "By Jules Maisonnave"
echo ""

#==========================================
# GLOBAL PATHS
#==========================================
DATA_ROOT="/data"
APPS_DIR="$DATA_ROOT/apps"
CONFIG_DIR="$DATA_ROOT/config"
LOG_DIR="$DATA_ROOT/logs"
NETBIRD_INTERFACE="wt0"

#==========================================
# LOGGING FUNCTIONS
#==========================================
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

#==========================================
# UTILITY FUNCTIONS
#==========================================

# Get machine ID
get_machine_id() {
    if [ -f /etc/machine-id ]; then
        cat /etc/machine-id
    else
        uuidgen 2>/dev/null || echo "$(hostname)-$(date +%s)"
    fi
}

# Get NetBird IP from config file
get_netbird_ip() {
    local ip=""
    
    # Vérifier que le fichier de config existe
    if [ ! -f "$CONFIG_DIR/netbird/.env" ]; then
        log_error "Fichier de configuration NetBird introuvable: $CONFIG_DIR/netbird/.env"
        log_error "Veuillez installer et configurer NetBird d'abord."
        exit 1
    fi
    
    # Lire l'IP depuis le fichier
    ip=$(grep -E '^NETBIRD_IP=' "$CONFIG_DIR/netbird/.env" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    
    # Vérifier que l'IP a été trouvée
    if [ -z "$ip" ]; then
        log_error "NETBIRD_IP non trouvé dans $CONFIG_DIR/netbird/.env"
        log_error "Le fichier de configuration NetBird est incomplet ou corrompu."
        exit 1
    fi
    
    echo "$ip"
}

# Get local private IP address (non-NetBird interface)
get_private_ip() {
    local ip
    
    # Récupérer l'IP de l'interface principale
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)
    
    # Vérifier que l'IP a été trouvée
    if [ -z "$ip" ]; then
        log_error "Impossible de déterminer l'IP privée de la machine"
        log_error "Vérifiez votre configuration réseau"
        exit 1
    fi
    
    echo "$ip"
}

#==========================================
# GÉNÉRATION DU .ENV
#==========================================

generate_rdrive_env() {
    local rdrive_app_dir="$APPS_DIR/Ryvie-rDrive/tdrive"
    
    if [ -d "$rdrive_app_dir" ]; then
        log_info "Génération du .env pour rDrive..."
        
        # Récupérer l'IP NetBird
        local netbird_ip
        netbird_ip=$(get_netbird_ip)
        
        # Récupérer l'IP privée locale
        local private_ip
        private_ip=$(get_private_ip)
        
        # Charger le mot de passe LDAP depuis le fichier .env
        local ldap_admin_password=""
        if [ -f "$CONFIG_DIR/ldap/.env" ]; then
            source "$CONFIG_DIR/ldap/.env"
            ldap_admin_password="$LDAP_ADMIN_PASSWORD"
        fi
        
        # Générer le fichier .env directement dans le répertoire de l'app
        local rdrive_app_env="$rdrive_app_dir/.env"
        [ -f "$rdrive_app_env" ] && cp "$rdrive_app_env" "$rdrive_app_env.bak.$(date +%s)" || true
        
        cat > "$rdrive_app_env" << EOF
REACT_APP_FRONTEND_URL=http://$netbird_ip:3010
REACT_APP_BACKEND_URL=http://$netbird_ip:4000
REACT_APP_WEBSOCKET_URL=ws://$netbird_ip:4000/ws
REACT_APP_ONLYOFFICE_CONNECTOR_URL=http://$netbird_ip:5000
REACT_APP_ONLYOFFICE_DOCUMENT_SERVER_URL=http://$netbird_ip:8090
LDAP_BIND_PASSWORD=$ldap_admin_password
# Service OAuth centralisé (NE PAS MODIFIER)
OAUTH_SERVICE_URL=https://cloudoauth-files.ryvie.fr
INSTANCE_ID=$(get_machine_id)
REACT_APP_FRONTEND_URL_PRIVATE=$private_ip
EOF
        
        chmod 600 "$rdrive_app_env" || true
        chown "$EXEC_USER:$EXEC_USER" "$rdrive_app_env" 2>/dev/null || true
        log_info "✅ .env rDrive généré → $rdrive_app_env"
    else
        log_info "⚠️ Ryvie-rDrive non trouvé, skip de la génération du .env rDrive"
    fi
    
    log_info "Configuration d'environnement terminée"
}

#==========================================
# INSTALLATION ET LANCEMENT DE RDRIVE
#==========================================

install_and_launch_rdrive() {
    echo "-----------------------------------------------------"
    echo "Installation et lancement de Ryvie rDrive (compose unique)"
    echo "-----------------------------------------------------"
    
    # Dossier rDrive
    RDRIVE_DIR="$APPS_DIR/Ryvie-rDrive/tdrive"
    
    # 1) Vérifier la présence du compose et du .env
    cd "$RDRIVE_DIR" || { echo "❌ Impossible d'accéder à $RDRIVE_DIR"; exit 1; }
    
    if [ ! -f docker-compose.yml ]; then
        echo "❌ docker-compose.yml introuvable dans $RDRIVE_DIR"
        echo "   Place le fichier docker-compose.yml ici puis relance."
        exit 1
    fi
    
    # Le .env est généré directement dans le dossier de l'app
    if [ ! -f "$RDRIVE_DIR/.env" ]; then
        echo "⚠️ $RDRIVE_DIR/.env introuvable — tentative de régénération…"
        generate_rdrive_env || {
            echo "❌ Impossible de générer $RDRIVE_DIR/.env"
            exit 1
        }
    fi
    
    # 2) Lancement unique
    echo "🚀 Démarrage de la stack rDrive…"
    sudo docker compose --env-file "$RDRIVE_DIR/.env" pull || true
    sudo docker compose --env-file "$RDRIVE_DIR/.env" up -d --build
    
    echo ""
    echo "🧪 Test rclone (container app-rdrive-node)"
    if command -v docker >/dev/null 2>&1 && sudo docker ps --format '{{.Names}}' | grep -q '^app-rdrive-node$'; then
        sudo docker exec -it app-rdrive-node sh -lc '/usr/bin/rclone version && /usr/bin/rclone --config /root/.config/rclone/rclone.conf listremotes -vv' || true
    else
        echo "ℹ️ Container app-rdrive-node non démarré (test container ignoré)"
    fi
    
    # 3) Attentes/health (best-effort)
    echo "⏳ Attente des services (mongo, onlyoffice, node, frontend)…"
    wait_for_service() {
        local svc="$1"
        local retries=60
        while [ $retries -gt 0 ]; do
            if sudo docker compose ps --format json | jq -e ".[] | select(.Service==\"$svc\") | .State==\"running\"" >/dev/null 2>&1; then
                # si health est défini, essaye de lire
                if sudo docker inspect --format='{{json .State.Health}}' "$(sudo docker compose ps -q "$svc")" 2>/dev/null | jq -e '.Status=="healthy"' >/dev/null 2>&1; then
                    echo "✅ $svc healthy"
                    return 0
                fi
                # sinon, running suffit
                echo "✅ $svc en cours d'exécution"
                return 0
            fi
            sleep 2
            retries=$((retries-1))
        done
        echo "⚠️ Timeout d'attente pour $svc"
        return 1
    }
    
    echo "✅ rDrive est lancé via docker-compose unique."
    echo "   Frontend accessible (par défaut) sur http://localhost:3010"
}

#==========================================
# MAIN EXECUTION
#==========================================

main() {
    log_info "=== Début de l'installation de Ryvie rDrive ==="
    
    # Générer la configuration .env
    generate_rdrive_env
    
    # Installer et lancer rDrive
    install_and_launch_rdrive
    
    log_info "=== Installation de Ryvie rDrive terminée ==="
    echo ""
    echo "======================================================"
    echo "✅ Installation terminée avec succès !"
    echo "======================================================"
    echo ""
    echo "📍 Informations importantes :"
    echo "   - Configuration: $CONFIG_DIR/rdrive/.env"
    echo "   - Application: $APPS_DIR/Ryvie-rDrive/tdrive"
    echo "   - Frontend: http://$(get_netbird_ip):3010"
    echo "   - Backend: http://$(get_netbird_ip):4000"
    echo ""
    echo "📝 Commandes utiles :"
    echo "   - Voir les logs: cd $APPS_DIR/Ryvie-rDrive/tdrive && sudo docker compose logs -f"
    echo "   - Arrêter: cd $APPS_DIR/Ryvie-rDrive/tdrive && sudo docker compose down"
    echo "   - Redémarrer: cd $APPS_DIR/Ryvie-rDrive/tdrive && sudo docker compose restart"
    echo "   - Status: cd $APPS_DIR/Ryvie-rDrive/tdrive && sudo docker compose ps"
    echo ""
}

# Execute main function
main "$@"
