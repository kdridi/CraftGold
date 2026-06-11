Voici une analyse complète de l'architecture de cache d'items sur WoW Classic Era et les raisons pour lesquelles vos tests avec `GetItemInfo` échouent à reproduire le comportement asynchrone.

Vous n'arrivez pas à forcer le retour `nil` pour une raison architecturale très simple : **la plupart des items n'ont plus besoin d'être mis en cache depuis le serveur, car ils sont déjà "en dur" dans les fichiers locaux de votre jeu**.

---

### 1. Architecture du cache d'items WoW (Classic Era)

Le client WoW Classic Era (1.15.x) n'utilise pas le vieux moteur de 2004. Il est basé sur l'architecture moderne du client Retail (introduite autour de Legion/BfA).

* **Où sont stockées les données ?** Contrairement à Vanilla (2004) où le fichier `Cache/WDB/itemcache.wdb` construisait la base de données au fur et à mesure que vous croisiez des items, le client moderne utilise le **système de fichiers CASC**. Les données statiques des items sont pré-compilées dans des bases de données locales en mémoire, principalement `Item.db2` et `ItemSparse.db2` *[(Source : Wowdev - DB2)](https://wowdev.wiki/DB2)*. Le dossier `WDB` ne sert aujourd'hui qu'aux *hotfixes* (modifications en direct par Blizzard) ou aux items générés dynamiquement.
* **Quand le client précharge-t-il les items ?** Ces fichiers `.db2` sont chargés **en mémoire vive (RAM) dès le lancement du jeu** (avant même la sélection de personnage).
* **Pour quels items ?** Sur Classic Era, le jeu étant statique (pas de procs "Titanforged" ou de clés Mythiques), **absolument tous les items de base du jeu existent dans ces DB2 locaux**.
* **Classic Era vs Retail :** Sur Retail, un même item peut exister sous des centaines de variations d'ilvl ou de stats (Bonus IDs). Le client Retail ne peut pas tout stocker en DB2 et doit interroger le serveur en permanence, ce qui rend l'async omniprésent. Sur Classic, l'ID d'un *Linen Cloth* (2592) ou d'une *Thunderfury* (19019) est unique, immuable et codé en dur.

### 2. GetItemInfo — Comportement exact

* **Quand retourne-t-elle `nil` ?** `GetItemInfo(itemID)` retourne `nil` **uniquement** si le client ne trouve l'item ni dans ses DB2 locaux, ni dans son cache WDB, et qu'il est contraint d'envoyer une requête (query) au serveur *[(Source : Warcraft Wiki - API GetItemInfo)](https://warcraft.wiki.gg/wiki/API_GetItemInfo)*.
* **Les items de base :** Oui, ils sont **toujours** en cache DB2. Supprimer votre dossier WDB est inutile pour ces items, car le client n'a pas besoin du WDB pour savoir ce qu'est une *Copper Bar*.
* **GetItemInfo vs GetItemInfoInstant :**
`GetItemInfoInstant(itemID)` ne lit **que** les fichiers DB2 locaux. Elle ne fera jamais de requête serveur et est 100% synchrone. En contrepartie, elle retourne moins d'informations (pas de nom localisé, pas de qualité, juste l'ID, le type, les textures, etc.) *[(Source : Warcraft Wiki - API GetItemInfoInstant)](https://warcraft.wiki.gg/wiki/API_GetItemInfoInstant)*.
* **Forcer l'oubli :** C'est impossible pour les items standard. Vous ne pouvez pas demander au client d'oublier ce qui est écrit en dur dans ses fichiers système.

### 3. GET_ITEM_INFO_RECEIVED — Déclencheurs réels

* **Conditions de déclenchement :** L'événement se déclenche quand le client reçoit enfin la réponse du serveur suite à un `GetItemInfo` qui avait retourné `nil` *[(Source : Warcraft Wiki - GET_ITEM_INFO_RECEIVED)](https://warcraft.wiki.gg/wiki/GET_ITEM_INFO_RECEIVED)*.
* **Exemples d'items qui retournent `nil` sur Classic :**
C'est extrêmement rare. Cela ne se produit généralement que pour :
1. Un item fraîchement ajouté via un patch/hotfix que votre client n'a pas encore téléchargé.
2. Les variantes d'items "Random Enchantment" (ex: *... of the Bear*, *... of the Eagle*) si l'ID d'item-link spécifique n'a pas encore été croisé, car le suffixe modifie les stats.


* **Est-ce pertinent en Classic Era ?** Très peu pour la navigation de base, mais **obligatoire** comme sécurité (fallback) dans le code d'un add-on au cas où le joueur subirait des latences de base de données ou croiserait des items générés aléatoirement.

### 4. Méthodes pour reproduire l'async en développement

Puisque vous ne pouvez pas effacer les DB2, vous avez deux solutions pour tester votre code asynchrone :

**Méthode A : Tester avec des ItemIDs fantômes/futurs (aléatoire)**
Essayez de requêter des items qui n'existent pas dans les fichiers de base de Classic Era mais dont le serveur pourrait "négativement" ou "tardivement" accuser réception.

* Exemple Retail : `190190` (un ID d'item Dragonflight/The War Within).
* *Note :* Le client risque de juste retourner un `nil` silencieux sans jamais déclencher l'événement si le serveur Classic rejette l'ID.

**Méthode B : Le "Mocking" (La vraie solution de développeur)**
Puisque l'état asynchrone dépend du moteur C++, la meilleure façon de tester l'UI de votre add-on est de simuler (mocker) la latence en Lua. Voici un snippet que vous pouvez utiliser pendant le développement de CraftGold :

```lua
local isDevMode = true
local mockCache = {}

local function SafeGetItemInfo(itemID)
    if not isDevMode then 
        return GetItemInfo(itemID) 
    end

    if mockCache[itemID] then
        return GetItemInfo(itemID) -- Retourne la vraie donnée au second appel
    else
        -- Simule un délai réseau de 2 secondes
        C_Timer.After(2.0, function()
            mockCache[itemID] = true
            -- Force manuellement le déclenchement de votre handler
            local myFrame = CraftGold_EventFrame -- Remplacez par votre frame
            myFrame:GetScript("OnEvent")(myFrame, "GET_ITEM_INFO_RECEIVED", itemID, true)
        end)
        return nil -- Force le comportement asynchrone initial
    end
end

```

### 5. Scénarios de production (pour CraftGold)

Dans la vraie vie de votre add-on, avec ~100+ recettes d'artisanat :

* **Fréquence des items non cachés :** Un joueur normal ne rencontrera **pratiquement jamais** de `nil` pour des composants de craft (Linen Cloth, Iron Ore) car ce sont des items primaires inclus dans les DB2.
* **Items susceptibles de ne pas être en cache :** Les seuls vrais coupables potentiels en Vanilla sont les links d'items avec statistiques aléatoires (suffix ID). Si votre add-on liste des crafts avec des stats fixes (comme la *Lionheart Helm*), ce sera instantané 100% du temps.
* **Personnages / Métiers :** Le cache n'est **absolument pas lié au personnage**. Il est lié à l'installation du jeu. Un nouveau personnage niveau 1 aura exactement le même accès instantané en mémoire aux composants de l'ingénierie niveau 300 qu'un personnage qui a monté la profession.