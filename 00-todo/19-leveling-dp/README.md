# 19 — Leveling DP

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 6 — Leveling Planner                                  |
| Prerequisites | Capsule 18 — Skill Difficulty                               |
| Type          | Autonomous                                                  |
| Concepts      | DP plus court chemin skill 0→300, plan affiché, coût espéré total par segment |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Implémenter** la DP backward : pour chaque skill, choisir la recette au coût espéré minimum
2. **Reconstruire** le chemin optimal (quelles recettes crafter, sur quels segments de skill)
3. **Afficher** le plan complet avec coût espéré total

## Key Algorithm

```
cost[targetSkill] = 0
for skill = target-1 downto 0:
    cost[skill] = min(recipes: craftCost / skillupChance(recipe, skill) + cost[skill+1])
```

## Going Further

- → Capsule 20 : Shopping List (panier réel du plan)
