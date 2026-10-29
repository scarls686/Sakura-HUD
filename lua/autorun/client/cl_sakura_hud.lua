if SERVER then return end

local function GetText(key)
    return language.GetPhrase("sakura_hud.hud." .. key)
end

-- ===== 玩家可调整设置 =====
local cv_offX = CreateClientConVar("sakura_hud_x", "160", true, false, GetText("help_forward"))
local cv_offY = CreateClientConVar("sakura_hud_y", "-120", true, false, GetText("help_right"))
local cv_offZ = CreateClientConVar("sakura_hud_z", "-50", true, false, GetText("help_up"))

local cv_rotLeft  = CreateClientConVar("sakura_hud_rot_left", "-25", true, false, GetText("help_pitch"))
local cv_rotTop   = CreateClientConVar("sakura_hud_rot_top", "-15", true, false, GetText("help_yaw"))
local cv_rotPoint = CreateClientConVar("sakura_hud_rot_point", "5", true, false, GetText("help_roll"))

local cv_scale = CreateClientConVar("sakura_hud_scale", "1.0", true, false, GetText("help_scale"), 0.5, 2.0)

local cv_aimX = CreateClientConVar("sakura_hud_aim_x", "135", true, false, GetText("help_aim_x"))
local cv_aimY = CreateClientConVar("sakura_hud_aim_y", "0", true, false, GetText("help_aim_y"))

local cv_enabled = CreateClientConVar("sakura_hud_enabled", "1", true, false, GetText("help_enabled"))
local cv_aimMode = CreateClientConVar("sakura_hud_aim_mode", "1", true, false, GetText("help_aim_mode"))
local cv_blur = CreateClientConVar("sakura_hud_blur", "1", true, false, GetText("help_blur"))
local cv_shadow = CreateClientConVar("sakura_hud_shadow", "1", true, false, GetText("help_shadow"))

-- ===== 基础配置 =====
local BASE_W, BASE_H = 1920, 1080
local PETAL_MAT = Material("sakura/sakura_petal")
local BLUR_MAT = CreateMaterial("SakuraHUD_BlurPanel", "Refract", {
    ["$refractamount"]  = "0.01",
    ["$refracttint"]    = "[1 1 1]",
    ["$normalmap"]      = "dev/bump_normal",
    ["$bluramount"]     = "2",
    ["$model"]          = "1",
    ["$nocull"]         = "1",
})
-- 为飘落花瓣预留左侧空间。
local PETAL_MARGIN = 120

local COLOR_SAKURA   = Color(255, 183, 197, 255)
local COLOR_DANGER   = Color(255, 80, 80, 255)
local COLOR_POISON   = Color(0, 255, 127, 255)
local COLOR_ARMOR    = Color(0, 191, 255, 255)
local COLOR_WHITE    = Color(255, 255, 255, 255)
local COLOR_EMPTY    = Color(30, 30, 30, 150)
local COLOR_BG_PANEL = Color(255, 255, 255, 30)

local visualArmor = 0
local isPoisoned = false
local lastHP = 100
local petalAnimations = {}
local fallingPetals = {}

net.Receive("SakuraHUD_PoisonSync", function()
    isPoisoned = net.ReadBool()
end)

local function Scale(val)
    return val * (ScrH() / BASE_H)
end

-- ===== 字体定义 =====
surface.CreateFont("Sakura_ThemeFont", { 
    font = "FZSJ-LIANRSZYHC", 
    size = 30, 
    weight = 300, 
    extended = true 
})

surface.CreateFont("SakuraMainFont", { 
    font = "Segoe UI Light", 
    size = Scale(70), 
    weight = 300, 
    antialias = true 
})

surface.CreateFont("Sakura3D_Large", { 
    font = "Segoe UI Light", 
    size = 60, 
    weight = 300, 
    antialias = true 
})

surface.CreateFont("Sakura3D_Medium", { 
    font = "Segoe UI Light", 
    size = 40, 
    weight = 300, 
    antialias = true 
})

surface.CreateFont("Sakura3D_Small", { 
    font = "Segoe UI Light", 
    size = 30, 
    weight = 300, 
    antialias = true 
})

-- ===== 绘图函数 =====

local COLOR_SHADOW = Color(0, 0, 0, 120)

local function DrawTextShadow(text, font, x, y, color, alignX, alignY, ox, oy)
    if cv_shadow:GetBool() then
        local sx = ox or 2
        local sy = oy or 2
        draw.SimpleText(text, font, x + sx, y + sy, COLOR_SHADOW, alignX, alignY)
    end
    draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

-- 预计算护甲环顶点
local armorRingCache = {}
local function CacheArmorRing(radius, thickness, segments)
    local cacheKey = radius .. "_" .. thickness .. "_" .. segments
    if armorRingCache[cacheKey] then return armorRingCache[cacheKey] end
    
    segments = segments or 10
    local gapAngle = 5
    local sectorAngle = (360 / segments) - gapAngle
    local cache = {}
    
    for i = 1, segments do
        local startAngle = -90 + (i - 1) * (sectorAngle + gapAngle)
        cache[i] = {
            background = {},
            fill = {}
        }

        for t = 0, thickness do
            local r = radius - t
            local step = sectorAngle / 8
            for j = 0, 7 do
                local a1 = math.rad(startAngle + j * step)
                local a2 = math.rad(startAngle + (j + 1) * step)
                table.insert(cache[i].background, {
                    x1 = math.cos(a1) * r,
                    y1 = math.sin(a1) * r,
                    x2 = math.cos(a2) * r,
                    y2 = math.sin(a2) * r
                })
            end
        end

        for t = 0, thickness do
            local r = radius - t
            local step = sectorAngle / 8
            for j = 0, 7 do
                local a1 = math.rad(startAngle + j * step)
                local a2 = math.rad(startAngle + (j + 1) * step)
                table.insert(cache[i].fill, {
                    x1 = math.cos(a1) * r,
                    y1 = math.sin(a1) * r,
                    x2 = math.cos(a2) * r,
                    y2 = math.sin(a2) * r,
                    angle = startAngle
                })
            end
        end
    end
    
    armorRingCache[cacheKey] = cache
    return cache
end

local function DrawSegmentedArmor3D(x, y, radius, percentage, thickness, segments)
    segments = segments or 10
    local cache = CacheArmorRing(radius, thickness, segments)
    local currentProgress = percentage * segments
    
    for i = 1, segments do
        local segmentData = cache[i]
        local segmentFill = math.Clamp(currentProgress - (i - 1), 0, 1)

        surface.SetDrawColor(COLOR_BG_PANEL)
        for _, v in ipairs(segmentData.background) do
            surface.DrawLine(x + v.x1, y + v.y1, x + v.x2, y + v.y2)
        end

        if segmentFill > 0 then
            surface.SetDrawColor(COLOR_ARMOR)

            if segmentFill >= 1 then
                for _, v in ipairs(segmentData.fill) do
                    surface.DrawLine(x + v.x1, y + v.y1, x + v.x2, y + v.y2)
                end
            else
                local sectorAngle = (360 / segments) - 5
                local drawAngle = sectorAngle * segmentFill
                local startAngle = segmentData.fill[1].angle
                
                for t = 0, thickness do
                    local r = radius - t
                    local step = drawAngle / 8
                    for j = 0, 7 do
                        local a1 = math.rad(startAngle + j * step)
                        local a2 = math.rad(startAngle + (j + 1) * step)
                        surface.DrawLine(
                            x + math.cos(a1) * r, y + math.sin(a1) * r,
                            x + math.cos(a2) * r, y + math.sin(a2) * r
                        )
                    end
                end
            end
        end
    end
end

local function DrawSakuraHealth3D(centerX, centerY, size, hp, maxHP)
    maxHP = (maxHP and maxHP > 0) and maxHP or 100
    -- 每片花瓣代表 20% 血量
    local hpPerPetal = maxHP / 5

    surface.SetMaterial(PETAL_MAT)
    local dist = size * 0.38
    local flash = (math.sin(RealTime() * 9) + 1) / 2

    if hp ~= lastHP then
        local oldPetalCount = math.ceil(lastHP / hpPerPetal)
        local newPetalCount = math.ceil(hp / hpPerPetal)

        if newPetalCount > oldPetalCount then
            for i = oldPetalCount + 1, newPetalCount do
                local fromIndex = i - 1
                local toIndex = i

                petalAnimations[i] = {
                    progress = 0,
                    fromAngle = (fromIndex - 1) * 72,
                    toAngle = (toIndex - 1) * 72,
                    direction = 1
                }
            end
        elseif newPetalCount < oldPetalCount then
            for i = oldPetalCount, newPetalCount + 1, -1 do
                local stepAngle = (i - 1) * 72
                local rad = math.rad(stepAngle - 90)
                local startX = centerX + math.cos(rad) * dist
                local startY = centerY + math.sin(rad) * dist

                local petalColor = isPoisoned and COLOR_POISON or COLOR_DANGER

                table.insert(fallingPetals, {
                    x = startX,
                    y = startY,
                    vx = math.random(-30, 30) / 10,
                    vy = math.random(40, 80) / 10,
                    rotation = -stepAngle,
                    rotSpeed = math.random(-200, 200) / 10,
                    color = petalColor,
                    alpha = 255,
                    startTime = RealTime(),
                    lifetime = 2.5
                })
            end
        end

        lastHP = hp
    end

    local animSpeed = 5 * FrameTime()
    for i, anim in pairs(petalAnimations) do
        anim.progress = math.min(anim.progress + animSpeed, 1)
        if anim.progress >= 1 then
            petalAnimations[i] = nil
        end
    end

    local dt = FrameTime()
    for i = #fallingPetals, 1, -1 do
        local petal = fallingPetals[i]
        local elapsed = RealTime() - petal.startTime

        if elapsed >= petal.lifetime then
            table.remove(fallingPetals, i)
        else
            petal.x = petal.x + petal.vx * dt * 60
            petal.y = petal.y + petal.vy * dt * 60
            petal.rotation = petal.rotation + petal.rotSpeed * dt

            petal.alpha = 255 * (1 - elapsed / petal.lifetime)
        end
    end

    for i = 1, 5 do
        local stepAngle = (i - 1) * 72
        local rad = math.rad(stepAngle - 90)
        local px = centerX + math.cos(rad) * dist
        local py = centerY + math.sin(rad) * dist
        
        surface.SetDrawColor(COLOR_EMPTY)
        surface.DrawTexturedRectRotated(px, py, size, size, -stepAngle)
    end

    for i = 1, 5 do
        local petalMaxHP = i * hpPerPetal
        local petalMinHP = (i - 1) * hpPerPetal
        local shouldDraw = false
        local petalColor = COLOR_EMPTY
        local drawAngle = (i - 1) * 72
        local drawDist = dist

        if petalAnimations[i] then
            local anim = petalAnimations[i]
            local angleDiff = anim.toAngle - anim.fromAngle
            local currentAngle = anim.fromAngle + angleDiff * anim.progress
            drawAngle = currentAngle
            shouldDraw = true
            if hp >= petalMaxHP then
                petalColor = COLOR_SAKURA
            elseif hp > petalMinHP then
                if isPoisoned then
                    petalColor = Color(
                        Lerp(flash, COLOR_EMPTY.r, COLOR_POISON.r),
                        Lerp(flash, COLOR_EMPTY.g, COLOR_POISON.g),
                        Lerp(flash, COLOR_EMPTY.b, COLOR_POISON.b),
                        255
                    )
                else
                    petalColor = Color(
                        Lerp(flash, COLOR_SAKURA.r, COLOR_DANGER.r),
                        Lerp(flash, COLOR_SAKURA.g, COLOR_DANGER.g),
                        Lerp(flash, COLOR_SAKURA.b, COLOR_DANGER.b),
                        255
                    )
                end
            end
        else
            if hp >= petalMaxHP then
                petalColor = COLOR_SAKURA
                shouldDraw = true
            elseif hp > petalMinHP then
                shouldDraw = true
                if isPoisoned then
                    petalColor = Color(
                        Lerp(flash, COLOR_EMPTY.r, COLOR_POISON.r),
                        Lerp(flash, COLOR_EMPTY.g, COLOR_POISON.g),
                        Lerp(flash, COLOR_EMPTY.b, COLOR_POISON.b),
                        255
                    )
                else
                    petalColor = Color(
                        Lerp(flash, COLOR_SAKURA.r, COLOR_DANGER.r),
                        Lerp(flash, COLOR_SAKURA.g, COLOR_DANGER.g),
                        Lerp(flash, COLOR_SAKURA.b, COLOR_DANGER.b),
                        255
                    )
                end
            end
        end

        if shouldDraw then
            local rad = math.rad(drawAngle - 90)
            local px = centerX + math.cos(rad) * drawDist
            local py = centerY + math.sin(rad) * drawDist

            surface.SetDrawColor(petalColor)
            surface.DrawTexturedRectRotated(px, py, size, size, -drawAngle)
        end
    end

    for _, petal in ipairs(fallingPetals) do
        surface.SetDrawColor(petal.color.r, petal.color.g, petal.color.b, petal.alpha)
        surface.DrawTexturedRectRotated(petal.x, petal.y, size, size, petal.rotation)
    end
end

-- ===== 主HUD渲染 =====
hook.Add("HUDPaint", "SakuraHUD_Main", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local hp = math.max(ply:Health(), 0)
    local maxHP = math.max(ply:GetMaxHealth(), 1)
    local protection = SakuraMES.GetAP(ply)
    local realArmor = protection and protection.current or 0
    local maxArmor = protection and protection.maximum or 1
    local protectionLabel = GetText("ap")
    local wep = ply:GetActiveWeapon()

    local armorLerpSpeed = (realArmor < visualArmor) and 25 or 15
    visualArmor = Lerp(armorLerpSpeed * FrameTime(), visualArmor, realArmor)
    if math.abs(visualArmor - realArmor) < 0.1 then
        visualArmor = realArmor
    end

    local isAiming = IsValid(wep) and ply:KeyDown(IN_ATTACK2) and cv_aimMode:GetBool()

    -- ===== 3D悬浮面板 =====
    if cv_enabled:GetBool() then

    local modelPos = (IsValid(wep) and wep:GetClass() ~= "keys")
        and ply:GetViewModel():GetPos()
        or ply:GetShootPos()

    local angles = ply:EyeAngles()
    local drawAng = angles + ply:GetViewPunchAngles()

    drawAng:RotateAroundAxis(drawAng:Right(), 90)
    drawAng:RotateAroundAxis(drawAng:Up(), -90)
    drawAng:RotateAroundAxis(drawAng:Forward(), 0)

    drawAng:RotateAroundAxis(drawAng:Up(), cv_rotPoint:GetFloat())
    drawAng:RotateAroundAxis(drawAng:Right(), cv_rotLeft:GetFloat())
    drawAng:RotateAroundAxis(drawAng:Forward(), cv_rotTop:GetFloat())

    local finalPos = modelPos
        + (angles:Forward() * cv_offX:GetFloat())
        + (angles:Right() * cv_offY:GetFloat())
        + (angles:Up() * cv_offZ:GetFloat())

    local hudScale = cv_scale:GetFloat() * 0.15

    -- 面板内容的X偏移量（为飘落花瓣留出左侧空间）
    local panelX = PETAL_MARGIN
    local panelW, panelH = 400, 350

    cam.Start3D()
        cam.Start3D2D(finalPos, drawAng, hudScale)

            -- 背景模糊效果（Refract材质）
            if cv_blur:GetBool() then
                render.UpdateRefractTexture()
                surface.SetMaterial(BLUR_MAT)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(panelX, 0, panelW, panelH)
            end

            draw.RoundedBox(15, panelX, 0, panelW, panelH, COLOR_BG_PANEL)

            local flowerX, flowerY = 100 + panelX, 100
            DrawSakuraHealth3D(flowerX, flowerY, 100, hp, maxHP)
            DrawSegmentedArmor3D(flowerX, flowerY, 75, visualArmor / maxArmor, 7, 10)
            DrawTextShadow(
                hp,
                "Sakura3D_Large",
                flowerX, flowerY + 110,
                COLOR_SAKURA,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )
            DrawTextShadow(
                GetText("hp"),
                "Sakura_ThemeFont",
                flowerX - 15, flowerY + 165,
                COLOR_WHITE,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
            )

            local armorColor = (realArmor > 0) and COLOR_ARMOR or COLOR_BG_PANEL
            DrawTextShadow(
                math.floor(visualArmor),
                "Sakura3D_Medium",
                flowerX + 140, flowerY - 25,
                armorColor,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
            )
            DrawTextShadow(
                protectionLabel,
                "Sakura_ThemeFont",
                flowerX + 140, flowerY + 10,
                COLOR_WHITE,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
            )

            -- 联动 ArmorPlate 系统
            if ply.GetArmorPlates then
                local plates = ply:GetArmorPlates()
                if plates and plates > 0 then
                    surface.SetFont("Sakura_ThemeFont")
                    local armorTextW, _ = surface.GetTextSize(protectionLabel)

                    DrawTextShadow(
                        plates,
                        "Sakura3D_Medium",
                        flowerX + 140 + armorTextW + 10, flowerY + 10,
                        COLOR_ARMOR,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                    )
                end
            end
            -- Warzone™ Armor System 护甲板数量
            local wz_plates = ply:GetAmmoCount("WZ_ARMORPLATE") or 0
            if wz_plates > 0 then
                surface.SetFont("Sakura_ThemeFont")
                local armorTextW, _ = surface.GetTextSize(protectionLabel)
                DrawTextShadow(
                    wz_plates,
                    "Sakura3D_Medium",
                    flowerX + 140 + armorTextW + 10, flowerY + 10,
                    COLOR_ARMOR,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                )
            end

            -- 联动 MW Stim 系统
            if ply.GetStims then
                local stimCount = ply:GetStims()
                if stimCount and stimCount > 0 then
                    surface.SetFont("Sakura_ThemeFont")
                    local hpTextW, _ = surface.GetTextSize(GetText("hp"))

                    DrawTextShadow(
                        stimCount,
                        "Sakura3D_Medium",
                        flowerX - 15 + hpTextW + 10, flowerY + 165,
                        COLOR_SAKURA,
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                    )
                end
            end

            if IsValid(wep) and not isAiming then
                local clip = wep:Clip1()
                local count = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
                local grenades = ply:GetAmmoCount("Grenade")

                if clip >= 0 then
                    local maxClip = wep:GetMaxClip1()
                    local ammoColor = (maxClip > 0 and (clip / maxClip) <= 0.3)
                        and COLOR_DANGER
                        or COLOR_WHITE

                    DrawTextShadow(
                        clip,
                        "Sakura3D_Large",
                        flowerX + 140, flowerY + 110,
                        ammoColor,
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
                    )
                    DrawTextShadow(
                        "/ " .. count,
                        "Sakura3D_Medium",
                        flowerX + 180, flowerY + 120,
                        COLOR_WHITE,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                    )
                end

                if grenades > 0 then
                    local grenadeText = GetText("grenade") .. " "
                    surface.SetFont("Sakura_ThemeFont")
                    local tw, _ = surface.GetTextSize(grenadeText)

                    DrawTextShadow(
                        grenadeText,
                        "Sakura_ThemeFont",
                        flowerX + 110, flowerY + 165,
                        COLOR_SAKURA,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                    )
                    DrawTextShadow(
                        grenades,
                        "Sakura3D_Small",
                        flowerX + 110 + tw + 5, flowerY + 165,
                        COLOR_WHITE,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                    )
                end
            end

        cam.End3D2D()
    cam.End3D()

    end

    if isAiming and IsValid(wep) then
        local clip = wep:Clip1()
        local maxClip = wep:GetMaxClip1()

        if clip >= 0 then
            local ammoColor = (maxClip > 0 and (clip / maxClip) <= 0.3)
                and COLOR_DANGER
                or COLOR_WHITE
            
            DrawTextShadow(
                clip,
                "SakuraMainFont",
                ScrW() / 2 + Scale(cv_aimX:GetFloat()),
                ScrH() / 2 + Scale(cv_aimY:GetFloat()),
                ammoColor,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER,
                Scale(2), Scale(2)
            )
        end
    end
end)

-- ===== UI 菜单 =====

local function BuildSakuraHUDMenu(panel)
    panel:ClearControls()

    panel:Help(GetText("menu_title"))

    panel:Help(GetText("menu_toggles"))
    panel:CheckBox(GetText("menu_enabled"), "sakura_hud_enabled")
    panel:CheckBox(GetText("menu_blur"), "sakura_hud_blur")
    panel:CheckBox(GetText("menu_shadow"), "sakura_hud_shadow")

    panel:Help(GetText("menu_size"))
    panel:NumSlider(GetText("menu_scale"), "sakura_hud_scale", 0.5, 2.0, 2)

    panel:Help(GetText("menu_position"))
    panel:NumSlider(GetText("menu_forward"), "sakura_hud_x", 0, 300, 0)
    panel:NumSlider(GetText("menu_right"), "sakura_hud_y", -300, 300, 0)
    panel:NumSlider(GetText("menu_up"), "sakura_hud_z", -200, 200, 0)

    panel:Help(GetText("menu_rotation"))
    panel:NumSlider(GetText("menu_pitch"), "sakura_hud_rot_left", -90, 90, 0)
    panel:NumSlider(GetText("menu_yaw"), "sakura_hud_rot_top", -90, 90, 0)
    panel:NumSlider(GetText("menu_roll"), "sakura_hud_rot_point", -180, 180, 0)

    panel:Help(GetText("menu_aim"))
    panel:CheckBox(GetText("menu_aim_mode"), "sakura_hud_aim_mode")
    panel:NumSlider(GetText("menu_aim_x"), "sakura_hud_aim_x", -500, 500, 0)
    panel:NumSlider(GetText("menu_aim_y"), "sakura_hud_aim_y", -500, 500, 0)

    panel:Help(GetText("menu_poison"))
    local poisonSlider = panel:NumSlider(GetText("menu_poison_duration"), "sakura_hud_poison_duration", 0, 30, 1)
    poisonSlider:SetTooltip(GetText("menu_poison_tooltip"))

    panel:Help("")
    local reset = panel:Button(GetText("menu_reset"))
    reset.DoClick = function()
        RunConsoleCommand("sakura_hud_enabled", "1")
        RunConsoleCommand("sakura_hud_aim_mode", "1")
        RunConsoleCommand("sakura_hud_blur", "1")
        RunConsoleCommand("sakura_hud_shadow", "1")
        RunConsoleCommand("sakura_hud_scale", "1.0")
        RunConsoleCommand("sakura_hud_x", "160")
        RunConsoleCommand("sakura_hud_y", "-120")
        RunConsoleCommand("sakura_hud_z", "-50")
        RunConsoleCommand("sakura_hud_rot_left", "-25")
        RunConsoleCommand("sakura_hud_rot_top", "-15")
        RunConsoleCommand("sakura_hud_rot_point", "5")
        RunConsoleCommand("sakura_hud_aim_x", "135")
        RunConsoleCommand("sakura_hud_aim_y", "0")
        RunConsoleCommand("sakura_hud_poison_duration", "10")

        timer.Simple(0.1, function()
            if IsValid(panel) then BuildSakuraHUDMenu(panel) end
        end)
    end
end

hook.Add("PopulateToolMenu", "SakuraHUD_Menu", function()
    spawnmenu.AddToolMenuOption("Options", "Sakura HUD", "SakuraHUD_Settings", "#sakura_hud.hud.menu_entry", "", "", function(panel)
        BuildSakuraHUDMenu(panel)
    end)
end)
