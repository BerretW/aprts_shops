local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayerIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.citizenid or nil
end

function GetPlayerMoney(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.Functions.GetMoney('bank') or 0
end

function RemovePlayerMoney(source, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then return Player.Functions.RemoveMoney('bank', amount) end
    return false
end

function AddPlayerMoney(source, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then return Player.Functions.AddMoney('bank', amount) end
end

function GetPlayerName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or "Neznámý"
end

-- Ověření admina
function IsAdmin(source)
    return QBCore.Functions.HasPermission(source, Config.AdminGroup)
end