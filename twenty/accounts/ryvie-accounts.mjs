/**
 * ryvie-accounts.mjs — Fiche de gestion des comptes Twenty CRM.
 *
 * Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-twenty (serveur
 * node de Twenty), qui embarque bcrypt + le driver pg. Ryvie ne fait que la
 * déclencher (docker exec) et lire son résultat.
 *
 * Twenty stocke ses comptes dans Postgres : table core."user", hash bcrypt dans
 * la colonne "passwordHash". On réutilise le bcrypt présent dans l'app.
 *
 * Sous-commandes :
 *   list                       -> JSON des comptes sur stdout
 *   reset  (env RESET_ID/PWD)  -> réécrit le hash + vérifie -> "OK"/"FAIL"
 *   verify (env RESET_ID/PWD)  -> "OK" si le mot de passe correspond, sinon "NO"
 *
 * Env : PG_DATABASE_URL (fourni par le conteneur).
 */
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const PATHS = ['/app/packages/twenty-server/node_modules', '/app/node_modules'];

function loadAny(names) {
  for (const n of names) {
    try {
      return require(require.resolve(n, { paths: PATHS }));
    } catch (_) {
      /* essai suivant */
    }
  }
  throw new Error(`module introuvable: ${names.join(' / ')}`);
}

const bcrypt = loadAny(['bcrypt', 'bcryptjs']);
const { Client } = loadAny(['pg']);

// core."user" : identifiants quotés (camelCase + mot réservé `user`).
const REF = 'core."user"';

const client = new Client({ connectionString: process.env.PG_DATABASE_URL });
await client.connect();

try {
  const cmd = process.argv[2];

  if (cmd === 'list') {
    const r = await client.query(
      `SELECT id, email, "firstName", "lastName" FROM ${REF} ORDER BY email`
    );
    console.log(JSON.stringify(
      r.rows.map((u) => ({
        id: u.id,
        email: u.email,
        username: [u.firstName, u.lastName].filter(Boolean).join(' ').trim() || undefined,
        isAdmin: true,
      }))
    ));

  } else if (cmd === 'reset') {
    const id = process.env.RESET_ID;
    const pwd = process.env.RESET_PWD;
    const hash = await bcrypt.hash(pwd, 10); // bcrypt : rounds indifférents au login
    const up = await client.query(
      `UPDATE ${REF} SET "passwordHash" = $1 WHERE id = $2`,
      [hash, id]
    );
    const row = await client.query(
      `SELECT "passwordHash" AS h FROM ${REF} WHERE id = $1`,
      [id]
    );
    const ok =
      up.rowCount === 1 &&
      row.rows[0] &&
      (await bcrypt.compare(pwd, row.rows[0].h));
    console.log(ok ? 'OK' : 'FAIL');

  } else if (cmd === 'verify') {
    const id = process.env.RESET_ID;
    const pwd = process.env.RESET_PWD;
    const row = await client.query(
      `SELECT "passwordHash" AS h FROM ${REF} WHERE id = $1`,
      [id]
    );
    const ok = row.rows[0] && row.rows[0].h && (await bcrypt.compare(pwd, row.rows[0].h));
    console.log(ok ? 'OK' : 'NO');

  } else {
    process.stderr.write(`sous-commande inconnue: ${cmd}\n`);
    process.exit(2);
  }
} finally {
  await client.end();
}
