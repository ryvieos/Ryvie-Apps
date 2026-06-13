#!/bin/sh
# Hook de déconnexion IA d'open-notebook (exécuté par Ryvie pendant que l'app est
# encore up). Supprime la/les credential(s) Ryvie (et leurs modèles associés).
API="http://127.0.0.1:5055"
CRED_NAME="Ryvie AI (LiteLLM)"

# App injoignable → rien à nettoyer.
curl -fsS "$API/api/models/providers" >/dev/null 2>&1 || { echo "open-notebook: API injoignable, rien à faire"; exit 0; }

curl -fsS "$API/api/credentials" 2>/dev/null | python3 -c "
import sys, json, urllib.request
try: creds = json.load(sys.stdin)
except Exception: creds = []
n = 0
for c in creds:
    if c.get('name') == '$CRED_NAME':
        r = urllib.request.Request('$API/api/credentials/' + c['id'], method='DELETE')
        try: urllib.request.urlopen(r, timeout=10); n += 1
        except Exception as e: print('del warn:', e)
print('open-notebook: IA déconnectée (%d credential(s) supprimée(s))' % n)
" || true
