#!/usr/bin/env python3
"""Extrait le tableau JSON de findings de la sortie brute de l'agent.

Lit  $OUT_DIR/result.txt, écrit $OUT_DIR/findings.json,
imprime "crit warn info total" sur stdout (consommé par review.sh).
"""
from __future__ import annotations

import json
import os
import pathlib
import re

out = pathlib.Path(os.environ.get("OUT_DIR", "."))
raw = (out / "result.txt").read_text()
m = re.search(r"\[.*\]", raw, re.S)
try:
    data = json.loads(m.group(0)) if m else []
    if not isinstance(data, list):
        data = []
except Exception:
    data = []

(out / "findings.json").write_text(json.dumps(data, ensure_ascii=False))


def sev(s: str) -> int:
    return sum(1 for d in data if str(d.get("severity", "")).lower() == s)


print(sev("critical"), sev("warning"), sev("info"), len(data))
