ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)


ESX.RegisterServerCallback('custom_hud:getPlayerCount', function(source, cb)
    local count = GetNumPlayerIndices()
    cb(count)
end)

ESX.RegisterServerCallback('LS-Hud:getPlayerMoney', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        cb(xPlayer.getMoney())
    else
        cb(0)
    end
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) 

        
        local hour, minute, day, month, year = tonumber(os.date("%H")), tonumber(os.date("%M")), tonumber(os.date("%d")), tonumber(os.date("%m")), tonumber(os.date("%Y"))

        
        local onlinePlayers = #GetPlayers()
        local maxPlayers = GetConvarInt('sv_maxclients', 32)

        
        TriggerClientEvent('LS-Hud:updateDateTime', -1, hour, minute, day, month, year)
        TriggerClientEvent('LS-Hud:updatePlayerCount', -1, onlinePlayers, maxPlayers)
    end
end)

RegisterNetEvent('LS-Hud:requestInitialData')
AddEventHandler('LS-Hud:requestInitialData', function()
    local _source = source

    
    local hour, minute, day, month, year = tonumber(os.date("%H")), tonumber(os.date("%M")), tonumber(os.date("%d")), tonumber(os.date("%m")), tonumber(os.date("%Y"))

    
    local onlinePlayers = #GetPlayers()
    local maxPlayers = GetConvarInt('sv_maxclients', 32)

    
    TriggerClientEvent('LS-Hud:updateDateTime', _source, hour, minute, day, month, year)
    TriggerClientEvent('LS-Hud:updatePlayerCount', _source, onlinePlayers, maxPlayers)
end)
