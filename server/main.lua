local QBCore = exports['qb-core']:GetCoreObject()
local Shops = {}

-- Načtení obchodů
MySQL.ready(function()
    local result = MySQL.query.await('SELECT * FROM aprts_shops')
    if result then
        for _, v in pairs(result) do
            v.coords = json.decode(v.coords)
            v.products = v.products and json.decode(v.products) or {}
            Shops[v.shop_id] = v
            -- Registrace stashe
            exports.ox_inventory:RegisterStash(v.shop_id, v.label, 50, 100000, v.owner)
        end
    end
end)

-- Pomocná funkce pro Admina
local function IsAdmin(source)
    return QBCore.Functions.HasPermission(source, Config.AdminGroup) or IsPlayerAceAllowed(source, 'command')
end

-- Callback pro vytvoření obchodu (přes příkaz)
RegisterNetEvent('aprts_shops:server:createShop', function(data)
    local src = source
    if not IsAdmin(src) then return end

    local shopId = 'shop_' .. math.random(1000, 9999)
    local coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
    
    local id = MySQL.insert.await('INSERT INTO aprts_shops (shop_id, label, coords, owner) VALUES (?, ?, ?, ?)', {
        shopId, data.label, json.encode(coords), nil
    })

    if id then
        Shops[shopId] = {
            shop_id = shopId, label = data.label, coords = coords, owner = nil, products = {}, money = 0
        }
        exports.ox_inventory:RegisterStash(shopId, data.label, 50, 100000, nil)
        TriggerClientEvent('aprts_shops:client:syncNewShop', -1, Shops[shopId])
    end
end)

-- Callback: Otevření Management Menu
lib.callback.register('aprts_shops:openManagement', function(source, shopId)
    local src = source
    local shop = Shops[shopId]
    if not shop then return false end

    local identifier = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
    local isAdmin = IsAdmin(src)

    -- Přístup jen pro majitele nebo admina
    if shop.owner ~= identifier and not isAdmin then return false end

    -- Získání všech existujících itemů v ox_inventory (pro výběr v menu)
    local allItemsRaw = exports.ox_inventory:Items()
    local gameItems = {}
    
    for name, data in pairs(allItemsRaw) do
        table.insert(gameItems, {
            name = name,
            label = data.label
        })
    end

    -- Seřadíme itemy podle abecedy pro lepší hledání
    table.sort(gameItems, function(a, b) return a.label < b.label end)

    return {
        shopData = shop,
        gameItems = gameItems, -- Seznam všech itemů ve hře
        isAdmin = isAdmin
    }
end)

lib.callback.register('aprts_shops:getShopData', function(source, shopId)
    if shopId then
        -- Pokud klient žádá konkrétní obchod (např. pro update jedné zóny)
        return Shops[shopId]
    else
        -- Pokud klient nepošle ID (při startu scriptu), vrátíme kompletní seznam
        return Shops
    end
end)


-- NUI Eventy
RegisterNetEvent('aprts_shops:updatePrice', function(data)
    local src = source
    local shop = Shops[data.shopId]
    if not shop then return end
    
    local identifier = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
    if shop.owner ~= identifier and not IsAdmin(src) then return end

    if not shop.products then shop.products = {} end

    if data.price == nil then
        -- Pokud je cena null, item z obchodu odstraníme
        shop.products[data.item] = nil
    else
        -- Jinak nastavíme cenu
        shop.products[data.item] = { price = data.price }
    end
    
    MySQL.update('UPDATE aprts_shops SET products = ? WHERE shop_id = ?', {
        json.encode(shop.products), data.shopId
    })
    
    TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Ceník aktualizován'})
end)

RegisterNetEvent('aprts_shops:withdrawMoney', function(shopId)
    local src = source
    local shop = Shops[shopId]
    local player = QBCore.Functions.GetPlayer(src)
    
    if shop and shop.money > 0 and (shop.owner == player.PlayerData.citizenid) then
        local amount = shop.money
        shop.money = 0
        player.Functions.AddMoney('cash', amount)
        MySQL.update('UPDATE aprts_shops SET money = 0 WHERE shop_id = ?', {shopId})
        TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Vybráno $'..amount})
    end
end)