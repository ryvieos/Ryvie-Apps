#!/usr/bin/env node
/**
 * ryvie-accounts.mjs — Fiche de gestion du compte OpenClaw.
 *
 * OpenClaw s'authentifie par UN mot de passe de gateway (gateway.auth.password),
 * pas par multi-comptes. Le « compte » unique exposé à Ryvie représente donc ce
 * mot de passe. La fiche s'exécute DANS app-openclaw et pilote la CLI native
 * `openclaw config` (dans /app). Ryvie ne connaît ni le format ni le stockage.
 *
 * Sous-commandes :
 *   list                        -> JSON [{id,username,isAdmin}] (compte unique)
 *   verify (env RESET_PWD)      -> "OK" si RESET_PWD == mot de passe courant, sinon "NO"
 *   reset  (env RESET_PWD)      -> change gateway.auth.password + vérifie -> "OK"/"FAIL"
 *
 * ⚠️ La gateway ne relit le mot de passe qu'au redémarrage → la recette déclare
 * resetRestarts: true (le cœur Ryvie redémarre le conteneur après le reset).
 */
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const CONFIG = process.env.OPENCLAW_CONFIG || '/home/node/.openclaw/openclaw.json';
const CLI = '/app/openclaw.mjs';

function currentPassword() {
  try {
    return JSON.parse(readFileSync(CONFIG, 'utf8'))?.gateway?.auth?.password || '';
  } catch {
    return '';
  }
}

function setPassword(pwd) {
  // Passe par la CLI officielle (écrit openclaw.json proprement).
  execFileSync('node', [CLI, 'config', 'set', 'gateway.auth.password', pwd], { stdio: 'pipe' });
}

const cmd = process.argv[2];

if (cmd === 'list') {
  console.log(JSON.stringify([{ id: 'gateway', username: 'Gateway (mot de passe)', isAdmin: true }]));
} else if (cmd === 'verify') {
  console.log(currentPassword() === (process.env.RESET_PWD || '') ? 'OK' : 'NO');
} else if (cmd === 'reset') {
  const pwd = process.env.RESET_PWD || '';
  setPassword(pwd);
  console.log(currentPassword() === pwd ? 'OK' : 'FAIL');
} else {
  process.stderr.write(`sous-commande inconnue: ${cmd}\n`);
  process.exit(2);
}
