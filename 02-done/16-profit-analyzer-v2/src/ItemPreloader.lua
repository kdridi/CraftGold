-- src/ItemPreloader.lua
-- Batch preload item data into the client cache before AH scanning.
-- Uses Item:ContinueOnItemLoad() (Blizzard ObjectAPI, available in Classic Era 1.15.x).
-- Pattern sourced from Auctionator's full scan + consensus 4/4 LLM research.

local _, ns = ...

local ItemPreloader = {}
ns.ItemPreloader = ItemPreloader

-------------------------------------------------
-- Preload a list of itemIDs into the client cache.
-- callback(loaded, failed) is called when all items are resolved (or timeout).
-- loaded = number of items successfully cached
-- failed = number of items that could not be loaded
-------------------------------------------------
function ItemPreloader.preloadItems(itemIDs, callback, timeoutSeconds)
    timeoutSeconds = timeoutSeconds or 5

    local pending = 0
    local finished = false
    local loaded, failed = 0, 0

    local function checkDone()
        if not finished and pending == 0 then
            finished = true
            callback(loaded, failed)
        end
    end

    for _, itemID in ipairs(itemIDs) do
        -- Already cached? Skip.
        if GetItemInfo(itemID) then
            loaded = loaded + 1
        else
            pending = pending + 1
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                if finished then return end
                local name = GetItemInfo(itemID)
                if name then
                    loaded = loaded + 1
                else
                    failed = failed + 1
                end
                pending = pending - 1
                checkDone()
            end)
        end
    end

    -- All already cached — fire immediately
    checkDone()

    -- Safety timeout: some itemIDs never trigger ContinueOnItemLoad
    if pending > 0 then
        C_Timer.After(timeoutSeconds, function()
            if not finished then
                finished = true
                -- Count remaining as failed
                failed = failed + pending
                callback(loaded, failed)
            end
        end)
    end
end
