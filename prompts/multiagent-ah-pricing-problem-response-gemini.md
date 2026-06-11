C'est une excellente analyse de la situation. Tu viens de heurter le mur classique du développement d'outils économiques pour WoW : la transition entre un modèle mathématique théorique et la réalité chaotique des données de l'Hôtel des Ventes. C'est exactement à ce stade que beaucoup d'add-ons sont abandonnés, mais ton approche par capsules est la bonne méthode pour le surmonter.

Voici une analyse technique, algorithmique et pragmatique pour débloquer CraftGold, suivie d'une proposition de roadmap révisée.

### Analyse du Problème 1 : Le prix réel à l'Hôtel des Ventes

Le problème d'acheter une quantité exacte d'un composant au moindre coût en combinant des piles (stacks) de tailles et de prix différents s'apparente au **Problème du sac à dos (Knapsack Problem)**, et plus précisément à une variante du **Set Cover Problem**.

* **Complexité :** Dans le cas général, ce problème est **NP-difficile**. Cela signifie qu'il n'existe pas d'algorithme rapide (en temps polynomial) pour trouver la solution parfaite à chaque fois.
* **L'approche Gloutonne (Greedy) :** C'est l'heuristique la plus courante. Tu tries tous les listings par **prix unitaire croissant**, puis tu "achètes" virtuellement ces listings jusqu'à atteindre la quantité désirée.
* **La limite du Glouton :** L'algorithme glouton se fait piéger par les grandes piles. Si tu as besoin de 2 unités, et qu'il y a 2 unités à l'unité pour 5s/u, et une pile de 20 pour 2s/u (total 40s), le glouton choisira la pile de 20 et te fera dépenser 40s au lieu de 10s. Pour pallier cela, on ajoute souvent une passe d'optimisation locale : comparer le coût total de la sélection gloutonne avec le coût absolu du plus petit stack qui couvre à lui seul le besoin restant.

**Comment font les add-ons existants (TSM, Auctionator) ?**

Ils **trichent**, tout simplement. Calculer le coût réel en combinant les piles pour des arbres d'artisanat récursifs profonds ferait exploser le temps d'exécution (et gèlerait le client WoW, déclenchant l'erreur Lua `Script ran too long`).

* **Auctionator** calcule une moyenne ou prend le prix unitaire le plus bas disponible, s'en servant comme "Market Value".
* **TradeSkillMaster (TSM)** utilise des sources de prix précalculées (`dbminbuyout`, `dbmarket`). Quand TSM calcule le coût d'un craft, il multiplie simplement la quantité requise par cette source de prix unitaire. Il ne simule pas l'achat des stacks exacts lors du calcul de rentabilité. Il ne fait la résolution des stacks qu'au tout dernier moment, lorsque tu ouvres l'interface d'achat ("Shopping list").

---

### Analyse du Problème 2 : Le Leveling Planner et les probabilités

Monter de compétence est un problème d'optimisation de chemin (Pathfinding). Tu cherches le chemin le moins cher pour aller du nœud A (Skill 0) au nœud B (Skill 300).

* **L'espérance mathématique :** Si une recette coûte un montant $C$ et offre une probabilité $p$ de donner un point de compétence (avec $0 < p \le 1$), l'espérance du coût pour obtenir un point avec cette recette est calculée par la formule :

$$E = \frac{C}{p}$$



Ainsi, une recette à 2s avec 25% de chance de proc ($p = 0.25$) a un coût espéré de 8s par point de compétence.
* **L'algorithme de Dijkstra :** C'est l'algorithme parfait pour ça. Chaque niveau de compétence (0 à 300) est un nœud. Chaque recette est une arête (edge) qui relie le nœud `Skill` au nœud `Skill + 1`. Le "poids" de cette arête est l'espérance mathématique du coût de la recette $\frac{C}{p}$ à ce niveau de compétence précis.

**Le lien entre les deux problèmes :**
Si tu épuises les composants bon marché de l'HdV pour passer de 50 à 51, ces composants ne sont plus disponibles pour passer de 51 à 52. Le coût $C$ est donc dynamique. Pour que le Planner soit réaliste, l'algorithme doit être incrémental : évaluer la recette la moins chère pour le *prochain* point, simuler la consommation des composants dans l'HdV virtuel, puis recalculer le coût des recettes pour le point suivant.

---

### Roadmap Révisée (Orientée Données et Pédagogie)

Pour garder des capsules atomiques et ne pas te noyer dans la complexité algorithmique, nous devons séparer l'approximation des prix (pour la rentabilité des crafts) de la simulation d'achat (pour le leveling planner).

| # | Capsule | Concepts et Objectifs |
| --- | --- | --- |
| 08 | Analyze & Report | `/cg analyze`, tri des crafts par profit, affichage chat (modèle basique). |
| 09 | Item Info | `GetItemInfo()`, cache asynchrone, noms lisibles pour l'UI. |
| 10 | AH Scanner (Moyennes) | Écoute de `QueryAuctionItems`. Au lieu de stocker tous les stacks, calculer et stocker un `MinBuyout` (prix unitaire le plus bas). **Résout l'Objectif 2 (Rentabilité) de manière performante.** |
| 11 | Profit Window | Interface graphique basique pour afficher le Top 10 des crafts rentables basé sur les données de la Capsule 10. |
| 12 | Scroll Frame | Ajout de la navigation si la liste des crafts déborde. |
| 13 | Stack Resolver | Nouvelle fonction Lua isolée : implémentation de l'algorithme Glouton pour calculer le coût exact d'une quantité `N` à partir d'une table brute de listings HdV. |
| 14 | Skill Math | Introduction des probabilités. Fonction qui prend un `SkillLevel` et une `Recipe`, et retourne le coût espéré $\frac{C}{p}$. |
| 15 | Leveling Planner | L'algorithme incrémental. Boucle de 0 à 300. Utilise la Capsule 13 (pour le coût réel) et la Capsule 14 (pour la probabilité). Sortie texte dans le chat du chemin optimal. |
| 16 | CraftGold v1 | UI finale intégrant le Planner, DB complète, polish. |

Préfères-tu que l'on détaille en premier le code Lua de l'algorithme Glouton pour la résolution des stacks (Capsule 13), ou la logique mathématique des probabilités par couleur (Capsule 14) ?