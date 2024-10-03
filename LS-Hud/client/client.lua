ESX = nil

local postalsData = {}
local bank, blackMoney, money = 0, 0, 0
local usingRadio, voiceMode, characterLoaded, micActive = false, 2, false, false
local radioDelay, inVehicle = 20, false
local leftIndicatorOn, rightIndicatorOn, hazardLightsOn = false, false, false
local voiceModes = {}
local voiceMarkerActive = false
local lastClipAmmo, lastTotalAmmo = nil, nil
local isAmmoHUDVisible, isSyncPaused, wasReloading = false, false, false
local lastWeaponHash = nil
local playerWeapons = {}
local hudVisible = true

Citizen.CreateThread(function()
    local file = LoadResourceFile(GetCurrentResourceName(), "oulsen_satmap_postals.json")
    if file then
        postalsData = json.decode(file)
        if not postalsData then
            print("Error: Postals data is nil")
        end
    end
end)

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(10)
    end

    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(10)
    end

    ESX.PlayerData = ESX.GetPlayerData()

    TriggerEvent("pma-voice:settingsCallback", function(voiceSettings)
        voiceModes = voiceSettings.voiceModes
    end)

    initializePlayerData()
end)

function initializePlayerData()
    print("initializePlayerData: Wird aufgerufen.")
    bank, blackMoney = 0, 0

    if ESX.PlayerData.accounts then
        for _, account in ipairs(ESX.PlayerData.accounts) do
            if account.name == 'bank' then
                bank = account.money
            elseif account.name == 'black_money' then
                blackMoney = account.money
            end
        end
    else
        print("Error: Accounts data is nil after playerLoaded event.")
    end

    ESX.TriggerServerCallback('LS-Hud:getPlayerMoney', function(serverMoney)
        money = serverMoney

        characterLoaded = true
        print("initializePlayerData: characterLoaded auf true gesetzt.")

        SendNUIMessage({ type = "showHUD" })
        print("initializePlayerData: HUD angezeigt.")

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle ~= 0 then
            local seatIndex = -1 
            if GetPedInVehicleSeat(vehicle, seatIndex) == playerPed then
                inVehicle = true
                SendNUIMessage({ type = "showTachoWithAnimation" })
                print("initializePlayerData: Tacho angezeigt.")
                updateIndicators()
            end
        end

        startHUDUpdateThread()
        checkPlayerWeaponStatus()
    end)
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    print("esx:playerLoaded: Spieler geladen.")
    initializePlayerData()
end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
    if account.name == 'bank' then
        bank = account.money
    elseif account.name == 'black_money' then
        blackMoney = account.money
    elseif account.name == 'money' then
        money = account.money
    end
    print("esx:setAccountMoney: Konto aktualisiert - " .. account.name .. ": " .. account.money)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
    print("esx:setJob: Job aktualisiert - " .. job.label .. " - " .. job.grade_label)
end)

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    voiceMarkerActive = false
    Citizen.Wait(50)

    voiceMode = mode

    if voiceModes[mode] then
        local proximityRange = voiceModes[mode][1]
        CreateProximityMarker(proximityRange)
    else
        print("Fehler: voiceModes für Modus " .. tostring(mode) .. " ist nicht definiert.")
    end

    SendNUIMessage({
        type = "updateVoiceLevel",
        voiceLevel = voiceMode
    })
    print("Voice Level aktualisiert: " .. tostring(voiceMode))
end)

function CreateProximityMarker(proximityRange)
    voiceMarkerActive = true

    Citizen.CreateThread(function()
        local currentAlpha = 0
        local fadeSpeed = 5
        local markerDuration = 3000
        local endTime = GetGameTimer() + markerDuration

        while voiceMarkerActive and GetGameTimer() < endTime do
            Citizen.Wait(0)
            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) then
                local coords = GetEntityCoords(playerPed)

                currentAlpha = math.min(currentAlpha + fadeSpeed, 100)

                DrawMarker(
                    28,
                    coords.x, coords.y, coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    proximityRange * 2.0, proximityRange * 2.0, proximityRange * 2.0,
                    83, 0, 245, currentAlpha,
                    false, false, 2,
                    nil, nil, false
                )
            end
        end

        while voiceMarkerActive and currentAlpha > 0 do
            Citizen.Wait(0)
            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) then
                local coords = GetEntityCoords(playerPed)
                currentAlpha = math.max(currentAlpha - fadeSpeed, 0)

                DrawMarker(
                    28,
                    coords.x, coords.y, coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    proximityRange * 2.0, proximityRange * 2.0, proximityRange * 2.0,
                    83, 0, 245, currentAlpha,
                    false, false, 2,
                    nil, nil, false
                )
            end
        end

        voiceMarkerActive = false
    end)
end

Citizen.CreateThread(function()
    local micWasActive = false

    while true do
        Citizen.Wait(100)

        if characterLoaded and not usingRadio then
            local micActiveNow = NetworkIsPlayerTalking(PlayerId())

            if micActiveNow ~= micWasActive then
                micWasActive = micActiveNow
                micActive = micActiveNow

                SendNUIMessage({
                    type = "updateMicStatus",
                    mic = micActiveNow
                })
                print("Mikrofonstatus aktualisiert: " .. tostring(micActiveNow))
            end
        end
    end
end)

AddEventHandler("pma-voice:radioActive", function(radioTalking)
    usingRadio = radioTalking

    SendNUIMessage({
        type = "updateRadioStatus",
        radio = radioTalking
    })
    print("Radiostatus aktualisiert: " .. tostring(radioTalking))
end)

RegisterNetEvent('LS-Hud:updateDateTime')
AddEventHandler('LS-Hud:updateDateTime', function(hour, minute, day, month, year)
    local formattedTime = string.format("%02d:%02d", hour, minute)
    local formattedDate = string.format("%02d.%02d.%04d", day, month, year)

    SendNUIMessage({
        type = "updateDateTime",
        time = formattedTime,
        date = formattedDate
    })
    print("Datum und Uhrzeit aktualisiert: " .. formattedTime .. " | " .. formattedDate)
end)

RegisterNetEvent('LS-Hud:updatePlayerCount')
AddEventHandler('LS-Hud:updatePlayerCount', function(onlinePlayers, maxPlayers)
    SendNUIMessage({
        type = "updatePlayerCount",
        online = onlinePlayers,
        max = maxPlayers
    })
    print("Spieleranzahl aktualisiert: " .. onlinePlayers .. "/" .. maxPlayers)
end)

function shouldHideHUD()
    return IsPauseMenuActive() or IsPlayerSwitchInProgress()
end

function startHUDUpdateThread()
    print("startHUDUpdateThread: Wird gestartet.")
    Citizen.CreateThread(function()
        while characterLoaded do
            if shouldHideHUD() then
                if hudVisible then
                    hudVisible = false
                    SendNUIMessage({ type = "hideHUD" })
                    print("HUD versteckt.")
                end
            else
                if not hudVisible then
                    hudVisible = true
                    SendNUIMessage({ type = "showHUD" })
                    print("HUD angezeigt.")
                end
                updateHUD()
            end
            Citizen.Wait(50) 
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)

        if characterLoaded and not shouldHideHUD() then
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            local isDriver = false

            if vehicle ~= 0 then
                local seatIndex = -1 
                if GetPedInVehicleSeat(vehicle, seatIndex) == playerPed then
                    isDriver = true
                end
            end

            if isDriver and not inVehicle then
                inVehicle = true
                SendNUIMessage({ type = "showTachoWithAnimation" })
                print("Fahrzeugüberprüfung: Tacho angezeigt.")
            elseif (not isDriver or vehicle == 0) and inVehicle then
                inVehicle = false
                SendNUIMessage({ type = "hideTachoWithAnimation" })
                SendNUIMessage({ type = "updateSpeed", speed = 0 })
                print("Fahrzeugüberprüfung: Tacho versteckt.")
            end

            print(string.format("Main loop: isDriver=%s, inVehicle=%s, vehicle=%s", tostring(isDriver), tostring(inVehicle), tostring(vehicle)))
        end
    end
end)

function getClosestPostal(coords)
    local nearestPostal = nil
    local shortestDistance = math.huge

    for _, postal in pairs(postalsData) do
        local distance = #(coords - vector3(postal.x, postal.y, 0.0))
        if distance < shortestDistance then
            nearestPostal = postal
            shortestDistance = distance
        end
    end

    return nearestPostal and nearestPostal.code or "undefined"
end

function getFuelLevel(vehicle)
    if DoesEntityExist(vehicle) then
        return exports['gacha_fuel']:GetFuel(vehicle)
    else
        return 0
    end
end

function updateIndicators()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        local indicatorLights = GetVehicleIndicatorLights(vehicle)

        if indicatorLights == 3 then
            if not hazardLightsOn then
                hazardLightsOn = true
                leftIndicatorOn = true
                rightIndicatorOn = true

                SendNUIMessage({
                    type = "updateIndicators",
                    left = true,
                    right = true,
                    sync = true
                })
                print("Blinker: Gefahrenlicht eingeschaltet.")
            end
        else
            hazardLightsOn = false

            local newLeftIndicatorOn = (indicatorLights == 1)
            local newRightIndicatorOn = (indicatorLights == 2)

            if newLeftIndicatorOn ~= leftIndicatorOn or newRightIndicatorOn ~= rightIndicatorOn then
                leftIndicatorOn = newLeftIndicatorOn
                rightIndicatorOn = newRightIndicatorOn

                SendNUIMessage({
                    type = "updateIndicators",
                    left = leftIndicatorOn,
                    right = rightIndicatorOn,
                    sync = false
                })
                print("Blinker: Links = " .. tostring(leftIndicatorOn) .. ", Rechts = " .. tostring(rightIndicatorOn))
            end
        end
    else
        if leftIndicatorOn or rightIndicatorOn or hazardLightsOn then
            leftIndicatorOn, rightIndicatorOn, hazardLightsOn = false, false, false

            SendNUIMessage({
                type = "updateIndicators",
                left = false,
                right = false,
                sync = false
            })
            print("Blinker: Alle Blinker ausgeschaltet.")
        end
    end
end

function updateHUD()
    local playerPed = PlayerPedId()
    local health = (GetEntityHealth(playerPed) - 100)
    local hunger, thirst = 100, 100

    TriggerEvent('esx_status:getStatus', 'hunger', function(status)
        hunger = math.floor(status.getPercent())
    end)

    TriggerEvent('esx_status:getStatus', 'thirst', function(status)
        thirst = math.floor(status.getPercent())
    end)

    if not ESX.PlayerData.job then
        ESX.PlayerData = ESX.GetPlayerData()
    end

    local playerId = GetPlayerServerId(PlayerId())
    local coords = GetEntityCoords(playerPed)
    local postalCode = getClosestPostal(coords)

    local streetNameHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetNameHash)
    local zoneName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    SendNUIMessage({
        type = "update",
        health = health,
        hunger = hunger,
        thirst = thirst,
        job = ESX.PlayerData.job.label,
        grade = ESX.PlayerData.job.grade_label,
        money = money,
        bank = bank,
        blackMoney = blackMoney,
        playerId = playerId,
        voiceLevel = voiceMode,
        street = streetName,
        zone = zoneName,
        postalCode = postalCode
    })
    print("HUD aktualisiert.")

    if inVehicle then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle and vehicle ~= 0 then
            local speed = GetEntitySpeed(vehicle) * 3.6
            local fuelLevel = getFuelLevel(vehicle)
            local maxSpeed = math.min(GetVehicleEstimatedMaxSpeed(vehicle) * 3.6, 300)

            SendNUIMessage({
                type = "updateSpeed",
                speed = math.floor(speed),
                maxSpeed = math.floor(maxSpeed)
            })
            print("updateHUD: Geschwindigkeit aktualisiert.")

            SendNUIMessage({
                type = "updateFuel",
                fuel = math.floor(fuelLevel)
            })
            print("updateHUD: Kraftstoffstand aktualisiert.")

            updateIndicators()

            local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)
            SendNUIMessage({
                type = "updateEngineCondition",
                engineHealth = engineHealth
            })
            print("updateHUD: Motorzustand aktualisiert.")

            local retval, vehicleLightsOn, highbeamsOn = GetVehicleLightsState(vehicle)
            local lightsMode = 0

            if retval then
                if highbeamsOn == 1 then
                    lightsMode = 2
                elseif vehicleLightsOn == 1 then
                    lightsMode = 1
                else
                    lightsMode = 0
                end
            end

            SendNUIMessage({
                type = "updateLightsMode",
                lightsMode = lightsMode
            })
            print("updateHUD: Lichtmodus aktualisiert.")
        else
            print("updateHUD: Kein Fahrzeug gefunden.")
        end
    end
end

function isWeaponInInventory(weaponHash)
    local loadout = ESX.PlayerData.loadout
    if loadout then
        for _, weapon in ipairs(loadout) do
            if GetHashKey(weapon.name) == weaponHash then
                return true
            end
        end
    end
    return false
end

function checkPlayerWeaponStatus()
    local playerPed = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(playerPed)

    if weaponHash ~= `WEAPON_UNARMED` and isWeaponInInventory(weaponHash) then
        local retval, ammoInClip = GetAmmoInClip(playerPed, weaponHash)
        local totalAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)

        if retval and ammoInClip and totalAmmo then
            lastClipAmmo = ammoInClip
            lastTotalAmmo = totalAmmo
            lastWeaponHash = weaponHash

            SendNUIMessage({
                type = "updateAmmo",
                clip = lastClipAmmo,
                total = lastTotalAmmo
            })
            SendNUIMessage({
                type = "showAmmoHUD"
            })
            isAmmoHUDVisible = true
            print("checkPlayerWeaponStatus: Munition aktualisiert und HUD angezeigt.")
        else
            Citizen.SetTimeout(100, function()
                checkPlayerWeaponStatus()
            end)
        end
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if not isSyncPaused then
            updateWeaponAmmo()
        end
    end
end)

function updateWeaponAmmo()
    local playerPed = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(playerPed)

    if weaponHash ~= `WEAPON_UNARMED` and isWeaponInInventory(weaponHash) then
        local retval, ammoInClip = GetAmmoInClip(playerPed, weaponHash)
        local totalAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)

        if retval and ammoInClip and totalAmmo then
            if lastClipAmmo == nil or weaponHash ~= lastWeaponHash then
                lastClipAmmo = ammoInClip
                lastTotalAmmo = totalAmmo
                lastWeaponHash = weaponHash

                SendNUIMessage({
                    type = "updateAmmo",
                    clip = lastClipAmmo,
                    total = lastTotalAmmo
                })
                print("updateWeaponAmmo: Munition aktualisiert.")
            end

            local isReloading = IsPedReloading(playerPed)
            local clipIncreased = ammoInClip > lastClipAmmo

            if isReloading or clipIncreased then
                wasReloading = true
            end

            if wasReloading and (not isReloading or clipIncreased) then
                lastClipAmmo = ammoInClip
                lastTotalAmmo = totalAmmo

                SendNUIMessage({
                    type = "updateAmmo",
                    clip = lastClipAmmo,
                    total = lastTotalAmmo
                })
                print("updateWeaponAmmo: Nachladen abgeschlossen, Munition aktualisiert.")

                wasReloading = false
            elseif lastClipAmmo ~= ammoInClip then
                lastClipAmmo = ammoInClip
                SendNUIMessage({
                    type = "updateAmmo",
                    clip = lastClipAmmo,
                    total = lastTotalAmmo
                })
                print("updateWeaponAmmo: Munition reduziert, aktualisiert.")
            end
        end

        if not isAmmoHUDVisible then
            SendNUIMessage({
                type = "showAmmoHUD"
            })
            isAmmoHUDVisible = true
            print("updateWeaponAmmo: Ammo HUD angezeigt.")
        end
    else
        if isAmmoHUDVisible then
            isSyncPaused = true
            SendNUIMessage({
                type = "hideAmmoHUD"
            })
            print("updateWeaponAmmo: Ammo HUD versteckt.")

            Citizen.Wait(500)
            isSyncPaused = false
            isAmmoHUDVisible = false
        end
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Citizen.Wait(1000)
        checkPlayerWeaponStatus()
        TriggerServerEvent('LS-Hud:requestInitialData')
        print("onClientResourceStart: Initialisiere Spielerdata und Waffenstatus.")
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        HideHudComponentThisFrame(2)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        local autopilotActive = false

        local status, result = pcall(function()
            if exports and exports['LS-Autopilot'] and exports['LS-Autopilot'].IsAutopilotActive then
                return exports['LS-Autopilot']:IsAutopilotActive()
            else
                return false
            end
        end)

        if status then
            autopilotActive = result
        end

        SendNUIMessage({
            type = "updateAutopilotStatus",
            active = autopilotActive
        })
        print("Autopilot-Status aktualisiert: " .. tostring(autopilotActive))
    end
end)
