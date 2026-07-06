#!/usr/bin/env python3
"""
ryvie-accounts.py — Fiche de gestion des comptes Home Assistant.

Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-homeassistant, qui
embarque python3 + la CLI native `hass --script auth` (list/validate/change_password).
Ryvie ne fait que la déclencher (docker exec) et lire son résultat.

Home Assistant stocke ses comptes dans /config/.storage/auth (+ le hash du mot de
passe dans auth_provider.homeassistant). Plutôt que de manipuler ces fichiers, on
réutilise la CLI officielle de HA → compatibilité garantie au login, quelle que
soit la version.

Sous-commandes :
  list                        -> JSON des comptes sur stdout
  reset  (env RESET_ID/PWD)   -> hass change_password + revalide -> "OK"/"FAIL"
  verify (env RESET_ID/PWD)   -> "OK" si le mot de passe correspond, sinon "NO"

RESET_ID = le nom d'utilisateur HA (souvent l'email). Le mot de passe est lu depuis
l'environnement (jamais sur la ligne de commande du cœur Ryvie) puis passé à la CLI
`hass` DANS le conteneur de l'app.

⚠️ Après un change_password, Home Assistant doit être REDÉMARRÉ pour relire les
identifiants (l'auth est cachée en mémoire) → la recette déclare resetRestarts: true,
le cœur Ryvie redémarre le conteneur après le reset.
"""
import os
import sys
import json
import subprocess

CONFIG = os.environ.get("HA_CONFIG", "/config")
AUTH_FILE = os.path.join(CONFIG, ".storage", "auth")


def load_accounts():
    """Liste les comptes du provider homeassistant en joignant credentials -> users."""
    with open(AUTH_FILE, encoding="utf-8") as f:
        data = json.load(f).get("data", {})
    users = {u["id"]: u for u in data.get("users", [])}
    out = []
    for cred in data.get("credentials", []):
        if cred.get("auth_provider_type") != "homeassistant":
            continue
        username = (cred.get("data") or {}).get("username")
        if not username:
            continue
        u = users.get(cred.get("user_id")) or {}
        # Ignore les comptes système (ex. « Home Assistant Content »).
        if u.get("system_generated"):
            continue
        # HA se connecte avec le « username » (souvent un email) → on l'expose en
        # `email` (affiché en principal par l'UI). Le nom d'affichage va en `username`
        # (affiché en secondaire), sauf s'il est identique à l'identifiant.
        name = u.get("name")
        out.append({
            "id": username,          # identifiant de login, utilisé par reset/verify
            "email": username,       # ce avec quoi on se connecte → affiché en principal
            "username": name if name and name != username else None,
            "isAdmin": bool(u.get("is_owner")),
        })
    return out


def hass_auth(*args):
    return subprocess.run(
        ["hass", "--script", "auth", "--config", CONFIG, *args],
        capture_output=True, text=True,
    )


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""

    if cmd == "list":
        print(json.dumps(load_accounts()))

    elif cmd == "verify":
        r = hass_auth("validate", os.environ["RESET_ID"], os.environ["RESET_PWD"])
        # La CLI imprime « Auth valid » / « Auth invalid » (et sort toujours en 0).
        print("OK" if "Auth valid" in r.stdout else "NO")

    elif cmd == "reset":
        rid = os.environ["RESET_ID"]
        pwd = os.environ["RESET_PWD"]
        r = hass_auth("change_password", rid, pwd)
        if r.returncode != 0:
            sys.stderr.write((r.stderr or r.stdout or "")[:200])
            print("FAIL")
            return
        # Vérifie au niveau du stockage : un nouveau process `hass validate` relit le
        # fichier (le HA en cours tourne encore sur l'ancien hash jusqu'au restart).
        v = hass_auth("validate", rid, pwd)
        print("OK" if "Auth valid" in v.stdout else "FAIL")

    else:
        sys.stderr.write(f"sous-commande inconnue: {cmd}\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
