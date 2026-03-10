-- ============================================================
--  REVIVE SYSTEM - CLIENT
-- ============================================================

local isDowned        = false
local isFinishedOff   = false  -- true if killed again while downed
local selfReviveReady = false
local isReviving      = false
local animLoopActive  = false
local nearbyDowned    = nil
local downedVersion   = 0
local originalRelGroup = nil   -- stored so we can restore on revive

-- Downed list synced from server
local downedList = {}

-- ============================================================
--  Helpers
-- ============================================================

local function loadAnimDict(dict)
    local waited = 0
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
        waited = waited + 10
        if waited > 1500 then
            -- Dict doesn't exist or failed to stream; bail out rather than
            -- infinite-looping and freezing the calling coroutine.
            break
        end
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
        duration = Config.HospitalTimer * 1000,
        color    = { r = 180, g = 0, b = 0, a = 220 },
    })
    SetTimeout(Config.HospitalTimer * 1000, function()
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
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 244, true)
            DisableControlAction(0, 36,  true) 
            DisableControlAction(0, 244, true) 
        end
    end
end)

local function switchToFinishedOffAnim()
    local ped = PlayerPedId()
    loadAnimDict(Config.FinishedOffAnim.dict)
    TaskPlayAnim(ped, Config.FinishedOffAnim.dict, Config.FinishedOffAnim.anim,
        4.0, -1.0, -1, 1, 0, false, false, false)
end

-- Anim re-enforcer — keeps the correct anim playing throughout the downed state
CreateThread(function()
    while true do
        Wait(1000)
        if isDowned and animLoopActive and not isReviving then
            local ped      = PlayerPedId()
            local animDict = isFinishedOff and Config.FinishedOffAnim.dict or Config.DownedAnim.dict
            local animName = isFinishedOff and Config.FinishedOffAnim.anim or Config.DownedAnim.anim
            if not IsEntityPlayingAnim(ped, animDict, animName, 3) then
                loadAnimDict(animDict)
                -- Re-check: leaveDownedState may have run during the async dict load
                if isDowned and animLoopActive then
                    TaskPlayAnim(ped, animDict, animName, 8.0, -1.0, -1, 1, 0, false, false, false)
                end
            end
        end
    end
end)

-- ============================================================
--  Enter downed state
--  Called after ragdoll delay. Resurrects the ped in-place so
--  TaskPlayAnim and SetPedCanRagdoll work on a live entity.
-- ============================================================

local enterDownedState  -- forward declaration

local function handleDeath()
    -- Death watcher only calls this when not isDowned; the isDowned path
    -- is handled separately in the death watcher (death-while-downed branch).
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

    -- Capture position while still ragdolled
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    SetPedDropsWeaponsWhenDead(ped, false)

    -- Resurrect in-place so the ped is a live entity.
    -- TaskPlayAnim does not work reliably on a dead ped, and
    -- SetPedCanRagdoll has no effect on one either.
    SetEntityInvincible(ped, true)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)

    local waited = 0
    repeat
        Wait(50)
        waited = waited + 50
        ped = PlayerPedId()
    until (not IsEntityDead(ped) and GetEntityHealth(ped) > 0) or waited > 3000

    -- If we were revived by staff during the resurrection wait, abort
    if not isDowned then return end

    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    SetPedCanRagdoll(ped, false)

    -- Change relationship group so NPCs (zombies) stop targeting the downed player.
    -- Restore to original group on revive.
    originalRelGroup = GetPedRelationshipGroupHash(ped)
    SetPedRelationshipGroupHash(ped, GetHashKey("CIVMALE"))
    SetEntityInvincible(ped, false)  -- rely on NPC ignoring, not invincibility

    -- Now play the writhe anim on the live ped
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
    if not isDowned then return end  -- guard against duplicate/spurious calls
    animLoopActive  = false
    isDowned        = false
    isFinishedOff   = false
    selfReviveReady = false

    sendNUI('endProgress', {})
    sendNUI('hideHint', {})

    -- Ped is already alive (resurrected in enterDownedState).
    -- Just restore state, re-enable ragdoll, and handle location.
    local ped = PlayerPedId()

    -- Pre-load the get-up dict NOW while the writhe is still playing so
    -- TaskPlayAnim can fire the instant ClearPedTasks stops the writhe.
    -- Without this, there is a visible stand-up gap while the dict streams in.
    if playGetUpAnim then
        loadAnimDict(Config.GetUpAnim.dict)
    end

    ClearPedTasks(ped)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    SetPedCanRagdoll(ped, true)
    SetEntityInvincible(ped, false)

    -- Restore original relationship group (re-enables NPC targeting)
    if originalRelGroup then
        SetPedRelationshipGroupHash(ped, originalRelGroup)
        originalRelGroup = nil
    end

    -- Restore full player control — GTA can leave the player in a partial
    -- death state (blocking menus like Escape / vMenu) without this
    SetPlayerControl(PlayerId(), true, 0)

    if toHospital then
        DoScreenFadeOut(800)
        Wait(900)  -- slight extra buffer to ensure fully black before teleporting
        SetEntityCoords(ped, Config.HospitalSpawn.x, Config.HospitalSpawn.y, Config.HospitalSpawn.z, false, false, false, true)
        SetEntityHeading(ped, Config.HospitalSpawn.heading)
        notify("~b~You've been taken to the hospital.")
        DoScreenFadeIn(1000)
    elseif playGetUpAnim then
        TaskPlayAnim(ped, Config.GetUpAnim.dict, Config.GetUpAnim.anim,
            4.0, -1.0, Config.GetUpAnimDuration, 0, 0, false, false, false)
        Wait(Config.GetUpAnimDuration)
        ClearPedTasks(ped)
    end

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
            -- Brief pause for the initial death reaction, then lock into writhe anim
            CreateThread(function()
                Wait(Config.RagdollDelay)
                handleDeath()
            end)
        elseif isDeadNow and wasAlive and isDowned and not isFinishedOff then
            -- Died again while downed → ragdoll plays, then transition to finished-off
            wasAlive = false
            CreateThread(function()
                Wait(Config.RagdollDelay)
                if not isDowned or isFinishedOff then return end
                isFinishedOff   = true
                selfReviveReady = false
                sendNUI('endProgress', {})
                notify("~r~You're critically injured. Wait for hospital transfer.")
                -- Fade before resurrection so the stand-up snap is never visible
                DoScreenFadeOut(500)
                Wait(600)
                -- Re-resurrect in-place for the passout animation
                local p       = PlayerPedId()
                local coords  = GetEntityCoords(p)
                local heading = GetEntityHeading(p)
                SetPedDropsWeaponsWhenDead(p, false)
                SetEntityInvincible(p, true)
                NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                local w = 0
                repeat Wait(50); w = w + 50; p = PlayerPedId()
                until (not IsEntityDead(p) and GetEntityHealth(p) > 0) or w > 3000
                -- Guard: if staff revived us during the resurrection wait, bail out
                if not isDowned or not isFinishedOff then
                    DoScreenFadeIn(500)
                    return
                end
                SetEntityHealth(p, 200)
                SetPedCanRagdoll(p, false)
                SetPedRelationshipGroupHash(p, GetHashKey("CIVMALE"))
                -- Keep invincible — they are finished off, nothing should alter their state.
                -- leaveDownedState clears this when they go to hospital.
                -- Do NOT call ClearPedTasks here — the watcher's resurrection-detection branch
                -- already applies the passout anim; ClearPedTasks would cancel it for one frame
                -- causing a visible stand-up flash ("revived again" visual).
                switchToFinishedOffAnim()
                DoScreenFadeIn(500)
                TriggerServerEvent('revive:playerFinishedOff')
                startHospitalTimer()
            end)
        elseif not isDeadNow and not wasAlive and not isDowned then
            -- Ped was resurrected (e.g. vMenu ped reload) while not downed — just reset
            wasAlive = true
        elseif not isDeadNow and not wasAlive and isDowned then
            -- Ped resurrected while downed (our own resurrection or vMenu ped reload)
            -- Re-apply the correct anim for the current state
            wasAlive = true
            local p        = PlayerPedId()
            local animDict = isFinishedOff and Config.FinishedOffAnim.dict or Config.DownedAnim.dict
            local animName = isFinishedOff and Config.FinishedOffAnim.anim or Config.DownedAnim.anim
            loadAnimDict(animDict)
            -- Re-check: staff may have revived us during the async dict load
            if isDowned then
                TaskPlayAnim(p, animDict, animName,
                    8.0, -1.0, -1, 1, 0, false, false, false)
            end
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
                text = "Press ~g~[E]~w~ to get up  |  Press ~r~[R]~w~ to give up"
            else
                text = "Press ~r~[R]~w~ to give up ~r~(leads to hospital)"
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
                -- Kill the ped — the death-while-downed watcher handles the
                -- finished-off transition naturally after the ragdoll delay.
                selfReviveReady = false
                sendNUI('endProgress', {})
                notify("~r~You've succumbed to your injuries...")
                SetEntityHealth(PlayerPedId(), 0)
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
                    DrawText3D(GetEntityCoords(nearbyDowned.ped), "~g~[E] Revive")
                    if not isReviving and IsControlJustPressed(0, Config.ReviveKey) then
                        startReviving(nearbyDowned)
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

        -- Validate against the original target directly, not the current nearbyDowned,
        -- which may have changed or cleared during the revive animation.
        local stillValid = false
        if target.ped and DoesEntityExist(target.ped) then
            local dist = #(GetEntityCoords(ped) - GetEntityCoords(target.ped))
            stillValid = dist <= Config.ReviveDistance + 1.0
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

RegisterNetEvent('revive:youAreRevived', function(byStaff)
    if isDowned then
        -- Staff revive: instant, no get-up animation
        -- Player revive: play the get-up animation
        leaveDownedState(not byStaff, false)
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
        SetEntityInvincible(PlayerPedId(), true)
        switchToFinishedOffAnim()
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
