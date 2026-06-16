#!/bin/sh
# Hook de BOOTSTRAP n8n, exécuté par Ryvie à l'INSTALL (aiService.bootstrapAppSecret),
# pendant que le compte propriétaire par défaut et son mot de passe sont encore valides.
#
# Crée UNE clé API n8n longue durée et la renvoie à Ryvie (stockée chiffrée dans
# appSecrets). Ainsi la connexion IA ultérieure (ai/connect.sh) n'a JAMAIS besoin du
# mot de passe — même si l'utilisateur le change AVANT de connecter l'IA.
#
# N'a PAS besoin que l'IA soit configurée (ne crée aucune credential LiteLLM ici) :
# c'est uniquement la création/stockage de la clé API. Idempotent (skip si déjà une
# clé valide). Reçoit : RYVIE_APP_LOGIN_EMAIL/PASSWORD, RYVIE_APP_SECRET (json),
# RYVIE_APP_SECRET_OUT (chemin de sortie).
python3 - <<'PY'
import os, json, urllib.request, http.cookiejar
N8N   = "http://127.0.0.1:5678"
EMAIL = os.environ.get("RYVIE_APP_LOGIN_EMAIL", "changeme@ryvie.fr")
PASS  = os.environ.get("RYVIE_APP_LOGIN_PASSWORD", "Changeme1234!")
secret = json.loads(os.environ.get("RYVIE_APP_SECRET") or "{}")
OUT = os.environ.get("RYVIE_APP_SECRET_OUT")
apikey = secret.get("apiKey")

def pub(method, path, body=None):
    """Appel API PUBLIQUE n8n, authentifié par la clé API (pas de mot de passe)."""
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

# Idempotent : si une clé API valide est déjà stockée, rien à faire.
if apikey_valid():
    print("n8n bootstrap: clé API déjà présente, rien à faire.")
    raise SystemExit(0)

# Login propriétaire (identifiants par défaut, valides à l'install) → API interne.
cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
def lc(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(N8N + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    return op.open(req, timeout=20)

try:
    lc("POST", "/rest/login", {"emailOrLdapLoginId": EMAIL, "password": PASS})
except Exception as e:
    raise SystemExit("n8n bootstrap: login par défaut échoué (%s) — clé API non créée." % e)

# Nettoie d'anciennes clés « Ryvie AI » pour éviter l'accumulation.
try:
    for k in json.load(lc("GET", "/rest/api-keys")).get("data", []):
        if k.get("label") == "Ryvie AI":
            try: lc("DELETE", "/rest/api-keys/" + k["id"])
            except Exception: pass
except Exception:
    pass

d = json.load(lc("POST", "/rest/api-keys", {
    "label": "Ryvie AI",
    "scopes": ["credential:create", "credential:delete", "credential:list", "credential:update"],
    "expiresAt": None,
})).get("data", {})
apikey = d.get("rawApiKey") or d.get("apiKey")
if not apikey:
    raise SystemExit("n8n bootstrap: création de la clé API impossible (réponse inattendue).")

# Renvoie la clé à Ryvie (stockée chiffrée) → connexion IA ultérieure sans mot de passe.
if OUT:
    try: json.dump({"apiKey": apikey}, open(OUT, "w"))
    except Exception as e: print("secret out warn:", e)
print("n8n bootstrap: clé API créée et stockée (connexion IA désormais indépendante du mot de passe).")
PY
