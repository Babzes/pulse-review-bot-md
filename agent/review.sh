#!/usr/bin/env bash
# Agent de revue Pulse : diff -> revue + sécurité -> findings.json + log structuré.
#
# Entrées :
#   $1                  fichier diff (défaut: stdin)
# Env :
#   ANTHROPIC_API_KEY   requis, injecté au RUNTIME (jamais dans l'image)
#   OUT_DIR             dossier de sortie (défaut: .)
#   PR_NUMBER / COMMIT_SHA / BASE_REF   métadonnées du run (facultatif)
# Sorties :
#   $OUT_DIR/findings.json   tableau de findings
#   $OUT_DIR/runs.jsonl      une ligne JSON par run (monitoring) + echo stdout
# Code retour : 1 si au moins un finding `critical`, 0 sinon.
set -euo pipefail

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY manquant (injecter au runtime, jamais dans image)}"
OUT_DIR="${OUT_DIR:-.}"
DIFF_FILE="${1:-/dev/stdin}"
mkdir -p "$OUT_DIR"

start=$(date +%s)
diff="$(cat "$DIFF_FILE")"

{
  echo "Tu es un relecteur de code et de sécurité pour le projet Pulse."
  echo "Analyse le diff de PR ci-dessous. Repère notamment :"
  echo "secrets/tokens en dur, injection SQL (concaténation de chaînes),"
  echo "print()/logs de debug oubliés, tests supprimés pour faire passer la CI."
  echo 'Réponds UNIQUEMENT par un tableau JSON, sans texte ni balises autour, au format :'
  echo '[{"file":"chemin","line":N,"severity":"critical|warning|info","category":"...","message":"..."}]'
  echo "Tableau vide [] si rien à signaler."
  echo "--- DIFF ---"
  echo "$diff"
} | claude -p --output-format json | jq -r '.result' > "$OUT_DIR/result.txt"

# Extrait le tableau JSON et lit "crit warn info total"
here="$(cd "$(dirname "$0")" && pwd)"
read -r crit warn info total < <(OUT_DIR="$OUT_DIR" python3 "$here/extract.py")

[ "$crit" -gt 0 ] && decision="block" || decision="pass"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
dur=$(( $(date +%s) - start ))
ver="cli=$(claude --version 2>/dev/null || echo unknown) pkg=${CLAUDE_CODE_VERSION:-unknown}"

rec=$(jq -nc \
  --arg ts "$ts" --arg pr "${PR_NUMBER:-}" --arg commit "${COMMIT_SHA:-}" \
  --arg base "${BASE_REF:-}" --arg ver "$ver" --arg decision "$decision" \
  --argjson crit "$crit" --argjson warn "$warn" --argjson info "$info" \
  --argjson total "$total" --argjson dur "$dur" \
  '{ts:$ts, pr:$pr, commit:$commit, base:$base, agent_version:$ver,
    findings_total:$total, critical:$crit, warning:$warn, info:$info,
    decision:$decision, duration_s:$dur}')

echo "$rec" | tee -a "$OUT_DIR/runs.jsonl"

[ "$crit" -gt 0 ] && exit 1 || exit 0
