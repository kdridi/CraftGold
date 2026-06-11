# Recherche — GetItemInfo : cache, cycle de vie, et comment forcer l'async

## Contexte

Nous développons un add-on WoW Classic Era (1.15.x). Nous utilisons `GetItemInfo(itemID)` pour résoudre des itemIDs en noms d'items. Nous avons aussi un handler sur l'événement `GET_ITEM_INFO_RECEIVED` pour mettre à jour l'UI quand un item arrive en cache.

**Problème** : nous n'arrivons PAS à reproduire le comportement asynchrone de `GetItemInfo`. Même après avoir :
- Supprimé le dossier `Cache/WDB/` du client
- Relancé WoW complètement
- Ouvert notre fenêtre d'add-on

→ `GetItemInfo()` retourne immédiatement le nom pour TOUS les items. L'événement `GET_ITEM_INFO_RECEIVED` ne se déclenche jamais.

## Questions de recherche

### 1. Architecture du cache d'items WoW

Comment fonctionne exactement le cache d'items côté client WoW Classic Era ?

- **Où** sont stockées les données d'items ? (`Cache/WDB/itemcache.wdb` ? autre chose ?)
- **Quand** le client précharge-t-il les items ? Au login ? À la sélection de personnage ? Au chargement du monde ?
- **Pour quels items** le client précharge-t-il les données ? Tous les items du jeu ? Seulement les items "communs" ? Ceux que le personnage a déjà vus ?
- **Quelle est la différence** entre Classic Era et Retail concernant le cache d'items ?

### 2. GetItemInfo — comportement exact

- `GetItemInfo(itemID)` : quand retourne-t-elle `nil` exactement ? Quels sont les scénarios précis où l'item n'est PAS en cache ?
- Est-ce que les items de base (Copper Bar, Linen Cloth, etc.) sont **toujours** en cache car ils sont dans les données client de base (DBC/DB2) ?
- Y a-t-il une différence entre `GetItemInfo()` et `GetItemInfoInstant()` en termes de cache ?
- Peut-on **forcer** le client à "oublier" un item pour tester le comportement async ?

### 3. GET_ITEM_INFO_RECEIVED — déclencheurs réels

- Dans quelles conditions réelles cet événement se déclenche-t-il en Classic Era ?
- Donnez des exemples concrets d'items pour lesquels `GetItemInfo()` retournerait `nil` en Classic Era
- Est-ce que cet événement est encore pertinent en Classic Era, ou le client charge-t-il tout au login ?

### 4. Méthodes pour reproduire l'async en développement

Comment un développeur d'add-on peut-il tester le comportement asynchrone de `GetItemInfo` ?

- Existe-t-il un itemID "exotique" qui n'est jamais préchargé et qui permet de tester facilement ?
- Peut-on utiliser des IDs d'items qui n'existent pas en Classic Era (ex: IDs Retail) pour forcer le nil ?
- Y a-t-il une commande console ou un setting pour vider sélectivement le cache d'items ?
- Existe-t-il des add-ons ou des outils de test pour simuler le cache vide ?

### 5. Scénarios de production

Dans la vraie vie d'un add-on comme CraftGold (base de données de recettes avec ~100+ itemIDs) :

- Est-ce qu'un joueur normal rencontrera **jamais**, **rarement**, ou **souvent** des items non cachés ?
- Quels types d'items sont les plus susceptibles de ne pas être en cache ? (items de high-level ? items de raid ? items de quêtes spécifiques ?)
- Un joueur qui n'a jamais joué Engineering aura-t-il les items d'Engineering en cache ?
- Un nouveau personnage niveau 1 aura-t-il les mêmes items en cache qu'un personnage niveau 60 ?

## Critères de réponse

1. **Recherche web obligatoire** — Faire une vraie recherche et fournir des **liens sources** (URLs) pour chaque affirmation.
2. **Format monobloc markdown** — La totalité de la réponse en un seul bloc markdown.
3. **Tests et exemples concrets** — Donnez des itemIDs précis qu'on peut tester en jeu pour reproduire le comportement async.
4. **Source de vérité** — Priorité à wowpedia, warcraft.wiki.gg, wowprogramming.com, et aux forums officiels Blizzard.
