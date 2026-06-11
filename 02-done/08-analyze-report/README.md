# 08 — Analyze & Report

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 3 — Cœur métier ✅                                    |
| Prerequisites | Capsule 07 — Price & Calculator                             |
| Type          | Autonomous                                                  |
| Concepts      | Module Report séparé, `/cg analyze [N]`, `/cg detail`, arbre récursif buy vs craft |

## Why This Capsule?

On a un moteur économique complet : DB de 26 recettes, prix manuels, calculateur récursif avec mémoïsation. Les commandes `/cg analyze` et `/cg cost` marchent… mais tout l'affichage est **mélangé avec le parsing** dans le shell monolithique (300+ lignes).

À mesure qu'on avance (ItemInfo, listings, scanner AH), ce shell va exploser. Cette capsule extrait un **module Report dédié** et enrichit l'affichage : Top N paramétrable, vue détail orientée profit, et arbre récursif complet des décisions buy/craft.

C'est aussi la **dernière capsule de la Phase 3** — le cœur métier est maintenant complet et bien structuré.

## Ce qu'on a fait

### Restructuration shell → Report

Avant (capsule 07) :
```
PriceCalc.lua (300+ lignes)
├── cmdHelp()
├── cmdPrice()
├── cmdCost()        ← affichage inline
├── cmdAnalyze()     ← affichage inline
├── RunInGameTests()
└── Events
```

Après (capsule 08) :
```
AnalyzeReport.lua (~80 lignes shell)
├── cmdHelp()
├── cmdPrice()       ← inchangé (que du parsing)
├── cmdCost()        ← délègue à Report.detail()
├── cmdAnalyze()     ← délègue à Report.topCrafts()
├── cmdDetail()      ← délègue à Report.detail()
├── RunInGameTests()
└── Events

src/Report.lua (NOUVEAU — ~130 lignes)
├── Report.topCrafts(n)      ← affiche Top N crafts rentables
├── Report.detail(itemID)    ← rapport complet d'un item
└── Report._printTree(result, indent)  ← arbre récursif privé
```

### Nouvelles commandes

| Commande | Description |
|----------|-------------|
| `/cg analyze [N]` | Top N crafts rentables (défaut : tous). Ajoute un hint "…and X more" si N limite les résultats |
| `/cg detail <itemID>` | Rapport complet : coût, buy vs craft, profit/marge, arbre récursif des composants |
| `/cg cost <itemID>` | Alias de `/cg detail` (même affichage) |

### Arbre récursif buy vs craft

La nouveauté principale. `/cg detail 4363` (Copper Modulator) affiche :

```
[CraftGold] Copper Modulator (4363)
  Cost: 43s 40c (craft)
  Buy: 72s | Craft: 43s 40c — craft is cheaper!
  Sell: 72s — Profit: 28s 60c — Margin: 66%
  Reagent tree:
    Linen Cloth x2 — 3s 10c each = 6s 20c (buy)
    Copper Bar x1 — 12s 40c each = 12s 40c (buy)
    Handful of Copper Bolts x2 — 12s 40c each = 24s 80c (craft)
      Copper Bar x1 — 12s 40c each = 12s 40c (buy)
```

Chaque composant montre s'il faut l'acheter (buy) ou le fabriquer (craft), et les sous-composants sont indentés récursivement.

## Structure

```
08-analyze-report/
├── AnalyzeReport.toc
├── AnalyzeReport.lua          (shell : parsing + events, ~80 lignes)
├── src/
│   ├── WoW.lua               (inchangé — seam API WoW)
│   ├── DB.lua                (inchangé — 26 recettes Engineering)
│   ├── Core.lua              (inchangé — requêtes DB)
│   ├── Money.lua             (inchangé — parse/format or/argent/cuivre)
│   ├── Prices.lua            (inchangé — stockage prix en SavedVariables)
│   ├── Calculator.lua        (inchangé — calcul récursif min(buy, craft))
│   └── Report.lua            (NOUVEAU — affichage chat)
└── README.md
```

## Comment tester

1. Symlink vers `Interface/AddOns/AnalyzeReport`
2. `/reload` en jeu
3. Poser des prix :
   - `/cg price 2840 12s40c` (Copper Bar)
   - `/cg price 2589 3s10c` (Linen Cloth)
   - `/cg price 4359 18s` (Copper Bolts — plus cher que le craft → le calculateur choisira craft)
   - `/cg price 4363 72s` (Copper Modulator — prix de vente)
4. `/cg analyze` → tous les crafts rentables
5. `/cg analyze 2` → top 2 seulement
6. `/cg detail 4363` → arbre récursif complet
7. `/cg test` → tests automatisés (0 failed)

## Pitfalls rencontrés

Aucun ! Tout est passé du premier coup. Le code de la capsule 07 était solide, la restructuration était mécanique.

## Leçons apprises

- **Séparer shell et affichage tôt** — Plus le shell grossit, plus c'est dur à extraire. On a bien fait de le faire maintenant.
- **`/cg cost` et `/cg detail` font la même chose** — Pour l'instant c'est un alias. Plus tard, `/cg cost` pourrait afficher juste le coût (sans le profit), et `/cg detail` la vue complète. Pas urgent.
- **`_printTree` appelle `Calculator.calculate()` à nouveau** — C'est un nouveau calcul, pas une réutilisation du cache de l'appel parent. Pas un problème de perf (la DB est petite), mais à savoir.

## Going Further

- → **Capsule 09** : Item Info — Remplacer les `item:XXXX` par de vrais noms quand `GetItemInfo()` retourne nil (cache asynchrone)
- → **Capsule 10** : Manual Listings — Remplacer le prix unitaire par des listings multiples `{count, buyout}`
