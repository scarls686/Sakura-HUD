-- 服务端：受击方向指示 (ME Shield 兼容)

resource.AddSingleFile("materials/sakura/hit_direction_indicator.png")
util.AddNetworkString("Sakura_DamageDirection")

if not ConVarExists("sv_sakura_damage_indicator_enable") then
    CreateConVar("sv_sakura_damage_indicator_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or force disable the damage direction indicator for all players.")
end
local cvarEnable = GetConVar("sv_sakura_damage_indicator_enable")

local playerArmorSnapshot = {}

local function InitPlayerData(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    playerArmorSnapshot[ply] = ply:Armor()
end

local function CleanupPlayerData(ply)
    playerArmorSnapshot[ply] = nil
end

local function ShouldShowIndicator(ply)
    if not cvarEnable:GetBool() then return false end
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local clientEnabled = ply:GetInfoNum("sakura_damage_indicator_enabled", 1)
    return clientEnabled == 1
end

local function SendDamageIndicator(victim, attackerPos, isArmorDamage)
    if not ShouldShowIndicator(victim) then return end
    if not attackerPos then return end
    
    net.Start("Sakura_DamageDirection")
    net.WriteVector(attackerPos)
    net.WriteBool(isArmorDamage)
    net.Send(victim)
end

-- "A_" 前缀：确保在 ME Shield 之前运行（字母排序 A < M）
hook.Add("EntityTakeDamage", "A_Sakura_DamageIndicator_Track", function(victim, dmginfo)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if victim:HasGodMode() then return end
    if not ShouldShowIndicator(victim) then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) then return end

    local dmgAmount = dmginfo:GetDamage()
    if dmgAmount <= 0 then return end

    if not playerArmorSnapshot[victim] then
        InitPlayerData(victim)
    end
    -- 优先使用 inflictor（爆炸物本身）的位置，适用于手雷、火箭弹等范围伤害
    -- 当 inflictor 与 attacker 不同时，说明存在独立的爆炸物实体，其位置更接近实际爆炸点
    local inflictor = dmginfo:GetInflictor()
    local attackerPos
    if IsValid(inflictor) and inflictor ~= attacker then
        attackerPos = inflictor:GetPos()
    elseif attacker:IsPlayer() then
        attackerPos = attacker:EyePos()
    elseif attacker:IsNPC() then
        attackerPos = attacker:EyePos()
    elseif attacker:IsVehicle() and IsValid(attacker:GetDriver()) then
        attackerPos = attacker:GetDriver():EyePos()
    else
        attackerPos = attacker:GetPos()
    end

    local armorBefore = victim:Armor()

    -- 延迟到下一帧检测护甲变化（此时 ME Shield 已处理）
    timer.Simple(0, function()
        if not IsValid(victim) then return end

        local armorAfter = victim:Armor()
        local armorDamaged = (armorAfter < armorBefore)

        SendDamageIndicator(victim, attackerPos, armorDamaged)
        playerArmorSnapshot[victim] = armorAfter
    end)
end)

local lastThinkTime = 0
local THINK_INTERVAL = 0.1

hook.Add("Think", "Sakura_DamageIndicator_ArmorSync", function()
    local curTime = CurTime()
    if curTime - lastThinkTime < THINK_INTERVAL then return end
    lastThinkTime = curTime

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            if not playerArmorSnapshot[ply] then
                InitPlayerData(ply)
            else
                local currentArmor = ply:Armor()
                if currentArmor > playerArmorSnapshot[ply] then
                    playerArmorSnapshot[ply] = currentArmor
                end
            end
        end
    end
end)

hook.Add("PlayerSpawn", "Sakura_DamageIndicator_InitData", function(ply)
    timer.Simple(0.2, function()
        if IsValid(ply) then
            InitPlayerData(ply)
        end
    end)
end)

hook.Add("PlayerDeath", "Sakura_DamageIndicator_OnDeath", function(ply)
    if playerArmorSnapshot[ply] then
        playerArmorSnapshot[ply] = 0
    end
end)

hook.Add("PlayerDisconnected", "Sakura_DamageIndicator_Cleanup", function(ply)
    CleanupPlayerData(ply)
end)

hook.Add("Initialize", "Sakura_DamageIndicator_InitAllPlayers", function()
    timer.Simple(1, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                InitPlayerData(ply)
            end
        end
    end)
end)