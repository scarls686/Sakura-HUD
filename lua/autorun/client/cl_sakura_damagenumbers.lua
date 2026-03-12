if CLIENT then
    -- ===== 客户端配置变量 =====
    local cv_enable = CreateClientConVar("sakura_dmgnum_enable", "1", true, false)
    local cv_font_style = CreateClientConVar("sakura_dmgnum_font", "FZSJ-LIANRSZYHC", true, false)
    local cv_size = CreateClientConVar("sakura_dmgnum_size", "35", true, false)
    local cv_lifetime = CreateClientConVar("sakura_dmgnum_lifetime", "0.8", true, false)

    local cv_col_norm_r = CreateClientConVar("sakura_dmgnum_col_norm_r", "255", true, false)
    local cv_col_norm_g = CreateClientConVar("sakura_dmgnum_col_norm_g", "255", true, false)
    local cv_col_norm_b = CreateClientConVar("sakura_dmgnum_col_norm_b", "255", true, false)

    local cv_col_crit_r = CreateClientConVar("sakura_dmgnum_col_crit_r", "255", true, false)
    local cv_col_crit_g = CreateClientConVar("sakura_dmgnum_col_crit_g", "183", true, false)
    local cv_col_crit_b = CreateClientConVar("sakura_dmgnum_col_crit_b", "197", true, false)

    -- ===== 多语言系统 =====
    local LANGUAGE = {
        zh = {
            menu_title = "伤害跳字设置",
            enable = "启用伤害跳字",
            font_select = "字体样式",
            font_size = "数字大小",
            lifetime = "存在时间 (秒)",
            col_norm = "普通伤害颜色",
            col_crit = "爆头伤害颜色",
            reset = "重置为默认值",
            reset_desc = "伤害跳字设置已重置",
            language = "语言"
        },
        en = {
            menu_title = "Damage Numbers Settings",
            enable = "Enable Damage Numbers",
            font_select = "Font Style",
            font_size = "Number Size",
            lifetime = "Lifetime (Seconds)",
            col_norm = "Normal Damage Color",
            col_crit = "Headshot Color",
            reset = "Reset to Default",
            reset_desc = "Damage number settings reset",
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

    -- ===== 字体管理 =====
    local currentFontName = "Sakura_DmgNum_Font_Dynamic"
    
    local function UpdateFont()
        local fontName = cv_font_style:GetString()
        local fontSize = ScreenScale(cv_size:GetInt() / 2)

        surface.CreateFont(currentFontName, {
            font = fontName,
            extended = true,
            size = fontSize,
            weight = 500,
            blursize = 0,
            scanlines = 0,
            antialias = true,
            outline = false,
            shadow = true
        })
    end

    cvars.AddChangeCallback("sakura_dmgnum_font", UpdateFont)
    cvars.AddChangeCallback("sakura_dmgnum_size", UpdateFont)
    hook.Add("InitPostEntity", "Sakura_DmgNum_Init", UpdateFont)
    UpdateFont()

    -- ===== 渲染核心逻辑 =====
    local active_numbers = {}

    net.Receive("Sakura_DamageNumber", function()
        if not cv_enable:GetBool() then return end

        local amount = net.ReadFloat()
        local pos = net.ReadVector()
        local isHeadshot = net.ReadBool()

        local data = {
            text = tostring(math.Round(amount)),
            pos = pos,
            vel = Vector(math.Rand(-50, 50), math.Rand(-50, 50), math.Rand(200, 300)),
            gravity = -686,
            startTime = UnPredictedCurTime(),
            lifetime = cv_lifetime:GetFloat(),
            isHeadshot = isHeadshot,
            alpha = 255
        }
        
        table.insert(active_numbers, data)
    end)

    hook.Add("HUDPaint", "Sakura_DrawDamageNumbers", function()
        if #active_numbers == 0 then return end
        
        local curTime = UnPredictedCurTime()
        local frameTime = RealFrameTime()
        local col_norm = Color(cv_col_norm_r:GetInt(), cv_col_norm_g:GetInt(), cv_col_norm_b:GetInt())
        local col_crit = Color(cv_col_crit_r:GetInt(), cv_col_crit_g:GetInt(), cv_col_crit_b:GetInt())

        for i = #active_numbers, 1, -1 do
            local dmgData = active_numbers[i]
            local elapsed = curTime - dmgData.startTime

            if elapsed >= dmgData.lifetime then
                table.remove(active_numbers, i)
            else
                dmgData.vel.z = dmgData.vel.z + dmgData.gravity * frameTime
                dmgData.pos = dmgData.pos + dmgData.vel * frameTime

                if elapsed > (dmgData.lifetime * 0.7) then
                    local fadeProgress = (elapsed - (dmgData.lifetime * 0.7)) / (dmgData.lifetime * 0.3)
                    dmgData.alpha = 255 * (1 - fadeProgress)
                else
                    if elapsed < 0.1 then
                        dmgData.alpha = (elapsed / 0.1) * 255
                    else
                        dmgData.alpha = 255
                    end
                end

                local screenPos = dmgData.pos:ToScreen()

                if screenPos.visible then
                    local drawColor = dmgData.isHeadshot and col_crit or col_norm
                    draw.SimpleText(
                        dmgData.text,
                        currentFontName,
                        screenPos.x,
                        screenPos.y,
                        Color(drawColor.r, drawColor.g, drawColor.b, dmgData.alpha),
                        TEXT_ALIGN_CENTER,
                        TEXT_ALIGN_CENTER
                    )
                end
            end
        end
    end)

    -- ===== UI 菜单 =====
    local function BuildSakuraDamageNumMenu(panel)
        panel:ClearControls()
        panel:Help(GetText("menu_title"))

        local langCombo = panel:ComboBox(GetText("language"))
        langCombo:AddChoice("中文", "zh", GetCurrentLang() == "zh")
        langCombo:AddChoice("English", "en", GetCurrentLang() == "en")
        langCombo.OnSelect = function(self, index, value, data)
            SetLang(data)
            timer.Simple(0.1, function()
                if IsValid(panel) then BuildSakuraDamageNumMenu(panel) end
            end)
        end

        panel:Help(" ")
        panel:CheckBox(GetText("enable"), "sakura_dmgnum_enable")

        local fontCombo = panel:ComboBox(GetText("font_select"), "sakura_dmgnum_font")
        fontCombo:AddChoice("Sakura Style (FZSJ-LIANRSZYHC)", "FZSJ-LIANRSZYHC")
        fontCombo:AddChoice("Clean Style (Segoe UI Light)", "Segoe UI Light")
        fontCombo:AddChoice("Default (Arial)", "Arial")
        
        panel:NumSlider(GetText("font_size"), "sakura_dmgnum_size", 10, 100, 0)
        panel:NumSlider(GetText("lifetime"), "sakura_dmgnum_lifetime", 0.5, 5, 1)

        panel:ControlHelp("\n" .. GetText("col_norm"))
        local cpNorm = vgui.Create("DColorMixer", panel)
        cpNorm:SetPalette(true)
        cpNorm:SetAlphaBar(false)
        cpNorm:SetColor(Color(cv_col_norm_r:GetInt(), cv_col_norm_g:GetInt(), cv_col_norm_b:GetInt()))
        cpNorm:SetTall(100)
        cpNorm.ValueChanged = function(_, col)
            RunConsoleCommand("sakura_dmgnum_col_norm_r", tostring(col.r))
            RunConsoleCommand("sakura_dmgnum_col_norm_g", tostring(col.g))
            RunConsoleCommand("sakura_dmgnum_col_norm_b", tostring(col.b))
        end
        panel:AddItem(cpNorm)

        panel:ControlHelp("\n" .. GetText("col_crit"))
        local cpCrit = vgui.Create("DColorMixer", panel)
        cpCrit:SetPalette(true)
        cpCrit:SetAlphaBar(false)
        cpCrit:SetColor(Color(cv_col_crit_r:GetInt(), cv_col_crit_g:GetInt(), cv_col_crit_b:GetInt()))
        cpCrit:SetTall(100)
        cpCrit.ValueChanged = function(_, col)
            RunConsoleCommand("sakura_dmgnum_col_crit_r", tostring(col.r))
            RunConsoleCommand("sakura_dmgnum_col_crit_g", tostring(col.g))
            RunConsoleCommand("sakura_dmgnum_col_crit_b", tostring(col.b))
        end
        panel:AddItem(cpCrit)

        panel:Help(" ")
        local btnReset = panel:Button(GetText("reset"))
        btnReset.DoClick = function()
            RunConsoleCommand("sakura_dmgnum_enable", "1")
            RunConsoleCommand("sakura_dmgnum_font", "FZSJ-LIANRSZYHC")
            RunConsoleCommand("sakura_dmgnum_size", "35")
            RunConsoleCommand("sakura_dmgnum_lifetime", "0.8")
            RunConsoleCommand("sakura_dmgnum_col_norm_r", "255")
            RunConsoleCommand("sakura_dmgnum_col_norm_g", "255")
            RunConsoleCommand("sakura_dmgnum_col_norm_b", "255")
            RunConsoleCommand("sakura_dmgnum_col_crit_r", "255")
            RunConsoleCommand("sakura_dmgnum_col_crit_g", "183")
            RunConsoleCommand("sakura_dmgnum_col_crit_b", "197")

            notification.AddLegacy(GetText("reset_desc"), NOTIFY_GENERIC, 3)
            timer.Simple(0.1, function()
                if IsValid(panel) then BuildSakuraDamageNumMenu(panel) end
            end)
        end
    end

    hook.Add("PopulateToolMenu", "SakuraDamageNum_Options", function()
        spawnmenu.AddToolMenuOption("Options", "Sakura HUD", "SakuraDamageNum_Settings", "伤害跳字设置", "", "", function(panel)
            BuildSakuraDamageNumMenu(panel)
        end)
    end)
end