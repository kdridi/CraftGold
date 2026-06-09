# CraftGold

## À quoi ça sert ?

CraftGold est un add-on World of Warcraft Classic Era qui aide à **optimiser l'or** dépensé et gagné via les métiers de fabrication. Il poursuit deux objectifs complémentaires :

### 🎯 Objectif 1 : Monter un métier au moindre coût

> *« Je veux monter Ingénierie de 1 à 300 en achetant tout à l'Hôtel des Ventes. Qu'est-ce que j'achète et que je fabrique pour dépenser le moins possible ? »*

Pour chaque niveau du métier, CraftGold détermine :
- Quels crafts faire pour monter le plus efficacement
- Pour chaque craft, le coût **réel** des matériaux en tenant compte du fait que certains composants intermédiaires coûtent moins cher à acheter directement qu'à fabriquer
- Le coût total optimal pour atteindre le niveau ciblé

### 💰 Objectif 2 : Gagner de l'or en craftant

> *« Quels objets puis-je fabriquer et revendre à l'HdV avec le plus de profit ? »*

CraftGold scanne l'Hôtel des Ventes et calcule, pour chaque craft disponible :
- Le coût réel de fabrication (calcul récursif)
- Le prix de vente à l'HdV
- Le profit net = vente − coût réel
- Affiche les crafts les plus rentables, triés par profit

### Le cœur de l'algorithme : calcul récursif des coûts

La différence avec les autres add-ons, c'est qu'on ne s'arrête pas au premier niveau de composants. On descend dans tout l'arbre de fabrication :

```
coûtRéel(objet) = min(
    prixHdV(objet),                    // acheter directement
    somme(coûtRéel(composant))         // fabriquer à partir des sous-composants
)
```

**Exemple concret (Ingénierie) :**
- Leurre → Poignée de boulons de cuivre + ...
- Poignée de boulons de cuivre → 3× Barre de cuivre (coût X)
- Mais à l'HdV, la Poignée coûte moins que X
- → Donc on achète la Poignée directement, et le vrai coût du Leurre baisse

## Public visé

Initialement développé et testé sur **WoW Classic Era**, avec focus sur le métier d'**Ingénierie**. L'add-on est conçu pour être extensible à tous les métiers et toutes les versions de WoW.

## Statut

🚧 **En cours de développement** — Phase d'apprentissage et prototypage.
