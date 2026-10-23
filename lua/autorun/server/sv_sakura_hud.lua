-- 服务端：中毒状态检测和同步

if CLIENT then return end

util.AddNetworkString("SakuraHUD_PoisonSync")

local playerPoisonEnd = {}
local playerPoisonState = {}

local cv_poisonDuration = CreateConVar("sakura_hud_poison_duration", "10", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "神经毒/麻痹的HUD提示时长；原版毒伤跟随引擎状态，0关闭所有中毒提示（仅影响视觉效果）", 0, 30)

local function SendPoisonState(ply, poisoned, force)
    if not force and playerPoisonState[ply] == poisoned then return end

    playerPoisonState[ply] = poisoned
    net.Start("SakuraHUD_PoisonSync")
        net.WriteBool(poisoned)
    net.Send(ply)
end

local function ClearPoisonState(ply, force)
    playerPoisonEnd[ply] = nil
    SendPoisonState(ply, false, force)
end

local function IsEnginePoisoned(ply)
    local damageType = ply:GetInternalVariable("m_bitsDamageType")
    local poisonDamage = ply:GetInternalVariable("m_nPoisonDmg")
    local poisonRestored = ply:GetInternalVariable("m_nPoisonRestored")

    if not isnumber(damageType) or not isnumber(poisonDamage) or not isnumber(poisonRestored) then
        return false
    end

    -- 与引擎 m_bPoisoned 的条件一致，生命阈值固定为 100。
    return bit.band(damageType, DMG_POISON) ~= 0
        and poisonDamage > poisonRestored
        and ply:Health() < 100
end

local function UpdatePoisonState(ply)
    if not ply:Alive() or cv_poisonDuration:GetFloat() <= 0 then
        ClearPoisonState(ply)
        return
    end

    local endTime = playerPoisonEnd[ply]
    if endTime and CurTime() >= endTime then
        playerPoisonEnd[ply] = nil
        endTime = nil
    end

    SendPoisonState(ply, IsEnginePoisoned(ply) or endTime ~= nil)
end

-- 热重载时移除原来的伤害前置检测。
hook.Remove("EntityTakeDamage", "SakuraHUD_PoisonDetect")
hook.Add("PostEntityTakeDamage", "SakuraHUD_PoisonDetect", function(target, dmg, took)
    if not took or not IsValid(target) or not target:IsPlayer() or not target:Alive() then return end
    if dmg:GetDamage() <= 0 then return end

    local duration = cv_poisonDuration:GetFloat()
    if duration <= 0 then return end

    if dmg:IsDamageType(DMG_NERVEGAS) or dmg:IsDamageType(DMG_PARALYZE) then
        playerPoisonEnd[target] = CurTime() + duration
    end

    UpdatePoisonState(target)
end)

timer.Create("SakuraHUD_PoisonCheck", 0.1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        UpdatePoisonState(ply)
    end
end)

cvars.AddChangeCallback("sakura_hud_poison_duration", function(_, _, value)
    if (tonumber(value) or 0) > 0 then return end

    for _, ply in ipairs(player.GetAll()) do
        ClearPoisonState(ply)
    end
end, "SakuraHUD_PoisonDisable")

hook.Add("PostPlayerDeath", "SakuraHUD_PoisonDeath", function(ply)
    ClearPoisonState(ply)
end)

hook.Add("PlayerSpawn", "SakuraHUD_PoisonSpawn", function(ply)
    ClearPoisonState(ply, true)
end)

hook.Add("PlayerDisconnected", "SakuraHUD_PoisonCleanup", function(ply)
    playerPoisonEnd[ply] = nil
    playerPoisonState[ply] = nil
end)

hook.Add("PlayerInitialSpawn", "SakuraHUD_PoisonInit", function(ply)
    ClearPoisonState(ply, true)
end)
