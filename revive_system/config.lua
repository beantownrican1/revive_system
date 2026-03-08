Config = {}

-- Timer before a downed player can self-revive (seconds)
Config.SelfReviveTimer = 60

-- How long the "get up" animation takes before control is restored (ms)
Config.GetUpAnimDuration = 4000

-- Cooldown after getting up before weapons are re-enabled (seconds)
Config.WeaponCooldown = 8

-- How close a player needs to be to revive another (metres)
Config.ReviveDistance = 2.0

-- How long it takes to revive another player (ms)
Config.ReviveDuration = 8000

-- Finish-off key (default R)
Config.FinishOffKey = 45  -- R key

-- Revive key (default E)
Config.ReviveKey = 38     -- E key

-- Hospital spawn location (where finished-off players are sent)
Config.HospitalSpawn = {
    x = 357.68,
    y = -1419.86,
    z = 32.50,
    heading = 180.0
}

-- Downed animation dict/name (player lying on ground)
Config.DownedAnim = {
    dict = "combat@damage@writhe",
    anim = "writhe_loop"
}

-- Revive animation performed by the reviver
Config.ReviveAnim = {
    dict = "mini@cpr@char_a@cpr_str",
    anim = "cpr_pumpchest"
}

-- Get-up animation (self revive)
Config.GetUpAnim = {
    dict = "move_crawlback@crawl_to_stand",
    anim = "crawl_to_stand"
}

-- How long the ragdoll plays before downed state locks in (ms)
-- Keep this short — long ragdoll windows allow the ped to clip through geometry
Config.RagdollDelay = 800

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
