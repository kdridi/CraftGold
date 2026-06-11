# Consultation CraftGold — Prix réels HdV & Leveling Planner

## 1. Analyse algorithmique

### 1.1 Problème 1 : acheter Q unités parmi des listings — nature du problème

Formalisons. Tu as `n` listings, chacun étant un couple `(quantité qᵢ, prix pᵢ)`, achetable **en bloc ou pas du tout** (en Classic, le buyout prend tout le stack). Tu veux un sous-ensemble `S` qui minimise `Σ pᵢ` sous contrainte `Σ qᵢ ≥ Q`.

Ce n'est ni du bin packing ni le knapsack classique, mais son cousin : le **covering knapsack** (ou *minimization knapsack*) — au lieu de maximiser une valeur sous un budget, on minimise un coût sous une contrainte de couverture. Réponses à tes trois sous-questions :

**Est-ce NP-difficile ?** Oui, dans le cas général (réduction depuis Subset Sum). **Mais** c'est NP-difficile *au sens faible* : il existe une programmation dynamique pseudo-polynomiale en `O(n × Q)`. Et dans ton contexte, `n` (nombre de listings d'un item, quelques dizaines à quelques centaines) et `Q` (quelques centaines, même pour 847 Copper Bars) sont minuscules. **Tu peux résoudre exactement, en quelques millisecondes, en Lua.** Le caractère NP-difficile est théorique ; en pratique le problème est trivial à ta taille.

La DP, c'est exactement du knapsack 0/1 :

```lua
-- listings = { {count=1, buyout=100}, {count=5, buyout=2500}, ... }
-- Retourne le coût minimal pour obtenir AU MOINS need unités
function CG.CostToBuy(listings, need)
    local INF = math.huge
    local dp = {}                      -- dp[k] = coût min pour >= k unités
    for k = 0, need do dp[k] = INF end
    dp[0] = 0
    for _, L in ipairs(listings) do
        for k = need, 0, -1 do         -- parcours inverse : 0/1, pas illimité
            if dp[k] < INF then
                local k2 = math.min(need, k + L.count)
                local c  = dp[k] + L.buyout
                if c < dp[k2] then dp[k2] = c end
            end
        end
    end
    return dp[need]                    -- INF si stock insuffisant
end
```

Le `math.min(need, k + L.count)` encode le fait qu'un surplus est acceptable : c'est ce qui permet à l'algorithme de découvrir que le stack x20 à 2g peut battre trois petits achats, ou l'inverse. Pour reconstruire *quels* listings acheter, garde un tableau de prédécesseurs.

**Heuristique simple ?** Le glouton « trier par prix unitaire croissant, acheter jusqu'à couvrir Q » est l'heuristique naturelle. Elle est bonne mais non optimale : elle rate les cas où un gros stack légèrement plus cher à l'unité couvre tout d'un coup, ou achète un gros stack alors qu'il manquait 1 unité. Vu que la DP exacte est si peu coûteuse, **l'heuristique gloutonne n'a d'intérêt que pédagogique** — et c'est précieux : capsule « glouton », puis capsule « contre-exemple + DP ». C'est un arc narratif parfait.

**Conséquence conceptuelle clé** : le « prix » d'un item n'est plus un nombre, c'est une **fonction** `CostToBuy(item, q)` — une fonction en escalier, croissante, et *non linéaire* (le coût marginal monte quand les listings pas chers s'épuisent). Toute la refonte de CraftGold découle de ce changement de type : `nombre → fonction(quantité)`.

### 1.2 Propagation dans le calcul récursif

Ton `min(buy, craft)` par item devient faux pour deux raisons :

1. **Le prix d'achat dépend de la quantité** — comparer un « prix unitaire » d'achat à un coût de craft unitaire n'a plus de sens.
2. **Les besoins se mutualisent** — si trois recettes consomment du Copper Bar, les listings pas chers ne peuvent servir qu'une fois. Les décisions buy/craft ne sont plus indépendantes par item.

Le problème global (DAG de craft + coûts d'achat non linéaires + décisions entières) est un programme en nombres entiers, NP-difficile en général. Mais inutile de sortir un solveur : l'approche pratique est en **deux phases avec point fixe** :

1. **Phase structure** : parcours le DAG des recettes en ordre topologique (tes composants forment un DAG, tu as déjà la détection de cycles) et décide buy/craft avec les prix marginaux courants.
2. **Phase agrégation** : déroule récursivement le plan en une *bill of materials* — la liste de courses totale `{itemID → quantité}` de matières premières.
3. **Phase pricing exact** : applique `CostToBuy(item, Q_total)` sur chaque ligne de la liste agrégée. C'est ici que les 847 Copper Bars sont chiffrés *vraiment*.
4. **(Optionnel) Itération** : si le pricing exact rend un craft moins bon qu'un achat (ou l'inverse), bascule la décision et reboucle. Sur une DB de 26 recettes, ça converge en 1-2 passes ; une recherche locale naïve suffit largement.

Pour CraftGold, je recommande de viser l'exactitude sur les étapes 2-3 (agrégation + DP, c'est là que se trouve 90 % de la justesse) et d'assumer une heuristique sur l'étape 1, documentée comme telle. C'est honnête, simple, et très supérieur à tout ce qui existe.

### 1.3 Ce que font les add-ons existants — avec sources

Spoiler : **aucun add-on grand public ne résout ton problème 1 de façon optimale.** Ils contournent.

**TSM (TradeSkillMaster)** ne calcule pas un coût d'achat pour une quantité donnée ; il produit des **statistiques de prix par item**. DBMinBuyout est simplement l'enchère la moins chère du serveur, et DBMarket est une « valeur de marché » calculée par AuctionDB. L'algorithme de market value procède en plusieurs étapes pour corriger les valeurs aberrantes et lisser dans le temps, plutôt que de faire une simple moyenne ; et la documentation reconnaît explicitement que la valeur d'un item dépend de la quantité qu'on achète typiquement — c'est exactement ta remarque. Leur exemple chiffré le montre : acheter les 15 listings les moins chers d'un jeu de données donne un prix moyen différent de la moyenne globale, ce que TSM décrit comme une faiblesse inhérente aux estimateurs de valeur de marché, qu'il tente de compenser en supposant que la demande d'un item est proportionnelle au stock présent à l'HdV, et en éliminant les sauts de prix de plus de 20 % après avoir parcouru 15 % des enchères. La valeur finale est la moyenne des points restants après filtrage, ce qui protège surtout contre l'empoisonnement par des posteurs à prix astronomiques. Autrement dit : TSM **estime un prix unitaire robuste**, il ne calcule pas un coût d'achat exact pour `Q` unités. Son module Crafting multiplie ce prix unitaire par les quantités — l'approximation que tu veux justement dépasser.

**Auctionator** est encore plus simple : son panneau d'achat affiche les items correspondants avec leurs prix les plus bas, et un clic déroule le résumé détaillé d'un item — une liste triée par prix unitaire, dans laquelle l'humain achète gloutonnement de haut en bas. Même philosophie chez des scanners alternatifs : des listes de buyouts ordonnées par prix unitaire, du moins cher au plus cher, pour faciliter l'achat manuel.

Conclusion : ta DP `CostToBuy` est un **vrai différenciateur** par rapport à l'état de l'art des add-ons. Ce n'est pas un problème résolu que tu réinventes — c'est un trou assumé que les gros add-ons comblent par des statistiques et du glouton humain.

### 1.4 Problème 2 : le leveling planner

**Le modèle de skill-up.** Sois transparent sur l'incertitude : les chances exactes de skill-up ne sont pas connues officiellement ; les seules valeurs certaines sont orange (garanti) et gris (jamais). Deux modèles circulent dans la communauté : des probabilités plates (orange 100 %, jaune 50 %, vert 25 %, gris 0 %, modèle populaire mais contesté), et une formule continue issue du wiki, utilisée par exemple par l'add-on SkillUpProbability, qui souligne que les chances ne sont pas simplement 25/75/100 %. La formule continue est `p(s) = clamp((gris − s) / (gris − jaune), 0, 1)` où `s` est le skill courant : 100 % jusqu'au seuil jaune, puis décroissance linéaire jusqu'à 0 au seuil gris. Recommandation : code le modèle comme une **fonction interchangeable** `p(recipe, skill)` — c'est à la fois plus propre et une leçon pédagogique (séparer le modèle du moteur).

**Espérance de crafts par point.** Chaque tentative est une Bernoulli de paramètre `p` → le nombre de crafts pour +1 point suit une loi géométrique d'espérance `1/p`. D'où le coût espéré d'un point au skill `s` avec la recette `r` :

```
coûtPoint(r, s) = coûtComposants(r) / p(r, s)
```

C'est exactement ton exemple Recette A vs Recette B.

**L'algorithme.** Une fois qu'on a `coûtPoint(r, s)`, le leveling planner est un **plus court chemin sur un DAG trivial** : les nœuds sont les niveaux de skill 0…300, et passer de `s` à `s+1` coûte `min sur r disponibles de coûtPoint(r, s)`. Comme on avance toujours de +1, c'est une simple boucle :

```lua
-- cost[s] = coût espéré pour aller de s à TARGET
local cost, plan = {}, {}
cost[TARGET] = 0
for s = TARGET - 1, START, -1 do
    local best, bestR = math.huge, nil
    for _, r in ipairs(recipes) do
        local p = CG.SkillUpChance(r, s)
        if p > 0 and s >= r.minSkill then
            local c = CG.MatCost(r) / p
            if c < best then best, bestR = c, r end
        end
    end
    cost[s] = best + cost[s + 1]
    plan[s] = bestR
end
```

Complexité `O(300 × |recettes|)` : instantané. Raffinements possibles (plus tard, pas dans la v1 de la capsule) : amortir le coût d'apprentissage des recettes (plans achetés au vendeur/HdV), réutiliser les produits d'un craft comme composants d'un craft ultérieur (les Bronze Tubes…), déduire la valeur de revente des produits.

**Le couplage avec le problème 1.** C'est un problème de poule et d'œuf : le plan détermine les quantités (847 Copper Bars), et les quantités déterminent les coûts via `CostToBuy`, qui déterminent le plan. Solution pragmatique en **point fixe** : (1) planifie avec les prix marginaux actuels (le prix unitaire du listing le moins cher, par exemple), (2) agrège la liste de courses du plan complet, (3) reprice chaque matière avec `CostToBuy(item, Q_total)` et recalcule le coût total affiché, (4) optionnellement, replanifie avec les coûts moyens issus de (3) et reboucle une fois. En pratique, une seule itération de repricing donne déjà le chiffre honnête que tu cherches (« combien ça coûte *vraiment* »), même si le plan lui-même reste légèrement sous-optimal. Note aussi que les quantités issues du plan sont des **espérances** — tu peux afficher une marge de sécurité (ex. +15 % sur les composants des recettes jaunes/vertes).

## 2. Roadmap révisée

Le fil conducteur : **d'abord changer le modèle de données (1 prix → liste de listings), puis l'algorithme d'achat, puis l'agrégation, puis seulement brancher l'HdV réel, puis le probabiliste, puis le planner.** Chaque capsule introduit exactement un concept et reste testable avec des données mock avant toute UI.

Légende : 🎯1 = leveling planner, 🎯2 = crafts rentables, 🎯1+2 = les deux.

| # | Capsule | Concepts | Objectif | Statut |
|---|---------|----------|----------|--------|
| 08 | Analyze & Report | `/cg analyze`, Top N, affichage chat | 🎯2 | inchangée |
| 09 | Item Info | `GetItemInfo()`, cache asynchrone | 🎯1+2 | inchangée |
| **10** | **Modèle multi-listings** | Remplacer `price[item]` par `listings[item] = {{count, buyout}, …}` ; saisie mock `/cg listing add 2840 5 2500` ; prix par stack vs unité | 🎯1+2 | **nouvelle** |
| **11** | **Glouton & contre-exemple** | Tri par prix unitaire, achat glouton, `/cg cost 2840 7` ; démonstration d'un cas où le glouton se trompe | 🎯1+2 | **nouvelle** |
| **12** | **CostToBuy (DP knapsack)** | DP `O(n×Q)`, reconstruction des achats, surplus accepté ; tests unitaires vs glouton | 🎯1+2 | **nouvelle** |
| **13** | **Bill of Materials** | Expansion récursive d'un craft en quantités de matières premières agrégées ; `/cg shoplist <recette> <n>` | 🎯1+2 | **nouvelle** |
| **14** | **Buy vs Craft à quantité** | Remplacer `min(buy, craft)` unitaire par la décision à quantité donnée + repricing de la liste agrégée ; mise à jour de `/cg analyze` | 🎯2 | **nouvelle** (absorbe la refonte du calculateur) |
| 15 | AH Scanner | `QueryAuctionItems`, pagination, throttling, `AUCTION_ITEM_LIST_UPDATE` → **alimente directement le modèle listings de la capsule 10** | 🎯1+2 | modifiée (ne stocke plus un prix unique) |
| 16 | Profit Window | Fenêtre, Top 10, sélection | 🎯2 | ex-11 |
| 17 | Scroll Frame | ScrollFrame, Slider | 🎯2 | ex-12 |
| **18** | **Modèle de skill-up** | Seuils de couleur par recette, `p(recipe, skill)` interchangeable (plat vs linéaire), espérance géométrique `1/p`, `/cg skillup <recette> <skill>` | 🎯1 | **nouvelle** |
| 19 | Leveling Planner | DP plus court chemin 0→300, plan affiché, coût espéré total | 🎯1 | ex-13, enrichie |
| **20** | **Pricing du plan (point fixe)** | Agrégation de la liste de courses du plan complet + `CostToBuy` réel + marge de sécurité sur les recettes non-orange | 🎯1 | **nouvelle** |
| 21 | CraftGold v1 | DB complète, intégration Trade Skill UI, polish | 🎯1+2 | ex-14 |

Pourquoi cet ordre fonctionne pédagogiquement :

- **10→11→12** est l'arc « le prix est une fonction » : on change le type de donnée, on essaie l'approche naïve, on la casse avec un contre-exemple, on la répare avec la DP. Aucune UI, aucun réseau — tout est testable avec des listings saisis à la main, exactement dans ton esprit « données d'abord ».
- **13 et 14** réutilisent ton calculateur récursif existant : 13 le détourne pour produire des quantités (pas des coûts), 14 recombine 12 + 13. Pas de saut : chaque capsule compose deux briques déjà connues.
- **15 (scanner)** arrive *après* que le modèle de données et les algos sont en place : le scanner n'est plus qu'une source de données qui remplit une structure déjà testée. C'est l'inverse de ta roadmap actuelle (scanner en 10, avant le modèle) — brancher l'asynchrone et le throttling sur un modèle pas encore stabilisé t'aurait obligé à tout réécrire.
- **18** est volontairement isolée du planner : la probabilité et l'espérance géométrique sont un concept à part entière, testable par une commande chat, avant d'être consommées par la DP de la capsule 19.
- **20** boucle la boucle en connectant les deux problèmes — c'est la capsule « synthèse », et elle justifie rétroactivement tout l'édifice : c'est elle qui répond enfin à « combien coûte *vraiment* Engineering 0→150 ».

Un dernier conseil de design : fais de `CostToBuy(item, q)` l'API centrale de tout l'add-on dès la capsule 12, avec le cas dégénéré « un seul listing de quantité infinie » reproduisant ton modèle actuel. Ainsi les capsules 1-9 restent valides conceptuellement : l'ancien modèle devient un cas particulier du nouveau, ce qui est la plus élégante des transitions pédagogiques.