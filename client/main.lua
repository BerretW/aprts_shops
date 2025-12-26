local CreatedShops = {}

local CreatedShops = {}
local CreatedBlips = {} -- Pole pro blipy

-- Funkce pro vytvoření/aktualizaci Blipu
function UpdateShopBlip(shopId, data)
    -- Pokud blip existuje, smažeme ho
    if CreatedBlips[shopId] then
        RemoveBlip(CreatedBlips[shopId])
    end

    -- Defaultní nastavení, pokud chybí
    local settings = data.settings or { blipSprite = 52, blipColor = 2, blipScale = 0.8 }
    
    -- Vytvoření blipu
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, settings.blipSprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, settings.blipColor)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.label)
    EndTextCommandSetBlipName(blip)

    CreatedBlips[shopId] = blip
end

function CreateShopZone(shopData)
    if CreatedShops[shopData.shop_id] then exports.ox_target:removeZone(CreatedShops[shopData.shop_id]) end

    -- Vytvoříme/Aktualizujeme Blip
    UpdateShopBlip(shopData.shop_id, shopData)

    local zoneId = exports.ox_target:addSphereZone({
        coords = vec3(shopData.coords.x, shopData.coords.y, shopData.coords.z),
        radius = 1.0,
        options = {
            {
                name = 'open_shop_ui',
                icon = 'fa-solid fa-basket-shopping',
                label = 'Nakupovat',
                onSelect = function()
                    -- KONTROLA OTEVÍRACÍ DOBY
                    local currentHour = GetClockHours()
                    local open = shopData.settings and shopData.settings.openHour or 0
                    local close = shopData.settings and shopData.settings.closeHour or 24
                    
                    -- Jednoduchá logika: Pokud je open < close (např 8-20)
                    -- Pokud je open > close (např 22-06), logika je složitější, ale pro začátek:
                    local isOpen = false
                    if open < close then
                        isOpen = (currentHour >= open and currentHour < close)
                    else
                        -- Přes půlnoc
                        isOpen = (currentHour >= open or currentHour < close)
                    end

                    if isOpen then
                        OpenBuyerNUI(shopData.shop_id)
                    else
                        lib.notify({type = 'error', description = 'Obchod je zavřený. (Otevřeno: '..open..':00 - '..close..':00)'})
                    end
                end
            },
            {
                name = 'manage_shop',
                icon = 'fa-solid fa-crown',
                label = 'Spravovat obchod',
                onSelect = function()
                    OpenManagementNUI(shopData.shop_id)
                end,
                -- Majitel může spravovat i když je zavřeno
                canInteract = function() return true end 
            }
        }
    })
    CreatedShops[shopData.shop_id] = zoneId
end

-- Event pro refresh dat (když majitel změní název/ikonu)
RegisterNetEvent('aprts_shops:client:refreshShopData', function(shopData)
    CreateShopZone(shopData)
end)

-- Načtení
CreateThread(function()
    Wait(1000) 
    lib.callback('aprts_shops:getShopData', false, function(shops) 
        if shops then
            for k, data in pairs(shops) do
                CreateShopZone(data)
            end
        end
    end)
end)
function CreateShopZone(shopData)
    if CreatedShops[shopData.shop_id] then exports.ox_target:removeZone(CreatedShops[shopData.shop_id]) end

    local zoneId = exports.ox_target:addSphereZone({
        coords = vec3(shopData.coords.x, shopData.coords.y, shopData.coords.z),
        radius = 1.0,
        options = {
            {
                name = 'open_shop_ui',
                icon = 'fa-solid fa-basket-shopping',
                label = 'Nakupovat',
                onSelect = function()
                    -- ZMĚNA: Otevíráme naše vlastní NUI místo ox_inventory
                    OpenBuyerNUI(shopData.shop_id)
                end
            },
            {
                name = 'manage_shop',
                icon = 'fa-solid fa-crown',
                label = 'Spravovat obchod',
                onSelect = function()
                    OpenManagementNUI(shopData.shop_id)
                end,
                canInteract = function() return true end 
            }
        }
    })
    CreatedShops[shopData.shop_id] = zoneId
end

-- Nová funkce pro otevření menu pro ZÁKAZNÍKA
function OpenBuyerNUI(shopId)
    -- Získáme čerstvá data o obchodu
    lib.callback('aprts_shops:getShopData', false, function(shop)
        if not shop then return end
        
        -- Musíme získat labely itemů (názvy), protože v DB máme jen spawn name
        -- Použijeme ox_inventory export
        local itemsWithLabels = {}
        if shop.products then
            for item, data in pairs(shop.products) do
                local oxItem = exports.ox_inventory:Items(item)
                if oxItem then
                    table.insert(itemsWithLabels, {
                        name = item,
                        label = oxItem.label,
                        price = data.price,
                        description = oxItem.description
                    })
                end
            end
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openBuyer', -- Jiná akce než pro admina
            shopLabel = shop.label,
            shopId = shop.shop_id,
            items = itemsWithLabels
        })
    end, shopId)
end

-- Callback pro nákup itemu (voláno z JS)
RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('aprts_shops:server:buyItem', data)
    cb('ok')
end)

-- ... (Zbytek kódu, OpenManagementNUI atd. zůstává stejný)

-- Synchronizace nového obchodu (když admin vytvoří)
RegisterNetEvent('aprts_shops:client:syncNewShop', function(data)
    CreateShopZone(data)
end)

-- Smazání zóny
RegisterNetEvent('aprts_shops:client:removeShopZone', function(shopId)
    if CreatedShops[shopId] then 
        exports.ox_target:removeZone(CreatedShops[shopId])
        CreatedShops[shopId] = nil
    end
end)

-- Načtení při startu
CreateThread(function()
    Wait(1000)
    lib.callback('aprts_shops:getShopData', false, function(shops) 
        if shops then
            for k, data in pairs(shops) do
                CreateShopZone(data)
            end
        end
    end)
end)

function OpenManagementNUI(shopId)
    lib.callback('aprts_shops:openManagement', false, function(data)
        if not data then 
            lib.notify({type = 'error', description = 'Nemáš přístup k tomuto obchodu.'})
            return 
        end
        -- print(json.encode(data))
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            shopData = data.shopData,
            inventoryItems = data.inventory,
            isAdmin = data.isAdmin
        })
    end, shopId)
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('updatePrice', function(data, cb)
    TriggerServerEvent('aprts_shops:updatePrice', data)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('aprts_shops:withdrawMoney', data.shopId)
    cb('ok')
end)

RegisterNUICallback('updateSettings', function(data, cb)
    TriggerServerEvent('aprts_shops:updateSettings', data)
    cb('ok')
end)

RegisterNUICallback('deleteShop', function(data, cb)
    TriggerServerEvent('aprts_shops:deleteShop', data)
    cb('ok')
end)

RegisterCommand(Config.AdminCommand, function()
    local input = lib.inputDialog('Vytvořit obchod', {
        {type = 'input', label = 'Název', required = true},
    })
    if input then
        TriggerServerEvent('aprts_shops:server:createShop', {
            label = input[1],
            coords = GetEntityCoords(cache.ped)
        })
    end
end)