# Consultation multi-agents — Stratégie CraftGold

## Contexte

Je développe **CraftGold**, un add-on World of Warcraft Classic Era (1.15.x) avec un double objectif :

1. **Monter un métier au moindre coût** — Déterminer les crafts optimaux et les matériaux les moins chers pour monter de 1 à 300
2. **Gagner de l'or en craftant** — Identifier les crafts rentables (achat de mats → fabrication → revente HdV)

Le cœur technique est un **calcul récursif des coûts** : pour chaque composant fabricable, on descend dans l'arbre et on choisit le chemin le moins cher entre acheter directement et fabriquer à partir de sous-composants.

## Ce qui est déjà fait

L'add-on est construit capsule par capsule (approche pédagogique). J'ai complété 5 capsules :

1. **Hello Azeroth** — `.toc`, `.lua`, `print()`, `/reload`
2. **Slash Commands** — `SLASH_*`, `SlashCmdList`, arguments, chat coloré
3. **Saved Variables** — `SavedVariables` dans `.toc`, `ADDON_LOADED`, persistance, architecture Functional Core / Imperative Shell (32 tests busted + 19 assertions in-game)
4. **My First Frame** — `CreateFrame()`, backdrop, position, drag
5. **Buttons & Text** — `CreateFrame("Button")`, `FontString`, `OnClick`, templates

**Connaissances acquises :**
- Créer des frames, boutons, texte
- Afficher une fenêtre déplaçable
- Interagir via clic et slash commands
- Persister des données en SavedVariables

## Décisions déjà prises

- **Source de données recettes** : DB statique en v1 (l'API Trade Skill ne liste que les recettes apprises → impossible de planifier un leveling sans DB). Engineering = set borné.
- **Composants stockés en itemID**, pas en nom
- **API Classic Era** : `C_TradeSkillUI` existe (pré-10.0), `C_AuctionHouse` n'existe PAS → utiliser `QueryAuctionItems()` + `GetAuctionItemInfo()`
- **Architecture** : Functional Core / Imperative Shell avec seam WoW injectable

## Roadmap actuelle (potentiellement obsolète)

```
Phase 1 — Bases (✅ fait) : 01-Hello, 02-Slash, 03-SavedVars
Phase 2 — Interface (partiel) : 04-Frame(✅), 05-Buttons(✅), 06-Scroll Frame(❌)
Phase 3 — Intégration : 07-Minimap, 08-Options
Phase 4 — Données : 09-ItemInfo, 10-TradeSkill, 11-AuctionHouse
Phase 5 — Algorithme : 12-CostCalculator
Phase 6 — Assemblage : 13-Final
```

## Le problème

Je m'apprêtais à faire la capsule 06 (Scroll Frame) quand j'ai réalisé : **je ne sais pas encore ce que CraftGold doit afficher**. J'apprends des widgets sur spéculation. Peut-être que je n'ai pas besoin de scroll frame. Peut-être que j'ai besoin d'autre chose. Je ne le sais pas car je n'ai pas encore travaillé avec les données réelles du jeu.

## Ce que je veux

**Un MVP fonctionnel de CraftGold** qui démontre la valeur métier. Pas un catalogue de widgets.

## Mes questions

### Q1 — Workflow joueur minimal
Quel est le workflow le plus simple qu'un joueur puisse utiliser ? Par exemple :
- Ouvre l'HdV → lance un scan → voit les crafts rentables ?
- Ouvre la fenêtre de métier → voit les coûts par recette ?
- Les deux ? Autre chose ?

### Q2 — Données à afficher concrètement
Pour chaque écran, quelles sont les colonnes / infos à afficher ? Par exemple :
- Liste de crafts : nom, coût mats, prix revente, profit, marge %
- Liste de mats : nom, prix unitaire, source (AH / craft / vendor)
- Plan de leveling : skill range, recette, mats nécessaires, coût total

### Q3 — Widgets nécessaires
En fonction de Q1 et Q2, de quels widgets ai-je VRAIMENT besoin ? Est-ce que ce que je sais déjà faire (frames, boutons, texte, SavedVariables) suffit pour un MVP ? Ou ai-je besoin de scroll frames, tableaux, onglets, etc. ?

### Q4 — Ordre de développement optimal
Si je devais réorganiser la roadmap, dans quel ordre devrais-je aborder :
- Scan de l'HdV (récupérer les prix)
- Données d'items (GetItemInfo, cache)
- DB statique des recettes
- Calcul des coûts
- Interface d'affichage

Quel est l'ordre qui permet d'avoir un truc visible et utile le plus vite possible ?

### Q5 — MVP scope
Quel est le plus petit ensemble de fonctionnalités qui démontre la valeur de CraftGold ? Qu'est-ce qui peut être reporté à plus tard ?

## Règles de réponse

1. **Fais une vraie recherche web** et fournis des **liens sources** pour chaque affirmation (wowpedia, warcraft.wiki.gg, forums, add-ons existants comme Auctionator, TradeSkillMaster, etc.)
2. **Réponse monobloc en markdown** — tout inline, pas de fichiers séparés
3. **Sois concret** — donne des exemples d'UI, des wireframes ASCII, des exemples de données
4. **Challenge la roadmap actuelle** — si elle est mauvaise, dis-le
5. **Pense MVP** — quel est le chemin le plus court vers un add-on utile ?
