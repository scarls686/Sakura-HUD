-- lua/autorun/server/sv_sakura_hitmarker.lua

util.AddNetworkString("Sakura_Hit")
util.AddNetworkString("Sakura_Kill")

local headshot_cache = {}
local armor_cache = {}
local npc_hit_frame = {}
local last_hit_frame = {} -- 单帧限流：[atkIdx_vicIdx] = 上次触发帧数
local npc_kill_sent = {}  -- [atkIdx_vicIdx] = true，OnNPCKilled 已发击杀时标记

local function CheckHitFrame(attacker, ent)
    local frameKey = attacker:EntIndex() .. "_" .. ent:EntIndex()
    local currentFrame = FrameNumber()
    if last_hit_frame[frameKey] == currentFrame then return false end
    last_hit_frame[frameKey] = currentFrame
    return true
end

local function CleanCache(ent)
    if IsValid(ent) then
        local idx = ent:EntIndex()
        headshot_cache[idx] = nil
        armor_cache[idx] = nil
        npc_hit_frame[idx] = nil
    end
end

-- 必须在 npcarmor hook 之前读取状态
hook.Add("ScaleNPCDamage", "Sakura_CheckNPCState", function(npc, hitgroup, dmginfo)
    local idx = npc:EntIndex()
    headshot_cache[idx] = (hitgroup == HITGROUP_HEAD)
    if hitgroup == HITGROUP_HEAD then
        armor_cache[idx] = npc:GetNWBool("npcarmor_helmet_enabled", false)
    else
        armor_cache[idx] = npc:GetNWBool("npcarmor_enabled", false) and
                           npc:GetNWBool("npcarmor_plated", false)
    end
    npc_hit_frame[idx] = true
end)

-- ME Shield 兼容：缓存爆头/护甲 状态并处理护盾吸收
hook.Add("EntityTakeDamage", "Sakura_CachePlayerState", function(ent, dmginfo)
    if not ent:IsPlayer() then return end
    local idx = ent:EntIndex()
    headshot_cache[idx] = (ent:LastHitGroup() == HITGROUP_HEAD)
    armor_cache[idx] = (ent:Armor() > 0)

    -- ME_ShieldFullBlock=true 表示护盾完全吸收
    if ent.ME_ShieldFullBlock then
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent and CheckHitFrame(attacker, ent) then
            armor_cache[idx] = true  -- 命中护盾 = 护甲命中，显示护甲颜色
            net.Start("Sakura_Hit")
            net.WriteBool(headshot_cache[idx])
            net.WriteBool(true)
            net.Send(attacker)
        end
    end

    -- ME Shield 生命门触发
    if ent.ME_HealthGateTriggered then
        ent.ME_HealthGateTriggered = false
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent and CheckHitFrame(attacker, ent) then
            net.Start("Sakura_Hit")
            net.WriteBool(headshot_cache[idx])
            net.WriteBool(false)
            net.Send(attacker)
        end
    end

    -- 生命门无敌期命中
    if ent.ME_HealthGateBlock then
        ent.ME_HealthGateBlock = false
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent and CheckHitFrame(attacker, ent) then
            net.Start("Sakura_Hit")
            net.WriteBool(headshot_cache[idx])
            net.WriteBool(false)
            net.Send(attacker)
        end
    end
end)

hook.Add("PlayerHurt", "Sakura_PlayerHit", function(victim, attacker, healthRemaining)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end
    if not CheckHitFrame(attacker, victim) then return end

    local idx = victim:EntIndex()

    if healthRemaining <= 0 then
        net.Start("Sakura_Kill")
    else
        net.Start("Sakura_Hit")
    end
    net.WriteBool(headshot_cache[idx] or false)
    net.WriteBool(armor_cache[idx] or false)
    net.Send(attacker)
end)

hook.Add("PostEntityTakeDamage", "Sakura_NPCHitProcess", function(ent, dmginfo, took)
    if ent:IsPlayer() then return end
    local idx = ent:EntIndex()

    -- npcarmor 护甲吸收时 took = false，用 npc_hit_frame 确保触发
    local was_hit = took or npc_hit_frame[idx]
    npc_hit_frame[idx] = nil
    if not was_hit then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == ent then return end
    if not (ent:IsNPC() or ent:IsNextBot()) then return end
    if not CheckHitFrame(attacker, ent) then return end

    -- 推迟到下一帧发送：此时 OnNPCKilled 已执行完毕，可通过 npc_kill_sent 判断是否为击杀
    local killKey = attacker:EntIndex() .. "_" .. idx
    local hs = headshot_cache[idx] or false
    local ar = armor_cache[idx] or false
    timer.Simple(0, function()
        if not IsValid(attacker) then return end
        if npc_kill_sent[killKey] then
            npc_kill_sent[killKey] = nil
            return  -- OnNPCKilled 已发 Sakura_Kill，不重复发命中
        end
        net.Start("Sakura_Hit")
        net.WriteBool(hs)
        net.WriteBool(ar)
        net.Send(attacker)
    end)
end)

hook.Add("OnNPCKilled", "Sakura_KillNPC", function(victim, attacker, inflictor)
    if type(attacker) == "Player" and IsValid(attacker) and victim ~= attacker then
        local idx = victim:EntIndex()
        -- 标记此次击杀，PostEntityTakeDamage 的定时器会检查此标记并跳过命中反馈
        npc_kill_sent[attacker:EntIndex() .. "_" .. idx] = true
        net.Start("Sakura_Kill")
        net.WriteBool(headshot_cache[idx] or false)
        net.WriteBool(armor_cache[idx] or false)
        net.Send(attacker)
    end
    CleanCache(victim)
end)

hook.Add("EntityRemoved", "Sakura_CleanCache", CleanCache)
