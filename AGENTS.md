# Consignes Agent — CraftGold

## Contexte du projet

**CraftGold** est un add-on World of Warcraft Classic Era (focus initial : Ingénierie) qui poursuit deux objectifs :

1. **Monter un métier au moindre coût** — Déterminer les crafts optimaux et les matériaux les moins chers pour monter de 1 à N
2. **Gagner de l'or en craftant** — Identifier les crafts rentables (achat de mats → fabrication → revente HdV)

Le cœur technique est un **calcul récursif des coûts** : pour chaque composant fabricable, on descend dans l'arbre et on choisit le chemin le moins cher entre acheter directement et fabriquer à partir de sous-composants.

Ce projet a un **double but** : produire un add-on fonctionnel ET apprendre à créer des add-ons WoW.

## Mode de travail — Protocole en 3 phases

### Phase A — Conception (on discute, zéro fichier)

On valide 6 points :

#### Étape 0 — Mise en scène (storytelling)

L'agent raconte la capsule en story simple : où on en est, quel problème on va rencontrer, ce qu'on va apprendre, pourquoi maintenant, à quoi ça servira plus tard. **La mise en scène atterrit dans le README** sous `## Why This Capsule?`.

#### Étapes 1-5 — Checklist technique

| Étape | Question |
|-------|----------|
| 1 | Objectifs observables (2-4 verbes d'action) |
| 2 | Critères de réussite (ce qu'on voit quand ça marche) |
| 3 | Prérequis & limites (frontière explicite) |
| 4 | Plan du code (sections du .lua dans l'ordre) |
| 5 | Plan du README (points à documenter) |

🔒 **Aucun fichier généré en Phase A.**

### Phase B — Exploration pas-à-pas (l'apprenant fait)

L'agent **guide** : « crée ce fichier avec ce contenu », « copie le dossier dans `Interface/AddOns/` », « `/reload` dans le chat, tape `/monaddon` ».

- L'apprenant exécute, observe, fait des retours
- Si ça ne marche pas comme prévu → on creuse, on ne rationalise pas, on corrige
- L'agent ne produit pas les fichiers — il guide pour que l'apprenant les crée

**Workflow de test :**
1. Copier le dossier capsule dans `Interface/AddOns/`
2. `/reload` en jeu (ou relancer WoW)
3. Vérifier dans Échap → Système → Addons
4. Tester le comportement
5. `/console scriptErrors 1` pour voir les erreurs Lua

### Phase C — Polissage (l'agent finalise)

1. Intégrer la mise en scène dans le README
2. Ajouter les commentaires pédagogiques dans le code (en anglais)
3. Reformater et organiser le code
4. Écrire le README reflétant le vrai vécu (pitfalls rencontrés, ordre réel des choses)
5. L'apprenant relit et valide

## Conventions linguistiques

| Élément | Langue |
|---|---|
| AGENTS.md, ROADMAP.md, README.md (racine) | 🇫🇷 Français |
| Nos discussions | 🇫🇷 Français |
| Code Lua (fonctions, variables, commentaires) | 🇬🇧 Anglais |
| Noms de fichiers et répertoires | 🇬🇧 Anglais |
| README.md des capsules | 🇬🇧 Anglais |

## Conventions techniques

- **WoW Classic Era** (version 1.15.x, interface ~11507)
- **Lua** + fichiers `.toc` — pas de build, pas de compilation
- Chaque capsule = un mini-add-on autonome avec son propre `.toc`
- Les capsules se testent en les copiant dans `Interface/AddOns/` + `/reload`
- Références API : [wowpedia.fandom.com](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API), [classic.wowhead.com](https://classic.wowhead.com/), [wowprogramming.com](https://wowprogramming.com/)

### Types de capsules

| Type | Définition |
|------|-----------|
| **Autonomous** | Pas besoin d'être connecté avec un personnage spécifique |
| **Semi-autonomous** | Nécessite d'être connecté en jeu |
| **Sequential** | Nécessite qu'une capsule précédente ait été comprise |

## Organisation filesystem

```
00-todo/     ← Capsules non commencées (squelettes README.md)
01-wip/      ← Capsule en cours (au plus une)
02-done/     ← Capsules terminées et validées
```

- **Prochaine capsule** = premier répertoire dans `00-todo/` (trié par numéro)
- **Capsule en cours** = contenu de `01-wip/`

### ⛔ `git mv` toujours, jamais `mv`

### Rituel de session

**🟢 Début de session :**
1. `ls 01-wip/` → capsule en cours ?
2. `ls 02-done/` → combien de terminées ?
3. `ls 00-todo/ | head -1` → prochaine
4. Comparer avec ROADMAP.md → filesystem = source de vérité

**🔴 Fin de session :**
1. Capsule validée → `git mv 01-wip/XX 02-done/` + commit
2. Capsule en cours → reste dans `01-wip/`
3. Mettre à jour ROADMAP.md (historique)
4. Vérifier cohérence

### Conventions de commit

- Un commit = un sujet
- Format : `type: description` (`feat:`, `docs:`, `chore:`)
- Commits de déplacement séparés du code
