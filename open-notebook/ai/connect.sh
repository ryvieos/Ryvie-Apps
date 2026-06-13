#!/bin/sh
# Hook de connexion IA d'open-notebook, exécuté par Ryvie (aiService.runHook).
# Reçoit en env : RYVIE_AI_API_KEY, RYVIE_AI_BASE_URL, RYVIE_AI_MODEL, RYVIE_AI_PROVIDER…
# open-notebook a son propre registre de modèles : l'env ne suffit pas, il faut
# créer une credential + un modèle + définir les défauts via son API (port 5055).
set -e

API="http://127.0.0.1:5055"
MODEL="${RYVIE_AI_MODEL:-gpt-4o-mini}"
CRED_NAME="Ryvie AI (LiteLLM)"

# 1) Attendre que l'API open-notebook réponde (le conteneur vient de redémarrer).
i=0
while [ "$i" -lt 40 ]; do
  if curl -fsS "$API/api/models/providers" >/dev/null 2>&1; then break; fi
  i=$((i+1)); sleep 3
done

# 2) Idempotence : supprimer les credentials Ryvie existantes (et leurs modèles).
curl -fsS "$API/api/credentials" 2>/dev/null | python3 -c "
import sys, json, urllib.request
try: creds = json.load(sys.stdin)
except Exception: creds = []
for c in creds:
    if c.get('name') == '$CRED_NAME':
        r = urllib.request.Request('$API/api/credentials/' + c['id'], method='DELETE')
        try: urllib.request.urlopen(r, timeout=10)
        except Exception as e: print('cleanup warn:', e)
" || true

# 3) Créer la credential (clé + base LiteLLM), puis le modèle, puis les défauts.
python3 - <<PY
import json, urllib.request, os
API="$API"; MODEL="$MODEL"; NAME="$CRED_NAME"
def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API+path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

cred = call("POST", "/api/credentials", {
    "name": NAME, "provider": "openai", "modalities": ["language"],
    "api_key": os.environ["RYVIE_AI_API_KEY"], "base_url": os.environ["RYVIE_AI_BASE_URL"],
})
model = call("POST", "/api/models", {
    "name": MODEL, "provider": "openai", "type": "language", "credential": cred["id"],
})
call("PUT", "/api/models/defaults", {
    "default_chat_model": model["id"], "default_transformation_model": model["id"],
    "default_tools_model": model["id"], "large_context_model": model["id"],
})
print("open-notebook: IA connectée (model=%s, cred=%s)" % (MODEL, cred["id"]))
PY
