#!/bin/sh
# Hook de déconnexion IA de n8n : supprime la/les credential(s) « Ryvie AI (LiteLLM) ».
# Utilise la clé API stockée (RYVIE_APP_SECRET.apiKey) si disponible — donc SANS mot de
# passe — sinon retombe sur un login propriétaire. La clé API est CONSERVÉE pour qu'une
# reconnexion ultérieure reste indépendante du mot de passe.
python3 - <<'PY'
import os, json, urllib.request, http.cookiejar
N8N  = "http://127.0.0.1:5678"
NAME = "Ryvie AI (LiteLLM)"
EMAIL = os.environ.get("RYVIE_APP_LOGIN_EMAIL", "changeme@ryvie.fr")
PASS  = os.environ.get("RYVIE_APP_LOGIN_PASSWORD", "Changeme1234!")
secret = json.loads(os.environ.get("RYVIE_APP_SECRET") or "{}")
apikey = secret.get("apiKey")

def pub(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(N8N + path, data=data, method=method,
        headers={"Content-Type": "application/json", "X-N8N-API-KEY": apikey})
    return urllib.request.urlopen(req, timeout=20)

def apikey_valid():
    if not apikey:
        return False
    try:
        pub("GET", "/api/v1/credentials?limit=1"); return True
    except Exception:
        return False

n = 0
if apikey_valid():
    # Chemin clé API (sans mot de passe).
    try:
        for c in json.load(pub("GET", "/api/v1/credentials")).get("data", []):
            if c.get("name") == NAME:
                try: pub("DELETE", "/api/v1/credentials/" + c["id"]); n += 1
                except Exception as e: print("del warn:", e)
    except Exception as e:
        print("list warn:", e)
else:
    # Repli : login propriétaire + API interne.
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    def call(method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(N8N + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        return op.open(req, timeout=20)
    try:
        call("POST", "/rest/login", {"emailOrLdapLoginId": EMAIL, "password": PASS})
    except Exception as e:
        raise SystemExit("n8n: login échoué (%s), rien à nettoyer." % e)
    try:
        for c in json.load(call("GET", "/rest/credentials")).get("data", []):
            if c.get("name") == NAME:
                try: call("DELETE", "/rest/credentials/" + c["id"]); n += 1
                except Exception as e: print("del warn:", e)
    except Exception as e:
        print("list warn:", e)

print("n8n: IA déconnectée (%d credential(s) supprimée(s))" % n)
PY
