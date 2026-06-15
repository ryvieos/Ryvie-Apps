#!/bin/sh
# Hook de déconnexion IA de Hermes : retire le provider LiteLLM de ~/.hermes/config.yaml
# (clés provider/default/base_url/api_key du bloc model:) puis redémarre l'agent.
# Le reste de la config est préservé. Symétrique de connect.sh.
set -e

CONTAINER="app-hermes-agent"

docker exec -i "$CONTAINER" python3 - <<'PY'
import os
home = os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")
path = os.path.join(home, "config.yaml")
try:
    import yaml
except Exception:
    yaml = None
if not (yaml and os.path.exists(path)):
    print("hermes: pas de config.yaml à nettoyer.")
    raise SystemExit(0)
try:
    data = yaml.safe_load(open(path)) or {}
except Exception:
    data = {}
# Réactive le catalogue de modèles natif de Hermes (désactivé par connect.sh).
mc = data.get("model_catalog")
if isinstance(mc, dict):
    mc["enabled"] = True
    data["model_catalog"] = mc
m = data.get("model")
if isinstance(m, dict):
    for k in ("provider", "default", "base_url", "api_key"):
        m.pop(k, None)
    if m:
        data["model"] = m
    else:
        data.pop("model", None)
    with open(path, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False)
    print("hermes: provider LiteLLM retiré de config.yaml.")
else:
    with open(path, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False)
    print("hermes: aucun provider LiteLLM à retirer.")
PY

docker restart "$CONTAINER" >/dev/null
echo "hermes: agent déconnecté de LiteLLM et redémarré."
