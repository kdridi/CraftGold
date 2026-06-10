# Le fichier `.toc` — Manifeste d'add-on WoW

> Consolidé à partir des recherches ChatGPT, Claude et Gemini (Session 1).
> Voir `prompts/research-capsule-01-hello-azeroth-response-*.md` pour les réponses brutes.

---

## Qu'est-ce que c'est ?

Le fichier `.toc` (Table of Contents) est le **manifeste** qui indique à WoW comment reconnaître et charger votre add-on. Sans lui, votre dossier est invisible.

## Règles obligatoires

1. **Le nom du fichier doit correspondre au nom du dossier** — `HelloAzeroth/HelloAzeroth.toc`. S'ils diffèrent, WoW ignore silencieusement tout le dossier. C'est la cause #1 de « mon add-on n'apparaît pas ».
2. **Emplacement du fichier** — Doit être dans `_classic_era_/Interface/AddOns/VotreDossier/` (PAS `_retail_` ou `_classic_`)
3. **UTF-8 sans BOM** — Un BOM peut corrompre la première directive (surtout `## Interface:`)

## `.toc` minimal valide

```
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on

HelloAzeroth.lua
```

## Tous les champs disponibles

```toc
## Interface: 11508
## Title: Hello Azeroth
## Notes: My first WoW add-on
## Author: YourName
## Version: 1.0.0
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## Dependencies: SomeOtherAddon
## OptionalDeps: AnotherAddon
## DefaultState: enabled
## LoadOnDemand: 1

HelloAzeroth.lua
src\Utils.lua
```

### Détail des champs

| Champ | Rôle | Requis ? |
|-------|------|----------|
| `## Interface:` | Numéro de version du jeu. S'il ne correspond pas, l'add-on est marqué « out of date » | Pratiquement oui |
| `## Title:` | Nom affiché dans la liste des add-ons. Par défaut le nom du dossier si absent | Non |
| `## Notes:` | Texte de l'info-bulle au survol dans la liste des add-ons | Non |
| `## Author:` | Nom du créateur (informatif, affiché dans la liste) | Non |
| `## Version:` | Votre chaîne de version (informatif) | Non |
| `## SavedVariables:` | Variables globales persistées sur disque (tous les personnages) | Non |
| `## SavedVariablesPerCharacter:` | Variables persistées par personnage | Non |
| `## Dependencies:` | Add-ons qui DOIVENT se charger avant celui-ci | Non |
| `## OptionalDeps:` | Add-ons qui doivent se charger avant celui-ci s'ils sont présents | Non |
| `## DefaultState:` | `enabled` ou `disabled` à la première installation | Non |
| `## LoadOnDemand:` | `1` = ne pas charger au démarrage, charger via `LoadAddOn()` | Non |

## Version d'interface

Le numéro d'interface suit le pattern `majeur * 10000 + mineur * 100 + patch` :
- 1.15.4 → 11504
- 1.15.7 → 11507
- 1.15.8 → 11508

**Toujours vérifier en jeu** : `/dump select(4, GetBuildInfo())`

Si le numéro est plus ancien que le client, l'add-on est marqué « out of date » mais peut quand même se charger si l'utilisateur coche **« Load out of date AddOns »**.

## Liste des fichiers

- Les fichiers listés après les en-têtes `##` sont chargés **dans l'ordre**, de haut en bas
- Les sous-répertoires sont autorisés : `src\Core.lua` ou `modules\Utils.lua`
- Si un fichier listé n'existe pas, cette ligne est ignorée silencieusement
- Seuls les 1024 premiers caractères de chaque ligne sont lus

## Pièges courants

1. **Ne pas oublier `##`** avant les lignes de métadonnées. `Interface: 11508` sans `##` est traité comme un nom de fichier
2. **Ne pas indenter** les lignes de commentaires — un espace avant `#` fait que WoW la traite comme un nom de fichier
3. **Extensions cachées sur Windows** — Le fichier peut en réalité s'appeler `HelloAzeroth.toc.txt`
4. **Double imbrication** — L'extraction d'un ZIP crée `AddOns/HelloAzeroth/HelloAzeroth/HelloAzeroth.toc` (un dossier de trop)
5. **Sensibilité à la casse** — Garder le nom du dossier, du `.toc` et les références de fichiers cohérents (surtout multi-plateforme)

## Accéder aux métadonnées depuis le code

```lua
-- Récupérer n'importe quel champ ## de son propre add-on
local version = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Version")
local notes = C_AddOns.GetAddOnMetadata("HelloAzeroth", "Notes")
```
