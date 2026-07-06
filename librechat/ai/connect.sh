#!/bin/sh
# Hook de connexion IA de LibreChat, exécuté par Ryvie (aiService.runHook) APRÈS
# le (re)démarrage du conteneur. Rôle : injecter l'endpoint "Ryvie AI" dans
# librechat.yaml, puis recharger LibreChat pour qu'il l'affiche.
# Reçoit en env : RYVIE_APP_DIR, RYVIE_AI_KEY, RYVIE_AI_BASE_URL, RYVIE_AI_MODEL…
set -e

APP_DIR="${RYVIE_APP_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
YAML="${APP_DIR}/librechat.yaml"
MODEL="${RYVIE_AI_MODEL:-ryvie-ai}"

[ -f "$YAML" ] || { echo "[librechat] librechat.yaml introuvable: $YAML"; exit 0; }

# Idempotence : retirer un éventuel bloc géré existant avant de le réécrire.
sed -i '/# >>> RYVIE-AI/,/# <<< RYVIE-AI/d' "$YAML" 2>/dev/null || true

# Ajouter l'endpoint "Ryvie AI" (bloc délimité par des marqueurs, top-level YAML).
# LibreChat récupère la liste des modèles dynamiquement via LiteLLM (fetch: true).
cat >> "$YAML" <<YML
# >>> RYVIE-AI (géré par Ryvie — ne pas éditer) >>>
endpoints:
  custom:
    - name: "Ryvie AI"
      apiKey: "\${RYVIE_AI_KEY}"
      baseURL: "\${RYVIE_AI_BASE_URL}"
      models:
        default: ["${MODEL}"]
        fetch: true
      titleConvo: true
      titleModel: "current_model"
      modelDisplayLabel: "Ryvie AI"
# <<< RYVIE-AI <<<
YML

# Recharger la config : `docker restart` préserve les réseaux attachés (ryvie-ai).
docker restart app-librechat >/dev/null 2>&1 || true
echo "[librechat] endpoint « Ryvie AI » activé (model=${MODEL})"
