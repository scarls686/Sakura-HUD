-- ===== 配置 ConVar — 生命条基础参数 =====
local cv_enabled = CreateClientConVar("sakura_health_enabled", "1", true, false)
local cv_mode    = CreateClientConVar("sakura_health_mode",    "1", true, false)
local cv_range   = CreateClientConVar("sakura_health_range",   "1000", true, false)
local cv_width   = CreateClientConVar("sakura_health_width",   "120", true, false)
local cv_height  = CreateClientConVar("sakura_health_height",  "8", true, false)

-- ===== 配置 ConVar — 生命条颜色 =====
local cv_col_friend_r = CreateClientConVar("sakura_health_friend_r", "135", true, false)
local cv_col_friend_g = CreateClientConVar("sakura_health_friend_g", "206", true, false)
local cv_col_friend_b = CreateClientConVar("sakura_health_friend_b", "250", true, false)

local cv_col_enemy_r = CreateClientConVar("sakura_health_enemy_r", "30",  true, false)
local cv_col_enemy_g = CreateClientConVar("sakura_health_enemy_g", "144", true, false)
local cv_col_enemy_b = CreateClientConVar("sakura_health_enemy_b", "255", true, false)

local cv_col_bg_r = CreateClientConVar("sakura_health_bg_r", "30",  true, false)
local cv_col_bg_g = CreateClientConVar("sakura_health_bg_g", "30",  true, false)
local cv_col_bg_b = CreateClientConVar("sakura_health_bg_b", "30",  true, false)
local cv_col_bg_a = CreateClientConVar("sakura_health_bg_a", "180", true, false)

local cv_col_dmg_r   = CreateClientConVar("sakura_health_dmg_r",   "255", true, false)
local cv_col_dmg_g   = CreateClientConVar("sakura_health_dmg_g",   "255", true, false)
local cv_col_dmg_b   = CreateClientConVar("sakura_health_dmg_b",   "255", true, false)

local cv_col_flash_r = CreateClientConVar("sakura_health_flash_r", "255", true, false)
local cv_col_flash_g = CreateClientConVar("sakura_health_flash_g", "255", true, false)
local cv_col_flash_b = CreateClientConVar("sakura_health_flash_b", "255", true, false)

-- ===== 配置 ConVar — 护甲条参数 =====
local cv_armor_height  = CreateClientConVar("sakura_health_armor_height", "2", true, false)
local cv_col_armor_r   = CreateClientConVar("sakura_health_armor_r", "0",   true, false)
local cv_col_armor_g   = CreateClientConVar("sakura_health_armor_g", "255", true, false)
local cv_col_armor_b   = CreateClientConVar("sakura_health_armor_b", "255", true, false)

-- ===== 目标缓存表 =====
local TargetCache = {}

-- ===== 多语言字符串 =====
local LANGUAGE = {
    zh = {
        menu_title      = "血条显示设置",
        enable          = "启用血条显示",
        mode            = "显示模式",
        mode_1          = "视线内所有目标",
        mode_2          = "仅准星瞄准目标",
        mode_3          = "范围内所有目标 (透视)",
        range           = "最大显示距离",
        size_w          = "血条宽度",
        size_h          = "血条高度",
        col_friend      = "友军血条颜色",
        col_enemy       = "敌军血条颜色",
        col_bg          = "背景底色",
        col_dmg         = "受损部分颜色",
        col_flash       = "闪烁颜色",
        armor_section   = "── 护甲条设置 ──",
        armor_height    = "护甲条高度",
        col_armor       = "护甲条颜色",
        reset           = "重置为默认值",
        reset_desc      = "已重置血条设置",
        language        = "语言"
    },
    en = {
        menu_title      = "Health Bar Settings",
        enable          = "Enable Health Bar",
        mode            = "Display Mode",
        mode_1          = "Visible Targets",
        mode_2          = "Crosshair Only",
        mode_3          = "All Targets (X-Ray)",
        range           = "Max Distance",
        size_w          = "Bar Width",
        size_h          = "Bar Height",
        col_friend      = "Friendly Color",
        col_enemy       = "Enemy Color",
        col_bg          = "Background Color",
        col_dmg         = "Damage Color",
        col_flash       = "Flash Color",
        armor_section   = "── Armor Bar Settings ──",
        armor_height    = "Armor Bar Height",
        col_armor       = "Armor Bar Color",
        reset           = "Reset to Default",
        reset_desc      = "Settings reset",
        language        = "Language"
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

-- ===== 准星目标检测 =====
local crosshairEntity = NULL
local lastCrosshairCheck = 0
local CROSSHAIR_CHECK_INTERVAL = 0.05

local function UpdateCrosshairTarget()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local curTime = UnPredictedCurTime()
    if curTime - lastCrosshairCheck < CROSSHAIR_CHECK_INTERVAL then return end
    lastCrosshairCheck = curTime

    local trace = ply:GetEyeTrace()

    if trace.Hit and trace.HitNonWorld and IsValid(trace.Entity) then
        local ent = trace.Entity
        if ent ~= ply and ent:GetNWBool("Sakura_Health_Valid", false) then
            crosshairEntity = ent
            return
        end
    end

    crosshairEntity = NULL
end

-- ===== 目标收集 =====
local TargetClasses = {"npc_*", "monster_*"}

local function CollectTargets(mode, maxRange)
    local ply = LocalPlayer()
    if not IsValid(ply) then return {} end

    local targets = {}
    local playerPos = ply:EyePos()

    if mode == 1 then
        for _, class in ipairs(TargetClasses) do
            for _, ent in pairs(ents.FindByClass(class)) do
                if IsValid(ent) and ent:GetNWBool("Sakura_Health_Valid", false) then
                    local dist = playerPos:Distance(ent:GetPos())
                    if dist < maxRange and ent:IsLineOfSightClear(playerPos) then
                        table.insert(targets, ent)
                    end
                end
            end
        end
        for _, ent in ipairs(player.GetAll()) do
            if ent ~= ply and IsValid(ent) and ent:GetNWBool("Sakura_Health_Valid", false) then
                local dist = playerPos:Distance(ent:GetPos())
                if dist < maxRange and ent:IsLineOfSightClear(playerPos) then
                    table.insert(targets, ent)
                end
            end
        end

    elseif mode == 2 then
        if IsValid(crosshairEntity) and crosshairEntity:GetNWBool("Sakura_Health_Valid", false) then
            table.insert(targets, crosshairEntity)
        end

    elseif mode == 3 then
        for _, class in ipairs(TargetClasses) do
            for _, ent in pairs(ents.FindByClass(class)) do
                if IsValid(ent) and ent:GetNWBool("Sakura_Health_Valid", false) then
                    if playerPos:Distance(ent:GetPos()) < maxRange then
                        table.insert(targets, ent)
                    end
                end
            end
        end
        for _, ent in ipairs(player.GetAll()) do
            if ent ~= ply and IsValid(ent) and ent:GetNWBool("Sakura_Health_Valid", false) then
                if playerPos:Distance(ent:GetPos()) < maxRange then
                    table.insert(targets, ent)
                end
            end
        end
    end

    return targets
end

-- ===== 目标缓存更新 =====
local function AddTargetToCache(ent)
    local idx       = ent:EntIndex()
    local hp        = ent:GetNWInt("Sakura_Health_HP", 0)
    local max_hp    = ent:GetNWInt("Sakura_Health_MaxHP", 100)
    local timestamp = UnPredictedCurTime()

    local is_friend = false
    if ent:IsPlayer() then
        local ply = LocalPlayer()
        if ent:Team() == ply:Team() and ent:Team() ~= 0 and ent:Team() ~= 1001 then
            is_friend = true
        end
    elseif ent:IsNPC() then
        -- Disposition: D_HT=1(仇恨) D_FR=2(恐惧) D_LI=3(喜爱) D_NU=4(中立)
        local relation = ent:GetNWInt("Sakura_Health_Relation_" .. LocalPlayer():UniqueID(), 1)
        is_friend = (relation == 3 or relation == 4)
    elseif ent:IsNextBot() then
        is_friend = false
    end

    if not TargetCache[idx] then
        TargetCache[idx] = {
            ent              = ent,
            hp               = hp,
            max_hp           = max_hp,
            is_friend        = is_friend,
            decay_hp         = hp,
            flash_end_time   = 0,
            last_update_time = timestamp,
            last_pos         = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 10),
            fade             = 255,
            fade_delay       = timestamp + 0.25
        }
    else
        local data = TargetCache[idx]

        if hp < data.hp then
            data.decay_hp      = data.hp
            data.flash_end_time = timestamp + 2.0
        end

        data.hp               = hp
        data.max_hp           = max_hp
        data.is_friend        = is_friend
        data.last_update_time = timestamp
        data.last_pos         = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 10)
        data.fade             = 255
        data.fade_delay       = timestamp + 0.25
    end
end

local function LerpColor(t, c1, c2)
    return Color(
        c1.r + (c2.r - c1.r) * t,
        c1.g + (c2.g - c1.g) * t,
        c1.b + (c2.b - c1.b) * t,
        255
    )
end

-- ===== 核心绘制 Hook =====
hook.Add("HUDPaint", "DrawSakuraHealthBar", function()
    if not cv_enabled:GetBool() then return end

    local svEnabled = GetConVar("sv_sakura_health_enabled")
    if svEnabled and not svEnabled:GetBool() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local curTime   = UnPredictedCurTime()
    local frameTime = FrameTime()

    UpdateCrosshairTarget()

    local ScH = ScrH() / 1080
    local BAR_W = cv_width:GetInt()  * ScH
    local BAR_H = cv_height:GetInt() * ScH
    local ARMOR_H = cv_armor_height:GetInt() * ScH

    local displayMode = cv_mode:GetInt()
    local maxRange    = cv_range:GetInt()
    local col_bg     = Color(cv_col_bg_r:GetInt(),     cv_col_bg_g:GetInt(),     cv_col_bg_b:GetInt(),     cv_col_bg_a:GetInt())
    local col_dmg    = Color(cv_col_dmg_r:GetInt(),    cv_col_dmg_g:GetInt(),    cv_col_dmg_b:GetInt())
    local col_friend = Color(cv_col_friend_r:GetInt(), cv_col_friend_g:GetInt(), cv_col_friend_b:GetInt())
    local col_enemy  = Color(cv_col_enemy_r:GetInt(),  cv_col_enemy_g:GetInt(),  cv_col_enemy_b:GetInt())
    local col_flash  = Color(cv_col_flash_r:GetInt(),  cv_col_flash_g:GetInt(),  cv_col_flash_b:GetInt())
    local col_armor  = Color(cv_col_armor_r:GetInt(),  cv_col_armor_g:GetInt(),  cv_col_armor_b:GetInt())

    local activeTargets = CollectTargets(displayMode, maxRange)
    for _, ent in ipairs(activeTargets) do
        AddTargetToCache(ent)
    end

    for idx, data in pairs(TargetCache) do
        local entValid  = IsValid(data.ent) and data.ent:GetNWBool("Sakura_Health_Valid", false)
        local decayActive = data.decay_hp > (entValid and data.hp or 0.1)

        if entValid then
            local inActiveList = false
            for _, ent in ipairs(activeTargets) do
                if ent == data.ent then inActiveList = true; break end
            end
            if not inActiveList then
                if curTime > data.fade_delay then
                    data.fade = math.max(0, data.fade - frameTime * 765)
                end
            end
        else
            if not decayActive then
                data.fade = math.max(0, data.fade - frameTime * 765)
            end
        end

        -- 完全淡出且实体无效时清除缓存条目
        if data.fade <= 0 and not entValid then
            TargetCache[idx] = nil

        elseif data.fade > 0 or decayActive then
            local drawPos = data.last_pos
            if entValid then
                drawPos      = data.ent:GetPos() + Vector(0, 0, data.ent:OBBMaxs().z + 10)
                data.last_pos = drawPos
            end

            local screenData = drawPos:ToScreen()

            if screenData.visible then
                local currentHP = entValid and data.hp or 0
                local hpPct     = math.Clamp(currentHP / data.max_hp, 0, 1)

                data.decay_hp = math.Approach(data.decay_hp, currentHP, frameTime * data.max_hp * 2.0)
                local decayPct = math.Clamp(data.decay_hp / data.max_hp, 0, 1)

                local baseColor = data.is_friend and col_friend or col_enemy
                local drawColor = baseColor
                if curTime < data.flash_end_time and entValid then
                    local flashLeft = data.flash_end_time - curTime
                    local wave      = math.abs(math.sin(curTime * 8)) * (flashLeft / 2)
                    drawColor       = LerpColor(wave, baseColor, col_flash)
                end

                local rx = screenData.x - BAR_W / 2
                local ry = screenData.y
                local alpha = math.min(data.fade, 255)

                local alphaBg    = Color(col_bg.r,    col_bg.g,    col_bg.b,    math.min(col_bg.a, alpha))
                local alphaDmg   = Color(col_dmg.r,   col_dmg.g,   col_dmg.b,   alpha)
                local alphaColor = Color(drawColor.r, drawColor.g, drawColor.b, alpha)

                surface.SetDrawColor(alphaBg)
                surface.DrawRect(rx, ry, BAR_W, BAR_H)

                if decayPct > 0 then
                    surface.SetDrawColor(alphaDmg)
                    surface.DrawRect(rx, ry, BAR_W * decayPct, BAR_H)
                end

                if hpPct > 0 then
                    surface.SetDrawColor(alphaColor)
                    surface.DrawRect(rx, ry, BAR_W * hpPct, BAR_H)
                end

                -- ──────────────────────────────
                -- 绘制护甲条（紧贴生命条上方）
                -- 仅当目标拥有护甲且护甲高度 > 0 时绘制；无衰减/闪烁动画
                -- ──────────────────────────────
                if entValid and ARMOR_H > 0 then
                    local hasArmor  = data.ent:GetNWBool("Sakura_Health_HasArmor", false)
                    local curArmor  = data.ent:GetNWInt("Sakura_Health_Armor", 0)
                    local maxArmor  = data.ent:GetNWInt("Sakura_Health_ArmorMax", 0)

                    -- 仅在目标确实拥有护甲系统且最大护甲 > 0 时绘制护甲条
                    if hasArmor and maxArmor > 0 then
                        local armorPct = math.Clamp(curArmor / maxArmor, 0, 1)

                        -- 护甲条 Y 坐标：生命条顶边缘上方（紧贴，无间隙）
                        local ary = ry - ARMOR_H

                        -- 护甲条背景（与生命条底色一致）
                        surface.SetDrawColor(alphaBg)
                        surface.DrawRect(rx, ary, BAR_W, ARMOR_H)

                        -- 护甲条填充
                        if armorPct > 0 then
                            local alphaArmor = Color(col_armor.r, col_armor.g, col_armor.b, alpha)
                            surface.SetDrawColor(alphaArmor)
                            surface.DrawRect(rx, ary, BAR_W * armorPct, ARMOR_H)
                        end
                    end
                end
            end
        end
    end
end)

-- ===== 设置面板构建 =====
local function BuildSakuraHealthMenu(panel)
    panel:ClearControls()
    panel:Help(GetText("menu_title"))

    local langCombo = panel:ComboBox(GetText("language"))
    langCombo:AddChoice("中文",    "zh", GetCurrentLang() == "zh")
    langCombo:AddChoice("English", "en", GetCurrentLang() == "en")
    langCombo.OnSelect = function(self, index, value, data)
        SetLang(data)
        timer.Simple(0.1, function()
            if IsValid(panel) then BuildSakuraHealthMenu(panel) end
        end)
    end

    panel:Help(" ")
    panel:CheckBox(GetText("enable"), "sakura_health_enabled")

    local combo = panel:ComboBox(GetText("mode"), "sakura_health_mode")
    combo:AddChoice(GetText("mode_1"), 1)
    combo:AddChoice(GetText("mode_2"), 2)
    combo:AddChoice(GetText("mode_3"), 3)

    panel:NumSlider(GetText("range"), "sakura_health_range", 100, 5000, 0)
    panel:NumSlider(GetText("size_w"), "sakura_health_width", 50, 400, 0)
    panel:NumSlider(GetText("size_h"), "sakura_health_height", 1, 30, 0)

    local function AddMixer(label, r, g, b, a)
        panel:ControlHelp("\n" .. label)
        local m = vgui.Create("DColorMixer", panel)
        m:SetPalette(true)
        m:SetAlphaBar(a ~= nil)
        m:SetTall(100)
        m:SetColor(Color(
            GetConVar(r):GetInt(),
            GetConVar(g):GetInt(),
            GetConVar(b):GetInt(),
            a and GetConVar(a):GetInt() or 255
        ))
        m.ValueChanged = function(_, col)
            RunConsoleCommand(r, col.r)
            RunConsoleCommand(g, col.g)
            RunConsoleCommand(b, col.b)
            if a then RunConsoleCommand(a, col.a) end
        end
        panel:AddItem(m)
    end

    AddMixer(GetText("col_enemy"),  "sakura_health_enemy_r",  "sakura_health_enemy_g",  "sakura_health_enemy_b")
    AddMixer(GetText("col_friend"), "sakura_health_friend_r", "sakura_health_friend_g", "sakura_health_friend_b")
    AddMixer(GetText("col_bg"),     "sakura_health_bg_r",     "sakura_health_bg_g",     "sakura_health_bg_b",   "sakura_health_bg_a")
    AddMixer(GetText("col_dmg"),    "sakura_health_dmg_r",    "sakura_health_dmg_g",    "sakura_health_dmg_b")
    AddMixer(GetText("col_flash"),  "sakura_health_flash_r",  "sakura_health_flash_g",  "sakura_health_flash_b")

    panel:Help(" ")
    panel:Help(GetText("armor_section"))
    panel:NumSlider(GetText("armor_height"), "sakura_health_armor_height", 1, 15, 0)
    AddMixer(GetText("col_armor"), "sakura_health_armor_r", "sakura_health_armor_g", "sakura_health_armor_b")

    panel:Help(" ")
    local btnReset = panel:Button(GetText("reset"))
    btnReset.DoClick = function()
        RunConsoleCommand("sakura_health_mode",   "1")
        RunConsoleCommand("sakura_health_range",  "1000")
        RunConsoleCommand("sakura_health_width",  "120")
        RunConsoleCommand("sakura_health_height", "8")
        RunConsoleCommand("sakura_health_friend_r", "135")
        RunConsoleCommand("sakura_health_friend_g", "206")
        RunConsoleCommand("sakura_health_friend_b", "250")

        RunConsoleCommand("sakura_health_enemy_r", "30")
        RunConsoleCommand("sakura_health_enemy_g", "144")
        RunConsoleCommand("sakura_health_enemy_b", "255")

        RunConsoleCommand("sakura_health_bg_r", "30")
        RunConsoleCommand("sakura_health_bg_g", "30")
        RunConsoleCommand("sakura_health_bg_b", "30")
        RunConsoleCommand("sakura_health_bg_a", "180")

        RunConsoleCommand("sakura_health_dmg_r", "255")
        RunConsoleCommand("sakura_health_dmg_g", "255")
        RunConsoleCommand("sakura_health_dmg_b", "255")

        RunConsoleCommand("sakura_health_flash_r", "255")
        RunConsoleCommand("sakura_health_flash_g", "255")
        RunConsoleCommand("sakura_health_flash_b", "255")
        RunConsoleCommand("sakura_health_armor_height", "2")
        RunConsoleCommand("sakura_health_armor_r", "0")
        RunConsoleCommand("sakura_health_armor_g", "255")
        RunConsoleCommand("sakura_health_armor_b", "255")

        notification.AddLegacy(GetText("reset_desc"), NOTIFY_GENERIC, 3)
        timer.Simple(0.1, function() if IsValid(panel) then BuildSakuraHealthMenu(panel) end end)
    end
end

hook.Add("PopulateToolMenu", "SakuraHealth_Options", function()
    spawnmenu.AddToolMenuOption("Options", "Sakura HUD", "SakuraHealth_Settings", "血条显示设置", "", "", function(p) BuildSakuraHealthMenu(p) end)
end)