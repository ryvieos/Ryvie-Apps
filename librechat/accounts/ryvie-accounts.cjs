/**
 * ryvie-accounts.cjs — Fiche de gestion des comptes LibreChat.
 *
 * Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-librechat, qui
 * embarque Node, le driver `mongodb` et `bcryptjs` (deps d'auth de LibreChat).
 * Ryvie ne fait que la déclencher (docker exec) et lire son résultat — il ne
 * connaît ni le schéma ni le format de hash.
 *
 * LibreChat stocke ses comptes dans MongoDB (conteneur app-librechat-mongodb,
 * base « LibreChat », collection `users`) avec un mot de passe hashé bcrypt.
 * On réutilise `bcryptjs` de l'app pour garantir la compatibilité au login.
 * La connexion se fait via MONGO_URI (injecté par le compose).
 *
 * Sous-commandes :
 *   list                          -> JSON des comptes sur stdout
 *   reset    (env RESET_ID/PWD)   -> réécrit le hash + vérifie -> "OK"/"FAIL"
 *   verify   (env RESET_ID/PWD)   -> "OK" si le mot de passe correspond, sinon "NO"
 *   provision(env DEFAULT_*)      -> crée le compte par défaut s'il manque -> "DONE"
 *
 * Env : MONGO_URI (fourni par le conteneur ; défaut mongodb://librechat-mongodb:27017/LibreChat).
 */
const { createRequire } = require('module');

// Résout les deps depuis les node_modules de LibreChat, indépendamment de
// l'emplacement de la fiche (montée dans /ryvie). Le monorepo hisse les deps à
// la racine mais on tente aussi le sous-projet api par prudence.
function resolveFrom(bases, mod) {
  for (const b of bases) {
    try { return createRequire(b)(mod); } catch (_) { /* base suivante */ }
  }
  throw new Error(`module introuvable dans le conteneur: ${mod}`);
}
const BASES = ['/app/', '/app/api/', '/app/api/server/'];
const { MongoClient, ObjectId } = resolveFrom(BASES, 'mongodb');
const bcrypt = resolveFrom(BASES, 'bcryptjs');

const MONGO_URI =
  process.env.MONGO_URI || 'mongodb://librechat-mongodb:27017/LibreChat';
// LibreChat hache en bcrypt avec 10 rounds (bcryptjs.genSalt(10)).
const BCRYPT_ROUNDS = 10;

(async () => {
  const cmd = process.argv[2];
  const client = new MongoClient(MONGO_URI);
  try {
    await client.connect();
    // La base est portée par l'URI (…/LibreChat) → client.db() la sélectionne.
    const users = client.db().collection('users');

    if (cmd === 'list') {
      const rows = await users
        .find({}, { projection: { email: 1, username: 1, name: 1, role: 1 } })
        .toArray();
      console.log(JSON.stringify(
        rows.map((u) => ({
          id: String(u._id),
          email: u.email || undefined,
          username: u.username || u.name || undefined,
          isAdmin: u.role === 'ADMIN',
        }))
      ));

    } else if (cmd === 'reset') {
      const id = process.env.RESET_ID;
      const pwd = process.env.RESET_PWD;
      const hash = bcrypt.hashSync(pwd, BCRYPT_ROUNDS);
      await users.updateOne({ _id: new ObjectId(id) }, { $set: { password: hash } });
      const u = await users.findOne({ _id: new ObjectId(id) }, { projection: { password: 1 } });
      console.log(u && u.password && bcrypt.compareSync(pwd, u.password) ? 'OK' : 'FAIL');

    } else if (cmd === 'verify') {
      const id = process.env.RESET_ID;
      const pwd = process.env.RESET_PWD;
      const u = await users.findOne({ _id: new ObjectId(id) }, { projection: { password: 1 } });
      console.log(u && u.password && bcrypt.compareSync(pwd, u.password) ? 'OK' : 'NO');

    } else if (cmd === 'provision') {
      // Crée (idempotent) le compte par défaut Ryvie. LibreChat n'embarque aucun
      // compte : le 1er inscrit devient l'utilisateur. On pré-crée changeme@ryvie.fr
      // en ADMIN (provider local, email vérifié) pour un comportement uniforme.
      const email = process.env.DEFAULT_EMAIL;
      const username = process.env.DEFAULT_USER || '';
      const pwd = process.env.DEFAULT_PWD;
      const existing = await users.findOne({ email });
      if (!existing) {
        const now = new Date();
        await users.insertOne({
          email,
          username,
          name: username || email,
          password: bcrypt.hashSync(pwd, BCRYPT_ROUNDS),
          role: 'ADMIN',
          provider: 'local',
          emailVerified: true,
          createdAt: now,
          updatedAt: now,
        });
      }
      console.log('DONE');

    } else {
      process.stderr.write(`sous-commande inconnue: ${cmd}\n`);
      process.exitCode = 2;
    }
  } finally {
    await client.close();
  }
})().catch((e) => {
  process.stderr.write(`erreur: ${e.message}\n`);
  process.exit(1);
});
