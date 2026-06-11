# Architecture UI — Patterns composants orientés données

> Base de connaissances validée — Session 8, Capsule 06
> Source : consultation multi-agents (Claude, Gemini, ChatGPT, GitHub)

## Pattern retenu : Mixin + ContinueOnItemLoad

### Pourquoi ce pattern

- **Idiomatique WoW** : Blizzard utilise des `*Mixin` partout dans le FrameXML moderne
- **ContinueOnItemLoad** existe nativement en Classic Era 1.15.x (vérifié dans `Blizzard_ObjectAPI/Classic/Item.lua`) — Blizzard a déjà codé le resolver async
- **Encapsulation** : chaque composant (ligne de recette) est autonome — il sait se dessiner et se mettre à jour
- **Zéro index externe** : plus de `itemToTexts` reliant Phase 1 et Phase 2
- **~40 lignes** de code

### Comment ça marche

```lua
-- Chaque ligne est un composant Mixin autonome
RecipeLineMixin = {}

function RecipeLineMixin:SetRecipe(recipe)
    self.recipe = recipe
    self:Render()

    local name = GetItemInfo(recipe.output)
    if not name then
        -- Blizzard's promise-like API: callback quand l'item arrive en cache
        local item = Item:CreateFromItemID(recipe.output)
        item:ContinueOnItemLoad(function()
            if self.recipe == recipe then  -- garde anti-recyclage
                self:Render()
            end
        end)
    end
end

function RecipeLineMixin:Render()
    local name = GetItemInfo(self.recipe.output)
    self.text:SetText(name or ("item:" .. self.recipe.output))
end
```

### ContinueOnItemLoad — sous le capot

Blizzard implémente ça dans `ItemEventListener` (dispo en Classic Era) :
- S'enregistre sur `ITEM_DATA_LOAD_RESULT` (pas `GET_ITEM_INFO_RECEIVED`)
- Déduplication automatique : 10 lignes pour le même itemID = 1 seule attente
- Appelle le callback quand l'item est chargé
- Pas besoin d'écrire notre propre resolver

### Testabilité

- Extraire la logique pure dans des fonctions statiques (formatage, tri) → testable en busted
- Les méthodes WoW (`Render`, `CreateFontString`) sont de la "colle" triviale qu'on ne teste pas unitairement
- Injection `env` possible si on veut tester les composants avec des stubs

---

## Architecture de référence (pour CraftGold)

```
CraftGold/
├── Core.lua           -- Logique pure : DB, queries, calculs de coûts
├── UI/
│   ├── RecipeLine.lua -- Composant Mixin : SetRecipe / Render / Destroy
│   └── RecipeList.lua -- Frame pool + dispatch
└── CraftGold.lua      -- Shell WoW : ADDON_LOADED, slash commands
```

Règle : **Personne hors RecipeLine ne touche à RecipeLine.text.**

---

## Autres patterns évalués (pour référence future)

| Pattern | Verdict | Quand l'envisager |
|---------|---------|-------------------|
| **Component OOP + ItemResolver maison** | Bon (2ème choix) | Si `ContinueOnItemLoad` n'existait pas, ou pour un resolver custom |
| **Signal-based / Reactive** | Élégant mais complexe | Si CraftGold a des données partagées entre panneaux, prix réactifs, filtres dynamiques |
| **Data-driven + Frame Pool** | Bon pour les listes scrollables | Si la liste dépasse ~50 lignes (capsule 12 Scroll Frame) |
| **MVVM** | Testabilité max mais boilerplate | Si la fenêtre devient très complexe (onglets, état partagé) |
| **Observer / Event-bus** | Infrastructure utile | Si on a beaucoup d'événements custom cross-composants |
| **ECS** | Rejeté — overkill | Jamais pour une liste UI |
| **Immediate mode** | Rejeté — incompatible WoW | Les frames sont retained, pas un canvas |
| **Virtual DOM (React-like)** | Rejeté — trop coûteux | Le diffing alloue trop sans build step |

### Anti-patterns WoW spécifiques

1. **Frames indestructibles** : `CreateFrame()` alloue un objet C++ jamais libéré. Toujours recycler (Hide/Show), jamais recréer
2. **Événements globaux** : `GET_ITEM_INFO_RECEIVED` est dispatché à TOUS les frames enregistrés. Centraliser si >100 lignes
3. **Pas de build step** : pas de JSX, pas de compiler — les tables Lua sont notre "déclaratif"

---

## Projets open source de référence

| Projet | Pattern | Lien |
|--------|---------|------|
| FrameXML Blizzard | Mixin, ContinueOnItemLoad, FramePool | `Blizzard_ObjectAPI/Classic/Item.lua` |
| Details! / DetailsFramework | Mixin + injection de méthodes | https://github.com/Tercioo/Details-Damage-Meter |
| WeakAuras | Data-driven + états réactifs | https://github.com/WeakAuras/WeakAuras2 |
| oUF | Data-driven déclaratif | https://github.com/oUF-wow/oUF |
| Ace3 (AceEvent) | Observer / event-bus | https://www.wowace.com/projects/ace3 |
