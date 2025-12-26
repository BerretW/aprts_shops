local QBCore = exports['qb-core']:GetCoreObject()
local Shops = {}

-- Načtení obchodů při startu
MySQL.ready(function()
    local result = MySQL.query.await('SELECT * FROM aprts_shops')
    if result then
        for _, v in pairs(result) do
            v.coords = json.decode(v.coords)
            v.products = v.products and json.decode(v.products) or {}
            
            -- NOVÉ: Načtení nastavení (pokud neexistuje, vytvoříme defaultní)
            v.settings = v.settings and json.decode(v.settings) or {
                blipSprite = 52,    -- Default ikona (obchod)
                blipColor = 2,      -- Default barva (zelená)
                blipScale = 0.8,
                openHour = 0,       -- Od
                closeHour = 24      -- Do
            }
            
            Shops[v.shop_id] = v
        end
    end
end)

-- Pomocné funkce
local function IsAdmin(source)
    return QBCore.Functions.HasPermission(source, Config.AdminGroup) or IsPlayerAceAllowed(source, 'command')
end

local function GetPlayerIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.citizenid or nil
end

local function GetPlayerName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or "Neznámý"
end

-- =============================================
-- CALLBACKS (Komunikace Client -> Server -> Data)
-- =============================================

-- Callback: Otevření Management Menu
-- Callback: Otevření Management Menu
RegisterCommand("getInventory", function(source, args, rawCommand)
    local src = source
    local inventoryData = {}
    
    -- HRÁČ: Načteme jeho inventář přes nativní OX funkci
    -- Zkusíme získat kompletní objekt inventáře
    local rawInventory = exports.ox_inventory:GetInventory(src)
    
    print(json.encode(rawInventory, { indent = true })) -- Debug výpis celého inventáře
end)
-- Callback: Otevření Management Menu
lib.callback.register('aprts_shops:openManagement', function(source, shopId)
    local src = source
    local shop = Shops[shopId]
    print("Otevírám management pro shop:", shopId)
    
    if not shop then return false end

    local identifier = GetPlayerIdentifier(src)
    local isAdmin = IsAdmin(src)
    print("IsAdmin:", isAdmin)
    -- Kontrola přístupu
    if shop.owner ~= identifier and not isAdmin then 
        return false
     end
     print("Přístup povolen.")
    -- Příprava dat pro inventář
    local inventoryData = {}
    
    if isAdmin then
        -- ADMIN: Načteme seznam VŠECH itemů ve hře
        local items = exports.ox_inventory:Items()
        if items then
            for name, data in pairs(items) do
                -- print(name)
                table.insert(inventoryData, { 
                    name = name, 
                    label = data.label, 
                    count = 9999 
                })
            end
            table.sort(inventoryData, function(a, b) return a.label < b.label end)
        end
    else
        -- HRÁČ: Načtení inventáře podle tvého JSON formátu
        local rawInventory = exports.ox_inventory:GetInventory(src)
        if not rawInventory.items then 
            print("Chyba: Nelze načíst inventář hráče ID "..src)
            return
        end
        if rawInventory and rawInventory.items then
            -- Iterujeme přes všechny sloty
            for _, item in pairs(rawInventory.items) do
                -- Kontrola: item nesmí být null (prázdný slot) a musí být tabulka
                if item and type(item) == 'table' and item.name then
                    -- print(item.name)
                    -- Ignorujeme peníze (aby nešly prodávat)
                    if item.name ~= 'money' then
                        local count = item.count or 0
                        
                        if count > 0 then
                            table.insert(inventoryData, {
                                name = item.name,
                                label = item.label,
                                count = count,
                                -- Můžeme poslat i metadata pro zobrazení (např. sériové číslo)
                                metadata = item.metadata 
                            })
                        end
                    end
                end
            end
        end
    end

    return {
        shopData = shop,
        inventory = inventoryData, 
        isAdmin = isAdmin
    }
end)

-- Callback: Získání dat pro zákazníka
lib.callback.register('aprts_shops:getShopData', function(source, shopId)
    if shopId then return Shops[shopId] else return Shops end
end)

-- =============================================
-- EVENTS (Akce)
-- =============================================

-- PŘIDÁNÍ / ÚPRAVA / ODEBRÁNÍ ZBOŽÍ
RegisterNetEvent('aprts_shops:updatePrice', function(data)
    local src = source
    local shop = Shops[data.shopId]
    if not shop then return end
    
    local identifier = GetPlayerIdentifier(src)
    local isAdmin = IsAdmin(src)
    
    -- Bezpečnostní kontrola vlastníka
    if shop.owner ~= identifier and not isAdmin then return end
    if not shop.products then shop.products = {} end

    local itemName = data.item
    local price = tonumber(data.price)
    local countToAdd = tonumber(data.count) or 0
    local isRemove = data.remove == true

    -----------------------------------
    -- A) ODSTRANĚNÍ ITEMU Z OBCHODU --
    -----------------------------------
    if isRemove then
        local product = shop.products[itemName]
        if product then
            -- Pokud to není nekonečný (admin) item a jsou tam nějaké kusy, vrátíme je hráči
            if not product.infinite and product.count > 0 then
                if exports.ox_inventory:CanCarryItem(src, itemName, product.count) then
                    exports.ox_inventory:AddItem(src, itemName, product.count)
                    TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Zboží vráceno do inventáře'})
                else
                    TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Nemáš místo na vrácení zboží!'})
                    return -- Nepokračujeme, nesmažeme item z obchodu
                end
            end
            -- Smazání záznamu
            shop.products[itemName] = nil
        end

    -----------------------------------
    -- B) PŘIDÁNÍ / ÚPRAVA ZBOŽÍ     --
    -----------------------------------
    else
        local currentData = shop.products[itemName] or { price = 0, count = 0, infinite = false }
        
        -- Aktualizace ceny
        if price then currentData.price = price end

        -- Logika pro Admina (Generování z voidu)
        if isAdmin and (shop.owner == nil or shop.owner == 'admin') then
            currentData.infinite = true
            currentData.count = 100 -- Vizuální hodnota, reálně se neodečítá
        else
            -- Logika pro Hráče (Vklad z inventáře)
            if countToAdd > 0 then
                -- Má hráč itemy u sebe?
                local itemCount = exports.ox_inventory:GetItem(src, itemName, nil, true)
                if itemCount >= countToAdd then
                    exports.ox_inventory:RemoveItem(src, itemName, countToAdd)
                    currentData.count = currentData.count + countToAdd
                    currentData.infinite = false -- Hráčské itemy nejsou nekonečné
                else
                    TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Nemáš dostatek itemů!'})
                    return
                end
            end
        end
        
        shop.products[itemName] = currentData
    end

    -- Uložení do DB
    MySQL.update('UPDATE aprts_shops SET products = ? WHERE shop_id = ?', {
        json.encode(shop.products), data.shopId
    })
    
    -- Notifikace a refresh UI
    if not isRemove then
        TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Obchod aktualizován'})
    end
    -- Pošleme klientovi signál, ať si znovu načte data (aby se aktualizovala tabulka)
    TriggerClientEvent('aprts_shops:client:refreshUI', src)
end)


-- NÁKUP ITEMU ZÁKAZNÍKEM
RegisterNetEvent('aprts_shops:server:buyItem', function(data)
    local src = source
    local shopId = data.shopId
    local itemName = data.item
    local count = tonumber(data.count) or 1
    
    if count < 1 then return end

    local shop = Shops[shopId]
    if not shop or not shop.products or not shop.products[itemName] then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Tento produkt již není v nabídce.'})
        return
    end

    local product = shop.products[itemName]
    
    -- 1. Kontrola skladu (pokud není infinite)
    if not product.infinite then
        if product.count < count then
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Nedostatek zboží na skladě.'})
            return
        end
    end

    -- 2. Kontrola peněz
    local totalPrice = product.price * count
    local playerMoney = exports.ox_inventory:GetItem(src, 'money', nil, true) 

    if playerMoney < totalPrice then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Nemáš dostatek hotovosti.'})
        return
    end

    -- 3. Kontrola místa v inventáři
    if not exports.ox_inventory:CanCarryItem(src, itemName, count) then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'Nemáš místo v inventáři.'})
        return
    end

    -- 4. PROVEDENÍ TRANSAKCE
    exports.ox_inventory:RemoveItem(src, 'money', totalPrice)
    exports.ox_inventory:AddItem(src, itemName, count)

    -- Přičtení peněz do kasy obchodu
    shop.money = shop.money + totalPrice
    MySQL.update('UPDATE aprts_shops SET money = ? WHERE shop_id = ?', {shop.money, shopId})

    -- Odečtení ze skladu (pokud není infinite)
    if not product.infinite then
        product.count = product.count - count
        MySQL.update('UPDATE aprts_shops SET products = ? WHERE shop_id = ?', {
            json.encode(shop.products), shopId
        })
    end

    TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Zakoupil jsi '..count..'x '..itemName})
end)


-- VÝBĚR PENĚZ
RegisterNetEvent('aprts_shops:withdrawMoney', function(shopId)
    local src = source
    local shop = Shops[shopId]
    local identifier = GetPlayerIdentifier(src)
    
    if shop and shop.money > 0 and (shop.owner == identifier) then
        local amount = shop.money
        shop.money = 0
        exports.ox_inventory:AddItem(src, 'money', amount)
        MySQL.update('UPDATE aprts_shops SET money = 0 WHERE shop_id = ?', {shopId})
        TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Vybráno $'..amount})
    end
end)

-- NASTAVENÍ OBCHODU (Název)
RegisterNetEvent('aprts_shops:updateSettings', function(data)
    local src = source
    local shop = Shops[data.shopId]
    if not shop then return end
    
    local identifier = GetPlayerIdentifier(src)
    if shop.owner ~= identifier and not IsAdmin(src) then return end

    -- Aktualizace Labelu (Názvu)
    if data.label then
        shop.label = data.label
    end

    -- Aktualizace Settings
    if not shop.settings then shop.settings = {} end
    
    shop.settings.blipSprite = tonumber(data.blipSprite) or 52
    shop.settings.blipColor = tonumber(data.blipColor) or 2
    shop.settings.openHour = tonumber(data.openHour) or 0
    shop.settings.closeHour = tonumber(data.closeHour) or 24

    -- Uložení do DB (Label i Settings)
    MySQL.update('UPDATE aprts_shops SET label = ?, settings = ? WHERE shop_id = ?', {
        shop.label, json.encode(shop.settings), data.shopId
    })
    
    -- Notifikace
    TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Nastavení uloženo'})
    
    -- Refresh Blipů a UI pro všechny klienty (aby se změnil blip na mapě hned)
    TriggerClientEvent('aprts_shops:client:refreshShopData', -1, shop)
end)

-- VYTVOŘENÍ OBCHODU (Admin)
RegisterNetEvent('aprts_shops:server:createShop', function(data)
    local src = source
    if not IsAdmin(src) then return end

    local shopId = 'shop_' .. math.random(1000, 9999)
    local coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
    
    -- Owner je NIL = Admin shop / Na prodej
    local id = MySQL.insert.await('INSERT INTO aprts_shops (shop_id, label, coords, owner) VALUES (?, ?, ?, ?)', {
        shopId, data.label, json.encode(coords), nil
    })

    if id then
        Shops[shopId] = {
            shop_id = shopId, label = data.label, coords = coords, owner = nil, products = {}, money = 0
        }
        TriggerClientEvent('aprts_shops:client:syncNewShop', -1, Shops[shopId])
    end
end)

-- SMAZÁNÍ OBCHODU (Admin)
RegisterNetEvent('aprts_shops:deleteShop', function(data)
    local src = source
    if not IsAdmin(src) then return end
    
    local shopId = data.shopId
    if Shops[shopId] then
        MySQL.query('DELETE FROM aprts_shops WHERE shop_id = ?', {shopId})
        Shops[shopId] = nil
        TriggerClientEvent('aprts_shops:client:removeShopZone', -1, shopId)
    end
end)