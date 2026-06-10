# 01 — Hello Azeroth

| Métadonnée    | Valeur                                                      |
|---------------|------------------------------------------------------------|
| Phase         | Phase 1                                                    |
| Durée         | 20 min                                                     |
| Difficulté    | ●○○○○ (1/5)                                               |
| Prérequis     | Aucun                                                      |
| Type          | Autonome                                                   |
| Concepts      | `.toc`, `.lua`, `print()`, événements, varargs, `/reload` |

## Pourquoi cette capsule ?

> Tu viens d'installer World of Warcraft Classic Era. Tu entends parler d'add-ons, ces petits programmes qui modifient l'interface du jeu. Des trucs comme Questie, DBM, AtlasLoot… Mais comment ça marche ? Comment WoW les charge ? Tu ouvres le dossier `Interface/AddOns/` et tu y vois des dossiers mystérieux avec des `.toc` et des `.lua`.
>
> Cette capsule, c'est ton premier pas. On va créer le plus petit add-on possible : un dossier, deux fichiers, une ligne de code. Et quand tu vas lancer le jeu, tu verras ton propre message apparaître dans le chat. Ce moment où ton code s'exécute dans Azeroth, c'est magique — et c'est le fondement de tout le reste.
>
> **Le piège principal** : WoW est très silencieux quand quelque chose va mal. Si le dossier est mal nommé, le `.toc` est absent, ou l'encodage est mauvais, l'add-on n'apparaît tout simplement pas. Pas de message d'erreur, rien.

## Objectifs

À la fin de cette capsule, tu sauras :

1. **Créer** un fichier `.toc` valide que WoW reconnaît comme un add-on
2. **Écrire** un script Lua basique qui s'exécute au chargement de l'add-on
3. **Comprendre** le cycle de chargement : top-level vs événements
4. **Utiliser** `/reload` pour tester les changements sans redémarrer le jeu

## Fonctions API utilisées

| Fonction | Rôle |
|----------|------|
| `print(...)` | Affiche un message dans le chat |
| `CreateFrame("Frame")` | Crée un widget UI invisible (conteneur pour événements) |
| `frame:RegisterEvent(name)` | Abonne la frame à un événement WoW |
| `frame:SetScript("OnEvent", fn)` | Définit le callback quand un événement se déclenche |

→ Voir `docs/wow-api-functions.md` pour la documentation complète.

## Concepts clés

### Le fichier `.toc` — La carte d'identité de l'add-on

```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on
## Author: CraftGold

HelloAzeroth.lua
```

- `## Interface: 11508` — la version de l'API UI de WoW Classic Era (1.15.8, vérifier en jeu avec `/dump select(4, GetBuildInfo())`)
- `## Title` — le nom affiché dans la liste des add-ons
- Les fichiers listés en bas sont chargés **dans l'ordre** par WoW
- ⚠️ Le nom du fichier `.toc` doit **exactement correspondre** au nom du dossier

### Le vararg `...` — Comment WoW communique avec ton code

Quand WoW charge un fichier `.lua`, il lui passe automatiquement 2 arguments :

```lua
local addonName, ns = ...
-- addonName = "HelloAzeroth" (string, passé par WoW)
-- ns        = {} (table vide, partagée uniquement entre les fichiers de cet add-on)
```

`ns` sert de **namespace privé** entre les fichiers `.lua` d'un même add-on. Chaque fichier peut y lire et écrire. C'est l'alternative propre aux variables globales.

### La frame événementielle — Le pattern de base

```lua
local frame = CreateFrame("Frame")       -- widget invisible
frame:RegisterEvent("PLAYER_LOGIN")      -- écoute cet événement
frame:SetScript("OnEvent", function(self, event, ...)
    -- event = "PLAYER_LOGIN" quand il se déclenche
end)
```

Un seul `SetScript("OnEvent", ...)` gère **tous** les événements enregistrés sur la frame. Le 2e argument du callback contient le nom de l'événement qui s'est déclenché.

### `/reload` — Le meilleur ami du développeur

- Tape `/reload` dans le chat pour recharger toute l'UI
- Tous les add-ons sont rechargés depuis le disque
- Détecte même les **nouveaux** dossiers d'add-ons (vérifié en Session 2)
- Équivalent à redémarrer l'UI sans déconnecter

## Exécution

1. Le dossier de l'add-on doit être dans `Interface/AddOns/HelloAzeroth/`
2. Y placer `HelloAzeroth.toc` et `HelloAzeroth.lua`
3. Lancer WoW (ou taper `/reload` si déjà en jeu)
4. Vérifier le chat pour les messages
5. Vérifier dans Échap → Menu principal → Add-ons que « Hello Azeroth » apparaît

## Résultat attendu

```
[HelloAzeroth] addonName = HelloAzeroth
[HelloAzeroth] ns =
{}
[HelloAzeroth] Event received: PLAYER_LOGIN
[HelloAzeroth] Hello Azeroth! The add-on has loaded successfully.
```

## Déroulement réel (Phase B)

### Ce qu'on a testé

1. **Premier test** — Affichage d'un `print()` top-level + d'un `print()` dans `PLAYER_LOGIN` → les deux visibles ✅
2. **Deuxième test** — Ajout de `DumpTable(ns)` pour inspecter le namespace → table vide `{}` comme prévu
3. **Troisième test** — Modification du handler pour afficher le nom de l'événement reçu → `"PLAYER_LOGIN"` ✅

### Questions résolues en jeu

| Question | Réponse |
|----------|---------|
| `/reload` détecte-t-il les nouveaux dossiers ? | ✅ Oui |
| Chemin vers la liste des add-ons | Échap → Menu principal → « Add-ons » |
| Version de l'interface | 11508 |
| `print()` top-level visible ? | ✅ Oui (du moins avec `/reload`) |

### Pièges rencontrés

Aucun piège — tout s'est passé comme prévu. Le symlink fonctionne parfaitement pour le workflow de dev.

### Apprentissages clés

- Le vararg `...` n'est pas de la magie — WoW passe les arguments au fichier `.lua` comme un appel de fonction
- `ns` est vide tant qu'on n'y met rien — c'est normal avec un seul fichier
- `SetScript("OnEvent", ...)` prend un **script type** (`"OnEvent"`), pas un nom d'événement WoW — c'est le handler qui reçoit le nom de l'événement

## Pour aller plus loin

- → Prochaine capsule : **02 — Slash Commands**
