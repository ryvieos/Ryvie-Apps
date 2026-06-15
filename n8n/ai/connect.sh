#!/bin/sh
# Hook de connexion IA de n8n, exécuté par Ryvie (aiService.runHook).
# n8n NE lit PAS d'env pour ses credentials : il faut les créer via son API.
#
# Stratégie « clé API » (robuste face aux changements d'identifiants) :
#  - Si Ryvie a déjà une clé API n8n (RYVIE_APP_SECRET.apiKey) et qu'elle est valide,
#    on l'utilise pour (re)créer la credential — SANS mot de passe.
#  - Sinon (1ère fois, ou clé révoquée), on se logue UNE fois avec le compte
#    propriétaire (RYVIE_APP_LOGIN_*), on crée une clé API longue durée, et on la
#    renvoie à Ryvie (RYVIE_APP_SECRET_OUT) qui la stocke chiffrée pour la suite.
# Reçoit : RYVIE_AI_API_KEY, RYVIE_AI_BASE_URL, RYVIE_APP_LOGIN_EMAIL/PASSWORD,
#          RYVIE_APP_SECRET (json), RYVIE_APP_SECRET_OUT (chemin).
python3 - <<'PY'
import os, json, urllib.request, urllib.error, http.cookiejar
N8N  = "http://127.0.0.1:5678"
NAME = "Ryvie AI (LiteLLM)"
KEY  = os.environ["RYVIE_AI_API_KEY"]
URL  = os.environ["RYVIE_AI_BASE_URL"]
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

# 1) Garantir une clé API valide (login propriétaire seulement si nécessaire).
if not apikey_valid():
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
        raise SystemExit(
            "n8n: login échoué (%s). Aucune clé API enregistrée et le compte par défaut "
            "ne correspond plus. Reconnecte-toi avec les identifiants n8n actuels, ou crée "
            "une credential OpenAI manuellement (apiKey=master key, url=%s)." % (e, URL))
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
        raise SystemExit("n8n: création de la clé API impossible (réponse inattendue).")

# 2) Credential OpenAI → LiteLLM. On MET À JOUR en place si elle existe déjà (PATCH →
# l'ID est préservé, donc les nœuds n8n qui la référencent ne cassent pas) ; sinon on la
# crée. header:false débloque le validateur strict de l'API publique pour openAiApi.
DATA = {"apiKey": KEY, "url": URL, "header": False}
existing = []
try:
    existing = [c for c in json.load(pub("GET", "/api/v1/credentials")).get("data", []) if c.get("name") == NAME]
except Exception as e:
    print("list warn:", e)

try:
    if existing:
        cid = existing[0]["id"]
        pub("PATCH", "/api/v1/credentials/" + cid, {"name": NAME, "type": "openAiApi", "data": DATA})
        print("n8n: credential IA « %s » mise à jour, ID préservé (→ LiteLLM)." % NAME)
        for dup in existing[1:]:  # nettoie d'éventuels doublons
            try: pub("DELETE", "/api/v1/credentials/" + dup["id"])
            except Exception as e: print("dup warn:", e)
    else:
        pub("POST", "/api/v1/credentials", {"name": NAME, "type": "openAiApi", "data": DATA})
        print("n8n: credential IA « %s » créée via clé API (→ LiteLLM). Sélectionne-la dans tes nœuds IA." % NAME)
except urllib.error.HTTPError as e:
    raise SystemExit("n8n: enregistrement credential échoué (%s): %s" % (e.code, e.read().decode()[:300]))

# 4) Renvoie la clé API à Ryvie pour réutilisation (sans mot de passe la prochaine fois).
if OUT:
    try: json.dump({"apiKey": apikey}, open(OUT, "w"))
    except Exception as e: print("secret out warn:", e)
PY
