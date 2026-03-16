
-- ===== 多语言系统 =====
local LANGUAGE = {
    zh = {
        title = "原版HUD控制",
        desc = "独立控制每个原版HUD元素的显示与隐藏",
        cat_core = "=== 核心HUD ===",
        cat_combat = "=== 战斗相关 ===",
        cat_info = "=== 信息显示 ===",
        cat_other = "=== 其他 ===",
        cat_extra = "=== 额外控制 ===",
        language = "语言",
        language_section = "=== 语言设置 ===",
        reset = "全部重置为显示",
        hide_all = "全部隐藏",
        note_auto = "提示：启用 Sakura HUD/受击指示 时，已被替代的元素会自动隐藏。",
        CHudHealth = "生命值",
        CHudBattery = "护甲值",
        CHudAmmo = "主武器弹药",
        CHudSecondaryAmmo = "副武器弹药",
        CHudCrosshair = "准星",
        CHudWeaponSelection = "武器选择轮盘",
        CHudDamageIndicator = "受伤红屏闪烁",
        CHudPoisonDamageIndicator = "中毒指示器",
        CHUDQuickInfo = "准星旁血量/弹药",
        CHudVehicle = "载具准星",
        CHudHistoryResource = "拾取提示（引擎层）",
        CHudMessage = "游戏消息",
        CHudChat = "聊天框/ESC/控制台",
        CHudCloseCaption = "字幕",
        CHudHintDisplay = "按键提示",
        CHudZoom = "HEV放大镜",
        CHudSuitPower = "HEV电量",
        CHudSquadStatus = "小队状态",
        CHudGeiger = "盖革计数器（含音效）",
        CHudTrain = "列车控制",
        CHudMenu = "源引擎通用菜单",
        NetGraph = "网络图表 (net_graph)",
        CFPSPanel = "FPS/坐标 (cl_showfps)",
        deathnotice = "击杀信息",
        deathnotice_tip = "隐藏屏幕右上角的击杀/死亡通知",
        death_sound = "死亡报警音效（服务端）",
        death_sound_tip = "关闭玩家死亡时的蜂鸣报警声（需服务端安装 sv_sakura_vanilla_hud.lua）",
        death_sound_missing = "（未检测到服务端文件）",
        pickup_history = "拾取历史（武器/弹药）",
        pickup_history_tip = "隐藏拾取武器和弹药时的屏幕提示",
    },
    en = {
        title = "Vanilla HUD Control",
        desc = "Individually toggle each vanilla HUD element",
        cat_core = "=== Core HUD ===",
        cat_combat = "=== Combat ===",
        cat_info = "=== Information ===",
        cat_other = "=== Other ===",
        cat_extra = "=== Extra Controls ===",
        language = "Language",
        language_section = "=== Language ===",
        reset = "Show All",
        hide_all = "Hide All",
        note_auto = "Note: Elements replaced by Sakura HUD / Damage Indicator are auto-hidden.",
        -- Core HUD
        CHudHealth = "Health",
        CHudBattery = "Armor",
        CHudAmmo = "Primary Ammo",
        CHudSecondaryAmmo = "Secondary Ammo",
        -- Combat
        CHudCrosshair = "Crosshair",
        CHudWeaponSelection = "Weapon Selection",
        CHudDamageIndicator = "Damage Indicator (Red Flash)",
        CHudPoisonDamageIndicator = "Poison Indicator",
        CHUDQuickInfo = "Quick Info (HP/Ammo near crosshair)",
        CHudVehicle = "Vehicle Crosshair",
        -- Information
        CHudHistoryResource = "Pickup History (Engine)",
        CHudMessage = "Game Messages",
        CHudChat = "Chat / ESC / Console",
        CHudCloseCaption = "Closed Captions",
        CHudHintDisplay = "Key Hints",
        -- Other
        CHudZoom = "HEV Zoom",
        CHudSuitPower = "HEV Suit Power",
        CHudSquadStatus = "Squad Status",
        CHudGeiger = "Geiger Counter (incl. sound)",
        CHudTrain = "Train Controls",
        CHudMenu = "Source Engine Menu",
        NetGraph = "Net Graph (net_graph)",
        CFPSPanel = "FPS / Position (cl_showfps)",
        -- Extra Controls
        deathnotice = "Kill Feed",
        deathnotice_tip = "Hide kill/death notices in the top-right corner",
        death_sound = "Death Alarm Sound (Server)",
        death_sound_tip = "Mute the beep sound on player death (requires sv_sakura_vanilla_hud.lua on server)",
        death_sound_missing = "(Server file not detected)",
        pickup_history = "Pickup History (Weapon/Ammo)",
        pickup_history_tip = "Hide weapon and ammo pickup notifications",
    }
}

local function GetCurrentLang()
    return cookie.GetString("sakura_hud_lang", "zh")
end

local function SetLang(lang)
    cookie.Set("sakura_hud_lang", lang)
end

local function L(key)
    local lang = GetCurrentLang()
    return (LANGUAGE[lang] and LANGUAGE[lang][key]) or (LANGUAGE.zh[key]) or key
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

-- 初始化时应用
timer.Simple(0.1, function()
    if not cv_deathnotice:GetBool() then
        ApplyDeathNotice()
    end
end)

-- ===== 拾取历史控制（Lua绘制层）=====
-- GMod 中武器/弹药拾取提示由 Lua 绘制（GM:HUDDrawPickupHistory）
-- CHudHistoryResource 仅处理 health/suit 等引擎层拾取
-- 两者配合可完整隐藏所有拾取提示
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
    
    panel:Help(L("title"))
    panel:Help(L("desc"))
    panel:Help(L("note_auto"))

    panel:Help(L("language_section"))
    local langCombo = panel:ComboBox(L("language"))
    langCombo:AddChoice("中文", "zh", GetCurrentLang() == "zh")
    langCombo:AddChoice("English", "en", GetCurrentLang() == "en")
    langCombo.OnSelect = function(self, index, value, data)
        SetLang(data)
        timer.Simple(0.1, function()
            if IsValid(panel) then BuildVanillaHUDMenu(panel) end
        end)
    end

    panel:Help(L("cat_core"))
    for _, name in ipairs(HUD_ELEMENTS.core) do
        panel:CheckBox(L(name), "sakura_vanilla_" .. name)
    end

    panel:Help(L("cat_combat"))
    for _, name in ipairs(HUD_ELEMENTS.combat) do
        panel:CheckBox(L(name), "sakura_vanilla_" .. name)
    end

    panel:Help(L("cat_info"))
    for _, name in ipairs(HUD_ELEMENTS.info) do
        panel:CheckBox(L(name), "sakura_vanilla_" .. name)
    end

    panel:Help(L("cat_other"))
    for _, name in ipairs(HUD_ELEMENTS.other) do
        panel:CheckBox(L(name), "sakura_vanilla_" .. name)
    end

    panel:Help(L("cat_extra"))
    local cbDeath = panel:CheckBox(L("deathnotice"), "sakura_vanilla_deathnotice")
    if IsValid(cbDeath) then cbDeath:SetTooltip(L("deathnotice_tip")) end

    local cbPickup = panel:CheckBox(L("pickup_history"), "sakura_vanilla_pickup_history")
    if IsValid(cbPickup) then cbPickup:SetTooltip(L("pickup_history_tip")) end

    local cvDeathSound = GetDeathSoundConVar()
    if cvDeathSound then
        local cbSound = panel:CheckBox(L("death_sound"), "sakura_vanilla_death_sound")
        if IsValid(cbSound) then cbSound:SetTooltip(L("death_sound_tip")) end
    else
        local lbl = panel:Help("  " .. L("death_sound") .. " " .. L("death_sound_missing"))
        if IsValid(lbl) then
            lbl:SetTextColor(Color(150, 150, 150))
        end
    end

    panel:Help("")
    
    local btnReset = panel:Button(L("reset"))
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
    
    local btnHideAll = panel:Button(L("hide_all"))
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
        L("title"), "", "",
        function(panel) BuildVanillaHUDMenu(panel) end
    )
end)