/**
 * ryvie-accounts.mjs — Fiche de gestion des comptes Paperclip.
 *
 * Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-paperclip-server,
 * qui embarque déjà better-auth + le driver pg. Ryvie ne fait que la déclencher
 * (docker exec) et lire son résultat ; il ne connaît ni better-auth ni le schéma.
 *
 * Paperclip s'authentifie via better-auth : le hash du mot de passe est en
 * scrypt (format `salt:clé` hexa, PAS bcrypt), stocké dans la table `account`
 * (colonnes snake_case : user_id, provider_id='credential', password). On
 * réutilise donc le hasher natif de better-auth pour garantir la compatibilité.
 *
 * Sous-commandes :
 *   list                       → JSON des comptes sur stdout
 *   reset  (env RESET_ID/PWD)  → réécrit le hash + vérifie → "OK" / "FAIL"
 */
import { createRequire } from 'node:module';
import { hashPassword, verifyPassword } from 'better-auth/crypto';

// pg est un dep transitif (pnpm) : on le résout sans dépendre d'un symlink racine.
const require = createRequire(import.meta.url);
const pgPath = require.resolve('pg', {
  paths: [
    '/app/packages/db/node_modules',
    '/app/server/node_modules',
    '/app/node_modules/.pnpm/pg@8.18.0/node_modules',
  ],
});
const { Client } = require(pgPath);

const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

try {
  const cmd = process.argv[2];

  if (cmd === 'list') {
    const r = await client.query('SELECT id, email, name FROM "user" ORDER BY email');
    console.log(JSON.stringify(
      r.rows.map((u) => ({ id: u.id, email: u.email, username: u.name, isAdmin: true }))
    ));

  } else if (cmd === 'reset') {
    const id = process.env.RESET_ID;
    const pwd = process.env.RESET_PWD;
    if (!id || !pwd) throw new Error('RESET_ID et RESET_PWD requis');

    const hash = await hashPassword(pwd); // scrypt better-auth, format attendu par l'app
    const up = await client.query(
      `UPDATE account SET password = $1, updated_at = now()
         WHERE user_id = $2 AND provider_id = 'credential'`,
      [hash, id]
    );

    // Vérification intégrée : on relit le hash stocké et on le valide avec le
    // verify natif de better-auth (la même fonction qu'au login).
    const row = await client.query(
      `SELECT password FROM account WHERE user_id = $1 AND provider_id = 'credential'`,
      [id]
    );
    const ok =
      up.rowCount === 1 &&
      row.rows[0] &&
      (await verifyPassword({ hash: row.rows[0].password, password: pwd }));
    console.log(ok ? 'OK' : 'FAIL');

  } else {
    throw new Error(`sous-commande inconnue: ${cmd}`);
  }
} finally {
  await client.end();
}
