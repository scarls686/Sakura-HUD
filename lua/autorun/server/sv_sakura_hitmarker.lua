util.AddNetworkString("Sakura_Hit")
util.AddNetworkString("Sakura_Kill")

local headshot_cache, armor_cache, npc_hit_frame = {}, {}, {}
local pending = {}

local function CleanCache(ent)
    if not IsValid(ent) then return end
    local idx = ent:EntIndex()
    headshot_cache[idx], armor_cache[idx], npc_hit_frame[idx] = nil, nil, nil
end

local function QueueFeedback(victim, attacker, head, armor, killed, authoritative, targetID)
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    if not targetID and IsValid(victim) then targetID = victim:GetCreationID() end
    if not targetID then return end
    local list = pending[attacker] or {}
    pending[attacker] = list
    local item = list[targetID]
    if item then
        if killed then
            if not item.killed and (authoritative or not item.authoritative)
                or authoritative and not item.authoritative then
                item.head, item.armor, item.authoritative = head, armor, authoritative
            elseif item.killed and authoritative == item.authoritative then
                item.head, item.armor = item.head or head, item.armor or armor
            end
            item.killed = true
        elseif not item.killed then
            if authoritative and not item.authoritative then
                item.head, item.armor, item.authoritative = head, armor, true
            elseif authoritative == item.authoritative then
                item.head, item.armor = item.head or head, item.armor or armor
            end
        end
        return
    end
    item = {head = head, armor = armor, killed = killed, authoritative = authoritative}
    list[targetID] = item
    -- 合并本 tick 的回调：击杀优先，MES 的结算信息优先于原生缓存。
    timer.Simple(0, function()
        if list[targetID] ~= item then return end
        list[targetID] = nil
        if next(list) == nil and pending[attacker] == list then pending[attacker] = nil end
        if not IsValid(attacker) then return end
        net.Start(item.killed and "Sakura_Kill" or "Sakura_Hit")
        net.WriteBool(item.head)
        net.WriteBool(item.armor)
        net.WriteUInt(targetID, 24) -- GetCreationID 最大为一千万，避免 EntIndex 复用。
        net.Send(attacker)
    end)
end

hook.Add("ScaleNPCDamage", "Sakura_CheckNPCState", function(npc, hitgroup)
    local idx = npc:EntIndex()
    headshot_cache[idx] = hitgroup == HITGROUP_HEAD
    if hitgroup == HITGROUP_HEAD then
        armor_cache[idx] = npc:GetNWBool("npcarmor_helmet_enabled", false)
    else
        armor_cache[idx] = npc:GetNWBool("npcarmor_enabled", false) and npc:GetNWBool("npcarmor_plated", false)
    end
    npc_hit_frame[idx] = true
end)

hook.Add("EntityTakeDamage", "Sakura_CachePlayerState", function(ent)
    if not ent:IsPlayer() then return end
    local idx = ent:EntIndex()
    headshot_cache[idx] = ent:LastHitGroup() == HITGROUP_HEAD
    armor_cache[idx] = ent:Armor() > 0
end)

hook.Add("MEShieldDamageResolved", "Sakura_MES_Hit", function(victim, result)
    CleanCache(victim)
    if not SakuraMES.HasFeedback(result) then return end
    QueueFeedback(victim, result.attacker, result.hitGroup == HITGROUP_HEAD,
        result.shieldDamage > 0 or result.armorDamage > 0 or result.gate == "shield",
        result.killed, true, result.targetID)
end)

hook.Add("PlayerHurt", "Sakura_PlayerHit", function(victim, attacker, healthRemaining)
    if healthRemaining > 0 and SakuraMES.IsTracked(victim) then return end
    local idx = victim:EntIndex()
    QueueFeedback(victim, attacker, headshot_cache[idx] or false, armor_cache[idx] or false, healthRemaining <= 0, false)
end)

hook.Add("PostEntityTakeDamage", "Sakura_NPCHitProcess", function(ent, dmginfo, took)
    if SakuraMES.IsTracked(ent, dmginfo) or not IsValid(ent) or ent:IsPlayer() then return end
    local idx = ent:EntIndex()
    local wasHit = took or npc_hit_frame[idx]
    npc_hit_frame[idx] = nil
    if not wasHit or not (ent:IsNPC() or ent:IsNextBot()) then return end
    QueueFeedback(ent, dmginfo:GetAttacker(), headshot_cache[idx] or false, armor_cache[idx] or false, ent:Health() <= 0, false)
end)

hook.Add("OnNPCKilled", "Sakura_KillNPC", function(victim, attacker)
    local idx = victim:EntIndex()
    QueueFeedback(victim, attacker, headshot_cache[idx] or false, armor_cache[idx] or false, true, false)
    CleanCache(victim)
end)

hook.Add("EntityRemoved", "Sakura_CleanCache", CleanCache)
hook.Add("PlayerDisconnected", "Sakura_ClearPendingHits", function(ply) pending[ply] = nil end)
