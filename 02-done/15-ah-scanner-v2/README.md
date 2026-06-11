# 15 — AH Scanner v2

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 14 — AH Scanner v1                                  |
| Type          | Semi-autonomous                                             |
| Concepts      | Pagination (50 résultats/page), throttling, `CanSendAuctionQuery()`, file d'attente, buffer périmé |

## Why This Capsule?

En capsule 14, on avait un scanner qui savait chercher un item à l'HdV et injecter les résultats dans Listings. Le problème ? Il ne lisait que la page 0 (50 premiers résultats). Sur un serveur actif, un matériau courant comme le Copper Bar peut avoir 75+ listings — notre scanner rate les suivants et les meilleurs prix potentiels.

En plus, si on veut scanner plusieurs composants d'un craft d'un coup, il faut lancer les scans un par un manuellement. Pas viable pour un usage quotidien.

Cette capsule transforme le scanner en un **moteur de scan robuste** : pagination automatique à travers toutes les pages, throttling respectueux du serveur, et file d'attente multi-items.

## Ce qu'on a appris

### Pagination — le buffer AH est pollué

`GetNumAuctionItems("list")` retourne `(numBatchAuctions, totalAuctions)`. Sur chaque page, `numBatchAuctions` vaut 50 — **même sur la dernière page**. Le buffer interne de l'HdV contient les données de la page précédente dans les slots excédentaires.

Exemple concret avec 75 items (2 pages) :
- Page 0 : `numBatchAuctions = 50`, `totalAuctions = 75` → OK, 50 valides
- Page 1 : `numBatchAuctions = 50`, `totalAuctions = 75` → **seulement 25 sont nouveaux**, les 25 autres sont des résidus de la page 0

**Fix** : sur la dernière page, plafonner la boucle à `totalAuctions - page × 50`.

Sans le fix : 75 items → on lisait 100 listings. Avec le fix : 75 items → 75 listings.

### Throttling — OnUpdate + CanSendAuctionQuery

L'UI Blizzard ne fait aucun `sleep()`. Elle utilise un `OnUpdate` qui vérifie `CanSendAuctionQuery()` à chaque frame avant d'envoyer une nouvelle requête. On reproduit le même pattern : un frame caché qui tick et envoie la page suivante dès que le serveur l'autorise.

En pratique, le throttle est très court (~quelques dixièmes de seconde), donc même 3 pages passent en moins d'une seconde.

### File d'attente — state machine séquentielle

Le scanner est une state machine :
```
IDLE → scan(itemID) → SCANNING page 0
  → AUCTION_ITEM_LIST_UPDATE → accumulate
    → more pages? → SCANNING page N+1
    → no more? → callback → dequeue next item → SCANNING...
IDLE
```

Si un scan est en cours, `scan()` ajoute simplement l'item à `_queue`. Quand le scan en cours se termine, `_finishItem()` dépile automatiquement le suivant.

### API `GetNumAuctionItems("list")` retourne deux valeurs

```lua
local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
```
- `numBatchAuctions` : nombre d'entrées dans le buffer (toujours 50, même sur la dernière page)
- `totalAuctions` : nombre total de résultats pour la requête (constant à travers les pages)

## Objectifs

1. **Paginer** automatiquement toutes les pages d'un item (>50 résultats) ✅
2. **Throttler** les requêtes avec `CanSendAuctionQuery()` (pas de spam) ✅
3. **Empiler** les scans dans une file d'attente ✅

## Commandes

| Commande | Description |
|----------|-------------|
| `/cg scan <itemID>` | Scanne un item (pagination automatique) |
| `/cg scan status` | Progression du scan en cours |
| `/cg scan queue` | Items en file d'attente |
| `/cg scan cancel` | Annule le scan + vide la queue |
| `/cg scan 2840; scan 2589` | Scans séquentiels via batch `;` |

## Pitfalls rencontrés

### 1. Buffer AH périmé sur la dernière page
`GetNumAuctionItems("list")` retourne 50 même quand il n'y a que 25 nouveaux résultats. Les slots excédentaires contiennent des données de la page précédente. **Solution** : calculer le nombre d'items attendus sur la dernière page et plafonner la boucle.

### 2. CreateFrame retourne nil en tests
La seam WoW a un fallback `CreateFrame = function() return nil end`. Le scanner crée un frame pour le throttling OnUpdate. **Solution** : vérifier que le frame n'est pas nil avant d'appeler `:Show()` / `:Hide()`.

### 3. `_currentPage` mis à jour trop tard
Initialement, `_currentPage` n'était mis à jour que dans `onItemListUpdate()`. Mais `_requestNextPage()` envoie la query *avant* que l'événement arrive, donc la page demandée et la page stockée étaient désynchronisées. **Solution** : mettre à jour `_currentPage` dans `_requestNextPage()` au moment de l'envoi.

## Tests

- **154 tests busted** (0 failures)
  - 2 tests spécifiques au fix du buffer périmé (75 items → 75, 134 items → 134)
  - Tests pagination, queue, throttling, cancel, auto-cancel, progress

## Going Further

- → Capsule 16 : Profit Analyzer v2
