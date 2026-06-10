# Réponse Gemini — Capsule 02 : Slash Commands

*Coller la réponse de Gemini ci-dessous*

---

Voici une réponse détaillée à tes questions concernant la création de commandes personnalisées (slash commands) pour un add-on WoW Classic Era (1.15.x), basée sur la documentation officielle et communautaire du jeu.

## 1. Enregistrement d'une slash command

* **Définition des aliases :** Oui, la méthode standard consiste à déclarer des variables globales en utilisant le préfixe `SLASH_` suivi de la clé de ta commande et d'un chiffre incrémental. Par exemple : `SLASH_MONADDON1 = "/monalias"`.
* **Enregistrement du handler :** La fonction qui gère la commande (le handler) est ensuite affectée à la table globale `SlashCmdList` avec la même clé : `SlashCmdList["MONADDON"] = maFonctionHandler`.
* **Convention de nommage (Majuscules) :** Utiliser des MAJUSCULES pour la clé (ex: `MONADDON`) est une **convention historique et fortement recommandée** en Lua WoW, mais pas une obligation absolue du moteur. Cela permet d'éviter la collision de noms dans l'espace global, et assure une consistance entre `SLASH_NOM1` et `SlashCmdList["NOM"]`.
* **Nombre d'aliases :** Tu peux définir autant d'aliases que tu le souhaites. Il suffit d'incrémenter le numéro final : `SLASH_MONADDON1 = "/cmd"`, `SLASH_MONADDON2 = "/macmd"`, `SLASH_MONADDON3 = "/c"`, etc. Le client parcourt séquentiellement ces variables lors de l'initialisation.
* **Conflit avec une commande native :** Si tu utilises un alias qui est déjà pris par WoW (comme `/s` ou `/cast`), ton add-on entrera en conflit. Dans le meilleur des cas, la commande de l'add-on silenciera l'autre, mais dans la plupart des cas concernant les commandes protégées, le client WoW donnera la priorité au client natif ou crachera une erreur d'Interface (Action bloquée). Il est primordial de vérifier que ton alias est unique.

*(Sources : [Wowpedia - Creating a slash command](https://wowpedia.fandom.com/wiki/Creating_a_slash_command), [Wowpedia - GetSlashFunc](https://wowpedia.fandom.com/wiki/GetSlashFunc))*

---

## 2. Signature du handler

* **Paramètres exacts :** La fonction que tu enregistres reçoit toujours deux paramètres par le client du jeu : `function(msg, editBox)`.
* **État de la variable `msg` :** `msg` correspond à tout le texte tapé *après* la commande et le premier espace.
* `msg` n'est **jamais** `nil`.
* Si l'utilisateur tape juste `/ha` (sans espace ni texte), `msg` sera une chaîne vide `""`.
* Le client *trim* généralement l'espace situé juste après le nom de la commande, mais le texte interne reste tel quel.


* **Le paramètre `editBox` :** Il est toujours présent. Il s'agit d'une référence au widget (objet UI) de type `EditBox` à partir duquel l'utilisateur a envoyé la commande (presque toujours `ChatFrame1EditBox`, l'UI par défaut de saisie du chat). C'est très utile si tu veux manipuler l'interface de saisie en retour.
* **Distinguer `/ha` de `/ha test argument` :** Dans le premier cas, `msg == ""`. Dans le second, `msg == "test argument"`. C'est à toi d'analyser la chaîne `msg` dans ta fonction pour déterminer ce que l'utilisateur a demandé.

---

## 3. Parsing d'arguments

* **Séparer une chaîne (Split) :** L'API Lua de WoW inclut nativement une fonction très pratique nommée `strsplit(delimiter, string)`. Elle est totalement disponible dans Classic Era.
* **Gestion des sous-commandes :** La méthode la plus classique pour diviser une commande comme `/ha do something` consiste à découper le premier mot de `msg`, le convertir en minuscules (pour être insensible à la casse), puis à évaluer la suite avec une série de conditions `if / elseif`.
* **Pattern robuste :** De nombreux add-ons de renom utilisent `string.lower` et `strsplit`. Cependant, pour extraire facilement le premier mot de commande et garder le "reste" entier sans tronquer d'espaces potentiellement utiles, on utilise souvent l'API Lua de pattern matching :
```lua
local command, rest = msg:match("^(%S*)%s*(.-)$")
-- %S* prend le premier bloc de caractères non-espacés
-- %s* ignore les espaces entre les deux
-- .- capture tout le reste jusqu'à la fin ($)

```



*(Source : [Wowpedia - API strsplit](https://wowpedia.fandom.com/wiki/API_strsplit))*

---

## 4. Chat coloré

* **Format UI escape :** Le moteur de WoW utilise une syntaxe spécifique pour la couleur en ligne (UI Escape Sequences) qui est : `|cFFRRGGBBTexte|r`.
* `|c` démarre la séquence de couleur.
* `FF` représente la valeur Alpha (opacité) en hexadécimal (toujours `FF` pour opaque dans le chat).
* `RRGGBB` sont les composantes Rouge, Vert, Bleu en hexadécimal.
* `|r` restaure la couleur par défaut.


* **Affichage avec `print()` :** Oui, la fonction globale `print()` supporte parfaitement les codes couleurs. `print("|cFF00FF00Coucou|r")` affichera un message vert dans la fenêtre de chat par défaut.
* **L'API `DEFAULT_CHAT_FRAME:AddMessage` :** Elle est bien disponible en Classic Era. La signature complète est `DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b, id, addToStart)`.
* **Différence entre les deux :**
* `print(...)` est une fonction "wrapper" de haut niveau. Elle accepte de multiples arguments, les convertit en chaînes (tostring), les sépare par un espace, et envoie finalement le résultat à la ChatFrame sélectionnée par défaut.
* `DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)` est la méthode de bas niveau directement liée au widget `ScrollingMessageFrame`. Elle te permet de passer un texte unique et d'utiliser des paramètres numériques (0.0 à 1.0) pour forcer la couleur de toute la ligne sans avoir à insérer manuellement le code `|cFF...|r` au sein de la string.


* **Convention de préfixe pour add-on :** Les développeurs préfixent souvent leurs affichages pour que l'utilisateur sache d'où vient le message. L'usage typique est : `print("|cFF00FFFF[HelloAzeroth]|r " .. msg)`.

*(Sources : [Wowpedia - UI escape sequences](https://wowpedia.fandom.com/wiki/UI_escape_sequences), [Wowpedia - ScrollingMessageFrame:AddMessage](https://wowpedia.fandom.com/wiki/API_ScrollingMessageFrame_AddMessage))*

---

## 5. Exemple complet

Voici l'architecture complète incluant le fichier TOC et le script Lua inline, fonctionnant pour WoW Classic Era.

**Fichier : `HelloAzeroth.toc**`

```text
## Interface: 11508
## Title: HelloAzeroth
## Notes: Un add-on d'exemple pour tester les slash commands
## Author: Toi
## Version: 1.0

HelloAzeroth.lua

```

**Fichier : `HelloAzeroth.lua**`

```lua
-- Préfixe coloré utilisé par toutes les annonces de l'add-on (Bleu clair/Cyan)
local PREFIX = "|cFF00FFFF[HelloAzeroth]|r"

-- Fonction utilitaire pour envoyer un message formaté
local function ChatMsg(texte)
    -- print s'occupe de router vers DEFAULT_CHAT_FRAME
    print(PREFIX .. " " .. texte)
end

-- La fonction handler pour notre slash command
local function HelloAzeroth_Command(msg, editBox)
    -- Si l'utilisateur n'a tapé aucun argument, msg vaut ""
    if msg == "" then
        ChatMsg("Bienvenue ! Tape |cFFFFFF00/ha help|r pour voir les options.")
        return
    end

    -- Parsing robuste : on sépare la sous-commande du reste du message
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    -- On convertit en minuscules pour traiter "/ha HELP" comme "/ha help"
    command = string.lower(command)

    -- Traitement des sous-commandes
    if command == "help" then
        ChatMsg("Options disponibles :")
        print("  |cFFFFFF00/ha help|r - Affiche ce menu.")
        print("  |cFFFFFF00/ha status|r - Affiche l'état de l'add-on.")
        print("  |cFFFFFF00/ha echo <texte>|r - Répète votre message.")
        
    elseif command == "status" then
        -- Affichage natif en couleur jaune utilisant l'API widget (R, G, B allant de 0 à 1)
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " Le système est opérationnel.", 1.0, 1.0, 0.0)
        
    elseif command == "echo" then
        if rest and rest ~= "" then
            ChatMsg("Vous avez dit : " .. rest)
        else
            ChatMsg("Erreur: Vous devez fournir un texte. Ex: |cFFFFFF00/ha echo bonjour|r")
        end
        
    else
        ChatMsg("Commande inconnue : " .. command)
    end
end

-- Déclaration des variables globales d'aliases
SLASH_HELLOAZEROTH1 = "/helloazeroth"
SLASH_HELLOAZEROTH2 = "/ha"

-- Affectation du handler dans le dictionnaire global des macros/chat du client
SlashCmdList["HELLOAZEROTH"] = HelloAzeroth_Command

-- Petit message discret au chargement
ChatMsg("Add-on chargé (v1.0).")

```

---

## 6. Différences Classic Era vs Retail

Concernant spécifiquement le **système de slash commands, le chat et le traitement des chaînes de caractères**, il n'y a **absolument aucune différence** technique entre Classic Era (1.15.x) et Retail (10.x/11.x).

Pourquoi ? Parce que les projets Classic (Era, Progression, SoD) tournent en réalité sur le même moteur client moderne que Retail (ce qu'on appelle "modern engine"). Blizzard a backporté les données Vanilla sur l'architecture client récente. Les fonctions comme `strsplit`, `SlashCmdList`, `DEFAULT_CHAT_FRAME` ou `print()` réagissent de manière totalement identique.

La distinction de l'API Classic Era vs Retail se fait presque exclusivement sur :

1. Les fonctions qui touchent au gameplay et qui ont été intentionnellement "bridées" (protection des fonctions de ciblage, suppression de certaines infos en combat, restriction du calcul de distance pour les heals, API des cartes).
2. Les systèmes n'existant pas dans Classic (Transmogrification, batailles de mascottes, donjons mythiques+, etc.).

*(Source des différences globales API : discussions communautaires d'Addon dev et [Reddit - Add-on framework differences](https://www.reddit.com/r/classicwow/comments/d29kwg/how_different_is_the_addon_framework_for_classic/))*