# 18 — Skill Difficulty

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 6 — Leveling Planner                                  |
| Prerequisites | Capsule 09 — Item Info                                      |
| Type          | Autonomous                                                  |
| Concepts      | Seuils orange/jaune/vert/gris par recette, `p(recipe, skill)` interchangeable, espérance géométrique `1/p`, formule `(graySkill - currentSkill) / (graySkill - yellowSkill)` |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Ajouter** les seuils de couleur (orange/jaune/vert/gris) dans la DB recettes
2. **Calculer** la probabilité de skill-up en fonction du skill courant
3. **Afficher** le coût espéré par point de compétence pour chaque recette

## Key Formula

```
p(recipe, skill) = (graySkill - skill) / (graySkill - yellowSkill)
coût par point = coûtCraft / p
```

## Going Further

- → Capsule 19 : Leveling DP (chemin optimal 0→300)
