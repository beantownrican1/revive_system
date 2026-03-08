-- ============================================================
--  REVIVE SYSTEM - CLIENT
--  Approach: let the ped stay dead naturally. Never fight
--  NetworkResurrectLocalPlayer during the downed window.
--  Only resurrect on actual revive/self-revive.
-- ============================================================

local isDowned        = false
local isFinishedOff   = false  -- true if killed again while downed
local selfReviveReady = false
local isReviving      = false
local animLoopActive  = false
local nearbyDowned    = nil
local downedVersion   = 0

-- Downed list synced from server
local downedList = {}

-- ============================================================
--  Helpers
-- ============================================================

local function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

local function notify(msg)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

local function sendNUI(action, data)
    data        = data or {}
    data.action = action
    SendNUIMessage(data)
end

-- Start a timer that allows the finished-off player to press [E] for hospital
local function startHospitalTimer()
    local myVersion = downedVersion
    sendNUI('startProgress', {
        label    = "⚰  Critical — awaiting hospital transfer...",
        duration = Config.SelfReviveTimer * 1000,
        color    = { r = 180, g = 0, b = 0, a = 220 },
    })
    SetTimeout(Config.SelfReviveTimer * 1000, function()
        if downedVersion ~= myVersion then return end
        if isDowned and isFinishedOff then
            sendNUI('endProgress', {})
            selfReviveReady = true
            notify("~b~Press [E] to go to the hospital.")
        end
    end)
end

-- ============================================================
--  Sync downed list from server
-- ============================================================

RegisterNetEvent('revive:syncDownedList', function(list)
    downedList = list
end)

-- ============================================================
--  Emote blocking (while reviving someone)
-- ============================================================

local emoteBlocked = false

AddEventHandler('chat:chatMessage', function(_, _, text)
    if emoteBlocked then
        local cmd = text:match("^/(%a+)")
        if cmd and (cmd == "e" or cmd == "c" or cmd == "emote" or cmd == "cancel") then
            CancelEvent()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if emoteBlocked then
            DisableControlAction(0, 73,  true)
            DisableControlAction(0, 194, true)
        end
    end
end)

-- ============================================================
--  Downed enforcement loop
-- ============================================================

CreateThread(function()
    while true do
        Wait(0)
        if isDowned then
            local ped = PlayerPedId()
            SetPedCanRagdoll(ped, false)
            DisableControlAction(0, 30,  true)
            DisableControlAction(0, 31,  true)
            DisableControlAction(0, 21,  true)
            DisableControlAction(0, 22,  true)
            DisableControlAction(0, 23,  true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 44,  true)
            DisableControlAction(0, 45,  true)
            DisableControlAction(0, 37,  true)
            DisableControlAction(0, 58,  true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
        end
    end
end)

-- Anim re-enforcer — only for downed writhe, not for revive CPR
CreateThread(function()
    while true do
        Wait(1000)
        if isDowned and animLoopActive and not isReviving then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, Config.DownedAnim.dict, Config.DownedAnim.anim, 3) then
                loadAnimDict(Config.DownedAnim.dict)
                TaskPlayAnim(ped, Config.DownedAnim.dict, Config.DownedAnim.anim,
                    8.0, -1.0, -1, 1, 0, false, false, false)
            end
        end
    end
end)

-- ============================================================
--  Enter downed state
--  Called after ragdoll delay. Ped stays dead — we just take
--  over visually. No NetworkResurrectLocalPlayer here.
-- ============================================================

local enterDownedState  -- forward declaration

local function handleDeath()
    if isDowned then
        -- Killed again while already downed — finish them off
        if not isFinishedOff then
            isFinishedOff   = true
            selfReviveReady = false
            sendNUI('endProgress', {})
            notify("~r~You've been finished off. Wait for hospital transfer.")
            TriggerServerEvent('revive:playerFinishedOff')
            startHospitalTimer()
        end
        return
    end

    enterDownedState()
end

enterDownedState = function()
    isDowned        = true
    isFinishedOff   = false
    selfReviveReady = false
    animLoopActive  = true
    downedVersion   = downedVersion + 1

    local myVersion = downedVersion
    local ped       = PlayerPedId()

    SetPedCanRagdoll(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)

    -- Play writhe anim — ped is dead so anim plays on ragdolled body
    loadAnimDict(Config.DownedAnim.dict)
    TaskPlayAnim(ped, Config.DownedAnim.dict, Config.DownedAnim.anim,
        8.0, -1.0, -1, 1, 0, false, false, false)

    -- HUD appears immediately
    sendNUI('startProgress', {
        label    = "⚕  Downed — wait to recover...",
        duration = Config.SelfReviveTimer * 1000,
        color    = Config.BarColor,
    })

    TriggerServerEvent('revive:playerDowned')

    SetTimeout(Config.SelfReviveTimer * 1000, function()
        if downedVersion ~= myVersion then return end
        if isDowned and not isFinishedOff then
            sendNUI('endProgress', {})
            selfReviveReady = true
            notify("~g~Press [E] to get up.")
        end
    end)
end

-- ============================================================
--  Leave downed state
-- ============================================================

function leaveDownedState(playGetUpAnim, toHospital)
    animLoopActive  = false
    isDowned        = false
    isFinishedOff   = false
    selfReviveReady = false

    sendNUI('endProgress', {})
    sendNUI('hideHint', {})

    local ped     = PlayerPedId()
    local coords  = toHospital and vector3(Config.HospitalSpawn.x, Config.HospitalSpawn.y, Config.HospitalSpawn.z)
                               or GetEntityCoords(ped)
    local heading = toHospital and Config.HospitalSpawn.heading or GetEntityHeading(ped)

    SetEntityInvincible(ped, true)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)

    local waited = 0
    repeat
        Wait(50)
        waited = waited + 50
        ped = PlayerPedId()
    until (not IsEntityDead(ped) and GetEntityHealth(ped) > 0) or waited > 3000

    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    SetPedCanRagdoll(ped, true)

    if toHospital then
        -- Teleport to hospital, no get-up anim
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(ped, heading)
        notify("~b~You've been taken to the hospital.")
    elseif playGetUpAnim then
        loadAnimDict(Config.GetUpAnim.dict)
        TaskPlayAnim(ped, Config.GetUpAnim.dict, Config.GetUpAnim.anim,
            4.0, -1.0, Config.GetUpAnimDuration, 0, 0, false, false, false)
        Wait(Config.GetUpAnimDuration)
        ClearPedTasks(ped)
    end

    SetEntityInvincible(ped, false)

    TriggerServerEvent('revive:playerRevived')
end

-- ============================================================
--  Death detection — per-frame watcher
-- ============================================================

CreateThread(function()
    local wasAlive = true
    while true do
        Wait(0)
        local ped       = PlayerPedId()
        local isDeadNow = IsEntityDead(ped)

        if isDeadNow and wasAlive and not isDowned then
            wasAlive = false
            -- Wait for ragdoll to play naturally, then enter downed state
            CreateThread(function()
                Wait(Config.RagdollDelay)
                handleDeath()
            end)
        elseif not isDeadNow and not wasAlive and not isDowned then
            -- Ped was resurrected (e.g. vMenu ped reload) while not downed — just reset
            wasAlive = true
        elseif not isDeadNow and not wasAlive and isDowned then
            -- Ped was externally resurrected while downed (vMenu ped model reload)
            -- Re-apply downed anim immediately to fight it
            wasAlive = true
            local p = PlayerPedId()
            loadAnimDict(Config.DownedAnim.dict)
            TaskPlayAnim(p, Config.DownedAnim.dict, Config.DownedAnim.anim,
                8.0, -1.0, -1, 1, 0, false, false, false)
        end
    end
end)

-- ============================================================
--  Banned weapon enforcement
-- ============================================================

CreateThread(function()
    while true do
        Wait(2000)
        if not isDowned then
            local ped = PlayerPedId()
            for _, hash in ipairs(Config.BannedWeapons) do
                if HasPedGotWeapon(ped, hash, false) then
                    RemoveWeaponFromPed(ped, hash)
                end
            end
        end
    end
end)

-- ============================================================
--  Spawnmanager — let basic-gamemode handle initial spawn,
--  disable auto-respawn after first spawn
-- ============================================================

local hasSpawnedIn = false

AddEventHandler('onClientMapStart', function()
    if hasSpawnedIn then return end
    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
end)

AddEventHandler('playerSpawned', function()
    if hasSpawnedIn then return end
    hasSpawnedIn = true
    exports.spawnmanager:setAutoSpawn(false)
end)

CreateThread(function()
    while true do
        Wait(5000)
        if hasSpawnedIn then
            exports.spawnmanager:setAutoSpawn(false)
        end
    end
end)

local lastHintText = ""

CreateThread(function()
    while true do
        Wait(1500)  -- refresh hint every 1.5s, NUI auto-hides after 2s
        if isDowned then
            local text
            if isFinishedOff and selfReviveReady then
                text = "Press ~b~[E]~w~ to go to the hospital"
            elseif isFinishedOff then
                text = "~r~Finished off — awaiting hospital transfer..."
            elseif selfReviveReady then
                text = "Press ~g~[E]~w~ to get up  |  Press ~r~[R]~w~ to finish yourself off"
            else
                text = "Press ~r~[R]~w~ to finish yourself off ~r~(hospital respawn)"
            end
            if text ~= lastHintText then
                lastHintText = text
            end
            sendNUI('showHint', { text = text })
        else
            if lastHintText ~= "" then
                lastHintText = ""
                sendNUI('hideHint', {})
            end
        end
    end
end)



CreateThread(function()
    while true do
        Wait(0)

        -- Self-revive or self finish-off while downed
        if isDowned then

            if selfReviveReady and IsControlJustPressed(0, Config.ReviveKey) then
                selfReviveReady = false
                if isFinishedOff then
                    notify("~b~Going to hospital...")
                    CreateThread(function()
                        leaveDownedState(false, true)
                    end)
                else
                    notify("~w~Getting up...")
                    CreateThread(function()
                        leaveDownedState(true, false)
                    end)
                end
            end

            if not isFinishedOff and IsDisabledControlJustPressed(0, Config.FinishOffKey) then
                isFinishedOff   = true
                selfReviveReady = false
                sendNUI('endProgress', {})
                notify("~r~You've finished yourself off. Wait for hospital transfer.")
                TriggerServerEvent('revive:playerFinishedOff')
                startHospitalTimer()
            end
        end

        -- Scan for nearby downed players
        if not isDowned then
            local ped   = PlayerPedId()
            local myPos = GetEntityCoords(ped)
            nearbyDowned = nil

            for _, localId in ipairs(GetActivePlayers()) do
                local targetPed = GetPlayerPed(localId)
                if targetPed ~= ped and DoesEntityExist(targetPed) then
                    local serverId = GetPlayerServerId(localId)
                    local entry    = downedList[serverId] or downedList[tostring(serverId)]
                    if entry then
                        local dist = #(myPos - GetEntityCoords(targetPed))
                        if dist <= Config.ReviveDistance then
                            nearbyDowned = {
                                ped          = targetPed,
                                serverId     = serverId,
                                localId      = localId,
                                isFinishedOff = entry.isFinishedOff or false,
                            }
                            break
                        end
                    end
                end
            end

            if nearbyDowned then
                if nearbyDowned.isFinishedOff then
                    DrawText3D(GetEntityCoords(nearbyDowned.ped), "~r~Finished Off — Staff Revive Only")
                else
                    DrawText3D(GetEntityCoords(nearbyDowned.ped), "~g~[E] Revive   ~r~[R] Finish Off")
                    if not isReviving then
                        if IsControlJustPressed(0, Config.ReviveKey) then
                            startReviving(nearbyDowned)
                        end
                        if IsControlJustPressed(0, Config.FinishOffKey) then
                            TriggerServerEvent('revive:finishOffPlayer', nearbyDowned.serverId)
                            notify("~r~Player finished off.")
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
--  Reviving another player
-- ============================================================

local reviveAborted = false  -- set externally to kill an in-progress revive immediately

local function cancelRevive()
    if not isReviving then return end
    reviveAborted = true  -- loop sees this and breaks next frame
end

function startReviving(target)
    if isReviving then return end
    isReviving    = true
    reviveAborted = false
    emoteBlocked  = true

    local ped = PlayerPedId()

    loadAnimDict(Config.ReviveAnim.dict)
    TaskPlayAnim(ped, Config.ReviveAnim.dict, Config.ReviveAnim.anim,
        2.0, -1.0, Config.ReviveDuration, 1, 0, false, false, false)

    sendNUI('startProgress', {
        label    = "⚕  Reviving player...",
        duration = Config.ReviveDuration,
        color    = Config.ReviveBarColor,
    })

    notify("~r~[Escape] or [X] to cancel revive.")

    CreateThread(function()
        local startTime  = GetGameTimer()
        local cancelledByInput = false

        while (GetGameTimer() - startTime) < Config.ReviveDuration do
            Wait(0)

            -- External abort (target was revived/admin revived)
            if reviveAborted then
                break
            end

            -- Manual cancel via Escape or X (use Disabled variant — emoteBlocked disables control 73)
            if IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 73) then
                cancelledByInput = true
                break
            end

            -- Anim re-enforcer every ~500ms
            if (GetGameTimer() - startTime) % 500 < 16 then
                if not IsEntityPlayingAnim(ped, Config.ReviveAnim.dict, Config.ReviveAnim.anim, 3) then
                    loadAnimDict(Config.ReviveAnim.dict)
                    TaskPlayAnim(ped, Config.ReviveAnim.dict, Config.ReviveAnim.anim,
                        2.0, -1.0, Config.ReviveDuration, 1, 0, false, false, false)
                end
            end
        end

        -- Always clean up immediately
        emoteBlocked  = false
        isReviving    = false
        local wasAborted = reviveAborted
        reviveAborted = false
        ClearPedTasksImmediately(ped)
        sendNUI('endProgress', {})

        if cancelledByInput or wasAborted then
            if cancelledByInput then notify("~r~Revive cancelled.") end
            return
        end

        local stillValid = false
        if nearbyDowned and nearbyDowned.serverId == target.serverId then
            local dist = #(GetEntityCoords(ped) - GetEntityCoords(target.ped))
            if dist <= Config.ReviveDistance + 1.0 then
                stillValid = true
            end
        end

        if stillValid then
            TriggerServerEvent('revive:revivePlayer', target.serverId)
            notify("~g~Player revived!")
        else
            notify("~r~Target moved — revive failed.")
        end
    end)
end

-- ============================================================
--  Server → Client events
-- ============================================================

RegisterNetEvent('revive:youAreRevived', function()
    if isDowned then
        -- Always revive in-place regardless of finished-off state.
        -- Hospital transport only happens when the player chooses it themselves.
        leaveDownedState(true, false)
        notify("~g~You were revived!")
    end
    cancelRevive()
end)

-- Fired to everyone when a player is revived — stops any in-progress revive animations
RegisterNetEvent('revive:reviveCancelled', function(revivedServerId)
    if isReviving and nearbyDowned and nearbyDowned.serverId == revivedServerId then
        cancelRevive()
    end
end)

RegisterNetEvent('revive:youAreFinishedOff', function()
    if isDowned and not isFinishedOff then
        isFinishedOff   = true
        selfReviveReady = false
        sendNUI('endProgress', {})
        notify("~r~You've been finished off. Wait for hospital transfer.")
        startHospitalTimer()
    end
end)

-- ============================================================
--  3D text helper
-- ============================================================

function DrawText3D(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 0.8)
    if onScreen then
        SetTextScale(0.0, 0.45)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropShadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(screenX, screenY)
    end
end
