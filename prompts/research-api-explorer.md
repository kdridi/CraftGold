# Recherche — API Explorer WoW : projets existants et dump de l'API

**Contexte** : Je développe des add-ons World of Warcraft Classic Era (version 1.15.x, interface 11508). L'API WoW Lua est **non documentée officiellement** — pas de doc Blizzard, pas de référence complète à jour. Les wikis (warcraft.wiki.gg, wowprogramming.com) sont partiels, parfois obsolètes, et ne distinguent pas toujours Retail vs Classic Era.

**Mon besoin** : Je veux pouvoir **dumper et explorer systématiquement** tout ce que WoW expose via Lua sur un client Classic Era spécifique — fonctions globales, tables, méthodes de widgets, événements, templates XML, mixins.

**Mode** : Fais une **vraie recherche web**. Fournis des **liens sources** (URLs) pour chaque affirmation. La réponse doit être un **seul bloc markdown** complet.

---

## 1. Projets existants d'exploration/dump de l'API WoW

Existe-t-il des projets (open source ou non) qui font un dump systématique de l'API Lua WoW ? Je cherche :

- Des outils qui listent **toutes les fonctions globales** accessibles en Lua (`_G`)
- Des outils qui listent **toutes les méthodes** disponibles sur chaque type de widget (`Frame`, `Button`, etc.)
- Des outils qui listent **tous les événements** disponibles (`"PLAYER_LOGIN"`, etc.)
- Des dumps déjà publiés spécifiquement pour **Classic Era** (ou qu'on peut filtrer par version)
- Des projets GitHub, WowInterface, CurseForge, forums Blizzard, etc.

Pour chaque projet trouvé :
- URL du projet
- Ce qu'il dump (fonctions ? méthodes ? événements ? templates ?)
- Comment il fonctionne (addon in-game ? parsing du binaire ? analyse du code FrameXML ?)
- Dernière mise à jour connue
- Est-ce qu'il distingue les versions (Retail vs Classic vs Classic Era) ?

## 2. La commande `/console ExportInterfaceFiles`

Je sais que WoW a une commande console intégrée :
```
/exportInterfaceFiles code
```

- Où exactement les fichiers sont-ils dumpés ? (`World of Warcraft/_classic_era_/BlizzardInterfaceCode/` ?)
- Quel est le contenu exact ? (fichiers .lua, .xml ? structure des répertoires ?)
- Est-ce que cette commande fonctionne en **Classic Era 1.15.x** ?
- Combien de fichiers ça génère environ ?
- Est-ce qu'on y trouve la définition de TOUTES les fonctions API accessibles en Lua, ou seulement le code de l'UI Blizzard ?
- Y a-t-il aussi une commande `/exportInterfaceFiles art` ? Que donne-t-elle ?

**Sources** : https://warcraft.wiki.gg/wiki/ExportInterfaceFiles ou équivalent

## 3. Méthodologie : comment dumper l'API depuis Lua in-game

Si je devais construire un addon qui explore l'API automatiquement, quelles sont les techniques possibles ?

### 3a. Dump des globales
```lua
for k, v in pairs(_G) do print(k, type(v)) end
```
- Ça liste-t-il vraiment TOUTES les fonctions/tables globales ?
- Y a-t-il des globales qui ne sont pas dans `_G` ?
- Comment distinguer les fonctions WoW des fonctions Lua standard ?

### 3b. Exploration des méthodes de widget
- Comment lister toutes les méthodes disponibles sur un objet Frame ? (Y a-t-il un equivalent `getmetatable(frame).__index` ?)
- Est-ce que les widgets WoW ont un `__methods` ou un mécanisme similaire ?
- Comment les projets existants font-ils pour lister les méthodes de chaque type de widget ?

### 3c. Événements
- Existe-t-il une liste complète des événements disponibles dans le client ?
- Certains projets utilisent-ils des techniques spéciales pour découvrir les événements ?

### 3d. Templates et Mixins
- Comment lister tous les templates XML disponibles ?
- Comment lister tous les Mixins définis dans le code FrameXML ?

## 4. Projets similaires dans d'autres écosystèmes

Existe-t-il des outils similaires pour d'autres jeux/modding qui pourraient inspirer notre approche ?
- Par exemple : des API dumpers pour d'autres MMOs, des outils d'introspection Lua, etc.

## 5. Limites et précautions

- Y a-t-il des fonctions/API qui sont **cachées** et ne sont pas découvrables par introspection Lua ?
- Y a-t-il des risques (ban, ToS violation) à utiliser `ExportInterfaceFiles` ou à explorer l'API systématiquement ?
- Est-ce que Blizzard a déjà changé ou restreint `ExportInterfaceFiles` ?
- Certaines API sont-elles "tainted" (secure/protected) et non appelables depuis un addon standard ?

---

**Rappel** : Toute la réponse doit être en **markdown inline** (un seul bloc). Fournis des **liens sources** pour chaque section. Merci !
