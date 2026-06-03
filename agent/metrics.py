#!/usr/bin/env python3
"""Métriques de pilotage à partir des logs de run (runs.jsonl).

Usage : python3 metrics.py [runs.jsonl]

3 métriques de pilotage :
  1. block_rate_pct  — % de runs bloqués (au moins un finding critical) : pression sécurité entrante.
  2. avg_findings    — findings moyens par run : charge de revue / qualité du code soumis.
  3. avg_duration_s  — latence moyenne d'un run agent : coût/temps de la boucle.
"""
from __future__ import annotations

import json
import pathlib
import sys


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "runs.jsonl")
    if not path.exists():
        print(json.dumps({"runs": 0}))
        return 0

    runs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    n = len(runs)
    if n == 0:
        print(json.dumps({"runs": 0}))
        return 0

    blocked = sum(1 for r in runs if r.get("decision") == "block")
    metrics = {
        "runs": n,
        "block_rate_pct": round(100 * blocked / n, 1),
        "avg_findings": round(sum(r.get("findings_total", 0) for r in runs) / n, 2),
        "avg_duration_s": round(sum(r.get("duration_s", 0) for r in runs) / n, 1),
    }
    print(json.dumps(metrics, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
