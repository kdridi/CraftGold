Tu traverses exactement la crise existentielle classique du développeur d'add-ons : le **"Widget-Trap"**, ou l'art d'implémenter des composants graphiques complexes par spéculation avant d'avoir touché à la moindre donnée réelle.

Tu as eu le très bon réflexe de t'arrêter. Ta roadmap actuelle est effectivement imparfaite, car elle place l'interface complète avant d'avoir validé la tuyauterie de données de WoW Classic.

Voici une refonte stratégique orientée **MVP strict** pour CraftGold.

---

## Q1 — Le Workflow joueur minimal

Pour un MVP, n'essaie pas de créer une usine à gaz comme TradeSkillMaster (TSM). Inspire-toi plutôt de la simplicité historique d'**Auctionator** ou **Skillet**.

Le workflow le plus court, le plus propre et le moins sujet aux bugs d'interface se divise en 2 étapes :

1. **La Collecte (À l'HdV) :** Le joueur ouvre l'HdV et clique sur un bouton unique "Scanner CraftGold". L'add-on enregistre les prix de tous les composants et items du jeu via `QueryAuctionItems(..., true)`.
2. **La Consultation (Dans la fenêtre de Métier) :** Le joueur ferme l'HdV, part à l'aventure ou s'installe près d'une enclume. Il ouvre son panneau de métier classique WoW (`C_TradeSkillUI`). CraftGold vient injecter ses lignes de texte directement sous ou à côté des recettes pour afficher : *Coût de fabrication VS Prix de vente → Profit*.

**Pourquoi ce workflow ?** Tu n'as pas besoin de recréer une fenêtre entière pour lister 200 crafts. L'interface de Blizzard fait déjà le tri par sous-catégories. Tu viens juste **enrichir** cette interface existante (ce qu'on appelle un *hook* d'UI).

---

## Q2 — Les données à afficher concrètement

Restons minimalistes. L'affichage doit répondre à une seule question : *"Est-ce que je clique sur Créer ?"*

### 1. Sur la fenêtre de Métier (Intégration Blizzard)

Sous le nom de la recette sélectionnée, à côté des composants requis :

```text
======================================================
[Icône] Gantelets en bronze lourds (Skill: 135)
======================================================
Coût Craft (Optimal) : 12s 50c 
  -> Via achat direct des mats : 15s 00c
  -> Via sous-composants : 12s 50c  <-- [Choisi]
Prix Estimé à l'HdV   : 22s 00c

PROFIT NET : +9s 50c (Marge : 43%)
======================================================

```

### 2. Le Plan de Leveling (Ta Frame CraftGold autonome créée à la capsule 4)

Puisque tu as déjà une Frame déplaçable, elle servira uniquement de **Feuille de Route** textuelle pour le leveling, sans boutons complexes.

```text
=========================================
      CRAFTGOLD — PLANING INGENIERIE     
=========================================
Étape 1 [1 - 30] : Poudre explosive rugueuse
 -> Faire : 40 exemplaires
 -> Mats requis : 40x Pierre brute (Coût: 40s)

Étape 2 [30 - 50] : Poignée de boulons en bronze
 -> Faire : 25 exemplaires
 -> Mats requis : 25x Barre de bronze (Coût: 1g 20s)
=========================================
Total estimé pour 1-300 : 42 pièces d'or

```

---

## Q3 — De quels widgets as-je VRAIMENT besoin ?

**Bonne nouvelle : Tu as déjà codé 90% des widgets requis pour le MVP.**

* ❌ **Scroll Frame :** Tu n'en as pas besoin si tu affiches tes données dans l'interface de métier de Blizzard ou si ta feuille de route de leveling est concise (par exemple, afficher uniquement les 3 prochaines étapes optimales).
* ✅ **Ce que tu as déjà (Frames, FontStrings, Buttons) suffit amplement.**
* 🆕 **Le seul "nouveau" widget indispensable :** Les textures de pièces de monnaie de Blizzard pour afficher joliment l'or, l'argent et le cuivre (`"Interface\\MoneyFrame\\UI-GoldIcon"`, etc.), ou plus simplement utiliser le formatage texte natif de WoW via les *Escape Sequences* : `|cffffd700g|r`, `|cffc7c7c7s|r`, `|cffb87333c|r`.

---

## Q4 — Ordre de développement optimal (Le Pivot)

Ta roadmap actuelle souffre du syndrome "top-down" graphique. Inversons la tendance pour valider la technique (Data) avant l'esthétique (UI).

```
[Ancienne Roadmap] UI Spéculative ──> Data (Bloqué au milieu)
[Nouvelle Roadmap] Data brute (Chat) ──> Hook UI Blizzard ──> Feuille de route

```

Voici l'ordre optimal pour construire le MVP en restant motivé par des résultats visibles :

### Étape 1 : La DB Statique & Le Calculateur (Moteur Synaptique)

Ne lance même pas WoW. Reste sur ton environnement de test hors-ligne (busted).

* Implémente ta table de recettes d'Ingénierie en dur (ItemID produit, itemID composants, quantité).
* Code ta fonction récursive de calcul de coût. Donne-lui de faux prix HdV en entrée et vérifie via tes assertions qu'elle trouve le chemin le moins cher.

### Étape 2 : Le Scan HdV (La source d'énergie)

Entre en jeu. Oublie les fenêtres pour l'instant.

* Utilise l'événement `AUCTION_HOUSE_SHOW` pour savoir quand l'HdV est ouverte.
* Utilise [QueryAuctionItems()](https://wowpedia.fandom.com/wiki/API_QueryAuctionItems) avec le flag `getAll = true` (le scan complet de 15 minutes, identique à ce que fait l'ancien Auctionator).
* Boucle sur [GetAuctionItemInfo()](https://wowpedia.fandom.com/wiki/API_GetAuctionItemInfo) pour chasser le prix le plus bas de chaque ItemID et stocke-le dans tes `SavedVariables`.
* **Validation MVP :** Une commande slash `/cg prices` qui affiche dans le chat le prix enregistré d'un composant.

### Étape 3 : Hook de l'UI Blizzard (L'affichage direct)

* Écoute l'événement `TRADE_SKILL_SHOW`.
* Fais un "Hook" (interception) sur la fonction de Blizzard qui met à jour les détails de la recette sélectionnée ([C_TradeSkillUI](https://www.google.com/search?q=https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI)).
* Crée à la volée un simple `FontString` textuel CraftGold que tu ancres en dessous du cadre de Blizzard pour y écrire tes calculs de profit.

### Étape 4 : Le plan de leveling dans ta Frame autonome

* Reprends ta frame de la capsule 4.
* Utilise une boucle simple pour générer quelques lignes de texte (`FontString`) résumant les étapes les moins chères calculées à l'Étape 1.

---

## Q5 — Scope du MVP (Maximum Viable Product)

Pour prouver la valeur de CraftGold d'ici ce week-end, applique une politique de découpe agressive :

### 📦 Inclus dans le MVP :

* **Un seul métier :** L'Ingénierie (parce que ses recettes sont déterministes et linéaires, parfait pour tester un algorithme récursif).
* **Le Scan HdV de masse (GetAll) :** Une fois toutes les 15 minutes. C'est rustique mais c'est une seule ligne d'API à appeler.
* **Le calcul récursif de niveau 2 maximum :** (Ex: Barre de bronze + Pierre brute = Truc d'ingé).
* **Affichage texte pur :** Pas de listes déroulantes, pas d'onglets personnalisés à l'HdV.

### 🚫 Reporté à la v2 (À fuir pour le MVP) :

* *Gestion des procs de craft* (Alchimie) ou des crafts qui donnent plusieurs exemplaires de façon aléatoire.
* *Scans ciblés d'items par itemID* (Nécessite une gestion fine des files d'attente de requêtes à l'HdV pour éviter les déconnexions).
* *Prise en compte des frais de dépôt de l'HdV* et de la taxe de vente de 5% dans le calcul de marge.
* *Interface graphique léchée* avec barres de défilement et filtres.

En suivant ce plan, ta prochaine session de code ne consistera pas à te battre avec des repères XML ou des calculs de pixels pour une Scroll Frame, mais à faire cracher à ton add-on son tout premier : **"Acheter ce composant vous fera perdre 12 d'argent, fabriquez-le !"** dans ton canal de discussion. C'est là que réside la vraie valeur de ton projet.