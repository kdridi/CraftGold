Développer un add-on pour l'Hôtel des Ventes en Classic Era est un vrai défi, surtout parce que nous sommes coincés avec l'ancienne API et ses caprices d'avant `C_AuctionHouse`. Tu as fait le bon diagnostic : pour un full scan, la clé est le paramètre `getAll = true`, mais il s'accompagne de contraintes strictes imposées par Blizzard.

Voici les réponses point par point, basées sur l'API héritée de Vanilla/TBC et le fonctionnement actuel du client Classic Era.

### 1. `getAll = true` — Comportement exact

* **Est-ce que ça retourne TOUTES les enchères ?** Oui. En appelant `QueryAuctionItems("", nil, nil, 0, false, nil, true)`, le client demande au serveur de lui envoyer l'intégralité de la base de données de l'HdV actif en un seul bloc.
* **Que retourne `GetNumAuctionItems("list")` ?** Cette fonction retourne deux valeurs : `numBatchAuctions` (les enchères de la page courante) et `totalAuctions` (le total existant). Avec `getAll = true`, `numBatchAuctions` sera égal à `totalAuctions`.
* **Y a-t-il une pagination ?** Non. L'avantage du `getAll`, c'est que toute la notion de "page" disparaît. Tu reçois tout sur l'index 1 à N (où N peut dépasser 100 000).
* **Est-ce que `text = ""` est correct ?** Oui, une chaîne de caractères vide `""` (ou même `nil`) est la bonne méthode pour n'appliquer aucun filtre de nom.
* *Sources : [Vanilla WoW Archive - API QueryAuctionItems*](https://vanilla-wow-archive.fandom.com/wiki/API_QueryAuctionItems)

### 2. `CanSendAuctionQuery()` — Retour exact

* **Combien de valeurs retourne-t-elle ?** Elle retourne **deux** valeurs booléennes : `canQuery` et `canQueryAll`.
* **`canQueryAll` existe-t-il en Classic Era ?** Absolument. Cette mécanique a été introduite initialement au patch 2.3 et a été conservée dans le client moderne de Classic Era (basé sur le moteur Retail).
* **Comment vérifier ?** Il suffit de faire `local canQuery, canQueryAll = CanSendAuctionQuery()`. Si `canQueryAll` est `true`, le serveur autorise le full scan.
* *Sources : [Wowpedia - CanSendAuctionQuery](https://wowpedia.fandom.com/wiki/API_CanSendAuctionQuery) | [Wowpedia - Patch 2.3 API Changes*](https://wowpedia.fandom.com/wiki/Patch_2.3.0/API_changes)

### 3. Cooldown du full scan

* **Quel est le cooldown exact ?** Le temps de recharge entre deux requêtes `getAll = true` est de **15 minutes** très exactes.
* **Par personnage ou par compte ?** La restriction est appliquée **côté serveur, par compte et par royaume**. Te déconnecter pour passer sur un reroll (alt) ne réinitialisera pas ce timer de 15 minutes.
* *Sources : [AddOn Studio - API QueryAuctionItems*](https://addonstudio.org/wiki/WoW:API_QueryAuctionItems)

### 4. Limitations et pièges

* **La limite de résultats :** Il n'y a pas de limite logicielle codée en dur, mais sur les méga-serveurs (comme le cluster Firemaw EU), l'HdV peut contenir plus de 100 000 entrées.
* **Risque de déconnexion :** C'est le danger numéro un. Demander un getAll déclenche l'envoi d'un énorme paquet de données serveur vers client. Les joueurs avec une connexion instable ou un faible débit peuvent subir une déconnexion immédiate (`WOW51900319`).
* **Le piège du Timeout Lua (Client Freeze) :** Si tu fais un `for i=1, 100000 do GetAuctionItemInfo("list", i) end` dans la même *frame*, le jeu va freeze complètement pendant plusieurs secondes. Si l'exécution dépasse une certaine limite de temps, WoW va crasher l'add-on ("Script ran too long").
* **Pattern recommandé :** Les add-ons majeurs contournent ce freeze en utilisant des **coroutines** ou un gestionnaire `OnUpdate` pour fractionner la lecture. Par exemple, ils lisent 2 000 enchères par frame (`yield`), laissent le jeu s'afficher, puis reprennent à l'enchère 2 001 à la frame suivante.

### 5. Exemple de code complet minimal

Voici un pattern fonctionnel. Pour faire simple ici, on ne met pas de coroutine complexe, mais l'architecture de base (check -> query -> event -> parse) est là.

```lua
local frame = CreateFrame("Frame")
local isScanning = false

-- Notre base de données résultante
CraftGoldDB_AH = {} 

frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "AUCTION_ITEM_LIST_UPDATE" and isScanning then
        -- L'event peut se déclencher deux fois : une fois quand la liste se vide, une fois pleine.
        local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
        
        -- Si totalAuctions est 0, c'est que les données arrivent encore (clear initial)
        if totalAuctions > 0 and numBatchAuctions == totalAuctions then
            print("CraftGold: Téléchargement HdV terminé. Parsing de " .. totalAuctions .. " items...")
            
            -- /!\ ATTENTION /!\ 
            -- Sur un très gros HdV, ce for d'un bloc fera un micro-freeze.
            -- En prod, il faudra le fractionner avec une coroutine ou un OnUpdate.
            for i = 1, totalAuctions do
                local name, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
                
                if itemID and buyoutPrice > 0 then
                    if not CraftGoldDB_AH[itemID] then
                        CraftGoldDB_AH[itemID] = {}
                    end
                    table.insert(CraftGoldDB_AH[itemID], {
                        c = count,
                        b = buyoutPrice
                    })
                end
            end
            
            print("CraftGold: Scan terminé avec succès !")
            isScanning = false
        end
    end
end)

function CraftGold_StartFullScan()
    local canQuery, canQueryAll = CanSendAuctionQuery()
    
    if canQueryAll then
        print("CraftGold: Début du full scan (GetAll)...")
        isScanning = true
        -- Lancement de la requête magique
        QueryAuctionItems("", nil, nil, 0, false, nil, true)
    else
        print("CraftGold: Scan impossible. Tu dois attendre le cooldown de 15 minutes.")
    end
end

-- Pour tester ingame : /run CraftGold_StartFullScan()

```

### 6. Comment procède Auctionator Classic ?

* **Documentation et Code Source :** Le code source est totalement public sur GitHub ([repo de l'organisation Auctionator](https://github.com/Auctionator/Auctionator)).
* **Méthode utilisée :** Ils utilisent exactement l'appel `QueryAuctionItems("", nil, nil, 0, false, nil, true)` (le `true` en 7e position).
* **Gestion du cooldown :** Auctionator gère cela dans son interface utilisateur. L'add-on enregistre le `GetTime()` du moment du scan. Le bouton "Full Scan" dans l'onglet Auctionator est ensuite "grisé" (désactivé visuellement) et le compte à rebours est affiché en temps réel. En coulisses, il boucle en continu sur `CanSendAuctionQuery()` dans un `OnUpdate` pour savoir exactement quand réactiver le bouton au terme des 15 minutes.
* **Gestion des performances :** Pour éviter que le jeu ne freeze en parsant les 100 000 objets, Auctionator implémente un système asynchrone (un parseur chunk par chunk dans des handlers `OnUpdate`) qui distribue la charge de travail sur plusieurs dizaines de secondes si nécessaire.