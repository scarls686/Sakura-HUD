-- ===== 配置变量 =====
local cv_enabled = CreateClientConVar("sakura_hitmarker_enabled", "1", true, false)
local cv_size = CreateClientConVar("sakura_hitmarker_size", "34", true, false)
local cv_init_dist = CreateClientConVar("sakura_hitmarker_init_dist", "15", true, false)
local cv_spread_dist = CreateClientConVar("sakura_hitmarker_spread_dist", "27", true, false)

local cv_col_norm_r = CreateClientConVar("sakura_hitmarker_color_norm_r", "255", true, false)
local cv_col_norm_g = CreateClientConVar("sakura_hitmarker_color_norm_g", "183", true, false)
local cv_col_norm_b = CreateClientConVar("sakura_hitmarker_color_norm_b", "197", true, false)

local cv_col_crit_r = CreateClientConVar("sakura_hitmarker_color_crit_r", "255", true, false)
local cv_col_crit_g = CreateClientConVar("sakura_hitmarker_color_crit_g", "80", true, false)
local cv_col_crit_b = CreateClientConVar("sakura_hitmarker_color_crit_b", "80", true, false)

local cv_col_armor_r = CreateClientConVar("sakura_hitmarker_color_armor_r", "0", true, false)
local cv_col_armor_g = CreateClientConVar("sakura_hitmarker_color_armor_g", "191", true, false)
local cv_col_armor_b = CreateClientConVar("sakura_hitmarker_color_armor_b", "255", true, false)

local MAT_PETAL = Material("sakura/sakura_petal", "noclamp smooth")
local active_markers = {}

local function GetResolutionScale()
    local baseHeight = 1080
    local currentHeight = ScrH()
    return currentHeight / baseHeight
end

-- ===== 多语言系统 =====
local LANGUAGE = {
    zh = {
        menu_title = "命中反馈设置",
        enable = "启用命中反馈",
        size = "花瓣大小",
        init_dist = "基础半径 (准星距)",
        spread_dist = "击杀散开距离",
        col_norm = "普通命中颜色",
        col_crit = "爆头命中颜色",
        col_armor = "护甲命中颜色",
        reset = "重置为默认值",
        reset_desc = "已重置所有数值",
        language = "语言"
    },
    en = {
        menu_title = "Hitmarker Settings",
        enable = "Enable Hitmarker",
        size = "Petal Size",
        init_dist = "Initial Radius",
        spread_dist = "Kill Spread Radius",
        col_norm = "Normal Color",
        col_crit = "Headshot Color",
        col_armor = "Armor Hit Color",
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

local function AddMarker(isHeadshot, isKill, isArmor)
    if not cv_enabled:GetBool() then return end

    local data = {
        time = UnPredictedCurTime(),
        duration = isKill and 0.7 or 0.35,
        isHeadshot = isHeadshot,
        isKill = isKill,
        isArmor = isArmor or false,
        baseSize = cv_size:GetInt(),
        initDist = cv_init_dist:GetInt(),
        spreadDist = cv_spread_dist:GetInt(),
        randOffset = math.random(-15, 15)
    }

    if isHeadshot then
        data.angles = {90, 162, 234, 306, 18} -- 5瓣向上
    else
        data.angles = {45, 135, 225, 315} -- 4瓣
    end

    table.insert(active_markers, data)
end

net.Receive("Sakura_Hit", function() AddMarker(net.ReadBool(), false, net.ReadBool()) end)
net.Receive("Sakura_Kill", function() AddMarker(net.ReadBool(), true, net.ReadBool()) end)

hook.Add("HUDPaint", "DrawSakuraHitmarker", function()
    if #active_markers == 0 then return end

    local resolutionScale = GetResolutionScale()

    local function GetScaledValue(value)
        return value * resolutionScale
    end

    local cx, cy = ScrW() / 2, ScrH() / 2
    local curTime = UnPredictedCurTime()

    local col_norm  = Color(cv_col_norm_r:GetInt(),  cv_col_norm_g:GetInt(),  cv_col_norm_b:GetInt())
    local col_crit  = Color(cv_col_crit_r:GetInt(),  cv_col_crit_g:GetInt(),  cv_col_crit_b:GetInt())
    local col_armor = Color(cv_col_armor_r:GetInt(), cv_col_armor_g:GetInt(), cv_col_armor_b:GetInt())

    surface.SetMaterial(MAT_PETAL)

    for i = #active_markers, 1, -1 do
        local marker = active_markers[i]
        local elapsed = curTime - marker.time

        if elapsed >= marker.duration then
            table.remove(active_markers, i)
        else
            local progress = elapsed / marker.duration
            local easeProgress = 1 - math.pow(1 - progress, 3)

            local alpha = 255 * (1 - math.pow(progress, 2))
            local size = GetScaledValue(marker.baseSize)

            local scale = 1
            if progress < 0.2 then
                scale = 1 + math.sin((progress / 0.2) * math.pi) * 0.3
            end
            local drawSize = size * scale

            local distOffset = GetScaledValue(marker.initDist)
            local orbitRotation = marker.randOffset
            local selfRotation = 0

            if marker.isKill then
                orbitRotation = orbitRotation - (700 * easeProgress)
                selfRotation = easeProgress * 900
                distOffset = distOffset + (GetScaledValue(marker.spreadDist) * easeProgress)
            else
                distOffset = distOffset + (GetScaledValue(8) * easeProgress)
            end

            local baseColor
            if marker.isArmor then
                baseColor = col_armor
            elseif marker.isHeadshot then
                baseColor = col_crit
            else
                baseColor = col_norm
            end

            surface.SetDrawColor(baseColor.r, baseColor.g, baseColor.b, alpha)

            for _, baseAngle in ipairs(marker.angles) do
                local currentAng = baseAngle + orbitRotation
                local rad = math.rad(currentAng)
                local px = cx + math.cos(rad) * distOffset
                local py = cy - math.sin(rad) * distOffset
                surface.DrawTexturedRectRotated(px, py, drawSize, drawSize, (currentAng - 90) + selfRotation)
            end
        end
    end
end)

local function BuildSakuraHitmarkerMenu(panel)
    panel:ClearControls()

    panel:Help(GetText("menu_title"))

    local langCombo = panel:ComboBox(GetText("language"))
    langCombo:AddChoice("中文", "zh", GetCurrentLang() == "zh")
    langCombo:AddChoice("English", "en", GetCurrentLang() == "en")
    langCombo.OnSelect = function(self, index, value, data)
        SetLang(data)
        timer.Simple(0.1, function()
            if IsValid(panel) then
                BuildSakuraHitmarkerMenu(panel)
            end
        end)
    end

    panel:Help(" ")
    panel:CheckBox(GetText("enable"), "sakura_hitmarker_enabled")

    panel:NumSlider(GetText("size"), "sakura_hitmarker_size", 10, 150, 0)
    panel:NumSlider(GetText("init_dist"), "sakura_hitmarker_init_dist", 0, 100, 0)
    panel:NumSlider(GetText("spread_dist"), "sakura_hitmarker_spread_dist", 0, 200, 0)

    panel:ControlHelp("\n" .. GetText("col_norm"))
    local cpNorm = vgui.Create("DColorMixer", panel)
    cpNorm:SetPalette(true)
    cpNorm:SetAlphaBar(false)
    cpNorm:SetColor(Color(cv_col_norm_r:GetInt(), cv_col_norm_g:GetInt(), cv_col_norm_b:GetInt()))
    cpNorm:SetTall(100)
    cpNorm.ValueChanged = function(_, col)
        RunConsoleCommand("sakura_hitmarker_color_norm_r", tostring(col.r))
        RunConsoleCommand("sakura_hitmarker_color_norm_g", tostring(col.g))
        RunConsoleCommand("sakura_hitmarker_color_norm_b", tostring(col.b))
    end
    panel:AddItem(cpNorm)

    panel:ControlHelp("\n" .. GetText("col_crit"))
    local cpCrit = vgui.Create("DColorMixer", panel)
    cpCrit:SetPalette(true)
    cpCrit:SetAlphaBar(false)
    cpCrit:SetColor(Color(cv_col_crit_r:GetInt(), cv_col_crit_g:GetInt(), cv_col_crit_b:GetInt()))
    cpCrit:SetTall(100)
    cpCrit.ValueChanged = function(_, col)
        RunConsoleCommand("sakura_hitmarker_color_crit_r", tostring(col.r))
        RunConsoleCommand("sakura_hitmarker_color_crit_g", tostring(col.g))
        RunConsoleCommand("sakura_hitmarker_color_crit_b", tostring(col.b))
    end
    panel:AddItem(cpCrit)

    panel:ControlHelp("\n" .. GetText("col_armor"))
    local cpArmor = vgui.Create("DColorMixer", panel)
    cpArmor:SetPalette(true)
    cpArmor:SetAlphaBar(false)
    cpArmor:SetColor(Color(cv_col_armor_r:GetInt(), cv_col_armor_g:GetInt(), cv_col_armor_b:GetInt()))
    cpArmor:SetTall(100)
    cpArmor.ValueChanged = function(_, col)
        RunConsoleCommand("sakura_hitmarker_color_armor_r", tostring(col.r))
        RunConsoleCommand("sakura_hitmarker_color_armor_g", tostring(col.g))
        RunConsoleCommand("sakura_hitmarker_color_armor_b", tostring(col.b))
    end
    panel:AddItem(cpArmor)

    panel:Help(" ")
    local btnReset = panel:Button(GetText("reset"))
    btnReset.DoClick = function()
        RunConsoleCommand("sakura_hitmarker_size", "34")
        RunConsoleCommand("sakura_hitmarker_init_dist", "15")
        RunConsoleCommand("sakura_hitmarker_spread_dist", "27")
        RunConsoleCommand("sakura_hitmarker_color_norm_r", "255")
        RunConsoleCommand("sakura_hitmarker_color_norm_g", "183")
        RunConsoleCommand("sakura_hitmarker_color_norm_b", "197")
        RunConsoleCommand("sakura_hitmarker_color_crit_r", "255")
        RunConsoleCommand("sakura_hitmarker_color_crit_g", "80")
        RunConsoleCommand("sakura_hitmarker_color_crit_b", "80")
        RunConsoleCommand("sakura_hitmarker_color_armor_r", "0")
        RunConsoleCommand("sakura_hitmarker_color_armor_g", "191")
        RunConsoleCommand("sakura_hitmarker_color_armor_b", "255")

        notification.AddLegacy(GetText("reset_desc"), NOTIFY_GENERIC, 3)
        timer.Simple(0.1, function()
            if IsValid(panel) then BuildSakuraHitmarkerMenu(panel) end
        end)
    end
end

hook.Add("PopulateToolMenu", "SakuraHitmarker_Options", function()
    spawnmenu.AddToolMenuOption("Options", "Sakura HUD", "SakuraHitmarker_Settings", "命中反馈设置", "", "", function(panel)
        BuildSakuraHitmarkerMenu(panel)
    end)
end)
