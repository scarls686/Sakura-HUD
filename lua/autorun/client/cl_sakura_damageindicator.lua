-- ===== 配置变量 =====
local cv_enabled = CreateClientConVar("sakura_damage_indicator_enabled", "1", true, false)
local cv_size = CreateClientConVar("sakura_damage_indicator_size", "250", true, false)
local cv_distance = CreateClientConVar("sakura_damage_indicator_distance", "75", true, false)
local cv_duration = CreateClientConVar("sakura_damage_indicator_duration", "1.5", true, false)

local cv_col_armor_r = CreateClientConVar("sakura_damage_indicator_color_armor_r", "0", true, false)
local cv_col_armor_g = CreateClientConVar("sakura_damage_indicator_color_armor_g", "191", true, false)
local cv_col_armor_b = CreateClientConVar("sakura_damage_indicator_color_armor_b", "255", true, false)

local cv_col_health_r = CreateClientConVar("sakura_damage_indicator_color_health_r", "255", true, false)
local cv_col_health_g = CreateClientConVar("sakura_damage_indicator_color_health_g", "0", true, false)
local cv_col_health_b = CreateClientConVar("sakura_damage_indicator_color_health_b", "0", true, false)

local MAT_INDICATOR = Material("sakura/hit_direction_indicator", "smooth")
local activeIndicators = {}

local function GetResponsive(val)
    return val * (ScrH() / 1080)
end

-- ===== 多语言系统 =====
local LANGUAGE = {
    zh = {
        menu_title = "受击方向指示设置",
        enable = "启用受击方向指示",
        size = "指示器大小",
        distance = "指示器距离",
        duration = "显示时长",
        col_armor = "护甲伤害颜色",
        col_health = "生命伤害颜色",
        reset = "重置为默认值",
        reset_desc = "已重置所有数值",
        language = "语言"
    },
    en = {
        menu_title = "Damage Direction Indicator Settings",
        enable = "Enable Damage Indicator",
        size = "Indicator Size",
        distance = "Indicator Distance",
        duration = "Display Duration",
        col_armor = "Armor Damage Color",
        col_health = "Health Damage Color",
        reset = "Reset to Default",
        reset_desc = "Settings have been reset",
        language = "Language"
    }
}

local function GetCurrentLang()
    return cookie.GetString("sakura_hud_lang", "zh")
end

local function SetLang(lang)
    cookie.Set("sakura_hud_lang", lang)
end

local function GetText(key)
    local lang = GetCurrentLang()
    return LANGUAGE[lang] and LANGUAGE[lang][key] or LANGUAGE.zh[key] or key
end

-- ===== 核心逻辑 =====
local function AddIndicator(attackerPos, isArmorDamage)
    if not cv_enabled:GetBool() then return end
    if not attackerPos then return end
    
    table.insert(activeIndicators, {
        time = RealTime(),
        duration = cv_duration:GetFloat(),
        attackerPos = attackerPos,
        isArmorDamage = isArmorDamage
    })
end

net.Receive("Sakura_DamageDirection", function()
    local attackerPos = net.ReadVector()
    local isArmorDamage = net.ReadBool()
    AddIndicator(attackerPos, isArmorDamage)
end)

hook.Add("HUDPaint", "DrawSakuraDamageIndicator", function()
    if not cv_enabled:GetBool() or #activeIndicators == 0 then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local cx, cy = ScrW() / 2, ScrH() / 2
    local curTime = RealTime()
    local distance = GetResponsive(cv_distance:GetInt())
    local size = GetResponsive(cv_size:GetInt())
    local col_armor = Color(cv_col_armor_r:GetInt(), cv_col_armor_g:GetInt(), cv_col_armor_b:GetInt())
    local col_health = Color(cv_col_health_r:GetInt(), cv_col_health_g:GetInt(), cv_col_health_b:GetInt())

    surface.SetMaterial(MAT_INDICATOR)
    
    for i = #activeIndicators, 1, -1 do
        local indicator = activeIndicators[i]
        local elapsed = curTime - indicator.time
        
        if elapsed >= indicator.duration then
            table.remove(activeIndicators, i)
        else
            local progress = elapsed / indicator.duration
            local alpha = (progress < 0.8)
                and (255 * (1 - progress * 0.5))
                or (153 * (1 - (progress - 0.8) / 0.2))
            
            local eyeAngles = ply:EyeAngles()
            local dirToAttacker = (indicator.attackerPos - ply:GetShootPos()):GetNormalized()
            local angleToAttacker = dirToAttacker:Angle()
            local relYaw = math.NormalizeAngle(angleToAttacker.y - eyeAngles.y)
            local rotation = relYaw
            local rad = math.rad(-relYaw - 90)
            local px = cx + math.cos(rad) * distance
            local py = cy + math.sin(rad) * distance
            
            local drawColor = indicator.isArmorDamage and col_armor or col_health
            surface.SetDrawColor(drawColor.r, drawColor.g, drawColor.b, alpha)
            surface.DrawTexturedRectRotated(px, py, size, size, rotation)
        end
    end
end)

-- ===== UI 菜单 =====
local function BuildSakuraDamageIndicatorMenu(panel)
    panel:ClearControls()
    panel:Help(GetText("menu_title"))
    
    local langCombo = panel:ComboBox(GetText("language"))
    langCombo:AddChoice("中文", "zh", GetCurrentLang() == "zh")
    langCombo:AddChoice("English", "en", GetCurrentLang() == "en")
    langCombo.OnSelect = function(_, _, _, data)
        SetLang(data)
        timer.Simple(0.1, function() if IsValid(panel) then BuildSakuraDamageIndicatorMenu(panel) end end)
    end
    
    panel:Help(" ")
    panel:CheckBox(GetText("enable"), "sakura_damage_indicator_enabled")
    panel:NumSlider(GetText("size"), "sakura_damage_indicator_size", 64, 400, 0)
    panel:NumSlider(GetText("distance"), "sakura_damage_indicator_distance", 50, 500, 0)
    panel:NumSlider(GetText("duration"), "sakura_damage_indicator_duration", 0.5, 5.0, 1)
    
    panel:ControlHelp("\n" .. GetText("col_armor"))
    local cpArmor = vgui.Create("DColorMixer", panel)
    cpArmor:SetPalette(true)
    cpArmor:SetAlphaBar(false)
    cpArmor:SetColor(Color(cv_col_armor_r:GetInt(), cv_col_armor_g:GetInt(), cv_col_armor_b:GetInt()))
    cpArmor:SetTall(100)
    cpArmor.ValueChanged = function(_, col)
        RunConsoleCommand("sakura_damage_indicator_color_armor_r", tostring(col.r))
        RunConsoleCommand("sakura_damage_indicator_color_armor_g", tostring(col.g))
        RunConsoleCommand("sakura_damage_indicator_color_armor_b", tostring(col.b))
    end
    panel:AddItem(cpArmor)
    
    panel:ControlHelp("\n" .. GetText("col_health"))
    local cpHealth = vgui.Create("DColorMixer", panel)
    cpHealth:SetPalette(true)
    cpHealth:SetAlphaBar(false)
    cpHealth:SetColor(Color(cv_col_health_r:GetInt(), cv_col_health_g:GetInt(), cv_col_health_b:GetInt()))
    cpHealth:SetTall(100)
    cpHealth.ValueChanged = function(_, col)
        RunConsoleCommand("sakura_damage_indicator_color_health_r", tostring(col.r))
        RunConsoleCommand("sakura_damage_indicator_color_health_g", tostring(col.g))
        RunConsoleCommand("sakura_damage_indicator_color_health_b", tostring(col.b))
    end
    panel:AddItem(cpHealth)
    
    panel:Help(" ")
    local btnReset = panel:Button(GetText("reset"))
    btnReset.DoClick = function()
        RunConsoleCommand("sakura_damage_indicator_size", "250")
        RunConsoleCommand("sakura_damage_indicator_distance", "75")
        RunConsoleCommand("sakura_damage_indicator_duration", "1.5")
        RunConsoleCommand("sakura_damage_indicator_color_armor_r", "0")
        RunConsoleCommand("sakura_damage_indicator_color_armor_g", "191")
        RunConsoleCommand("sakura_damage_indicator_color_armor_b", "255")
        RunConsoleCommand("sakura_damage_indicator_color_health_r", "255")
        RunConsoleCommand("sakura_damage_indicator_color_health_g", "0")
        RunConsoleCommand("sakura_damage_indicator_color_health_b", "0")
        notification.AddLegacy(GetText("reset_desc"), NOTIFY_GENERIC, 3)
        timer.Simple(0.1, function() if IsValid(panel) then BuildSakuraDamageIndicatorMenu(panel) end end)
    end
end

hook.Add("PopulateToolMenu", "SakuraDamageIndicator_Options", function()
    spawnmenu.AddToolMenuOption("Options", "Sakura HUD", "SakuraDamageIndicator_Settings", "受击方向指示设置", "", "", function(panel)
        BuildSakuraDamageIndicatorMenu(panel)
    end)
end)