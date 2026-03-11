-- ============================================================
--  REVIVE SYSTEM - SERVER
-- ============================================================

local downedPlayers = {}

local function broadcastDownedList()
    TriggerClientEvent('revive:syncDownedList', -1, downedPlayers)
end

-- ============================================================
--  Player goes down
-- ============================================================

RegisterNetEvent('revive:playerDowned', function()
    local src = source
    if downedPlayers[src] then return end  -- ignore duplicate calls
    downedPlayers[src] = { isFinishedOff = false }
    Player(src).state:set('isDowned', true, true)
    broadcastDownedList()
    print(("[REVIVE] Player %s downed."):format(src))
end)

-- ============================================================
--  Player revived
-- ============================================================

RegisterNetEvent('revive:playerRevived', function()
    local src = source
    downedPlayers[src] = nil
    Player(src).state:set('isDowned', false, true)
    broadcastDownedList()
    print(("[REVIVE] Player %s recovered."):format(src))
end)

-- ============================================================
--  Finish off — self or by nearby player
-- ============================================================

-- Downed player finishes themselves off
RegisterNetEvent('revive:playerFinishedOff', function()
    local src = source
    if downedPlayers[src] and not downedPlayers[src].isFinishedOff then
        downedPlayers[src].isFinishedOff = true
        broadcastDownedList()
        print(("[REVIVE] Player %s finished themselves off."):format(src))
    end
end)

-- Another player finishes off a downed player
RegisterNetEvent('revive:finishOffPlayer', function(targetServerId)
    local src    = source
    local target = tonumber(targetServerId)
    if downedPlayers[target] and not downedPlayers[target].isFinishedOff then
        downedPlayers[target].isFinishedOff = true
        TriggerClientEvent('revive:youAreFinishedOff', target)
        broadcastDownedList()
        print(("[REVIVE] Player %s finished off by %s."):format(target, src))
    end
end)

-- ============================================================
--  Reviver triggers revive on target
-- ============================================================

RegisterNetEvent('revive:revivePlayer', function(targetServerId)
    local src    = source
    local target = tonumber(targetServerId)

    if not downedPlayers[target] then return end
    -- Finished-off players can only be revived by staff (/revive command)
    if downedPlayers[target].isFinishedOff then return end

    -- Server-side proximity check — prevents any client sending this event
    -- for a target they are not actually standing next to.
    local srcPed    = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not srcPed or srcPed == 0 or not targetPed or targetPed == 0 then return end
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > 5.0 then return end  -- generous cap; client checks 2m + 1m buffer

    TriggerClientEvent('revive:youAreRevived', target, false)  -- byStaff = false
    TriggerClientEvent('revive:reviveCancelled', -1, target)  -- stop any in-progress revive anims
    downedPlayers[target] = nil
    Player(target).state:set('isDowned', false, true)
    broadcastDownedList()
    print(("[REVIVE] Player %s revived by %s."):format(target, src))
end)

-- ============================================================
--  Staff command: /revive [id]
--  Requires Staff Discord role.
-- ============================================================

RegisterCommand('revive', function(src, args)
    if src ~= 0 and not exports['discord_perms']:IsRolePresent(src, "Staff") then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 80, 80},
            args  = {"[REVIVE]", "You don't have permission to use this command."}
        })
        return
    end

    local target

    if args[1] then
        target = tonumber(args[1])
        if not target then
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 200, 80},
                args  = {"[REVIVE]", "Usage: /revive [player id]"}
            })
            return
        end
    else
        if src == 0 then
            print("[REVIVE] Console must specify a player ID: revive <id>")
            return
        end
        local callerPed    = GetPlayerPed(src)
        local callerCoords = GetEntityCoords(callerPed)
        local closest, closestDist = nil, math.huge

        for id, _ in pairs(downedPlayers) do
            local p = GetPlayerPed(id)
            if p and p ~= 0 then
                local dist = #(callerCoords - GetEntityCoords(p))
                if dist < closestDist then
                    closestDist = dist
                    closest     = id
                end
            end
        end

        if not closest then
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 200, 80},
                args  = {"[REVIVE]", "No downed players nearby."}
            })
            return
        end
        target = closest
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 200, 80},
            args  = {"[REVIVE]", ("Player %d not found."):format(target)}
        })
        return
    end

    -- Always clean up regardless of whether they were registered downed
    local wasInList = downedPlayers[target] ~= nil
    downedPlayers[target] = nil
    Player(target).state:set('isDowned', false, true)

    TriggerClientEvent('revive:youAreRevived', target, true)  -- byStaff = true
    TriggerClientEvent('revive:reviveCancelled', -1, target)
    broadcastDownedList()

    local targetName = GetPlayerName(target) or tostring(target)
    local callerName = src == 0 and "Console" or (GetPlayerName(src) or tostring(src))
    print(("[REVIVE] %s was revived by staff (%s). Was in list: %s"):format(targetName, callerName, tostring(wasInList)))

    TriggerClientEvent('chat:addMessage', src, {
        color = {80, 255, 120},
        args  = {"[REVIVE]", ("Revived %s."):format(targetName)}
    })
end, false)

-- ============================================================
--  Cleanup on disconnect
-- ============================================================

AddEventHandler('playerDropped', function()
    local src = source
    if downedPlayers[src] then
        downedPlayers[src] = nil
        Player(src).state:set('isDowned', false, true)
        broadcastDownedList()
    end
end)
