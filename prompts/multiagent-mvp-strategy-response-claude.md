Voilà une réponse monobloc, dense et honnête. Accroche-toi.

---

# Consultation stratégique CraftGold — Réponse consolidée

## Le vrai problème avec ta roadmap actuelle

Ta roadmap est une roadmap d'apprentissage de widgets, pas une roadmap produit. Tu apprends le scroll frame avant de savoir si tu en as besoin. C'est comme construire une cuisine avant de décider ce que tu vas cuisiner.

Le symptôme : tu as fait 5 capsules et tu n'as encore **aucune donnée réelle dans ton add-on**. Aucun prix. Aucune recette. Aucun calcul. Juste de l'UI vide.

La conséquence : tu pourrais finir la capsule 06 (Scroll Frame), 07 (Minimap), 08 (Options)… et te retrouver à la capsule 12 avec un algorithme de coût qui ne tourne que sur des données fictives. Et là tu découvres que les vraies contraintes de l'API invalident tes décisions d'interface.

**La bonne approche MVP : données d'abord, interface ensuite.**

---

## Q1 — Workflow joueur minimal

Il y a deux workflows fondamentalement différents. Choisis-en un pour le MVP.

**Workflow A — "Je veux crafter pour vendre" (profit)**
```
1. Joueur ouvre l'HdV
2. Lance /craftgold scan (ou bouton dans l'UI)
3. L'add-on scanne les pages pertinentes (mats engineering)
4. Affiche : "Ces crafts sont rentables aujourd'hui"
5. Joueur achète les mats, craft, revend
```

**Workflow B — "Je veux monter le skill le moins cher" (leveling)**
```
1. Joueur ouvre la fenêtre de métier (/tradesk ou TradeSkillFrame)
2. Déclenche CraftGold via slash ou hook sur l'événement
3. L'add-on calcule : "Pour aller de skill X à 300, voici l'ordre optimal"
4. Affiche le plan avec coût total estimé
```

Pour le MVP, je recommande **Workflow B** en premier. Pourquoi ?

- Il ne nécessite pas un scan AH en temps réel (tu peux utiliser des prix stockés lors du dernier scan, voire des prix hardcodés provisoirement)
- Il produit une valeur immédiate et visible sans que le joueur soit debout devant l'AH
- Le calcul récursif est le cœur de ton add-on — autant le valider en production vite
- Workflow A sans données AH fraîches est inutile ; Workflow B avec des prix "stale" est encore utile

**Workflow B enrichi par A** : une fois que tu as le scan AH, les prix du leveling deviennent dynamiques. C'est l'évolution naturelle.

---

## Q2 — Données à afficher concrètement

### Écran principal : Plan de leveling

```
┌─────────────────────────────────────────────────────┐
│  CraftGold — Engineering Leveling Plan              │
│  Skill actuel : 142  →  Cible : 300                 │
│  Coût estimé total : 15g 42s  [Source: scan 14:23]  │
├──────┬──────────────────┬───────┬────────────────────┤
│ Skill│ Recette          │ Qté   │ Coût / unité       │
├──────┼──────────────────┼───────┼────────────────────┤
│142→  │ Bronze Framework │  12x  │ 23s  (mat: 1.1g)   │
│ 155  │                  │       │ [orange→yellow 150]│
├──────┼──────────────────┼───────┼────────────────────┤
│155→  │ Heavy Blasting   │  25x  │ 8s   (mat: 2g tot) │
│ 176  │ Powder           │       │ [orange→green 170] │
├──────┼──────────────────┼───────┼────────────────────┤
│ ...  │                  │       │                    │
└──────┴──────────────────┴───────┴────────────────────┘
[Total mats] [Acheter mats]
```

Colonnes essentielles par ligne :
- **Skill range** (de → couleur de la recette à ce niveau)
- **Nom de la recette** (avec sa source : trainer/vendor/drop)
- **Quantité nécessaire** (avec marge pour les yellows qui ratent)
- **Coût total segment** (prix AH des mats, ou vendor si pas d'AH)
- **Coût par skill point** (optionnel mais puissant pour comparer alternatives)

### Écran secondaire : Liste de mats agrégée

```
┌─────────────────────────────────────────────────────┐
│  Mats nécessaires (skill 142 → 300)                 │
├────────────────────┬──────┬─────────┬───────────────┤
│ Item               │ Qté  │ Source  │ Prix unité     │
├────────────────────┼──────┼─────────┼───────────────┤
│ Mithril Bar        │  120 │ AH      │ 18s  → 21g60s │
│ Mageweave Cloth    │   40 │ AH      │  4s  →  1g60s │
│ Solid Blasting Pwd │   80 │ craft   │ 3s   (mat: …) │
│  └ Solid Stone     │  320 │ AH      │  1s  →  3g20s │
│ Dense Blasting Pwd │   30 │ craft   │ 5s   (mat: …) │
│  └ Dense Stone     │   90 │ AH/mine │  2s  →  1g80s │
└────────────────────┴──────┴─────────┴───────────────┘
Total brut : 45g12s  |  Total si tu mines toi-même : 12g30s
```

Colonnes :
- **Nom** (avec indentation des sous-composants si craftable)
- **Quantité totale** (agrégée sur tout le plan)
- **Source recommandée** : AH / vendor / craft / farm
- **Prix unitaire** (AH = prix minimum actuel, vendor = prix fixe)
- **Coût total ligne**

### Écran profit (Workflow A, post-MVP)

```
┌─────────────────────────────────────────────────────┐
│  Crafts rentables — Engineering                     │
│  Scan : 14:23  |  Serveur : Whitemane               │
├──────────────────┬──────┬──────┬───────┬────────────┤
│ Craft            │ Mats │Revte │Profit │ Marge      │
├──────────────────┼──────┼──────┼───────┼────────────┤
│ Thorium Grenade  │ 45s  │ 1g2s │ +57s  │ +126%      │
│ Ice Deflector    │ 2g1s │ 3g8s │ +1g7s │  +82%      │
│ Mithril Dragonlg │12g3s │11g9s │ -40s  │   -3%  ✗  │
└──────────────────┴──────┴──────┴───────┴────────────┘
```

---

## Q3 — Widgets dont tu as VRAIMENT besoin

Avec ce que tu sais déjà faire (frames, boutons, texte, SavedVars), tu peux construire **tout le MVP**. Voici la réalité widget par widget :

**Ce dont tu as besoin pour le MVP :**

| Widget | Pour quoi | Tu sais déjà ? |
|--------|-----------|----------------|
| Frame + backdrop | Fenêtre principale | ✅ Capsule 04 |
| FontString | Texte de données | ✅ Capsule 05 |
| Boutons | Scan / Fermer / Toggle | ✅ Capsule 05 |
| SavedVariables | Stocker prix scannés | ✅ Capsule 03 |
| Slash commands | `/craftgold` | ✅ Capsule 02 |

**Ce dont tu n'as PAS besoin pour le MVP :**
- **Scroll Frame** : seulement si ton plan dépasse ~15 lignes visibles. Pour Engineering 1→300, tu as ~8-10 segments. Un scroll frame est un confort, pas une nécessité.
- **Onglets** : utile pour séparer "Leveling" et "Profit", mais pas bloquant pour un MVP mono-écran.
- **Minimap button** : nice-to-have, aucune valeur métier.
- **Options frame** : MVP sans options.

**Ce que tu dois apprendre que tu n'as PAS encore :**
- `GetNumAuctionItems()` + boucle de scan AH — c'est le cœur de la collecte de données
- `AUCTION_ITEM_LIST_UPDATE` — l'event qui te dit quand une page AH est prête
- `GetItemInfo()` — pour résoudre les noms d'items depuis les IDs

Le scroll frame peut attendre après le MVP. Commence d'abord à avoir des **données réelles** à afficher.

---

## Q4 — Ordre de développement optimal (roadmap corrigée)

Voici la roadmap révisée, orientée MVP :

```
─── PHASE DATA (fais ça avant toute UI supplémentaire) ───

Capsule 06 — DB statique des recettes Engineering
  - Table Lua hardcodée : recipeID → { output, mats, skillReq, skillColor }
  - ~50 recettes Engineering 1→300 (set borné, données publiques)
  - Pas d'API, juste du Lua
  - Livrable : CG.DB.recipes["engineering"] fonctionne en console
  - Source : wow-professions.com/classic/engineering-leveling-guide

Capsule 07 — GetItemInfo + cache
  - Résoudre nom/sellPrice depuis itemID
  - Gérer le nil (item pas encore en cache) avec retry sur BAG_UPDATE ou ITEM_PUSH
  - Livrable : CG.GetItemName(itemID) retourne un string ou "Unknown"
  - Source : warcraft.wiki.gg/wiki/API_GetItemInfo

Capsule 08 — Scan AH (coeur risqué, à débloquer tôt)
  - QueryAuctionItems("", nil, nil, page, nil, nil, false)
  - Boucle sur GetNumAuctionItems("list") → GetAuctionItemInfo("list", i)
  - Stocker minBuyout par itemID dans SavedVariables
  - Gestion de la pagination (event AUCTION_ITEM_LIST_UPDATE)
  - ⚠️ AH doit être ouverte, throttle 0.3s par page
  - Source : vanilla-wow-archive.fandom.com/wiki/API_QueryAuctionItems

Capsule 09 — Algorithme CostCalculator
  - calculateCost(itemID, quantity) récursif
  - Pour chaque mat : min(prixAH, prixVendor, coûtCraft)
  - Livrable : CG.Cost.calculate(73, 10) → {total=450, breakdown={...}}
  - Tests busted en isolation pure (pas d'API WoW)

─── PHASE MVP ───

Capsule 10 — Leveling Planner
  - buildLevelingPlan(currentSkill, targetSkill)
  - Retourne liste ordonnée de { recipe, qty, cost, skillGain }
  - Utilise CostCalculator + DB recettes
  - Tests busted

Capsule 11 — Affichage MVP
  - Fenêtre principale (tu sais déjà faire)
  - Lignes de texte dynamiques pour le plan
  - Bouton "Scan AH" qui déclenche le scan
  - Bouton "Calculer plan"
  - ← C'est seulement ici que tu as besoin de l'UI

─── PHASE POST-MVP ───

Capsule 12 — Scroll Frame (si le plan dépasse l'écran)
Capsule 13 — Vue Profit (workflow A)
Capsule 14 — Minimap, Options, polish
```

**Pourquoi ce changement radical ?** En faisant la DB statique en capsule 06 (pas le scroll frame), tu peux dès la capsule 09 avoir un calcul réel qui tourne. En capsule 10, tu as un algo testé. En capsule 11, tu sais exactement combien de lignes tu dois afficher, et là tu décides si tu as besoin d'un scroll frame. Tu apprends les widgets dont tu as besoin, pas ceux dont tu pourrais avoir besoin.

---

## Q5 — MVP scope

**Dans le MVP :**
- DB statique Engineering 1→300 (~50 recettes)
- Scan AH des mats Engineering (pas tout l'AH — juste les items de ta DB)
- Calcul du plan de leveling optimal avec les prix actuels
- Affichage du plan en fenêtre simple (pas de scroll si ≤ 15 lignes)
- Liste des mats agrégés avec coût total

**Hors MVP (plus tard) :**
- Vue profit / crafts rentables
- Support d'autres métiers (Tailoring, Blacksmithing, etc.)
- Scan complet de l'AH (getAll)
- Minimap button
- Onglets
- Historique des prix
- Export shopping list

**Le MVP tient en une phrase** : *"Ouvre l'AH, tape `/craftgold scan`, ferme l'AH, tape `/craftgold plan`, vois ce que tu dois crafter pour monter Engineering le moins cher."*

---

## Pièges techniques à connaître avant de coder le scan AH

**Piège 1 — getAll vs pagination**

`QueryAuctionItems` avec `getAll=true` télécharge tout l'HdV en une page, mais n'est autorisé que quand `CanSendAuctionQuery()` retourne true en deuxième valeur, soit environ toutes les 15 minutes. Pour un scan ciblé (juste les mats Engineering, ~20-30 items), la pagination normale à 0.3s d'intervalle est préférable et plus robuste.

**Piège 2 — GetItemInfo retourne nil**

`GetItemInfo` retourne nil si tu n'as jamais vu l'item — il doit avoir été dans ton inventaire ou ta banque au moins une fois dans cette session. Solution : inclure dans ta DB statique un champ `vendorPrice` hardcodé pour les mats courants (Rough Stone, Copper Bar, etc.), et utiliser `GetItemInfo` seulement comme enrichissement optionnel.

**Piège 3 — sellPrice ≠ buyoutPrice AH**

`GetItemInfo` retourne `itemSellPrice` qui est le prix de vente au vendeur NPC, pas le prix AH. `GetAuctionItemInfo` retourne `buyoutPrice` comme prix d'achat immédiat à l'AH. Pour calculer la rentabilité d'un craft, tu veux le `buyoutPrice` minimum parmi toutes les annonces pour cet item.

**Piège 4 — L'AH doit être ouverte**

`QueryAuctionItems` n'a aucun effet si la fenêtre de l'HdV n'est pas ouverte. Ton workflow devra explicitement demander au joueur d'ouvrir l'AH avant de scanner.

**Piège 5 — Structure du scan par pages**

```lua
-- Pattern standard pour scanner toutes les pages
local function ScanPage(page)
    if CanSendAuctionQuery() then
        QueryAuctionItems("", nil, nil, page, nil, nil, false)
        -- Attendre AUCTION_ITEM_LIST_UPDATE avant de lire
    end
end

-- Dans le handler d'event AUCTION_ITEM_LIST_UPDATE
local total = GetNumAuctionItems("list")
for i = 1, total do
    local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, itemId = 
        GetAuctionItemInfo("list", i)
    -- Stocker min(buyout / count) par itemId
end
-- Si currentPage < totalPages → ScanPage(currentPage + 1)
```

---

## Sources

- API `QueryAuctionItems` : [vanilla-wow-archive.fandom.com](https://vanilla-wow-archive.fandom.com/wiki/API_QueryAuctionItems) / [wowpedia](https://wowpedia.fandom.com/wiki/API_QueryAuctionItems)
- API `GetAuctionItemInfo` : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_GetAuctionItemInfo) / [vanilla-wow-archive.fandom.com](https://vanilla-wow-archive.fandom.com/wiki/API_GetAuctionItemInfo)
- API `GetItemInfo` : [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_GetItemInfo) / [vanilla-wow-archive.fandom.com](https://vanilla-wow-archive.fandom.com/wiki/API_GetItemInfo)
- Engineering 1→300 data : [wow-professions.com](https://www.wow-professions.com/classic/engineering-leveling-guide-classic-wow) / [zockify.com](https://www.zockify.com/classic/professions/engineering/)
- Addon de référence (scan AH Classic) : [Auctionator ClassicFix](https://www.curseforge.com/wow/addons/auctionator-classicfix) / [AuctionDB sur Wago](https://addons.wago.io/addons/auctiondb)