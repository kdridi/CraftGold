# Recherche — Architecture UI composants orientés données en Lua (WoW Add-ons)

## Contexte

Nous développons un add-on World of Warcraft Classic Era en Lua. Nous avons une fenêtre qui affiche une liste de recettes d'Engineering. Chaque ligne affiche des données résolues via `GetItemInfo(itemID)`, qui est potentiellement asynchrone (retourne `nil` la première fois, puis un événement `GET_ITEM_INFO_RECEIVED` apporte les données réelles plus tard).

### Le problème architectural

Actuellement, notre code a **deux phases séparées** dans la même fonction `Create()` :

```lua
-- Phase 1 : création visuelle + résolution initiale
for i, recipe in ipairs(sorted) do
    local text = line:CreateFontString(...)
    text:SetText(formatItemLine(recipe))  -- GetItemInfo() ici
    itemToTexts[itemID] = { text, recipe }  -- index externe
end

-- Phase 2 : mise à jour asynchrone (détachée)
frame:SetScript("OnEvent", function(self, event, itemID, success)
    for _, entry in ipairs(itemToTexts[itemID]) do
        entry.text:SetText(formatItemLine(entry.recipe))
    end
end)
```

**Ce qui nous déplaît** : la logique d'une même entité (une ligne de recette) est éclatée en deux endroits. Un index externe (`itemToTexts`) sert de pont entre la création et la mise à jour. Ce n'est pas encapsulé, ce n'est pas composant-oriented.

**Ce qu'on cherche** : une architecture où chaque entité UI est autonome — elle sait se dessiner, se mettre à jour, et réagir aux événements qui la concernent. Un modèle plus "component-oriented", similaire à ce que React/Vue/Svelte proposent (data-driven, réactivité, encapsulation).

### Contraintes spécifiques

- **Langage** : Lua 5.1 (pas de classes nativement, pas de tableaux associatifs ordonnés)
- **Pas de build step** — le code Lua est chargé directement par WoW
- **API WoW** : `CreateFrame()`, `FontString`, événements via `RegisterEvent`/`SetScript`
- **GetItemInfo()** est asynchrone : premier appel peut retourner `nil`, événement `GET_ITEM_INFO_RECEIVED` apporte la donnée plus tard
- **Pas de garbage collector agressif** — WoW gère sa mémoire, mais on évite les créations massives par frame
- **Pas de lib externe** — on veut du Lua pur, pas de dépendance à un framework

## Ce que nous voulons

### 1. Un classement argumenté des architectures/patterns UI applicables en Lua

Pour chaque pattern, nous voulons :
- **Nom du pattern** (ex: Observer, MVC, MVVM, ECS, Signal-based, Reactive, etc.)
- **Description** concise (2-3 phrases)
- **Avantages** dans notre contexte (Lua + WoW + async)
- **Inconvénients** dans notre contexte
- **Exemple de code** complet et fonctionnel en Lua, appliqué à notre cas concret (liste de recettes avec résolution async d'itemIDs)
- **Projets open source** qui utilisent ce pattern (lien si possible)

### 2. Les architectures à considérer (liste non exhaustive)

- **Component-oriented** (type React) : chaque composant encapsule son render + son state + ses handlers
- **Observer/Event-driven** : les composants s'abonnent à des événements ciblés
- **MVC/MVP/MVVM** : séparation modèle/vue/contrôleur
- **Signal-based / Reactive** : données réactives qui propagent les changements automatiquement
- **ECS (Entity Component System)** : entités = IDs, composants = data, systèmes = logique
- **Immediate mode UI** : re-render complet à chaque frame (type Dear ImGui)
- **Data-driven / Declarative** : décrire l'UI souhaitée, un engine la construit
- **Mixin/Module pattern** (idiot WoW) : comportements injectés dans les frames via mixins
- **Tout autre pattern** jugé pertinent par le répondant

### 3. Focus sur la testabilité

Pour chaque pattern, préciser :
- Comment tester unitairement les composants en pur Lua (hors WoW) ?
- Le pattern facilite-t-il ou complique-t-il les tests ?

### 4. Exemples concrets attendus

L'exemple de code doit résoudre **notre vrai problème** :
- Une liste de N recettes (table Lua avec itemIDs)
- Chaque ligne affiche un nom d'item (via `GetItemInfo`)
- Si l'item n'est pas en cache → afficher un placeholder
- Quand l'événement async arrive → la ligne se met à jour automatiquement
- Le tout doit être propre, encapsulé, et maintenable

## Instructions spécifiques par plateforme

### Pour Claude, Gemini, ChatGPT

Focus sur :
- La **théorie des patterns** et leur application en Lua
- Les **comparaisons argumentées** entre patterns
- Les **exemples de code** complets et idiomatiques en Lua 5.1
- Les **trade-offs** spécifiques au contexte WoW (pas de build step, API spécifique, etc.)
- Des **références** à des patterns utilisés dans d'autres langages/frameworks (React, Vue, Elm, SwiftUI, etc.) et comment ils pourraient s'adapter en Lua

### Pour GitHub Copilot (recherche de code)

Focus sur :
- **Rechercher des add-ons WoW open source** qui implémentent des patterns UI avancés
- Exemples concrets de code dans des projets comme : WeakAuras, Details!, Plater, DBM, AtlasLoot, TradeSkillInfo, Auctionator, CraftSim, Skillet, etc.
- **Rechercher des projets Lua hors WoW** (LÖVE2D, Corona SDK, Roblox, etc.) qui ont des patterns UI composant-oriented
- Montrer du **vrai code** de vrais projets avec les URLs GitHub

## Critères de réponse

1. **Classement** — Donner un top 3-5 des patterns recommandés pour notre cas, avec arguments
2. **Code** — Chaque pattern doit avoir un exemple de code Lua complet applicable à notre cas
3. **Sources** — Liens vers des projets, articles, ou documentation quand c'est possible
4. **Format monobloc markdown** — Tout en un seul bloc
5. **Honnêteté** — Si un pattern est mauvais pour Lua, le dire. Si Lua 5.1 limite un pattern, l'expliquer.
