# Recherche — Capsule 02 : Slash Commands

*Date : 2026-06-10*

---

## ⚠️ Instructions de format (OBLIGATOIRE)

- Fais une **vraie recherche sur internet** pour répondre. Ne te fie pas uniquement à tes connaissances d'entraînement.
- **Source chaque affirmation** avec un lien URL (wowpedia, warcraft.wiki.gg, wowprogramming.com, forums WoW, GitHub d'add-ons, etc.).
- Écris ta **réponse complète en markdown dans un seul bloc**. Ne crée aucun fichier séparé, aucun artifact, aucune pièce jointe. Tout le code et les exemples doivent être inline dans ta réponse.

---

Je crée un add-on WoW Classic Era (version 1.15.x, interface 11508). J'ai besoin de comprendre le système de slash commands personnalisées. Réponds aux questions suivantes avec précision, en citant des sources si possible.

## 1. Enregistrement d'une slash command

- Comment définit-on les aliases ? Est-ce bien via des globals `SLASH_<NAME>1 = "/monalias"` ?
- Comment enregistre-t-on le handler ? Est-ce `SlashCmdList["MONNAME"] = handler` ?
- La convention de nommage (MAJUSCULES pour la clé SlashCmdList) est-elle obligatoire ou conventionnelle ?
- Peut-on définir autant d'aliases qu'on veut (`SLASH_*1`, `SLASH_*2`, `SLASH_*3`...) ?
- Que se passe-t-il si un alias entre en conflit avec une commande WoW native ?

## 2. Signature du handler

- Quels sont les paramètres exacts du handler ? `(msg, editBox)` ?
- `msg` est-il trimé ? Peut-il être `""` ? `nil` ?
- `editBox` est-il toujours présent ? Quel type de widget ?
- Comment distinguer `/ha` de `/ha test argument` dans le handler ?

## 3. Parsing d'arguments

- Quelles fonctions sont disponibles en WoW Lua pour split une string ? `strsplit` existe-t-il en Classic Era ?
- Comment gère-t-on les sous-commandes typiques : `/ha help`, `/ha status`, `/ha do something here` ?
- Montre un pattern de parsing robuste utilisé par des add-ons connus (avec lien source).

## 4. Chat coloré

- Quel est le format exact pour colorer du texte ? `|cFFRRGGBBtexte|r` ?
- Comment afficher un message coloré dans le chat ? `print()` supporte-t-il les codes couleur ?
- Existe-t-il `DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)` en Classic Era ?
- Quelle est la différence entre `print()` et `DEFAULT_CHAT_FRAME:AddMessage()` ?
- Comment les add-ons affichent-ils typiquement un préfixe coloré genre `[MonAddon] Message normal` ?

## 5. Exemple complet

Fournis un exemple minimal mais complet d'un add-on avec :
- Un fichier .toc
- Un fichier .lua qui enregistre `/helloazeroth` et `/ha`
- Le handler parse les arguments (supporte "help" et un message libre)
- Affiche `[HelloAzeroth]` en couleur suivi du message
- Gère le cas où aucun argument n'est fourni

⚠️ Tout le code doit être inline en markdown dans ta réponse. Pas de fichiers séparés.

## 6. Différences Classic Era vs Retail

Y a-t-il des différences dans le système de slash commands entre Classic Era et Retail ? Des fonctions retirées ou modifiées ?
