#!/usr/bin/env bash
# Métriques de pilotage à partir des lignes JSON de run (runs.jsonl).
# Usage : metrics.sh [runs.jsonl]    (défaut: runs.jsonl)
#
# 3 métriques :
#   block_rate_pct  % de runs bloqués (>=1 critical)  -> pression sécurité entrante
#   avg_findings    findings moyens par run           -> charge de revue
#   avg_duration_s  latence moyenne du run agent      -> coût de la boucle
set -euo pipefail

LOG="${1:-runs.jsonl}"
if [ ! -s "$LOG" ]; then
  echo '{"runs":0}'
  exit 0
fi

# -s : slurp le JSONL en tableau. round à 1 décimale.
jq -s '
  (length) as $n
  | ([.[] | select(.decision == "block")] | length) as $blocked
  | {
      runs: $n,
      blocked: $blocked,
      block_rate_pct: (($blocked * 1000 / $n | floor) / 10),
      avg_findings:   (([.[].findings_total] | add // 0) * 100 / $n | floor) / 100,
      avg_duration_s: (([.[].duration_s]    | add // 0) * 10  / $n | floor) / 10
    }
' "$LOG"
