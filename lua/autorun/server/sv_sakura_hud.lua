-- 服务端：中毒状态检测和同步

if CLIENT then return end

util.AddNetworkString("SakuraHUD_PoisonSync")

local POISON_DAMAGE_TYPES = {
    DMG_POISON = true,      -- 131072 毒伤害（蚁狮工人、毒头蟹）
    DMG_NERVEGAS = true,    -- 65536  神经毒素
    DMG_PARALYZE = true     -- 32768  麻痹毒（等同POISON）
}

local playerPoisonEnd = {}

CreateConVar("sakura_hud_poison_duration", "10", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "HUD中毒效果持续时间（仅影响视觉效果）", 0, 30)

hook.Add("EntityTakeDamage", "SakuraHUD_PoisonDetect", function(target, dmg)
    if not IsValid(target) or not target:IsPlayer() then return end

    local damageType = dmg:GetDamageType()
    local isPoisonDamage = bit.band(damageType, DMG_POISON) > 0
                        or bit.band(damageType, DMG_NERVEGAS) > 0
                        or bit.band(damageType, DMG_PARALYZE) > 0

    if isPoisonDamage then
        local duration = GetConVar("sakura_hud_poison_duration"):GetFloat()
        playerPoisonEnd[target] = CurTime() + duration
        net.Start("SakuraHUD_PoisonSync")
            net.WriteBool(true)
        net.Send(target)
    end
end)

timer.Create("SakuraHUD_PoisonCheck", 0.1, 0, function()
    for ply, endTime in pairs(playerPoisonEnd) do
        if not IsValid(ply) then
            playerPoisonEnd[ply] = nil
        elseif CurTime() >= endTime then
            net.Start("SakuraHUD_PoisonSync")
                net.WriteBool(false)
            net.Send(ply)

            playerPoisonEnd[ply] = nil
        end
    end
end)

hook.Add("PlayerDisconnected", "SakuraHUD_PoisonCleanup", function(ply)
    playerPoisonEnd[ply] = nil
end)

hook.Add("PlayerInitialSpawn", "SakuraHUD_PoisonInit", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            net.Start("SakuraHUD_PoisonSync")
                net.WriteBool(false)
            net.Send(ply)
        end
    end)
end)