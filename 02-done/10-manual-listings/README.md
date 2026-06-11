# 10 — Manual Listings

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 07 — Price & Calculator, Capsule 09 — Item Info     |
| Type          | Autonomous                                                  |
| Concepts      | Listings `{{count, buyout}, …}`, stacks indivisibles, coexistence Prices/Listings, batch commands, output logging |

## Why This Capsule?

Jusqu'ici, le calculateur récursif fonctionnait avec un modèle simpliste : un prix unique par item (`price[itemID] = copper`). Ça marche sur le papier, mais pas dans la réalité de l'HdV.

En Classic Era, l'HdV vend des **stacks indivisibles**. Si on a besoin de 7 Copper Bars et qu'il y a un stack de 20 à 10g et un stack de 5 à 2g50s, on ne peut pas acheter exactement 7 — on achète le stack de 5 (2g50s) ou le stack de 20 (10g), pas les deux à la fois (enfin si, mais ça fait 25, pas 7). Le coût réel dépend d'une optimisation (covering knapsack, capsule 11).

Mais avant de résoudre ce problème d'optimisation, il faut **modéliser les données correctement**. C'est ce que fait cette capsule : on passe de « un item a un prix » à « un item a des listings ». Chaque listing est un stack indivisible avec une quantité et un prix d'achat immédiat (buyout).

**Bonus** : deux outils qui vont servir pour toutes les capsules suivantes :
- `/cg run` — batch commands séparées par des points-virgules
- `/cg log` — capture l'output dans un fichier lisible hors-jeu

## Ce qu'on a appris

### Le modèle de données

| Avant (Prices) | Après (Listings) |
|-----------------|-------------------|
| `prices[2840] = 1240` | `listings[2840] = { {count=20, buyout=100000}, {count=5, buyout=250} }` |
| Un prix unitaire | Plusieurs stacks, chacun indivisible |
| Directement utilisable | Nécessite un algorithme (DP knapsack, capsule 11) |

Le buyout est le **prix total du stack**, pas par unité — cohérent avec l'API Classic Era.

### Coexistence Prices ↔ Listings

Le Calculator actuel utilise `Prices.get(itemID)` — on ne l'a **pas touché**. Les deux modules vivent côte à côte :
- `Prices` = utilisé par le Calculator (simple, faux mais fonctionnel)
- `Listings` = données réalistes, prêtes pour la capsule 11

En capsule 13 (Buy vs Craft v2), le Calculator passera de Prices à Listings. Prices sera alors retiré.

### Outils de dev

| Commande | Usage |
|----------|-------|
| `/cg run cmd1; cmd2; ...` | Exécuter plusieurs commandes en une ligne |
| `/cg log on\|off\|clear\|show` | Capturer l'output dans un fichier (survit au `/reload`) |
| `/cg reset` | Nettoyer tous les prices et listings |

Le log est stocké dans les SavedVariables (`ManualListingsDB.log`). Après `/reload`, WoW l'écrit sur disque et on peut le lire hors-jeu. Pratique pour les tests sans copier-coller le chat.

### Pitfalls rencontrés

1. **Tests qui polluent les données utilisateur** — Les tests unitaires faisaient `Prices.set(2589, 310)` et oubliaient de nettoyer. L'utilisateur voyait des prix fantômes apparaître dans `/cg price list`. Solution : sauvegarder l'état avant les tests, nettoyer, tester, restaurer.

2. **Bug de restauration** — La première version ne faisait que `if savedPrices[id] then Prices.set(id, ...) end` pour restaurer. Problème : si l'item n'avait pas de prix avant les tests mais les tests en ont ajouté un, il restait après. Fix : `Prices.remove(id)` systématique avant la restauration.

3. **`getListings()` retourne `{}`, pas `nil`** — L'API publique retourne une table vide pour un item sans listings (plus sûr pour les callers). Mais en interne, la clé est supprimée. Un test qui vérifiait `== nil` échouait toujours.

## Code

### Nouveau fichier

- `src/Listings.lua` — Module CRUD pour les listings (add, remove, clear, getListings, getAll, count, countListings)

### Fichiers modifiés

- `ManualListings.lua` — Shell principal :
  - `/cg listing add/remove/list/clear` — gestion des listings
  - `/cg run` — batch commands
  - `/cg log on/off/clear/show` — capture d'output
  - `/cg reset` — nettoyage complet
  - Tests unitaires avec save/restore de l'état utilisateur

### Fichiers inchangés (copiés depuis capsule 09)

- `src/WoW.lua`, `src/DB.lua`, `src/Core.lua`, `src/Money.lua`, `src/Prices.lua`
- `src/Calculator.lua`, `src/ItemInfo.lua`, `src/Report.lua`

## Tests

42 tests unitaires (tous passent) :
- Listings CRUD basique (add, getListings, count)
- Remove par index (avec réindexation automatique)
- Clear d'un item
- Auto-cleanup (suppression de la clé quand le dernier listing est retiré)
- Validation des entrées (nil, count≤0, buyout<0, mauvais types)
- Coexistence Prices + Listings (les deux modules indépendants)
- Calculator toujours fonctionnel via Prices
- Money.parse (préservé)

## Going Further

- → Capsule 11 : Quote DP — algorithme optimal pour choisir les stacks (covering knapsack 0/1)
