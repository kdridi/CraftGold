# Questions ouvertes — ✅ TOUTES RÉSOLUES

> Questions sur lesquelles les LLM externes étaient en désaccord. Vérifiées en jeu lors des Phases B.

---

## Q1 : `/reload` détecte-t-il les nouveaux dossiers d'add-ons ?

| Source | Réponse |
|--------|---------|
| Claude | Oui — depuis Classic Era 1.14.0, `/reload` détecte les nouveaux dossiers et changements de TOC |
| Gemini | Non — les nouveaux dossiers nécessitent un redémarrage complet du client |
| ChatGPT | Peut-être — « généralement oui mais certains cas peuvent nécessiter un redémarrage » |

**→ ✅ VÉRIFIÉ (Capsule 01) : `/reload` DÉTECTE les nouveaux dossiers d'add-ons. Claude avait raison.**

## Q2 : Chemin exact vers la liste des add-ons en jeu

| Source | Réponse |
|--------|---------|
| Claude | Échap → bouton « AddOns » directement |
| Gemini | Échap → Options → onglet AddOns |
| ChatGPT | « Échap → Système → Add-ons » (incertain) |

**→ ✅ VÉRIFIÉ (Capsule 01) : Échap → Menu principal → bouton « Add-ons ».**

## Q3 : Version exacte de l'interface

| Source | Réponse |
|--------|---------|
| Claude | 11508 (patch 1.15.8) |
| ChatGPT | 11508 |
| Gemini | 11503-11507 |

**→ ✅ VÉRIFIÉ (Capsule 01) : `11508` — confirmé avec `/dump select(4, GetBuildInfo())`.**

## Q4 : `print()` au top-level est-il visible dans le chat ?

Les 3 s'accordent sur le fait que ça s'exécute pendant le loading screen, mais :
- Gemini dit explicitement que ce ne sera **probablement pas visible** (chat frame pas encore initialisé)
- Claude et ChatGPT ne le signalent pas aussi fortement

**→ ✅ VÉRIFIÉ (Capsule 01) : OUI, `print()` au top-level EST visible dans le chat après `/reload`.**

Les deux messages (top-level et event-driven) sont apparus.

---

## Q5 : `msg` est-il trimé par le moteur avant d'être passé au handler slash command ?

| Source | Réponse |
|--------|----------|
| Claude | Non — espaces superflus possibles, utiliser `strtrim()` |
| Gemini | Trimé « généralement » |
| ChatGPT | Oui — cite le code FrameXML : `hash_SlashCmdList[command](strtrim(msg), editBox)` |

**→ ✅ VÉRIFIÉ (Capsule 02) : OUI, `msg` est trimé par le moteur. ChatGPT avait la source primaire (code FrameXML).**

Testé avec `/ha   foo  ` → `msg` contenait `foo` (sans espaces autour). Les espaces **internes** sont conservés : `/ha a   b` → `msg = "a   b"`.
