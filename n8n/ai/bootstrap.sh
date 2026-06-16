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
#
# ROBUSTESSE : à l'install, n8n vient de démarrer — /healthz peut répondre AVANT que
# l'API REST (login, /rest/api-keys) soit réellement opérationnelle. On attend donc
# activement (retry/backoff) que le login ET la création de clé répondent, et on lit
# les réponses de façon défensive (un body vide n'a jamais le droit de produire une
# traceback Python : on émet un message clair et on sort proprement).
python3 - <<'PY'
import os, json, time, urllib.request, urllib.error, http.cookiejar
N8N   = "http://127.0.0.1:5678"
EMAIL = os.environ.get("RYVIE_APP_LOGIN_EMAIL", "changeme@ryvie.fr")
PASS  = os.environ.get("RYVIE_APP_LOGIN_PASSWORD", "Changeme1234!")
secret = json.loads(os.environ.get("RYVIE_APP_SECRET") or "{}")
OUT = os.environ.get("RYVIE_APP_SECRET_OUT")
apikey = secret.get("apiKey")

def read_json(resp, ctx):
    """Lit le corps d'une réponse et le parse en JSON. Lève un message clair (jamais
    une traceback brute) si le corps est vide ou non-JSON — typiquement n8n pas prêt."""
    raw = resp.read()
    if not raw or not raw.strip():
        raise ValueError("réponse vide pour %s (n8n pas prêt ?)" % ctx)
    try:
        return json.loads(raw)
    except ValueError:
        snippet = raw[:120].decode("utf-8", "replace")
        raise ValueError("réponse non-JSON pour %s: %r" % (ctx, snippet))

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

# Attente active : n8n peut ne pas être prêt juste après l'install. On retente le login
# jusqu'à ~60 s (30 × 2 s) avant d'abandonner. Un login OK pose aussi le cookie de session.
last = None
logged_in = False
for _ in range(30):
    try:
        r = lc("POST", "/rest/login", {"emailOrLdapLoginId": EMAIL, "password": PASS})
        if 200 <= getattr(r, "status", 200) < 300:
            logged_in = True
            break
    except Exception as e:
        last = e
    time.sleep(2)
if not logged_in:
    raise SystemExit("n8n bootstrap: login par défaut échoué après attente (%s) — clé API non créée." % last)

# Nettoie d'anciennes clés « Ryvie AI » pour éviter l'accumulation. Best-effort total.
try:
    keys = read_json(lc("GET", "/rest/api-keys"), "/rest/api-keys (liste)").get("data", [])
    for k in keys:
        if k.get("label") == "Ryvie AI":
            try: lc("DELETE", "/rest/api-keys/" + k["id"])
            except Exception: pass
except Exception:
    pass

# Création de la clé : on retente (~30 s) car l'endpoint peut répondre vide tant que
# n8n finalise son init, et on lit la réponse de façon défensive (jamais de traceback).
apikey = None
last = None
for _ in range(15):
    try:
        d = read_json(lc("POST", "/rest/api-keys", {
            "label": "Ryvie AI",
            "scopes": ["credential:create", "credential:delete", "credential:list", "credential:update"],
            "expiresAt": None,
        }), "/rest/api-keys (création)").get("data", {})
        apikey = d.get("rawApiKey") or d.get("apiKey")
        if apikey:
            break
        last = "réponse sans clé"
    except Exception as e:
        last = e
    time.sleep(2)
if not apikey:
    raise SystemExit("n8n bootstrap: création de la clé API impossible (%s)." % last)

# Renvoie la clé à Ryvie (stockée chiffrée) → connexion IA ultérieure sans mot de passe.
if OUT:
    try: json.dump({"apiKey": apikey}, open(OUT, "w"))
    except Exception as e: print("secret out warn:", e)
print("n8n bootstrap: clé API créée et stockée (connexion IA désormais indépendante du mot de passe).")
PY
