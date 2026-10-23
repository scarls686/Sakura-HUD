local function GetText(key)
    return language.GetPhrase("sakura_hud.vanilla_hud." .. string.lower(key))
end

local HUD_ELEMENTS = {
    core = {
        "CHudHealth",
        "CHudBattery",
        "CHudAmmo",
        "CHudSecondaryAmmo",
    },
    combat = {
        "CHudCrosshair",
        "CHudWeaponSelection",
        "CHudDamageIndicator",
        "CHudPoisonDamageIndicator",
        "CHUDQuickInfo",
        "CHudVehicle",
    },
    info = {
        "CHudHistoryResource",
        "CHudMessage",
        "CHudChat",
        "CHudCloseCaption",
        "CHudHintDisplay",
    },
    other = {
        "CHudZoom",
        "CHudSuitPower",
        "CHudSquadStatus",
        "CHudGeiger",
        "CHudTrain",
        "CHudMenu",
        "NetGraph",
        "CFPSPanel",
    },
}

local SAKURA_REPLACED = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudPoisonDamageIndicator"] = true,
}

local cvars_map = {}
local ALL_ELEMENTS = {}

for _, cat in pairs({"core", "combat", "info", "other"}) do
    for _, name in ipairs(HUD_ELEMENTS[cat]) do
        table.insert(ALL_ELEMENTS, name)
        cvars_map[name] = CreateClientConVar(
            "sakura_vanilla_" .. name, "1", true, false,
            "Toggle vanilla HUD element: " .. name
        )
    end
end

local cv_deathnotice = CreateClientConVar("sakura_vanilla_deathnotice", "1", true, false)
local cv_pickup_history = CreateClientConVar("sakura_vanilla_pickup_history", "1", true, false)

local function GetDeathSoundConVar()
    return GetConVar("sakura_vanilla_death_sound")
end

hook.Add("HUDShouldDraw", "SakuraHUD_VanillaControl", function(name)
    local cv = cvars_map[name]
    if cv and not cv:GetBool() then
        return false
    end
end)

-- 保存原始击杀信息显示时长用于恢复（默认6秒）
local originalDeathNoticeTime = 6
timer.Simple(0, function()
    local cv = GetConVar("hud_deathnotice_time")
    if cv then
        local val = cv:GetFloat()
        if val > 0 then
            originalDeathNoticeTime = val
        end
    end
end)

local function ApplyDeathNotice()
    if cv_deathnotice:GetBool() then
        RunConsoleCommand("hud_deathnotice_time", tostring(originalDeathNoticeTime))
    else
        RunConsoleCommand("hud_deathnotice_time", "0")
    end
end

cvars.AddChangeCallback("sakura_vanilla_deathnotice", function(cvar, old, new)
    ApplyDeathNotice()
end, "SakuraVanilla_DeathNotice")

timer.Simple(0.1, function()
    if not cv_deathnotice:GetBool() then
        ApplyDeathNotice()
    end
end)

-- 武器/弹药拾取提示由 Lua 绘制，需与引擎层 CHudHistoryResource 分别控制。
hook.Add("HUDDrawPickupHistory", "SakuraHUD_HidePickupHistory", function()
    if not cv_pickup_history:GetBool() then
        return false
    end
end)

-- 联动：Sakura HUD 主面板
cvars.AddChangeCallback("sakura_hud_enabled", function(cvar, old, new)
    if new == "1" then
        for name, _ in pairs(SAKURA_REPLACED) do
            RunConsoleCommand("sakura_vanilla_" .. name, "0")
        end
    else
        for name, _ in pairs(SAKURA_REPLACED) do
            RunConsoleCommand("sakura_vanilla_" .. name, "1")
        end
    end
end, "SakuraVanillaAutoToggle")

-- 联动：Sakura 受击方向指示
cvars.AddChangeCallback("sakura_damage_indicator_enabled", function(cvar, old, new)
    if new == "1" then
        RunConsoleCommand("sakura_vanilla_CHudDamageIndicator", "0")
    else
        RunConsoleCommand("sakura_vanilla_CHudDamageIndicator", "1")
    end
end, "SakuraVanilla_DmgIndicatorLink")

timer.Simple(0, function()
    local cvMain = GetConVar("sakura_hud_enabled")
    if cvMain and cvMain:GetBool() then
        for name, _ in pairs(SAKURA_REPLACED) do
            if cvars_map[name] and cvars_map[name]:GetBool() then
                RunConsoleCommand("sakura_vanilla_" .. name, "0")
            end
        end
    end
    local cvDmg = GetConVar("sakura_damage_indicator_enabled")
    if cvDmg and cvDmg:GetBool() then
        if cvars_map["CHudDamageIndicator"] and cvars_map["CHudDamageIndicator"]:GetBool() then
            RunConsoleCommand("sakura_vanilla_CHudDamageIndicator", "0")
        end
    end
end)

-- ===== UI 菜单 =====
local function BuildVanillaHUDMenu(panel)
    panel:ClearControls()
    
    panel:Help(GetText("title"))
    panel:Help(GetText("desc"))
    panel:Help(GetText("note_auto"))

    panel:Help(GetText("cat_core"))
    for _, name in ipairs(HUD_ELEMENTS.core) do
        panel:CheckBox(GetText(name), "sakura_vanilla_" .. name)
    end

    panel:Help(GetText("cat_combat"))
    for _, name in ipairs(HUD_ELEMENTS.combat) do
        panel:CheckBox(GetText(name), "sakura_vanilla_" .. name)
    end

    panel:Help(GetText("cat_info"))
    for _, name in ipairs(HUD_ELEMENTS.info) do
        panel:CheckBox(GetText(name), "sakura_vanilla_" .. name)
    end

    panel:Help(GetText("cat_other"))
    for _, name in ipairs(HUD_ELEMENTS.other) do
        panel:CheckBox(GetText(name), "sakura_vanilla_" .. name)
    end

    panel:Help(GetText("cat_extra"))
    local cbDeath = panel:CheckBox(GetText("deathnotice"), "sakura_vanilla_deathnotice")
    if IsValid(cbDeath) then cbDeath:SetTooltip(GetText("deathnotice_tip")) end

    local cbPickup = panel:CheckBox(GetText("pickup_history"), "sakura_vanilla_pickup_history")
    if IsValid(cbPickup) then cbPickup:SetTooltip(GetText("pickup_history_tip")) end

    local cvDeathSound = GetDeathSoundConVar()
    if cvDeathSound then
        local cbSound = panel:CheckBox(GetText("death_sound"), "sakura_vanilla_death_sound")
        if IsValid(cbSound) then cbSound:SetTooltip(GetText("death_sound_tip")) end
    else
        local lbl = panel:Help("  " .. GetText("death_sound") .. " " .. GetText("death_sound_missing"))
        if IsValid(lbl) then
            lbl:SetTextColor(Color(150, 150, 150))
        end
    end

    panel:Help("")
    
    local btnReset = panel:Button(GetText("reset"))
    btnReset.DoClick = function()
        for _, name in ipairs(ALL_ELEMENTS) do
            RunConsoleCommand("sakura_vanilla_" .. name, "1")
        end
        RunConsoleCommand("sakura_vanilla_deathnotice", "1")
        RunConsoleCommand("sakura_vanilla_pickup_history", "1")
        if GetDeathSoundConVar() then
            RunConsoleCommand("sakura_vanilla_death_sound", "1")
        end
        timer.Simple(0.1, function()
            if IsValid(panel) then BuildVanillaHUDMenu(panel) end
        end)
    end
    
    local btnHideAll = panel:Button(GetText("hide_all"))
    btnHideAll.DoClick = function()
        for _, name in ipairs(ALL_ELEMENTS) do
            RunConsoleCommand("sakura_vanilla_" .. name, "0")
        end
        RunConsoleCommand("sakura_vanilla_deathnotice", "0")
        RunConsoleCommand("sakura_vanilla_pickup_history", "0")
        if GetDeathSoundConVar() then
            RunConsoleCommand("sakura_vanilla_death_sound", "0")
        end
        timer.Simple(0.1, function()
            if IsValid(panel) then BuildVanillaHUDMenu(panel) end
        end)
    end
end

hook.Add("PopulateToolMenu", "SakuraHUD_VanillaMenu", function()
    spawnmenu.AddToolMenuOption(
        "Options", "Sakura HUD", "SakuraHUD_VanillaControl",
        "#sakura_hud.vanilla_hud.title", "", "",
        function(panel) BuildVanillaHUDMenu(panel) end
    )
end)