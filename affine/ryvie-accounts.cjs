/**
 * ryvie-accounts.cjs — Fiche de gestion des comptes AFFiNE.
 *
 * Vit AVEC l'app (appstore) et s'exécute DANS le conteneur app-affine-web, qui
 * embarque le client Prisma d'AFFiNE (accès DB) et @node-rs/argon2 (hash). Ryvie
 * ne fait que la déclencher (docker exec) et lire son résultat — il ne connaît ni
 * le schéma ni le format de hash.
 *
 * AFFiNE hache en argon2id SANS secret/pepper : on réutilise sa propre lib pour
 * garantir la compatibilité au login. Les comptes vivent dans la table `users`
 * (modèle Prisma `user`, colonne `password`).
 *
 * Sous-commandes :
 *   list                       -> JSON des comptes sur stdout
 *   reset  (env RESET_ID/PWD)  -> réécrit le hash + vérifie -> "OK"/"FAIL"
 *   verify (env RESET_ID/PWD)  -> "OK" si le mot de passe correspond, sinon "NO"
 *
 * Env : DATABASE_URL (fourni par le conteneur, lu par Prisma).
 */
const { createRequire } = require('module');

// Résout les deps depuis les node_modules d'AFFiNE, indépendamment de l'emplacement
// de la fiche (montée dans /ryvie).
const req = createRequire('/app/');
const argon2 = req('@node-rs/argon2');
const { PrismaClient } = req('@prisma/client');

const prisma = new PrismaClient();

(async () => {
  const cmd = process.argv[2];
  try {
    if (cmd === 'list') {
      const users = await prisma.user.findMany({
        select: { id: true, email: true, name: true },
        orderBy: { email: 'asc' },
      });
      console.log(JSON.stringify(
        users.map((u) => ({ id: u.id, email: u.email, username: u.name, isAdmin: true }))
      ));

    } else if (cmd === 'reset') {
      const id = process.env.RESET_ID;
      const pwd = process.env.RESET_PWD;
      const hash = argon2.hashSync(pwd); // argon2id, paramètres natifs d'AFFiNE
      await prisma.user.update({ where: { id }, data: { password: hash } });
      const u = await prisma.user.findUnique({ where: { id }, select: { password: true } });
      console.log(u && u.password && argon2.verifySync(u.password, pwd) ? 'OK' : 'FAIL');

    } else if (cmd === 'verify') {
      const id = process.env.RESET_ID;
      const pwd = process.env.RESET_PWD;
      const u = await prisma.user.findUnique({ where: { id }, select: { password: true } });
      console.log(u && u.password && argon2.verifySync(u.password, pwd) ? 'OK' : 'NO');

    } else {
      process.stderr.write(`sous-commande inconnue: ${cmd}\n`);
      process.exitCode = 2;
    }
  } finally {
    await prisma.$disconnect();
  }
})().catch((e) => {
  process.stderr.write(`erreur: ${e.message}\n`);
  process.exit(1);
});
