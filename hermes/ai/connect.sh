#!/bin/sh
# Hook de connexion IA de Hermes, exécuté par Ryvie (aiService.runHook) sur l'hôte.
#
# Hermes ne lit PAS d'env pour ses credentials LLM : la voie fiable est son fichier
# ~/.hermes/config.yaml (partagé entre l'agent et la webui via le volume hermes-home).
# On y écrit un provider « custom » (endpoint OpenAI-compatible) pointant vers LiteLLM,
# avec la master key interne et le modèle STABLE « ryvie-ai » (RYVIE_AI_MODEL).
# `base_url` a la priorité la plus haute côté Hermes → sélectionne de fait le custom.
#
# Reçoit de Ryvie : RYVIE_AI_API_KEY (master key LiteLLM), RYVIE_AI_BASE_URL
# (http://ryvie-litellm:PORT/v1), RYVIE_AI_MODEL (alias « ryvie-ai »).
set -e

CONTAINER="app-hermes-agent"
KEY="${RYVIE_AI_API_KEY:?master key manquante}"
URL="${RYVIE_AI_BASE_URL:?base url manquante}"
MODEL="${RYVIE_AI_MODEL:-ryvie-ai}"

# Écrit/fusionne le bloc model: dans config.yaml À L'INTÉRIEUR du conteneur agent
# (le volume hermes-home y est monté en écriture). Fusion via pyyaml si dispo pour
# préserver le reste de la config ; repli minimal sinon.
docker exec -i "$CONTAINER" python3 - "$KEY" "$URL" "$MODEL" <<'PY'
import os, sys
key, url, model = sys.argv[1], sys.argv[2], sys.argv[3]
home = os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")
path = os.path.join(home, "config.yaml")
os.makedirs(home, exist_ok=True)
try:
    import yaml
except Exception:
    yaml = None
data = {}
if yaml and os.path.exists(path):
    try:
        data = yaml.safe_load(open(path)) or {}
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}
m = data.get("model") if isinstance(data.get("model"), dict) else {}
m.update({"provider": "custom", "default": model, "base_url": url, "api_key": key})
data["model"] = m
# Désactive le catalogue de modèles intégré de Hermes (centaines de modèles
# Nous/OpenRouter non servis par LiteLLM) : le sélecteur ne propose alors que ce
# que LiteLLM expose réellement (ryvie-ai, …). Le vrai modèle se choisit
# dans les réglages IA de Ryvie, pas dans Hermes.
mc = data.get("model_catalog") if isinstance(data.get("model_catalog"), dict) else {}
mc["enabled"] = False
data["model_catalog"] = mc
if yaml:
    with open(path, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False)
else:
    with open(path, "w") as f:
        f.write('model:\n  provider: custom\n  default: "%s"\n  base_url: "%s"\n  api_key: "%s"\n'
                % (model, url, key))
print("hermes: config.yaml mis à jour (provider=custom, model=%s, base=%s)" % (model, url))
PY

# L'agent (gateway) lit config.yaml au démarrage → on le redémarre pour recharger.
docker restart "$CONTAINER" >/dev/null
echo "hermes: agent reconfiguré vers LiteLLM et redémarré."
