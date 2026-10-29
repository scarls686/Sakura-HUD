if SERVER then
    util.AddNetworkString("Sakura_DamageNumber")

    local cv_sv_enable = CreateConVar("sakura_dmgnum_sv_enable", "1", FCVAR_ARCHIVE, "Enable/Disable damage numbers globally", 0, 1)

    local headshot_cache = {}

    local function CleanCache(ent)
        if IsValid(ent) then
            headshot_cache[ent:EntIndex()] = nil
        end
    end

    hook.Add("ScaleNPCDamage", "Sakura_DmgNum_NPCScale", function(npc, hitgroup, dmginfo)
        headshot_cache[npc:EntIndex()] = (hitgroup == HITGROUP_HEAD)
    end)

    -- ScalePlayerDamage 比 EntityTakeDamage 更早且更准确
    hook.Add("ScalePlayerDamage", "Sakura_DmgNum_PlayerScale", function(ply, hitgroup, dmginfo)
        headshot_cache[ply:EntIndex()] = (hitgroup == HITGROUP_HEAD)
    end)

    hook.Add("PostEntityTakeDamage", "Sakura_DmgNum_PostDamage", function(target, dmgInfo, took)
        if SakuraMES.IsTracked(target, dmgInfo) then CleanCache(target); return end
        if not cv_sv_enable:GetBool() then return end
        if not took then return end
        if not IsValid(target) then return end

        if not (target:IsPlayer() or target:IsNPC() or target:IsNextBot()) then return end

        local attacker = dmgInfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() or attacker == target then
            CleanCache(target)
            return
        end

        local damage = math.Round(dmgInfo:GetDamage())
        if damage <= 0 then
            CleanCache(target)
            return
        end

        local isHeadshot = headshot_cache[target:EntIndex()] or false
        local position
        if dmgInfo:IsBulletDamage() then
            position = dmgInfo:GetDamagePosition()
        else
            local obbcenter = target:OBBCenter()
            local obbmaxs = target:OBBMaxs()
            local heightOffset = math.max(obbmaxs.z, 10)
            position = target:LocalToWorld(Vector(obbcenter.x, obbcenter.y, heightOffset))
        end
        net.Start("Sakura_DamageNumber")
            net.WriteFloat(damage)
            net.WriteVector(position)
            net.WriteBool(isHeadshot)
            net.WriteBool(false)
        net.Send(attacker)

        CleanCache(target)
    end)

    hook.Add("MEShieldDamageResolved", "Sakura_MES_DamageNumbers", function(target, result)
        CleanCache(target)
        if not cv_sv_enable:GetBool() then return end
        local attacker = result.attacker
        if not IsValid(attacker) or not attacker:IsPlayer() or attacker == target then return end
        for _, layer in ipairs({{result.shieldDamage, true}, {result.armorDamage, true}, {result.healthDamage, false}}) do
            if layer[1] > 0 then
                net.Start("Sakura_DamageNumber")
                net.WriteFloat(layer[1])
                net.WriteVector(result.position)
                net.WriteBool(result.hitGroup == HITGROUP_HEAD)
                net.WriteBool(layer[2])
                net.Send(attacker)
            end
        end
    end)

    hook.Add("EntityRemoved", "Sakura_DmgNum_Cleanup", CleanCache)
end
