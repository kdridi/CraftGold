Recherche faite. Voici les réponses, dans l'ordre de tes questions.

## 1. Le pattern recommandé : `Item:CreateFromItemID(id):ContinueOnItemLoad(callback)` + compteur

C'est exactement ce que fait **Auctionator** dans son full scan Classic. Dans `Source_Classic/FullScan/Mixins/Frame.lua`, quand un listing n'a pas encore de lien d'item, Auctionator vérifie d'abord `C_Item.GetItemInfoInstant(itemID)` (pour écarter les IDs invalides), puis crée un objet `Item:CreateFromItemID(itemID)` et enregistre un callback via `item:ContinueOnItemLoad(...)`, en décrémentant un compteur `self.waitingForData` au fur et à mesure. Quand le compteur tombe à zéro, le traitement continue. C'est précisément le pattern `preloadItems(ids, callback)` que tu veux.

Source : https://github.com/Auctionator/Auctionator/blob/master/Source_Classic/FullScan/Mixins/Frame.lua (le dossier `Source_Classic` cible les clients Classic, dont Era).

`ItemMixin` et `ContinueOnItemLoad` sont bien disponibles en Classic Era 1.15.x — le mixin vit dans `Blizzard_ObjectAPI/Item.lua`, présent dans le FrameXML des clients Classic. Sous le capot, `ContinueOnItemLoad` appelle lui-même `C_Item.RequestLoadItemDataByID` et écoute `ITEM_DATA_LOAD_RESULT` via `AsyncCallbackSystem` — tu n'as donc pas à gérer l'événement toi-même.

**Piège important** : pour certains itemIDs, `C_Item.DoesItemExistByID` retourne `true` mais `ITEM_DATA_LOAD_RESULT` arrive avec `success:false` et `GetItemInfo` ne retournera jamais rien — dans ce cas `ContinueOnItemLoad` ne déclenche jamais le callback. Le contournement est d'utiliser `ContinueWithCancelOnItemLoad` avec un timeout, ou d'écouter directement `ITEM_DATA_LOAD_RESULT`. Pour un batch de 130 items, un seul ID pourri bloquerait ton callback final → il faut un timeout de sécurité.

## 2. `RequestLoadItemDataByID` + `GetItemInfo` immédiat : non

Le retry dans le même tick ne marche pas, et ce n'est pas un bug de ton code : `RequestLoadItemDataByID` demande les données et déclenche `ITEM_DATA_LOAD_RESULT` — c'est un mécanisme événementiel, jamais garanti synchrone, même quand les données sont dans les DB2 locaux. En pratique en Era le résultat arrive typiquement au frame suivant (quelques ms), mais il faut attendre l'événement ou le callback, pas re-poller dans la même exécution. La fonction est confirmée présente en client vanilla 1.15.8 (ajoutée côté Classic en 1.13.2).

Donc : pas de méthode synchrone fiable (question 3). Le bon modèle mental est "quasi-instantané mais asynchrone d'au moins un frame". Ton `Scanner.scan` doit devenir asynchrone, ou être appelé seulement après le preload.

## 3. Le hack historique des liens (question 4)

Coller un lien dans le chat force le chargement parce que le client, pour *afficher* le lien (couleur, nom), doit résoudre l'item — c'est le rendu qui déclenche la requête de cache, pas la chaîne elle-même. Créer une string `"item:12345"` en Lua ne charge rien. L'ancien hack des add-ons vanilla/early-Classic était `GameTooltip:SetHyperlink("item:"..itemID)` sur un tooltip caché : poser le tooltip force la résolution de l'item. Ça marche encore, mais c'est obsolète depuis que `RequestLoadItemDataByID` / `ContinueOnItemLoad` existent — ne l'utilise que si tu veux supporter des clients très anciens.

## 4. Implémentation complète de `preloadItems`

Le pattern Auctionator, adapté à ta liste d'IDs, avec timeout de sécurité :

```lua
-- Précharge une liste d'itemIDs dans le cache client.
-- callback(loaded, failed) est appelé quand tout est résolu (ou timeout).
function ns.preloadItems(itemIDs, callback, timeoutSeconds)
    timeoutSeconds = timeoutSeconds or 5
    local pending = 0
    local loaded, failed = {}, {}
    local finished = false

    local function checkDone()
        if not finished and pending == 0 then
            finished = true
            callback(loaded, failed)
        end
    end

    for _, itemID in ipairs(itemIDs) do
        if GetItemInfo(itemID) then
            -- Déjà en cache, rien à faire
            table.insert(loaded, itemID)
        elseif not C_Item.DoesItemExistByID(itemID) then
            -- ID invalide : ContinueOnItemLoad ne se déclencherait jamais
            table.insert(failed, itemID)
        else
            pending = pending + 1
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                if finished then return end
                table.insert(loaded, itemID)
                pending = pending - 1
                checkDone()
            end)
        end
    end

    checkDone() -- cas où tout était déjà en cache

    -- Filet de sécurité : certains IDs "existent" mais ne chargent jamais
    if pending > 0 then
        C_Timer.After(timeoutSeconds, function()
            if not finished then
                finished = true
                callback(loaded, failed) -- les non-chargés sont simplement absents de loaded
            end
        end)
    end
end
```

Notes d'intégration pour CraftGold :

- Le `GetItemInfo(itemID)` en première ligne évite de créer 130 objets Item si la plupart sont déjà en cache (deuxième session, etc.).
- En Era, pour 130 items, tout se résout généralement en 1-2 frames — le preload est imperceptible pour le joueur.
- Garde quand même ton message d'erreur actuel comme fallback dans `Scanner.scan`, mais après le preload il ne devrait quasiment plus se déclencher.
- Si tu veux être plus robuste sur les IDs zombies, remplace `ContinueOnItemLoad` par `item:ContinueWithCancelOnItemLoad(...)` et annule au timeout — disponible aussi via le mixin.

Sur tes autres pistes : TSM a bien son propre système (un module `ItemInfo` avec une file d'attente qui poll par batch sur OnUpdate + `GET_ITEM_INFO_RECEIVED`), mais c'est beaucoup plus lourd parce qu'il gère des dizaines de milliers d'items et son propre cache persistant — surdimensionné pour 130 items. Baganator/AdiBags s'appuient eux aussi sur le mixin Item pour les items non cachés. Le pattern Auctionator ci-dessus est le standard moderne et le bon choix ici.