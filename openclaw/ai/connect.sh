#!/bin/sh
# Hook de connexion IA d'OpenClaw, exécuté par Ryvie (aiService.runHook) APRÈS le
# (re)démarrage du conteneur. OpenClaw ne lit pas de variable d'env pour ses
# providers : on enregistre donc un provider « ryvie » (OpenAI-compatible) pointant
# sur le point IA central (LiteLLM), via la CLI native, puis on redémarre la gateway.
# Reçoit en env : RYVIE_AI_API_KEY, RYVIE_AI_BASE_URL, RYVIE_AI_MODEL.
set -e

MODEL="${RYVIE_AI_MODEL:-ryvie-default}"

# --merge : ajout additif (ne casse pas les autres providers). api openai-completions
# = backends OpenAI-compatibles (LiteLLM). baseUrl/apiKey fournis par Ryvie.
docker exec app-openclaw node /app/openclaw.mjs config set models.providers.ryvie \
  "{\"api\":\"openai-completions\",\"baseUrl\":\"${RYVIE_AI_BASE_URL}\",\"apiKey\":\"${RYVIE_AI_API_KEY}\",\"models\":[{\"id\":\"${MODEL}\",\"name\":\"Ryvie AI\"}]}" \
  --strict-json --merge >/dev/null 2>&1 || echo "[openclaw] (config provider non appliquée)"

# La gateway relit sa config au démarrage (préserve le réseau ryvie-ai attaché).
docker restart app-openclaw >/dev/null 2>&1 || true
echo "[openclaw] provider « Ryvie AI » configuré (model=${MODEL}) — sélectionnez-le dans l'UI OpenClaw."
