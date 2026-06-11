# Recherche — Capsule 06 : Sources de données recettes Engineering (WoW Classic Era)

## Contexte

Nous développons un add-on WoW Classic Era (version 1.15.x) appelé **CraftGold**. Pour notre base de données statique de recettes d'Ingénierie, nous avons besoin d'itemIDs, noms d'items, composants (reagents) avec quantités, et skill levels.

Plutôt que de scraper wowhead page par page, nous cherchons des projets open source, APIs, dumps ou bases de données qui contiennent déjà ces informations structurées.

## Questions de recherche

### 1. Bases de données open source WoW Classic

Quels projets open source fournissent des données structurées sur les items et recettes de WoW Classic (Vanilla / Classic Era) ? Pour chaque projet, préciser :

- **Nom du projet** + lien GitHub ou site
- **Format des données** (Lua tables, JSON, SQL, CSV, etc.)
- **Couverture** : items seulement ? recettes avec composants ? skill levels ? color difficulty (orange/yellow/green/gray) ?
- **Version** : Vanilla (1.12) ? Classic Era (1.15.x) ? Les itemIDs sont-ils identiques entre Vanilla et Classic Era ?
- **Licence** : utilisable dans un add-on WoW ?
- **Dernière mise à jour** : le projet est-il encore maintenu ?

Projets connus ou suspectés (à vérifier/compléter) :
- `wowdb` / `wowdb-client`
- `TradeskillInfo` (add-on existant avec DB embarquée)
- `AtlasLoot` (données de loot/craft)
- `WoW-Pro` / `WoWProfessions` (guides leveling avec données structurées)
- `Auctionator` (a-t-il une DB de recettes ?)
- `warcraft.wiki.gg` API
- `wowhead.com` API (toolhead)
- `tc/wowtools` dumps
- `Gethe/wow-ui-source`
- Tout autre projet pertinent

### 2. APIs publiques

Existe-t-il des APIs publiques (REST, GraphQL, ou autre) permettant de requêter :

- Les recettes d'un métier donné (ex: Engineering) avec leurs composants
- Les détails d'un item par itemID (nom, icon, quality, etc.)
- Les spell/recipe IDs avec leurs reagents

Préciser pour chaque API :
- URL de base
- Exemples d'endpoints pertinents
- Rate limits éventuels
- Clé API nécessaire ou non

### 3. Dumps et datasets

Existe-t-il des dumps complets et téléchargeables des données WoW Classic ?

- Dumps de `warcraft.wiki.gg` ou `wowpedia`
- Dumps DBC (DataBaseClient) — ces fichiers contiennent-ils les recettes avec composants ?
- Outils comme `wow.tools` ou `wow.dev`
- Tout dataset CSV/JSON/SQL disponible publiquement

### 4. Add-ons existants comme source

Quels add-ons WoW Classic embarquent déjà une DB de recettes Engineering complète et open source ? Idéalement :

- Un add-on dont le fichier Lua de données est directement réutilisable
- Ou dont on peut extraire la structure pour notre propre DB

### 5. ItemIDs Classic Era vs Vanilla

Les itemIDs de Classic Era (1.15.x) sont-ils **identiques** à ceux de Vanilla (1.12) ? Y a-t-il eu des changements connus ? Si oui, où trouver le mapping ?

## Critères de réponse

1. **Recherche web obligatoire** — Ne pas se contenter du training data. Faire une vraie recherche et fournir des **liens sources** (URLs) pour chaque affirmation.
2. **Format monobloc markdown** — La totalité de la réponse en un seul bloc markdown. Pas de fichiers séparés, pas d'artifacts.
3. **Priorité aux sources vérifiables** — GitHub repos avec URL, documentation avec lien, etc.
4. **Structurer la réponse par question** — Reprendre les 5 sections ci-dessus.

## Ce qu'on cherche au final

Un moyen fiable et efficient d'obtenir, pour 15-20 recettes Engineering Classic Era (niveau 1-150) :
- **Spell/Recipe ID** (optionnel mais utile)
- **Output itemID** + nom
- **Reagent itemIDs** + quantités
- **Skill level** requis (min pour apprendre, niveaux de couleur)
- **Source** (trainer, vendor, drop)

Si un projet open source contient tout ça dans un format exploitable (Lua, JSON, ou facile à convertir), c'est le jackpot.
