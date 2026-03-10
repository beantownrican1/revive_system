Config = {}

-- Timer before a downed player can self-revive (seconds)
Config.SelfReviveTimer = 90

-- Timer before a finished-off player can press E for hospital (seconds)
Config.HospitalTimer = 35

-- How long the "get up" animation takes before control is restored (ms)
Config.GetUpAnimDuration = 5000

-- How close a player needs to be to revive another (metres)
Config.ReviveDistance = 2.0

-- How long it takes to revive another player (ms)
Config.ReviveDuration = 15000

-- Finish-off key (default R)
Config.FinishOffKey = 45  -- R key

-- Revive key (default E)
Config.ReviveKey = 38     -- E key

-- Hospital spawn location (where finished-off players are sent)
-- Front door of Pillbox Hill Medical Center, top/street level
Config.HospitalSpawn = {
    x = 298.48,
    y = -584.28,
    z = 43.26,
    heading = 70.9
}

-- Downed animation dict/name (player lying on ground, writhing)
Config.DownedAnim = {
    dict = "combat@damage@writhe",
    anim = "writhe_loop"
}

-- Animation played when a player is finished off (unconscious/passed out).
-- Uses the sleeping scenario animation — plays as a motionless flat pose on live peds,
-- visually distinct from the active writhe of the downed state.
Config.FinishedOffAnim = {
    dict = "timetable@ron@sleep_4_bed@",
    anim = "idle_a",
}

-- Revive animation performed by the reviver
Config.ReviveAnim = {
    dict = "mini@cpr@char_a@cpr_str",
    anim = "cpr_pumpchest"
}

-- Get-up animation (self revive).
-- Uses the same dict as DownedAnim so it is guaranteed to already be loaded —
-- plays without looping for GetUpAnimDuration then GTA transitions to standing.
Config.GetUpAnim = {
    dict = "combat@damage@writhe",
    anim = "writhe_loop",
}

-- How long the ragdoll plays before downed state locks in (ms)
Config.RagdollDelay = 4000

-- NUI progress bar colors
Config.BarColor = {r = 255, g = 60, b = 60, a = 200}    -- downed timer
Config.ReviveBarColor = {r = 60, g = 200, b = 60, a = 200} -- revive progress

-- Weapons that are disabled on this server (commented out in vMenu permissions).
-- These are stripped from all players every 2 seconds.
Config.BannedWeapons = {
    GetHashKey("WEAPON_ASSAULTRIFLE_MK2"),
    GetHashKey("WEAPON_BULLPUPRIFLE_MK2"),
    GetHashKey("WEAPON_CARBINERIFLE_MK2"),
    GetHashKey("WEAPON_COMBATMG_MK2"),
    GetHashKey("WEAPON_HEAVYSNIPER_MK2"),
    GetHashKey("WEAPON_HOMINGLAUNCHER"),
    GetHashKey("WEAPON_MARKSMANRIFLE"),
    GetHashKey("WEAPON_MARKSMANRIFLE_MK2"),
    GetHashKey("WEAPON_PIPEBOMB"),
    GetHashKey("WEAPON_PISTOL_MK2"),
    GetHashKey("WEAPON_PUMPSHOTGUN_MK2"),
    GetHashKey("WEAPON_RPG"),
    GetHashKey("WEAPON_RAILGUN"),
    GetHashKey("WEAPON_REVOLVER_MK2"),
    GetHashKey("WEAPON_SMG_MK2"),
    GetHashKey("WEAPON_SNSPISTOL_MK2"),
    GetHashKey("WEAPON_SPECIALCARBINE_MK2"),
    GetHashKey("WEAPON_STICKYBOMB"),
    GetHashKey("WEAPON_EMPLAUNCHER"),
    GetHashKey("WEAPON_STUNGUN"),
    GetHashKey("WEAPON_PRECISIONRIFLE"),
    GetHashKey("WEAPON_RAILGUNXM3"),
    GetHashKey("WEAPON_PLASMAPISTOL"),
    GetHashKey("WEAPON_PLASMACARBINE"),
    GetHashKey("WEAPON_PLASMAMINIGUN"),
}
