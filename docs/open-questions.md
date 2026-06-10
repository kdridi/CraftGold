# Questions ouvertes — ✅ TOUTES RÉSOLUES (Session 2)

> Questions sur lesquelles les LLM externes étaient en désaccord. Vérifiées en jeu lors de la Phase B de la capsule 01.

---

## Q1 : `/reload` détecte-t-il les nouveaux dossiers d'add-ons ?

| Source | Réponse |
|--------|---------|
| Claude | Oui — depuis Classic Era 1.14.0, `/reload` détecte les nouveaux dossiers et changements de TOC |
| Gemini | Non — les nouveaux dossiers nécessitent un redémarrage complet du client |
| ChatGPT | Peut-être — « généralement oui mais certains cas peuvent nécessiter un redémarrage » |

**→ ✅ VÉRIFIÉ : `/reload` DÉTECTE les nouveaux dossiers d'add-ons. Claude avait raison.**

Le workflow de dev est `éditer → /reload → tester` — pas besoin de redémarrer WoW.

## Q2 : Chemin exact vers la liste des add-ons en jeu

| Source | Réponse |
|--------|---------|
| Claude | Échap → bouton « AddOns » directement |
| Gemini | Échap → Options → onglet AddOns |
| ChatGPT | « Échap → Système → Add-ons » (incertain) |

**→ ✅ VÉRIFIÉ : Échap → Menu principal → bouton « Add-ons ».**

## Q3 : Version exacte de l'interface

| Source | Réponse |
|--------|---------|
| Claude | 11508 (patch 1.15.8) |
| ChatGPT | 11508 |
| Gemini | 11503-11507 |

**→ ✅ VÉRIFIÉ : `11508` — confirmé avec `/dump select(4, GetBuildInfo())`.**

## Q4 : `print()` au top-level est-il visible dans le chat ?

Les 3 s'accordent sur le fait que ça s'exécute pendant le loading screen, mais :
- Gemini dit explicitement que ce ne sera **probablement pas visible** (chat frame pas encore initialisé)
- Claude et ChatGPT ne le signalent pas aussi fortement

**→ ✅ VÉRIFIÉ : OUI, `print()` au top-level EST visible dans le chat après `/reload`.**

Les deux messages (top-level et event-driven) sont apparus. L'inquiétude sur le loading screen était infondée (du moins avec `/reload`).
