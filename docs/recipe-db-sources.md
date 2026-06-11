# Sources de données recettes WoW Classic Era

> Base de connaissances validée — Session 8, Capsule 06

---

## ItemIDs : Vanilla 1.12 = Classic Era 1.15.x

**Consensus 4/4 LLM** (Claude, Gemini, ChatGPT, GitHub) : les itemIDs des items historiques Vanilla sont **strictement identiques** en Classic Era 1.15.x. Pas de mapping nécessaire.

Nuance : les items *nouveaux* (SoD, events saisonniers) ont des IDs qui n'existaient pas en 1.12. Pour Engineering 1-150, on est dans le corpus historique → aucun risque.

---

## Sources open source identifiées

### 🥇 LibCrafts-1.0 — Source retenue pour CraftGold

- **Repo** : https://github.com/refaim/LibCrafts-1.0
- **Licence** : MIT ✅ — réutilisable
- **Fichier clé** : `Professions/Engineering.lua` (1450 lignes, Engineering Vanilla complet)
- **Dernière màj** : septembre 2025
- **Contenu** : spellID, output itemID, reagent itemIDs + quantités, skill level, source (trainer/vendor/drop/quest)
- **API fluide** :
  ```lua
  module:NewCraft(3926, "Copper Modulator", 65, {SpellSource.Trainer})
      :SetResult(4363)
      :AddReagent(2589, 2) -- Linen Cloth
      :AddReagent(2840, 1) -- Copper Bar
      :AddReagent(4359, 2) -- Handful of Copper Bolts
      :Save()
  ```

### 🥈 CraftLib — Modèle de conception (pas copiable)

- **Repo** : https://github.com/kaldown/CraftLib
- **Licence** : All Rights Reserved ⚠️ — ne pas copier
- **Fichier clé** : `Data/` (239 recettes Engineering, Classic Era)
- **Dernière màj** : février 2026
- **Intérêt** : `SCHEMA.md` documente un modèle de recette parfait :
  - `id` (spellID), `name`, `itemId`, `skillRequired`, `skillRange` (orange/yellow/green/gray), `reagents[]`, `source`, `expansion`
- **Pipeline de données** : DB2 → Wowhead → Lua (Python, reproductible)
- **Add-ons utilisateurs** : LazyProf (leveling optimizer), confirme production-ready

### Autres sources (référence)

| Projet | Licence | Notes |
|--------|---------|-------|
| MissingTradeSkillsList (refaim) | Open source | DB Vanilla avec sources, bon pour validation croisée |
| TradeSkillsData (refaim) | À vérifier | Archivé, remplacé par LibCrafts |
| alaTradeSkill | MIT-compatible | Structure compacte spellID→array, données Engineering Vanilla |
| WowDbScripts (thespags) | BSD-2-Clause | Pipeline Python Wago DB2 + Wowhead |
| nexus-devs/wow-classic-items | MIT | JSON/npm, items seulement, pas de skill colors |
| AllTheThings | GPL v3 | Trop massif, mais complet |
| AtlasLootClassic | GPL/MIT | Orienté loot, pas craft leveling |

---

## APIs et dumps

### Blizzard Game Data API
- **Dispo pour Classic** : items uniquement (`/data/wow/item/{itemId}`)
- **Pas d'endpoint recettes/professions** pour Classic Era
- Rate limit : 36 000 req/h, clé OAuth2 gratuite
- **Utilité CraftGold** : résoudre `itemID → nom + icône` (capsule 09)

### DBC/DB2 (données client)
- **Fichiers clés** : `SpellReagents.db2`, `SkillLineAbility.db2`, `Item.db2`
- **Outil** : wow.tools.local (https://github.com/Marlamin/wow.tools.local)
- **Pipeline** : db2-parser (https://github.com/kaldown/db2-parser)
- **Utilité** : vérification technique si besoin, mais LibCrafts suffit pour v1

---

## Stratégie CraftGold v1

1. **Extraire** 15-20 recettes Engineering (skill 1-150) depuis LibCrafts-1.0
2. **Créer notre propre structure** Lua (pas de copie directe)
3. **Valider** les itemIDs en jeu via `/dump GetItemInfo(itemID)` (Phase B)
4. **V2 roadmap** : enrichir via CraftLib comme référence + validation API Blizzard
