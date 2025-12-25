local CreatedShops = {}



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
                    -- Zde by se otevíralo nákupní menu (NUI nebo Ox Inventory Shop)
                    -- Pro jednoduchost: Otevřeme STASH, pokud je to bazar, 
                    -- ale správně by to mělo být nákupní okno, kde se platí.
                    TriggerEvent('aprts_shops:client:openBuyerMenu', shopData.shop_id)
                end
            },
            {
                name = 'manage_shop',
                icon = 'fa-solid fa-crown',
                label = 'Spravovat obchod',
                onSelect = function()
                    OpenManagementNUI(shopData.shop_id)
                end,
                canInteract = function() return true end -- Server checkne permise v callbacku
            }
        }
    })
    CreatedShops[shopData.shop_id] = zoneId
end


-- Načtení
CreateThread(function()
    Wait(1000) -- Počkáme chvíli po startu
    -- Žádáme server o VŠECHNY obchody (parametr je false/nil)
    lib.callback('aprts_shops:getShopData', false, function(shops) 
        if shops then
            for k, data in pairs(shops) do
                -- Pro každý obchod vytvoříme target zónu
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
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            shopData = data.shopData,
            inventoryItems = data.inventoryItems,
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

-- Admin příkaz pro vytvoření
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