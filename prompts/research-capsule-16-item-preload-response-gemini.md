C'est un problème classique (et très frustrant) du développement d'add-ons sur WoW. Bien que Classic Era utilise des fichiers DB2 locaux, le client C++ ne charge pas l'intégralité de la base de données en RAM au démarrage pour des raisons d'optimisation. Il faut explicitement lui demander d'extraire les données, ce qui nécessite de basculer dans un paradigme asynchrone.

Voici les réponses à vos recherches et la solution complète pour **CraftGold**.

---

### 1. Comment les add-ons existants gèrent-ils le preload d'items ?

Les gros add-ons modernes (Auctionator, TSM, Baganator) ne gèrent plus les requêtes asynchrones "à la main" avec l'événement `GET_ITEM_INFO_RECEIVED`. Depuis l'introduction du framework objet **ItemMixin** (qui a été backporté de Retail vers Classic Era 1.15.x), ils utilisent quasiment tous la méthode `ItemMixin:ContinueOnItemLoad()`.

* **Auctionator** : Utilise intensivement `Item:CreateFromItemID(id):ContinueOnItemLoad(callback)` pour s'assurer que les données sont en RAM avant de construire ses fenêtres de recherche ou de scan.
* **TSM (TradeSkillMaster)** : TSM a son propre sous-système massif (`TSM.ItemInfo`) qui effectue des chargements par batch au démarrage de l'add-on, mettant en file d'attente les requêtes avec des callbacks pour peupler sa propre base de données SQLite (via son application bureau) ou son cache Lua.
* **AdiBags / Baganator** : Lorsqu'ils trient l'inventaire, si un item n'est pas en cache, ils l'ajoutent à une file d'attente asynchrone et forcent un rafraîchissement visuel du sac quand le callback `ContinueOnItemLoad` est déclenché.

### 2. `RequestLoadItemDataByID` vs `ContinueOnItemLoad` — quel pattern utiliser ?

**Oubliez `RequestLoadItemDataByID` et utilisez `ContinueOnItemLoad`.**

* `RequestLoadItemDataByID(itemID)` est l'API bas niveau. Si vous l'utilisez, vous devez vous-même enregistrer l'événement `ITEM_DATA_LOAD_RESULT`, vérifier dans l'événement si l'ID correspond à celui que vous attendez, déclencher votre logique, puis désenregistrer l'événement. C'est lourd, surtout pour des batchs.
* **`ContinueOnItemLoad(callback)`** est une abstraction officielle fournie par Blizzard. En interne, elle appelle `RequestLoadItemDataByID` et gère les événements pour vous. Elle exécute simplement votre fonction quand les données sont prêtes. C'est le standard actuel.

### 3. Existe-t-il une méthode synchrone ?

**Non.** Même sur Classic Era où la base de données est sur votre SSD, l'extraction de la donnée DB2 vers le cache mémoire du client Lua nécessite un aller-retour avec le moteur C++ du jeu.

Un `GetItemInfo(itemID)` appelé dans la même "frame" d'exécution qu'une requête de chargement retournera toujours `nil`. Il faut absolument céder l'exécution (yield) et attendre la frame suivante (ou l'événement). C'est pour cela que votre code de retry synchrone échouait.

### 4. Comment fonctionnent les liens d'items dans le chat ?

Créer un string de lien d'item (`"\124cff0070dd\124Hitem:1234...\124h[Nom]\124h\124r"`) en Lua ne force **pas** le chargement.

Ce qui force le chargement, c'est quand ce string est passé à un élément de l'UI (comme afficher le lien dans la `ChatFrame` ou passer le lien à `GameTooltip:SetHyperlink()`). À ce moment-là, le code C++ de l'interface détecte que l'item n'est pas en cache, lance une requête silencieuse, et met l'élément UI en attente de redessin (redraw) dès que `GET_ITEM_INFO_RECEIVED` est déclenché. Les vieux add-ons trichaient en envoyant les IDs à un Tooltip invisible pour forcer la mise en cache, mais c'est aujourd'hui obsolète.

---

### La Solution : Le pattern de "Batch Preload" recommandé

Pour précharger 130 items avant de lancer le scan AH, nous allons créer un chargeur par lots.

**Attention au piège :** Si un `itemID` est invalide ou n'existe plus dans les fichiers du jeu, `ContinueOnItemLoad` risque de ne *jamais* se déclencher, ce qui bloquerait votre add-on infiniment. Il est donc indispensable d'implémenter un **Timeout** de sécurité.

Voici le code exact que vous pouvez intégrer à `CraftGold` :

```lua
local ns = select(2, ...) -- Assumant votre namespace d'add-on

-- Fonction utilitaire pour précharger un lot d'items
function ns.PreloadItems(itemIDs, onCompleteCallback, timeoutSeconds)
    local pending = 0
    local isDone = false
    timeoutSeconds = timeoutSeconds or 3 -- 3 secondes est largement suffisant en Classic

    -- Fonction appelée quand tout est fini (ou au timeout)
    local function checkDone()
        if isDone then return end
        if pending == 0 then
            isDone = true
            onCompleteCallback()
        end
    end

    for _, itemID in ipairs(itemIDs) do
        local item = Item:CreateFromItemID(itemID)
        
        -- Si l'item n'est pas déjà dans le cache local
        if not item:IsItemDataCached() then
            pending = pending + 1
            
            -- Demande asynchrone
            item:ContinueOnItemLoad(function()
                if isDone then return end
                pending = pending - 1
                checkDone()
            end)
        end
    end

    -- Si tous les items étaient DÉJÀ en cache, on termine immédiatement
    checkDone()

    -- Failsafe : Timeout au cas où un itemID fantôme bloque la file d'attente
    if not isDone then
        C_Timer.After(timeoutSeconds, function()
            if not isDone then
                isDone = true
                -- Optionnel: vous pouvez log un avertissement ici
                print("CraftGold: Attention, " .. pending .. " item(s) n'ont pas pu être chargés dans le temps imparti.")
                onCompleteCallback()
            end
        end)
    end
end

```

### Comment l'utiliser dans votre logique `Scanner.lua`

Au lieu de scanner l'AH un par un en tentant de charger le cache à la volée, vous wrappez votre logique de scan dans le callback du preloader :

```lua
function Scanner.startBatchScan(itemIDs)
    print("CraftGold: Préchargement des items en cours...")
    
    ns.PreloadItems(itemIDs, function()
        -- Ce bloc s'exécute quand TOUS les items sont en cache (ou après 3s)
        print("CraftGold: Préchargement terminé. Lancement des requêtes AH.")
        
        for _, itemID in ipairs(itemIDs) do
            local name = GetItemInfo(itemID)
            if name then
                -- Lancez votre requête AH ici
                -- QueryAuctionItems(name) ...
            else
                -- Si name est nil ici, c'est que l'itemID est probablement invalide
                -- ou que le timeout a expiré pour cet item précis.
            end
        end
    end)
end

```

### En résumé

Ce pattern est solide, ne freeze pas le client (car il est non-bloquant), utilise la dernière API Blizzard (`ItemMixin`), et vous protège contre les items corrompus grâce au timer.