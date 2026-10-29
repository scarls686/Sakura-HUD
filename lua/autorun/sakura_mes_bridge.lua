if SERVER then AddCSLuaFile() end

SakuraMES = {}
local function available()
    return MEShield and MEShield.APIVersion == 1
end
function SakuraMES.GetState(ent)
    if available() then return MEShield.GetState(ent) end
end
function SakuraMES.GetAP(ent)
    if not IsValid(ent) then return end
    local state = SakuraMES.GetState(ent)
    if state then return state end

    local current, maximum
    if ent:IsPlayer() then
        current, maximum = ent:Armor(), ent:GetMaxArmor()
    elseif ent:GetNWBool("Sakura_Health_HasArmor", false) then
        current = ent:GetNWInt("Sakura_Health_Armor", 0)
        maximum = ent:GetNWInt("Sakura_Health_ArmorMax", 0)
    else
        return
    end
    if maximum <= 0 then return end
    return {current = math.max(0, current), maximum = maximum, fraction = math.Clamp(current / maximum, 0, 1)}
end
function SakuraMES.IsTracked(ent, damage)
    return available() and MEShield.IsDamageTracked and MEShield.IsDamageTracked(ent, damage) or false
end
function SakuraMES.UsesEvents(ent)
    return available() and MEShield.HandlesDamage and MEShield.HandlesDamage(ent) or false
end
function SakuraMES.HasFeedback(result)
    return result.healthDamage > 0 or result.shieldDamage > 0 or result.armorDamage > 0 or result.gateBlocked or result.gateTriggered
end
