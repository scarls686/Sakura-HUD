CreateConVar("sv_sakura_health_enabled", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "启用血条系统", 0, 1)

SAKURA_HEALTH = SAKURA_HEALTH or {}
SAKURA_HEALTH.entities = {}

SAKURA_HEALTH.NpcFactions = {
    -- 蚂蚁族
    npc_antlion = "ants", npc_antlionguard = "ants", npc_antlionguardian = "ants", npc_antlion_worker = "ants",
    -- 僵尸族
    npc_barnacle = "zombies", npc_fastzombie = "zombies", npc_fastzombie_torso = "zombies", npc_headcrab = "zombies",
    npc_headcrab_fast = "zombies", npc_headcrab_black = "zombies", npc_zombie = "zombies",
    npc_zombie_torso = "zombies", npc_zombine = "zombies", npc_poisonzombie = "zombies",
    -- 联合军
    npc_breen = "combine", npc_clawscanner = "combine", npc_combine_s = "combine", npc_cscanner = "combine",
    npc_strider = "combine", npc_hunter = "combine", npc_metropolice = "combine", npc_manhack = "combine",
    npc_stalker = "combine", npc_helicopter = "combine", npc_combinegunship = "combine", npc_combinedropship = "combine",
    -- 人类（友军）
    npc_alyx = "humans", npc_barney = "humans", npc_citizen = "humans", npc_dog = "humans", npc_eli = "humans",
    npc_fisherman = "humans", npc_gman = "humans", npc_kleiner = "humans", npc_magnusson = "humans",
    npc_monk = "humans", npc_mossman = "humans", npc_odessa = "humans", npc_vortigaunt = "humans",
    -- 中性生物
    npc_crow = "neutral", npc_pigeon = "neutral", npc_seagull = "neutral"
}

local function GetTargetFaction(npc)
    return SAKURA_HEALTH.NpcFactions[npc:GetClass()] or "unknown"
end

for k, ent in pairs(ents.GetAll()) do
    if ent:IsNPC() or ent:IsPlayer() or ent:IsNextBot() then
        table.insert(SAKURA_HEALTH.entities, ent)
    end
end

hook.Add("OnEntityCreated", "SakuraHealthEntityStorage", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if not (ent:IsNPC() or ent:IsPlayer() or ent:IsNextBot()) then return end
        table.insert(SAKURA_HEALTH.entities, ent)
    end)
end)

hook.Add("Think", "SakuraHealthBarUpdate", function()
    for k, target in pairs(SAKURA_HEALTH.entities) do
        if IsValid(target) then
            if target:Health() > 0 then
                target:SetNWBool("Sakura_Health_Valid", true)
                target:SetNWInt("Sakura_Health_HP", target:Health())
                local curMaxHP = target:GetMaxHealth()
                -- GetMaxHealth() 为 0 说明引擎尚未完成 NPC 初始化，跳过本帧避免将当前 HP 误存为最大值
                if curMaxHP > 0 then
                    if not target.Sakura_MaxHealth or target:Health() > target.Sakura_MaxHealth then
                        if target:Health() > curMaxHP then
                            target.Sakura_MaxHealth = target:Health()
                        else
                            target.Sakura_MaxHealth = curMaxHP
                        end
                    end

                    target.Sakura_PreviousMaxHP = target.Sakura_PreviousMaxHP or curMaxHP
                    if target.Sakura_PreviousMaxHP ~= curMaxHP then
                        target.Sakura_MaxHealth = curMaxHP
                        target.Sakura_PreviousMaxHP = curMaxHP
                    end
                end

                target:SetNWInt("Sakura_Health_MaxHP", target.Sakura_MaxHealth)
                target:SetNWInt("Sakura_Health_Index", target:EntIndex())

                if target:GetNWString("Sakura_Health_Faction", "") == "" then
                    if target:IsNPC() then
                        target:SetNWString("Sakura_Health_Faction", GetTargetFaction(target))
                    elseif target:IsPlayer() then
                        target:SetNWString("Sakura_Health_Faction", "players")
                    else
                        target:SetNWString("Sakura_Health_Faction", "unknown")
                    end
                end

                -- Disposition: D_HT=1(仇恨) D_FR=2(恐惧) D_LI=3(喜爱) D_NU=4(中立)
                -- 注意：Disposition() 返回的是关系类别，与战斗状态独立。
                -- GMod 沙盒中许多 NPC 对玩家的关系类别默认为 D_NU=4，
                -- 即使它们正在主动攻击；因此额外检查 GetEnemy() 以修正误判。
                if target:IsNPC() then
                    for _, ply in pairs(player.GetAll()) do
                        if IsValid(ply) then
                            local disp = target:Disposition(ply)
                            if IsValid(target:GetEnemy()) and target:GetEnemy() == ply then
                                disp = 1 -- 强制 D_HT：当前正以该玩家为目标
                            end
                            target:SetNWInt("Sakura_Health_Relation_" .. ply:UniqueID(), disp)
                        end
                    end
                end

                if target:IsPlayer() then
                    local curArmor    = target:Armor() or 0
                    local maxArmor    = target:GetMaxArmor() or 0
                    local hasArmor    = curArmor > 0
                    target:SetNWInt("Sakura_Health_Armor",    curArmor)
                    target:SetNWInt("Sakura_Health_ArmorMax",  maxArmor)
                    target:SetNWBool("Sakura_Health_HasArmor", hasArmor)
                elseif target:IsNPC() then
                    -- NPC：由外部护甲插件通过自身 NWVar 同步；
                    -- 此处从插件的 NWVar 读取后转写到 Sakura 命名空间，
                    -- 客户端统一从 Sakura_Health_* 读取，无需感知插件实现细节。
                    local hasArmor    = target:GetNWBool("npcarmor_plated", false)
                    local curArmor    = target:GetNWInt("npcarmor_amount", 0)
                    local maxArmor    = target:GetNWInt("npcarmor_amount_max", 0)
                    target:SetNWBool("Sakura_Health_HasArmor", hasArmor)
                    target:SetNWInt("Sakura_Health_Armor",    curArmor)
                    target:SetNWInt("Sakura_Health_ArmorMax",  maxArmor)
                else
                    target:SetNWBool("Sakura_Health_HasArmor", false)
                    target:SetNWInt("Sakura_Health_Armor",    0)
                    target:SetNWInt("Sakura_Health_ArmorMax",  0)
                end
            else
                target:SetNWBool("Sakura_Health_Valid", false)
            end
        else
            SAKURA_HEALTH.entities[k] = nil
        end
    end
end)

concommand.Add("sakura_health_debug", function(ply)
    local count = 0
    for k, v in pairs(SAKURA_HEALTH.entities) do
        if IsValid(v) then count = count + 1 end
    end

    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "Sakura Health: " .. count .. " entities cached")
    else
        print("Sakura Health: " .. count .. " entities cached")
    end
end)