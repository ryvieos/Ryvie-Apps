#!/usr/bin/env python3
"""
ryvie-accounts.py — Fiche de gestion des comptes Mealie.

Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-mealie, qui embarque
python3 + la lib de hash bcrypt (via passlib, dépendance d'auth de Mealie). Ryvie
ne fait que la déclencher (docker exec) et lire son résultat.

Mealie stocke ses comptes dans SQLite (table `users`) avec un hash bcrypt. On
réutilise le hasher présent dans l'app pour garantir la compatibilité au login.

Sous-commandes :
  list                       -> JSON des comptes sur stdout
  reset  (env RESET_ID/PWD)  -> réécrit le hash + déverrouille + vérifie -> "OK"/"FAIL"
  verify (env RESET_ID/PWD)  -> "OK" si le mot de passe correspond, sinon "NO"

Env : DB_PATH (chemin de la base SQLite, défaut /app/data/mealie.db).
"""
import os
import sys
import json
import sqlite3

DB_PATH = os.environ.get("DB_PATH", "/app/data/mealie.db")


def _hash(pwd: str) -> str:
    # bcrypt direct si présent, sinon passlib (toujours là dans Mealie).
    try:
        import bcrypt
        return bcrypt.hashpw(pwd.encode(), bcrypt.gensalt(rounds=12)).decode()
    except ImportError:
        from passlib.hash import bcrypt as pbcrypt
        return pbcrypt.using(rounds=12).hash(pwd)


def _verify(pwd: str, h: str) -> bool:
    if not h:
        return False
    try:
        import bcrypt
        return bcrypt.checkpw(pwd.encode(), h.encode())
    except ImportError:
        from passlib.hash import bcrypt as pbcrypt
        try:
            return pbcrypt.verify(pwd, h)
        except Exception:
            return False


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    con = sqlite3.connect(DB_PATH)
    try:
        if cmd == "list":
            rows = con.execute(
                'SELECT id, email, username, admin FROM users'
            ).fetchall()
            out = [
                {"id": str(r[0]), "email": r[1], "username": r[2], "isAdmin": bool(r[3])}
                for r in rows
            ]
            print(json.dumps(out))

        elif cmd == "reset":
            rid = os.environ["RESET_ID"]
            pwd = os.environ["RESET_PWD"]
            h = _hash(pwd)
            # Déverrouille le compte (Mealie verrouille après N échecs).
            con.execute(
                'UPDATE users SET password = ?, login_attemps = 0, locked_at = NULL '
                'WHERE id = ?',
                (h, rid),
            )
            con.commit()
            row = con.execute(
                'SELECT password FROM users WHERE id = ?', (rid,)
            ).fetchone()
            print("OK" if row and _verify(pwd, row[0]) else "FAIL")

        elif cmd == "verify":
            rid = os.environ["RESET_ID"]
            pwd = os.environ["RESET_PWD"]
            row = con.execute(
                'SELECT password FROM users WHERE id = ?', (rid,)
            ).fetchone()
            print("OK" if row and _verify(pwd, row[0]) else "NO")

        else:
            sys.stderr.write(f"sous-commande inconnue: {cmd}\n")
            sys.exit(2)
    finally:
        con.close()


if __name__ == "__main__":
    main()
