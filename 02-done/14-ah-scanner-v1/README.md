# 14 — AH Scanner v1

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 09 — Item Info, Capsule 10 — Manual Listings       |
| Type          | Semi-autonomous                                             |
| Concepts      | `QueryAuctionItems`, filtrage par itemID, `AUCTION_ITEM_LIST_UPDATE`, scan asynchrone, conditions CmdLang |

## Why This Capsule?

> Jusqu'ici, les listings HdV de CraftGold étaient saisis à la main : `/cg listing add 2840 20 5g`. Ça marche, mais c'est fastidieux — pour chaque composant, il faut ouvrir l'HdV, noter les stacks et les prix, les saisir un par un.
>
> CraftGold a tout le moteur pour calculer les coûts optimaux (DP knapsack, calculator récursif, BOM), mais il est **aveugle** : il ne voit pas l'HdV. Il attend qu'on lui donne les données manuellement.
>
> Cette capsule lui **ouvre les yeux**. Le module `Scanner` interroge directement l'HdV pour un item donné, récupère les listings réels (stack size + buyout), et les injecte automatiquement dans le modèle `Listings`.
>
> Fini le copier-coller : `/cg scan 2840` → CraftGold scanne l'HdV, filtre par itemID, récupère les buyouts, et peuple les listings. Le calculator peut ensuite utiliser ces vraies données.

## Concepts appris

### API HdV asynchrone

L'API HdV de Classic Era est **événementielle** :
1. `QueryAuctionItems(name, ...)` → lance une recherche par nom
2. Le jeu répond de manière asynchrone via l'événement `AUCTION_ITEM_LIST_UPDATE`
3. On lit les résultats avec `GetAuctionItemInfo("list", index)`

### Filtrage par itemID (pas par nom)

La recherche est textuelle (`QueryAuctionItems` prend un nom). Mais un même nom peut matcher plusieurs objets :
- "Tourte au fromage" → l'objet consommable ET la recette
- On filtre côté Lua : `if itemId == targetItemID then ...`

### Buyout vs Bid

Chaque listing HdV a deux prix :
- `buyoutPrice` → prix d'achat immédiat (**celui qu'on veut**)
- `minBid` / `bidAmount` → prix de l'enchère (incertain)
- On filtre : `buyoutPrice > 0`

### Cycle de vie du scan

Le scan n'est possible que si l'HdV est ouvert. On track l'état via les événements :
- `AUCTION_HOUSE_SHOW` → `_ahOpen = true`
- `AUCTION_HOUSE_CLOSED` → `_ahOpen = false` + auto-cancel du scan
- Condition CmdLang : `/cg scan` indisponible si AH fermé

### Bug CmdLang help() — nœuds hybrides

Découvert que `generateHelp()` traitait les nœuds en `if/else` : soit branche (subs), soit feuille (handler+args). Les nœuds hybrides (handler + subs) perdaient la ligne d'usage du handler.

**Fix** : si un nœud a des subs ET un handler avec args, afficher la ligne d'usage du handler en plus de la branche.

## Guide pas-à-pas

### Étape 1 — Extension du seam WoW

Ajout de 4 fonctions AH au seam `WoW.lua` :
- `CanSendAuctionQuery()` → vérifie si une requête est possible
- `QueryAuctionItems(...)` → lance la recherche
- `GetNumAuctionItems("list")` → nombre de résultats
- `GetAuctionItemInfo("list", i)` → détail d'un résultat

### Étape 2 — Module Scanner

`src/Scanner.lua` — machine à états minimale :
- `scan(itemID, callback)` → résout itemID→nom, lance la requête
- `onItemListUpdate()` → filtre les résultats par itemID + buyout
- `cancel()` → annule un scan bloqué
- `setAHOpen(bool)` → track l'état d'ouverture de l'HdV
- Condition CmdLang pour désactiver `/cg scan` quand l'HdV est fermé

### Étape 3 — Intégration shell

- Commande `/cg scan <itemID>` → scan + injection dans Listings
- Commande `/cg scan cancel` → annulation manuelle
- Événements : `AUCTION_ITEM_LIST_UPDATE`, `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`

## Gotchas rencontrés

### 1. Scan bloqué si HdV fermé

`QueryAuctionItems` échoue **silencieusement** si l'HdV n'est pas ouvert. Aucun événement ne se déclenche → le Scanner reste `_active=true` à jamais.

**Fix** : tracker l'état d'ouverture via `AUCTION_HOUSE_SHOW/CLOSED`. `setAHOpen(false)` auto-cancel le scan.

### 2. Item pas en cache → impossible de scanner

`GetItemInfo(itemID)` retourne `nil` au premier appel pour un item jamais vu. Sans le nom, impossible de lancer `QueryAuctionItems`.

**Message** : `"item not in cache (try viewing it first, then retry)"` — l'utilisateur doit voir l'item une fois (hover, sac, etc.) pour le mettre en cache.

### 3. buyoutPrice est par stack

`GetAuctionItemInfo` retourne `buyoutPrice` pour le **stack entier** (pas par unité). Diviser par `count` pour le prix unitaire.

### 4. Résultats parasites

Une recherche "Copper Bar" peut matcher l'objet ET sa recette. Toujours filtrer par `itemId == targetItemID`.

### 5. help() n'affiche pas les nœuds hybrides

Les nœuds avec handler+args ET subs n'affichaient que les subs dans `/cg help`. Le `if/else` dans `generateHelp()` ignorait le handler quand il y avait des subs.

## Tests

- **146 tests busted** (dont 17 Scanner, 1 bug help hybride)
- **18 tests in-game** (Scanner : état par défaut, cache miss, AH fermé, cancel, lifecycle, auto-cancel)
