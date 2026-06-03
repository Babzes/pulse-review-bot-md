# Monitoring de l'agent de revue

Chaque run de `review.sh` émet **une ligne JSON valide** :

- sur **stderr** (canal de monitoring, jamais mélangé au résultat sur stdout) ;
- et, par commodité, en append dans `$OUT_DIR/runs.jsonl`.

Le **résultat** (tableau de findings) sort sur **stdout** ; le stderr de `claude`
est isolé dans `$OUT_DIR/claude.log`. Donc le seul stderr du conteneur est la
ligne de pilotage.

Exemple de ligne :

```json
{"ts":"2026-06-03T10:00:00Z","pr":"4","commit":"abc123","base":"main","agent_version":"cli=… pkg=…","findings_total":2,"critical":1,"warning":1,"info":0,"decision":"block","duration_s":11}
```

## 4 stratégies de collecte

| # | Stratégie | Commande type | Quand |
|---|---|---|---|
| 1 | **Fichier via volume monté** | `docker run -v "$PWD/out:/work" …` (le script append à `runs.jsonl`) | Local / CI : zéro infra, persiste sur l'hôte. |
| 2 | **Redirection de stderr** | `docker run … 2>> runs.jsonl` | Découple l'app du chemin de sortie ; marche sans volume. |
| 3 | **Driver de logs Docker** | `--log-driver=json-file\|journald\|fluentd\|loki` puis `docker logs` / collecteur | Prod / cluster : capture stdout+stderr nativement, centralisé. |
| 4 | **Artifact / store distant** | `actions/upload-artifact`, ou push S3 / Loki / Elasticsearch | Agrégation multi-runs, dashboards, rétention. |

## Choix retenu (≥ 2 stratégies)

On combine **#1 (fichier volume)** + **#4 (artifact CI)**, avec **#2 (redirection stderr)**
en filet de sécurité dans le job.

**Pourquoi :**
- **#1** ne demande aucune infra et rend `runs.jsonl` immédiatement exploitable par
  `metrics.sh` dans le même job — déterministe, idéal pour un lab/CI.
- **#4** sort le log du runner éphémère : c'est ce qui permet l'**agrégation multi-PR**
  et l'historisation (les métriques de pilotage n'ont de sens que sur plusieurs runs).
- **#2** garantit que la ligne existe même si le volume n'est pas monté (run ad hoc).
- **#3** est la cible **production** (agent tournant en service derrière un driver de logs
  → Loki/ELK) ; hors-scope CI car elle suppose une stack de logs déjà en place.

## Calcul des métriques

```bash
bash agent/metrics.sh runs.jsonl
# {"runs":5,"blocked":3,"block_rate_pct":60,"avg_findings":…,"avg_duration_s":…}
```

Sur les 5 PR du lab, 3 sont `critical` (`pr2-secret`, `pr4-deleted-test`, `pr5-sqli`)
→ **taux de blocage = 3/5 = 60 %**.
