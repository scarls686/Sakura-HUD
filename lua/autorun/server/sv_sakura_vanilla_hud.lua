-- 服务端：死亡报警音效开关

local cv_death_sound = CreateConVar(
    "sakura_vanilla_death_sound", "1",
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "Toggle player death alarm sound (1 = on, 0 = off)"
)

hook.Add("PlayerDeathSound", "SakuraHUD_MuteDeathSound", function()
    if not cv_death_sound:GetBool() then
        return true
    end
end)