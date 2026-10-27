local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")

local math_sqrt, math_abs, math_floor, math_max, math_min = math.sqrt, math.abs, math.floor, math.max, math.min
local math_pi, math_atan, math_atan2 = math.pi, math.atan, math.atan2
local table_insert = table.insert
local os_clock, os_time, os_date = os.clock, os.time, os.date
local string_format, string_find, string_match, string_gsub = string.format, string.find, string.match, string.gsub
local pairs, ipairs, next, type, tostring, tonumber = pairs, ipairs, next, type, tostring, tonumber

local sluaIsValid = slua and slua.isValid
local function IsValid(obj)
    if obj == nil then return false end
    if sluaIsValid == nil then return false end
    return sluaIsValid(obj)
end

local function SafeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    return ok, a, b, c
end

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")

local SlateBlueprintLibrary, WidgetLayoutLibrary
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)

local FSlateColor = _G.FSlateColor
if not FSlateColor then
    pcall(function() FSlateColor = import("SlateColor") end)
    if not FSlateColor then
        pcall(function() FSlateColor = import("/Script/SlateCore.SlateColor") end)
    end
end

local InGameUITools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    and require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") or nil

local function Log(message)
    print(string_format("[MRMOD] [%s] %s", os_date("%H:%M:%S"), tostring(message)))
end

local function Notify(message)
    if _G.MRMODNotify then pcall(_G.MRMODNotify, tostring(message)) end
end

local function safe_atan2(y, x)
    if math_atan2 then return math_atan2(y, x) end
    if x > 0 then return math_atan(y / x)
    elseif x < 0 then return (y >= 0) and (math_atan(y/x) + math_pi) or (math_atan(y/x) - math_pi)
    else return (y > 0) and math_pi/2 or (y < 0) and -math_pi/2 or 0 end
end
-- ==========================================
-- CONFIGURATION
-- ==========================================
_G.Config = {
    ESPGlobal_Enabled = false,
    ESP_Enabled = false,
    BoxESP_Enabled = false,
    SnapLine_Enabled = false,
    EnemyCounter_Enabled = false,
    Title_Enabled = true,
    HealthBar_Enabled = false,
    ShowName_Enabled = false,
    ShowDistance_Enabled = false,
    Skeleton_Enabled = false,
    MagicBullet_Enabled = false,
    WideView_Enabled = false,
    Crosshair_Enabled = false,
    NewWallhack_Enabled = false,
    FPS165_Enabled = false,
    BlackSky_Enabled = false,
}

_G.Mod_SDK_FOVValue = 120

_G.CheatConfig = {
    Wallhack = {
        Enabled = false, ShowAI = true, BlendMode = 2, MaxDistance = 100,
        VisibleColor = { R = 255.0, G = 0.0, B = 0.0, A = 1.0 },
        HiddenColor = { R = 0, G = 255, B = 0, A = 255 },
        BotHiddenColor = { R = 0.0, G = 0.0, B = 255.0, A = 1.0 },
        BotVisibleColor = { R = 255.0, G = 255.0, B = 0.0, A = 1.0 }
    },
    MagicBullet = { Enabled = false, ScalePercent = 80, UpdateInterval = 1.0 },
    HealthBar = { Enabled = false, Width = 2.0 },
}

_G.ESP = _G.ESP or { WEAPON = false, FLAG = false, STATE = false }

local SlateColorEmerald = _G.SlateColorEmerald
if not SlateColorEmerald then
    local c = FLinearColor(0.0, 1.0, 0.5, 1.0)
    SlateColorEmerald = FSlateColor and FSlateColor(c) or c
    _G.SlateColorEmerald = SlateColorEmerald
end
local SlateColorCrimson = _G.SlateColorCrimson
if not SlateColorCrimson then
    local c = FLinearColor(1.0, 0.2, 0.2, 1.0)
    SlateColorCrimson = FSlateColor and FSlateColor(c) or c
    _G.SlateColorCrimson = SlateColorCrimson
end

_G.ColorConfig = _G.ColorConfig or { Brightness = 1.0 }
_G.ColorConfig.Title_Old = { Text = "MR BYPASS", Position = { X = -60, Y = 2*0 }, Color = { R = 0, G = 255, B = 0, A = 255 } }
_G.ColorConfig.Title_New = { Line1 = "TG@mr_ownerX", Line2 = "Main Id Full Safe", Position = { X = -650, Y = 420 }, LineSpacing = 40, Color = { R = 0, G = 255, B = 0, A = 255 }, Line2Color = { R = 0, G = 255, B = 0, A = 255 } }

_G.BoxESPConfig = {
    CornerThickness = 1.0, CornerLengthRatio = 0.28,
    Colors = {
        PlayerVisible = { R = 0.0, G = 1.0, B = 0.0, A = 1.0 },
        PlayerHidden = { R = 0.0, G = 1.0, B = 0.0, A = 1.0 },
        BotVisible = { R = 1.0, G = 1.0, B = 0.0, A = 1.0 },
        BotHidden = { R = 1.0, G = 1.0, B = 0.0, A = 1.0 },
    }
}

_G.SkeletonConfig = {
    Enabled = false, Thickness = 1.0,
    PlayerVisible = { R = 1.0, G = 0.0, B = 0.0, A = 1.0 },
    PlayerHidden  = { R = 0.0, G = 1.0, B = 0.0, A = 1.0 },
    BotVisible    = { R = 1.0, G = 1.0, B = 0.0, A = 1.0 },
    BotHidden     = { R = 0.0, G = 0.0, B = 1.0, A = 1.0 },
}

_G.SnapLineConfig = {
    SnapLineThickness = 1.0, SnapLineOriginOffsetX = 0, SnapLineOriginOffsetY = 50,
    SnapLineHeadOffsetX = 0, SnapLineHeadOffsetY = -14, SnapLineOpacity = 0.9,
    nUpdateInterval = 0.5, _LightUpdateInterval = 0.05,
    Colors = {
        PlayerVisible = { R = 255, G = 0, B = 0, A = 255 },
        PlayerHidden = { R = 0, G = 255, B = 0, A = 255 },
        BotVisible = { R = 255, G = 255, B = 0, A = 255 },
        BotHidden = { R = 0, G = 0, B = 255, A = 255 },
    }
}

_G.EnemyCounterConfig = { Scale = 1.0, BaseWidth = 48, BaseHeight = 22, BaseFontSize = 10, OffsetX = 0, YOffset = 15 }

local Config = _G.Config
local CheatConfig = _G.CheatConfig
local BoxESPConfig = _G.BoxESPConfig
local SkeletonConfig = _G.SkeletonConfig
local SnapLineConfig = _G.SnapLineConfig
local EnemyCounterConfig = _G.EnemyCounterConfig
local ColorConfig = _G.ColorConfig

-- ==========================================
-- [NEW] SAVE / LOAD SYSTEM
-- ==========================================
local SaveSystem = {
    FILE_PATH = nil,
    LastSaveTime = 0,
    SaveInterval = 2.0,
}

pcall(function()
    local function GetWritableDir()
        local packages = {
            "com.tencent.ig", "com.vng.pubgmobile", "com.pubg.krmobile",
            "com.rekoo.pubgm", "com.pubg.imobile", "com.tencent.tmgp.pubgmhd",
        }
        for _, pkg in ipairs(packages) do
            local dir = "/storage/emulated/0/Android/data/" .. pkg ..
                "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
            local testFile = dir .. ".mr_test.tmp"
            local f = io.open(testFile, "w")
            if f then
                f:write("t"); f:close(); os.remove(testFile)
                return dir
            end
        end
        return "./"
    end
    SaveSystem.FILE_PATH = GetWritableDir() .. "mr_cheat_save.ini"
    print("[SAVE] File: " .. tostring(SaveSystem.FILE_PATH))
end)

function SaveSystem.Save()
    pcall(function()
        local L = {}
        table_insert(L, "# MR Features Save")
        table_insert(L, "[ESP]")
        table_insert(L, "ESPGlobal=" .. tostring(Config.ESPGlobal_Enabled or false))
        table_insert(L, "Box=" .. tostring(Config.BoxESP_Enabled or false))
        table_insert(L, "Name=" .. tostring(Config.ShowName_Enabled or false))
        table_insert(L, "Distance=" .. tostring(Config.ShowDistance_Enabled or false))
        table_insert(L, "Health=" .. tostring(Config.HealthBar_Enabled or false))
        table_insert(L, "Skeleton=" .. tostring(Config.Skeleton_Enabled or false))
        table_insert(L, "SnapLine=" .. tostring(Config.SnapLine_Enabled or false))
        table_insert(L, "Counter=" .. tostring(Config.EnemyCounter_Enabled or false))
        table_insert(L, "Title=" .. tostring(Config.Title_Enabled or false))
        table_insert(L, "[CHEATS]")
        table_insert(L, "NewWallhack=" .. tostring(Config.NewWallhack_Enabled or false))
        table_insert(L, "MagicBullet=" .. tostring(Config.MagicBullet_Enabled or false))
        table_insert(L, "WideView=" .. tostring(Config.WideView_Enabled or false))
        table_insert(L, "Crosshair=" .. tostring(Config.Crosshair_Enabled or false))
        table_insert(L, "BlackSky=" .. tostring(Config.BlackSky_Enabled or false))
        table_insert(L, "FPS165=" .. tostring(Config.FPS165_Enabled or false))
        table_insert(L, "[EXTRA]")
        table_insert(L, "FOV=" .. tostring(_G.Mod_SDK_FOVValue or 120))
        table_insert(L, "ESP_Weapon=" .. tostring(_G.ESP and _G.ESP.WEAPON or false))
        table_insert(L, "ESP_Flag=" .. tostring(_G.ESP and _G.ESP.FLAG or false))
        table_insert(L, "ESP_State=" .. tostring(_G.ESP and _G.ESP.STATE or false))
        table_insert(L, "[TOGGLES]")
        for k, _ in pairs(_G) do
            if type(k) == "string" and (k:sub(1, 8) == "Mod_ESP_" or k:sub(1, 10) == "Mod_MAGIC_" or k:sub(1, 9) == "Mod_MISC_" or k:sub(1, 8) == "Mod_SDK_") then
                table_insert(L, k .. "=" .. tostring(_G[k]))
            end
        end
        local f = io.open(SaveSystem.FILE_PATH, "w")
        if f then f:write(table.concat(L, "\n")); f:close() end
    end)
end

function SaveSystem.Load()
    pcall(function()
        local f = io.open(SaveSystem.FILE_PATH, "r")
        if not f then return end
        local content = f:read("*all")
        f:close()
        if not content or content == "" then return end
        local sec = ""
        for line in content:gmatch("[^\r\n]+") do
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if line:match("^%[") then
                sec = line
            elseif line ~= "" and not line:match("^#") then
                local key, value = line:match("^([^=]+)=(.+)$")
                if key and value then
                    local bv = (value == "true")
                    local nv = tonumber(value)
                    if sec == "[ESP]" then
                        if key == "ESPGlobal" then Config.ESPGlobal_Enabled = bv
                        elseif key == "Box" then Config.BoxESP_Enabled = bv
                        elseif key == "Name" then Config.ShowName_Enabled = bv
                        elseif key == "Distance" then Config.ShowDistance_Enabled = bv
                        elseif key == "Health" then Config.HealthBar_Enabled = bv
                        elseif key == "Skeleton" then Config.Skeleton_Enabled = bv
                        elseif key == "SnapLine" then Config.SnapLine_Enabled = bv
                        elseif key == "Counter" then Config.EnemyCounter_Enabled = bv
                        elseif key == "Title" then Config.Title_Enabled = bv end
                    elseif sec == "[CHEATS]" then
                        if key == "NewWallhack" then Config.NewWallhack_Enabled = bv
                        elseif key == "MagicBullet" then Config.MagicBullet_Enabled = bv
                        elseif key == "WideView" then Config.WideView_Enabled = bv
                        elseif key == "Crosshair" then Config.Crosshair_Enabled = bv
                        elseif key == "BlackSky" then Config.BlackSky_Enabled = bv
                        elseif key == "FPS165" then Config.FPS165_Enabled = bv end
                    elseif sec == "[EXTRA]" then
                        if key == "FOV" and nv then _G.Mod_SDK_FOVValue = nv
                        elseif key == "ESP_Weapon" then _G.ESP.WEAPON = bv
                        elseif key == "ESP_Flag" then _G.ESP.FLAG = bv
                        elseif key == "ESP_State" then _G.ESP.STATE = bv end
                    elseif sec == "[TOGGLES]" then
                        _G[key] = bv
                    end
                end
            end
        end
        print("[SAVE] Loaded successfully")
    end)
end

function SaveSystem.AutoSave()
    local now = os_time()
    if now - SaveSystem.LastSaveTime < SaveSystem.SaveInterval then return end
    SaveSystem.LastSaveTime = now
    SaveSystem.Save()
end

function SaveSystem.Reset()
    pcall(function() os.remove(SaveSystem.FILE_PATH) end)
end

function SaveSystem.ApplyLoadedFeatures()
    pcall(function()
        if SkeletonConfig then SkeletonConfig.Enabled = Config.Skeleton_Enabled or false end
        if CheatConfig and CheatConfig.HealthBar then CheatConfig.HealthBar.Enabled = Config.HealthBar_Enabled or false end
        if CheatConfig and CheatConfig.Wallhack then CheatConfig.Wallhack.Enabled = Config.NewWallhack_Enabled or false end
        if CheatConfig and CheatConfig.MagicBullet then CheatConfig.MagicBullet.Enabled = Config.MagicBullet_Enabled or false end

        -- Config → _G টগল সিঙ্ক
        _G["Mod_MISC_Global"]        = Config.ESPGlobal_Enabled or false
        _G["Mod_ESP_Counter"]        = Config.EnemyCounter_Enabled or false
        _G["Mod_ESP_Line"]           = Config.SnapLine_Enabled or false
        _G["Mod_ESP_Box"]            = Config.BoxESP_Enabled or false
        _G["Mod_ESP_Health"]         = Config.HealthBar_Enabled or false
        _G["Mod_ESP_Name"]           = Config.ShowName_Enabled or false
        _G["Mod_ESP_Skeleton"]       = Config.Skeleton_Enabled or false
        _G["Mod_ESP_Distance"]       = Config.ShowDistance_Enabled or false
        _G["Mod_ESP_Wallhack"]       = (CheatConfig.Wallhack and CheatConfig.Wallhack.Enabled) or false
        _G["Mod_MAGIC_Enabled"]      = Config.MagicBullet_Enabled or false
        _G["Mod_ESP_Weapon"]         = _G.ESP and _G.ESP.WEAPON or false
        _G["Mod_ESP_Flag"]           = _G.ESP and _G.ESP.FLAG or false
        _G["Mod_ESP_State"]          = _G.ESP and _G.ESP.STATE or false
        _G["Mod_SDK_WideView"]       = Config.WideView_Enabled or false
        _G["Mod_SDK_Crosshair"]      = Config.Crosshair_Enabled or false
        _G["Mod_SDK_NewWH"]          = Config.NewWallhack_Enabled or false
        _G["Mod_SDK_165FPS"]         = Config.FPS165_Enabled or false
        _G["Mod_SDK_BlackSky"]       = Config.BlackSky_Enabled or false

        if Config.WideView_Enabled then
            _G.WideViewModule_TargetFOV = _G.Mod_SDK_FOVValue or 120
        end
        print("[SAVE] Features + toggles applied")
    end)
end

-- ==========================================
-- BLACK SKY MODULE (r.CylinderMaxDrawHeight style)
-- ==========================================
local BlackSkyModule = {}
local _bskyApplied = false

local function BSky_GetGI()
    local gi = nil
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        if lsg and lsg.GetGameInstance then gi = lsg.GetGameInstance() end
    end)
    if not gi then
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and pc.GetGameInstance then gi = pc:GetGameInstance() end
        end)
    end
    return gi
end

local function BSky_CMD(gi, cmd, val)
    if not gi then return false end
    local ok = pcall(function() gi:ExecuteCMD(cmd, val) end)
    return ok
end

local function BSky_World_CMD(cmd, val)
    local ok = false
    pcall(function()
        local world = slua.getWorld()
        if world and UKismetSystemLibrary and UKismetSystemLibrary.ExecuteConsoleCommand then
            UKismetSystemLibrary.ExecuteConsoleCommand(world, cmd .. " " .. tostring(val))
            ok = true
        end
    end)
    return ok
end

local function BSky_Send(cmd, val)
    local gi = BSky_GetGI()
    local ok1 = BSky_CMD(gi, cmd, val)
    local ok2 = BSky_World_CMD(cmd, val)
    return ok1 or ok2
end

function BlackSkyModule.Apply()
    if Config.BlackSky_Enabled and not _bskyApplied then
        -- আসল BlackSky: স্কাই সিলিন্ডারের আঁকা সীমা বাড়িয়ে দাও
        BSky_Send("r.CylinderMaxDrawHeight", "9999")
        -- বোনাস: ফগ/অ্যাটমোসফিয়ারও বন্ধ
        BSky_Send("r.SkyAtmosphere", "0")
        BSky_Send("r.SkyLUT", "0")
        BSky_Send("r.Atmosphere", "0")
        BSky_Send("r.SkyLight", "0")
        BSky_Send("r.VolumetricFog", "0")
        _bskyApplied = true
        print("[BLACKSKY] Applied")
    elseif not Config.BlackSky_Enabled and _bskyApplied then
        BSky_Send("r.CylinderMaxDrawHeight", "0000")
        BSky_Send("r.SkyAtmosphere", "1")
        BSky_Send("r.SkyLUT", "1")
        BSky_Send("r.Atmosphere", "1")
        BSky_Send("r.SkyLight", "1")
        BSky_Send("r.VolumetricFog", "1")
        _bskyApplied = false
        print("[BLACKSKY] Reset")
    end
end

function BlackSkyModule.Reset()
    BSky_Send("r.CylinderMaxDrawHeight", "0000")
    BSky_Send("r.SkyAtmosphere", "1")
    BSky_Send("r.SkyLUT", "1")
    BSky_Send("r.Atmosphere", "1")
    BSky_Send("r.SkyLight", "1")
    BSky_Send("r.VolumetricFog", "1")
    _bskyApplied = false
end

function BlackSkyModule.ForceReapply()
    if not Config.BlackSky_Enabled then return end
    BSky_Send("r.CylinderMaxDrawHeight", "9999")
    BSky_Send("r.SkyAtmosphere", "0")
    BSky_Send("r.SkyLUT", "0")
    BSky_Send("r.Atmosphere", "0")
    BSky_Send("r.SkyLight", "0")
    BSky_Send("r.VolumetricFog", "0")
    _bskyApplied = true
end

-- ==========================================
-- NEW WALLHACK SYSTEM (Dyeing/Outline-based)
-- ==========================================
local NewWallhack = {
    CONSOLE_READY = false,
    PROCESSED_PAWNS = {},
    TICK_COUNT = 0,
    WH_TIMER = nil,
    TICK_INTERVAL = 0.3,
    MAX_PAWNS_PER_TICK = 20,
    RESET_PROCESSED_EVERY = 6,
    AVATAR_SLOTS = {0,1,2,3,4,5,6,7},
}

local LinearColor = import("LinearColor")

local WH_COLORS = {
    vis  = LinearColor(255, 255, 0, 100),
    occ  = LinearColor(0, 255, 255, 100),
    bVis = LinearColor(255, 255, 0, 100),
    bOcc = LinearColor(0, 255, 255, 100),
}

local function SetupConsole()
    if NewWallhack.CONSOLE_READY then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        NewWallhack.CONSOLE_READY = true
    end)
end

local function ApplyToMesh(mesh, visColor, occColor)

    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function ClearMeshEffects(mesh)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawHighlight(false)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetIdeaOutlineOcclusionHighlight(false)
        mesh:SetIdeaOverrideOutlineAndOcclusion(false)
        mesh:SetRenderCustomDepth(false)
        mesh:SetCustomDepthStencilValue(0)
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    return pawn.Health and pawn.Health > 0
end

local function PBCtick()
    pcall(function()
        if not Config.NewWallhack_Enabled then return end
        local localPawn = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end
        SetupConsole()
        NewWallhack.TICK_COUNT = NewWallhack.TICK_COUNT + 1
        if NewWallhack.TICK_COUNT % NewWallhack.RESET_PROCESSED_EVERY == 0 then
            NewWallhack.PROCESSED_PAWNS = {}
        end
        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0
        for _, pawn in pairs(allPawns) do
            if processedCount >= NewWallhack.MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and NewWallhack.PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end
            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = pcall(Game.IsAI, pawn) and true or false
                local vis = isAI and WH_COLORS.bVis or WH_COLORS.vis
                local occ = isAI and WH_COLORS.bOcc or WH_COLORS.occ
                pcall(function()
                    if slua.isValid(pawn.Mesh) then ApplyToMesh(pawn.Mesh, vis, occ) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(NewWallhack.AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then ApplyToMesh(mesh, vis, occ) end
                        end
                    end
                    pcall(function()
                        local SK = import("SkeletalMeshComponent")
                        if SK then
                            local skComps = pawn:GetComponentsByClass(SK)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local ST = import("StaticMeshComponent")
                        if ST then
                            local stComps = pawn:GetComponentsByClass(ST)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then ApplyToMesh(comp, vis, occ) end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        ApplyToMesh(weapon.Mesh, vis, occ)
                    end
                end)
                if pawn.PlayerKey then NewWallhack.PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end
            ::continue::
        end
    end)
end

function NewWallhack.Start()
    SetupConsole()
    if NewWallhack.WH_TIMER then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(NewWallhack.WH_TIMER) end end)
        NewWallhack.WH_TIMER = nil
    end
    if _G.Game and _G.Game.AddGameTimer then
        NewWallhack.WH_TIMER = _G.Game:AddGameTimer(NewWallhack.TICK_INTERVAL, true, PBCtick)
        return true
    end
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        NewWallhack.WH_TIMER = pc:AddGameTimer(NewWallhack.TICK_INTERVAL, true, PBCtick)
        return true
    end
    return false
end

function NewWallhack.Stop()
    pcall(function()
        local localPawn = GameplayData.GetPlayerCharacter()
        local allPawns = Game:GetAllPlayerPawns() or {}
        for _, pawn in pairs(allPawns) do
            if slua.isValid(pawn) and pawn ~= localPawn then
                pcall(function()
                    if slua.isValid(pawn.Mesh) then ClearMeshEffects(pawn.Mesh) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(NewWallhack.AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then ClearMeshEffects(mesh) end
                        end
                    end
                    pcall(function()
                        local SK = import("SkeletalMeshComponent")
                        if SK then
                            local skComps = pawn:GetComponentsByClass(SK)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then
                                        ClearMeshEffects(comp)
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local ST = import("StaticMeshComponent")
                        if ST then
                            local stComps = pawn:GetComponentsByClass(ST)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then ClearMeshEffects(comp) end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        ClearMeshEffects(weapon.Mesh)
                    end
                end)
            end
        end
    end)
    if NewWallhack.WH_TIMER then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(NewWallhack.WH_TIMER) end end)
        NewWallhack.WH_TIMER = nil
    end
    NewWallhack.PROCESSED_PAWNS = {}
    NewWallhack.CONSOLE_READY = false
end

local _whRetry = 0
local function RetryStartWH()
    if _whRetry >= 30 then return end
    _whRetry = _whRetry + 1
    if NewWallhack.Start() then
        print("[PBC] Wallhack ready!")
    else
        if _G.Game and _G.Game.AddGameTimer then
            _G.Game:AddGameTimer(1.0, false, RetryStartWH)
        end
    end
end

_G.StartNewWallhack = function()
    if NewWallhack.WH_TIMER then return end
    if Config.NewWallhack_Enabled then RetryStartWH() end
end

_G._pbc_Cleanup = function()
    NewWallhack.Stop()
end

-- ==========================================
-- 165 FPS ENABLER
-- ==========================================
local FPS165 = { Loaded = false, Applied = false }

local function Enable165FPS()

    if FPS165.Loaded then return end
    local orig = {}
    pcall(function()
        local logicSettingGraphics = require("client.slua.logic.setting.logic_setting_graphics")
        if logicSettingGraphics then
            orig.SetFPS = logicSettingGraphics.SetFPS
            logicSettingGraphics.SetFPS = function(settings, fpsLevel)
                if orig.SetFPS then orig.SetFPS(settings, fpsLevel) end
                if fpsLevel == 8 and Config.FPS165_Enabled
                    and Game and Game.IsInGame and Game:IsInGame() then
                    pcall(function()
                        settings:ExecuteCMD("t.MaxFPS", "165")
                        settings:ExecuteCMD("r.FrameRateLimit", "165")
                    end)
                end
            end
        end
    end)
    pcall(function()
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        if GSC_FPS and GSC_FPS.__inner_impl then
            orig.GetMaxFPSLevel = GSC_FPS.__inner_impl.GetMaxFPSLevel
            GSC_FPS.__inner_impl.GetMaxFPSLevel = function() return 8, 8 end
        end
    end)
    pcall(function()
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            orig.FPSFT_ShowOrHide = GSC_FPSFT.__inner_impl.ShowOrHide
            orig.FPSFT_Init = GSC_FPSFT.__inner_impl.InitFPSFTSwitch
            orig.FPSFT_Value = GSC_FPSFT.__inner_impl.InitFPSFTValue165
            GSC_FPSFT.__inner_impl.ShowOrHide = function(ui)
                if orig.FPSFT_ShowOrHide then orig.FPSFT_ShowOrHide(ui) end
                if Game and Game.IsInGame and Game:IsInGame() then
                    ui:SelfHitTestInvisible()
                    if ui.InitFPSFTSwitch then ui:InitFPSFTSwitch() end
                end
            end
            GSC_FPSFT.__inner_impl.InitFPSFTSwitch = function(ui)
                if orig.FPSFT_Init then orig.FPSFT_Init(ui) end
                local DB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
                if DB then
                    local en = DB:GetUIData(DB.FPSFineTuneSwitch)
                    if ui.UIRoot and ui.UIRoot.Setting_Switch then
                        ui.UIRoot.Setting_Switch:SetSwitcherEnable2(en, true)
                    end
                end
            end
            GSC_FPSFT.__inner_impl.InitFPSFTValue165 = function(ui)
                if orig.FPSFT_Value then orig.FPSFT_Value(ui) end
                local DB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
                if DB and ui.UIRoot then
                    local en = DB:GetUIData(DB.FPSFineTuneSwitch)
                    local fps = en and DB:GetUIData(DB.FPSFineTuneNum) or 165
                    local root = ui.UIRoot
                    if root.Slider_screen3 then
                        if en then
                            root.Slider_screen3:SetLocked(false)
                            root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 1, 1, 1))
                            root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 1, 1, 1))
                        else
                            root.Slider_screen3:SetLocked(true)
                            root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 0.625, 0.6, 1))
                            root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 0.625, 0.6, 1))
                        end
                        local pct = (fps - 90) / (165 - 90)
                        root.Veihclescreen3:SetText(tostring(fps))
                        root.Slider_screen3:SetValue(pct)
                        root.ProgressBar_screen3:SetPercent(pct)
                    end
                end
            end
        end
    end)
    FPS165.Loaded = true
    print("[MRMOD] 165 FPS Enabler Loaded")
end

local function Apply165FPSInGame()

    if not Config.FPS165_Enabled then return end
    if FPS165.Applied then return end
    pcall(function()
        local world = slua.getWorld()
        if world then
            local KSL = import("KismetSystemLibrary")
            if KSL then
                KSL.ExecuteConsoleCommand(world, "t.MaxFPS 165")
                KSL.ExecuteConsoleCommand(world, "r.FrameRateLimit 165")
                FPS165.Applied = true
                print("[MRMOD] 165 FPS Applied In-Game")
            end
        end
    end)
end

local function Disable165FPS()
    pcall(function()
        local world = slua.getWorld()
        if world then
            local KSL = import("KismetSystemLibrary")
            if KSL then
                KSL.ExecuteConsoleCommand(world, "t.MaxFPS 60")
                KSL.ExecuteConsoleCommand(world, "r.FrameRateLimit 60")
            end
        end
    end)
    FPS165.Applied = false
    print("[MRMOD] 165 FPS Disabled")
end

-- ==========================================
-- WIDE VIEW MODULE (FIXED - SetFOV with immediate apply)
-- ==========================================
local WideViewModule = {
    TargetFOV = 120,
    DefaultFOV = 80,
    _lastAppliedFOV = 0,
}

function WideViewModule.SetFOV(v)
    v = tonumber(v) or 120
    if v < 80 then v = 80 end
    if v > 140 then v = 140 end
    WideViewModule.TargetFOV = v
    _G.Mod_SDK_FOVValue = v
    local lp = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
    if IsValid(lp) then
        WideViewModule.Apply(lp, true)
    end
    print("[WIDEVIEW] SetFOV = " .. tostring(v))
end

function WideViewModule.Apply(localPlayer, force)
    if not IsValid(localPlayer) then return end
    local cam = localPlayer.ThirdPersonCameraComponent
    if not IsValid(cam) then return end

    local target = tonumber(_G.Mod_SDK_FOVValue) or WideViewModule.TargetFOV or 120
    if target < 80 then target = 80 end
    if target > 140 then target = 140 end
    WideViewModule.TargetFOV = target

    local want
    if not Config.WideView_Enabled then
        want = WideViewModule.DefaultFOV
    elseif localPlayer.bIsWeaponAiming then
        want = WideViewModule.DefaultFOV
    else
        want = target
    end

    if not force and cam.FieldOfView == want then
        return
    end

    cam.FieldOfView = want
    pcall(function()
        if cam.DefaultFOV ~= nil then cam.DefaultFOV = want end
    end)
    WideViewModule._lastAppliedFOV = want
end

local CrosshairModule = {}
function CrosshairModule.Apply(localPlayer)
    if not Config.Crosshair_Enabled then return end
    if not IsValid(localPlayer) then return end
    local weapon = nil
    if localPlayer.WeaponManagerComponent then weapon = localPlayer.WeaponManagerComponent.CurrentWeaponReplicated end
    if not IsValid(weapon) and type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
    if not IsValid(weapon) then return end
    weapon.GameDeviationFactor = 0.0
    if weapon.GameDeviationAccuracy ~= nil then weapon.GameDeviationAccuracy = 0.0 end
    if weapon.RecoilKickADS ~= nil then weapon.RecoilKickADS = 0.0 end
    local entity = weapon.ShootWeaponEntityComp
    if IsValid(entity) then
        entity.GameDeviationFactor = 0.0
        if entity.GameDeviationAccuracy ~= nil then entity.GameDeviationAccuracy = 0.0 end
        if entity.RecoilKickADS ~= nil then entity.RecoilKickADS = 0.0 end
    end
end

local function WideViewCrosshairTick()
    pcall(function()
        local lp = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not IsValid(lp) then return end
        WideViewModule.Apply(lp, false)
        CrosshairModule.Apply(lp)
    end)
end

-- ==========================================
-- HEALTH BAR MODULE
-- ==========================================
local HealthBarModule = { HealthBarWidth = 2.0 }

function HealthBarModule.CreateHealthWidgets(ParentCanvas)

    local Bg = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not (Bg and sluaIsValid(Bg)) then return nil, nil, nil, nil end
    Bg:SetColorAndOpacity(FLinearColor(0, 0, 0, 0.85))
    Bg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    local BgS = ParentCanvas:AddChildToCanvas(Bg)
    if BgS then BgS:SetAutoSize(false) BgS:SetZOrder(998) BgS:SetAlignment(FVector2D(0.5, 1.0)) end

    local Hl = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not (Hl and sluaIsValid(Hl)) then return nil, nil, nil, nil end
    Hl:SetColorAndOpacity(FLinearColor(0, 1, 0, 1))
    Hl:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    local HlS = ParentCanvas:AddChildToCanvas(Hl)
    if HlS then HlS:SetAutoSize(false) HlS:SetZOrder(999) HlS:SetAlignment(FVector2D(0.5, 1.0)) end

    return Bg, BgS, Hl, HlS
end

function HealthBarModule.UpdateHealthBar(boxData, Pawn, cX, bw, bh, bby, show)

    if not boxData or not boxData.BgWidget or not boxData.HealthWidget then return end
    if not show then
        if boxData._hbShown then
            boxData.BgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            boxData.HealthWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            boxData._hbShown = false
        end
        return
    end
    local w = HealthBarModule.HealthBarWidth or 2.0
    local hX = cX - (bw * 0.5) - 2.5 - (w * 0.5)
    local hp = Pawn.Health or (Pawn.GetHealth and Pawn:GetHealth()) or 100
    local hpM = Pawn.HealthMax or (Pawn.GetHealthMax and Pawn:GetHealthMax()) or 100
    if hpM <= 0 then hpM = 100 end
    if boxData._lastHP == hp and boxData._lastHPMax == hpM and boxData._lastBBY == bby and boxData._lastBW == bw then return end
    boxData._lastHP = hp
    boxData._lastHPMax = hpM
    boxData._lastBBY = bby
    boxData._lastBW = bw
    local pct = math_max(0, math_min(1, hp / hpM))
    local curH = bh * pct
    boxData.BgSlot:SetSize(FVector2D(w, bh))
    boxData.BgSlot:SetPosition(FVector2D(hX, bby))
    boxData.HealthSlot:SetSize(FVector2D(w, curH))
    boxData.HealthSlot:SetPosition(FVector2D(hX, bby))
    local v = UEnums.ESlateVisibility.SelfHitTestInvisible
    boxData.BgWidget:SetWidgetVisibility(v)
    boxData.HealthWidget:SetWidgetVisibility(v)
    boxData._hbShown = true
end

-- ==========================================
-- SKELETON MODULE
-- ==========================================
local SkeletonModule = {
    BoneThickness = 2.0, Lines = {},
    BoneAliases = {
        head = {"head", "b_head", "Head"}, neck = {"neck_01", "b_neck", "Neck"},
        chest = {"spine_03", "b_chest", "Spine3", "spine_02"},
        pelvis = {"pelvis", "b_pelvis", "Pelvis", "Root"},
        upperarm_l = {"upperarm_l", "b_l_upperarm", "UpperArm_L"},
        lowerarm_l = {"lowerarm_l", "b_l_lowerarm", "LowerArm_L"},
        hand_l = {"hand_l", "b_l_hand", "Hand_L"},
        upperarm_r = {"upperarm_r", "b_r_upperarm", "UpperArm_R"},
        lowerarm_r = {"lowerarm_r", "b_r_lowerarm", "LowerArm_R"},
        hand_r = {"hand_r", "b_r_hand", "Hand_R"},
        thigh_l = {"thigh_l", "b_l_thigh", "Thigh_L"},
        calf_l = {"calf_l", "b_l_calf", "Calf_L"},
        foot_l = {"foot_l", "b_l_foot", "Foot_L"},
        thigh_r = {"thigh_r", "b_r_thigh", "Thigh_R"},
        calf_r = {"calf_r", "b_r_calf", "Calf_R"},
        foot_r = {"foot_r", "b_r_foot", "Foot_R"},
    },
    SkeletonBones = {
        {"neck","head"}, {"pelvis","neck"},
        {"upperarm_l","neck"}, {"lowerarm_l","upperarm_l"}, {"hand_l","lowerarm_l"},
        {"upperarm_r","neck"}, {"lowerarm_r","upperarm_r"}, {"hand_r","lowerarm_r"},
        {"thigh_r","thigh_l"},
        {"calf_l","thigh_l"}, {"foot_l","calf_l"},
        {"calf_r","thigh_r"}, {"foot_r","calf_r"},
    }
}

local BoneKeyList, BoneAliasCache = {}, {}
for k, v in pairs(SkeletonModule.BoneAliases) do
    BoneKeyList[#BoneKeyList + 1] = k
    BoneAliasCache[#BoneAliasCache + 1] = v
end
local BoneKeyCount = #BoneKeyList

function SkeletonModule.CreateBundle(ParentCanvas)

    local b = { lineDatas = {} }
    for i = 1, #SkeletonModule.SkeletonBones do
        local bo = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
        if bo and sluaIsValid(bo) then
            bo:SetBrushColor(FLinearColor(1,1,1,1))
            bo:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            bo:SetRenderTransformPivot(FVector2D(0.0, 0.5))
            local s = ParentCanvas:AddChildToCanvas(bo)
            if s then s:SetAutoSize(false) s:SetZOrder(1002) end
            b.lineDatas[i] = { Widget = bo, Slot = s, bVisible = true }
        end
    end
    return b
end

function SkeletonModule.HideSkeleton(k)
    local sk = SkeletonModule.Lines[k]
    if not sk then return end
    for i = 1, #sk.lineDatas do
        local ln = sk.lineDatas[i]
        if ln and ln.Widget and sluaIsValid(ln.Widget) and ln.bVisible then
            ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            ln.bVisible = false
        end
    end
end

function SkeletonModule.DestroySkeleton(k)
    local sk = SkeletonModule.Lines[k]
    if not sk then return end
    for i = 1, #sk.lineDatas do
        local ln = sk.lineDatas[i]
        if ln and ln.Widget and sluaIsValid(ln.Widget) then
            pcall(function()
                ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                ln.Widget:RemoveFromParent()
                ln.Widget:ConditionalBeginDestroy()
            end)
        end
    end
    SkeletonModule.Lines[k] = nil
end

function SkeletonModule.DestroyAll()
    for k, _ in pairs(SkeletonModule.Lines) do SkeletonModule.DestroySkeleton(k) end
    SkeletonModule.Lines = {}
end

function SkeletonModule.UpdateSkeleton(k, Pawn, PC, ParentCanvas, color, ProjFunc)
    local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
    if not mesh or not mesh.GetSocketLocation then SkeletonModule.HideSkeleton(k) return end
    local pr = {}
    for i = 1, BoneKeyCount do
        local bk = BoneKeyList[i]
        local aliases = BoneAliasCache[i]
        local loc = nil
        for j = 1, #aliases do
            local ok, l = pcall(mesh.GetSocketLocation, mesh, aliases[j])
            if ok and l and (l.X ~= 0 or l.Y ~= 0 or l.Z ~= 0) then
                loc = l
                break
            end
        end
        if loc then
            local ok, x, y = ProjFunc(PC, loc)
            if ok then pr[bk] = { x = x, y = y } end
        end
    end
    local sk = SkeletonModule.Lines[k]
    if not sk then
        sk = SkeletonModule.CreateBundle(ParentCanvas)
        SkeletonModule.Lines[k] = sk
    end
    local thickness = SkeletonConfig.Thickness or 2.0
    local bones = SkeletonModule.SkeletonBones
    for i = 1, #bones do
        local pair = bones[i]
        local c, p = pr[pair[1]], pr[pair[2]]
        local ln = sk.lineDatas[i]
        if c and p and ln and ln.Widget and sluaIsValid(ln.Widget) then
            local dx, dy = c.x - p.x, c.y - p.y
            local len = math_sqrt(dx*dx + dy*dy)
            local a = safe_atan2(dy, dx) * (180.0 / math_pi)
            local t = thickness
            if not ln._pos then
                ln._pos = FVector2D(p.x, p.y - t * 0.5)
                ln._size = FVector2D(len, t)
            else
                ln._pos.X = p.x ln._pos.Y = p.y - t * 0.5
                ln._size.X = len ln._size.Y = t
            end
            pcall(function()
                ln.Slot:SetPosition(ln._pos)
                ln.Slot:SetSize(ln._size)
                ln.Widget:SetRenderAngle(a)
                ln.Widget:SetBrushColor(color or FLinearColor(1,1,1,1))
                if not ln.bVisible then
                    ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    ln.bVisible = true
                end
            end)
        else
            if ln and ln.Widget and sluaIsValid(ln.Widget) and ln.bVisible then
                ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                ln.bVisible = false
            end
        end
    end
end

-- ==========================================
-- FLOATING MASTER BUTTON
-- ==========================================
local FloatingMenu = {
    MasterButton = nil, MasterImage = nil, MasterButtonShow = true,
    Config = { MasterPos = { X = 0, Y = 250 }, SizeBg = FVector2D(50, 50), SizeImage = FVector2D(80, 80) }
}

local _textureCache = {}

local function LoadFloatingTexture(url, cb)
    local cached = _textureCache[url]
    if cached and IsValid(cached) then if cb then cb(cached) end return end
    local got = false
    local function apply(tex)
        if tex and IsValid(tex) then
            got = true _textureCache[url] = tex
            if cb then cb(tex) end
            return true
        end
        return false
    end
    pcall(function()
        local A = import("AsyncTaskDownloadImage") or import("/Script/UMG.AsyncTaskDownloadImage")
        if A and A.DownloadImage then
            local t = A.DownloadImage(url)
            if t and t.OnSuccess then
                t.OnSuccess:Add(function(tex) if not got and tex then apply(tex) end end)
            end
        end
    end)
    if not got then
        pcall(function()
            local mm = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
            if not mm then pcall(function() mm = require("GameLua.GameCore.Module.ModuleManager") end) end
            local im = nil
            if mm and mm.GetModule and mm.CommonModuleConfig then im = mm.GetModule(mm.CommonModuleConfig.image_download_mgr) end
            if not im then pcall(function() im = require("client.slua.logic.image_download.image_download_mgr") end) end
            if im and im.DownloadImageByHttpWrapper then
                im:DownloadImageByHttpWrapper(url, function(tex) if not got and tex then apply(tex) end end, function() end)
            end
        end)
    end
end

-- ==========================================
-- MAGIC BULLET (with proper restore)
-- ==========================================
_G._MBOriginalSizes = _G._MBOriginalSizes or {}
_G._MBones = _G._MBones or {}

local MB_BONE_PATTERNS = {
    ["head"] = 1.0, ["neck_01"] = 1.0, ["pelvis"] = 1.0,
    ["spine_01"] = 1.0, ["spine_02"] = 1.0, ["spine_03"] = 1.0,
    ["upperarm_l"] = 1.0, ["upperarm_r"] = 1.0,
    ["lowerarm_l"] = 0.9, ["lowerarm_r"] = 0.9,
    ["hand_l"] = 0.5, ["hand_r"] = 0.5,
    ["thigh_l"] = 1.0, ["thigh_r"] = 1.0,
    ["calf_l"] = 0.9, ["calf_r"] = 0.9,
    ["foot_l"] = 0.5, ["foot_r"] = 0.5,
}

local function SaveOriginalPhysics(pa, an)
    if _G._MBOriginalSizes[an] then return end
    local saved = {}
    pcall(function()
        local setups = pa.SkeletalBodySetups
        for i = 1, 80 do
            local bs = nil
            pcall(function() bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i] end)
            if not bs or not sluaIsValid(bs) then break end
            local entry = { bone = tostring(bs.BoneName), box = {}, sph = {}, sphr = {} }
            local ag = bs.AggGeom
            pcall(function()
                local bx = (ag and ag.BoxElems) or bs.BoxElems
                if bx then
                    local b = (type(bx.Get) == "function") and bx:Get(0) or bx[1]
                    if b then entry.box = { X = b.X, Y = b.Y, Z = b.Z } end
                end
            end)
            pcall(function()
                local sp = (ag and ag.SphylElems) or bs.SphylElems
                if sp then
                    local s = (type(sp.Get) == "function") and sp:Get(0) or sp[1]
                    if s then entry.sph = { Radius = s.Radius, Length = s.Length } end
                end
            end)
            pcall(function()
                local sr = (ag and ag.SphereElems) or bs.SphereElems
                if sr then
                    local r = (type(sr.Get) == "function") and sr:Get(0) or sr[1]
                    if r then entry.sphr = { Radius = r.Radius } end
                end
            end)
            saved[i] = entry
        end
    end)
    _G._MBOriginalSizes[an] = saved
end

local function ApplyMagicBullet()

    if not CheatConfig.MagicBullet.Enabled then return end
    pcall(function()
        local c = GameplayData.GetPlayerCharacter()
        if not sluaIsValid(c) then return end
        local all = Game:GetAllPlayerPawns() or {}
        for _, t in pairs(all) do
            if sluaIsValid(t) and t ~= c and t.TeamID ~= c.TeamID then
                local m = t.Mesh
                if sluaIsValid(m) then
                    local pa = m.PhysicsAssetOverride
                    if not sluaIsValid(pa) and sluaIsValid(m.SkeletalMesh) then pa = m.SkeletalMesh.PhysicsAsset end
                    if sluaIsValid(pa) and pa.SkeletalBodySetups then
                        local an = (pa.GetName and pa:GetName()) or tostring(pa)
                        if not _G._MBones[an] then
                            SaveOriginalPhysics(pa, an)
                            local bpNorm = (CheatConfig.MagicBullet.ScalePercent or 100) / 100.0
                            local setups = pa.SkeletalBodySetups
                            for i = 1, 80 do
                                local bs = nil
                                pcall(function() bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i] end)
                                if not bs or not sluaIsValid(bs) then break end
                                local bn = tostring(bs.BoneName):lower()
                                local pct = nil
                                for pat, v in pairs(MB_BONE_PATTERNS) do
                                    if string_find(bn, pat) then pct = v * bpNorm break end
                                end
                                if pct then
                                    local sc = 1.0 + pct
                                    local ag = bs.AggGeom
                                    pcall(function()
                                        local bx = (ag and ag.BoxElems) or bs.BoxElems
                                        if bx then
                                            local b = (type(bx.Get) == "function") and bx:Get(0) or bx[1]
                                            if b then
                                                b.X = (b.X or 30) * sc b.Y = (b.Y or 30) * sc b.Z = (b.Z or 60) * sc
                                                if type(bx.Set) == "function" then bx:Set(0, b) else bx[1] = b end
                                                if ag then bs.AggGeom = ag else bs.BoxElems = bx end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sp = (ag and ag.SphylElems) or bs.SphylElems
                                        if sp then
                                            local s = (type(sp.Get) == "function") and sp:Get(0) or sp[1]
                                            if s then
                                                if s.Radius then s.Radius = s.Radius * sc end
                                                if s.Length then s.Length = s.Length * sc end
                                                if type(sp.Set) == "function" then sp:Set(0, s) else sp[1] = s end
                                                if ag then bs.AggGeom = ag else bs.SphylElems = sp end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sr = (ag and ag.SphereElems) or bs.SphereElems
                                        if sr then
                                            local r = (type(sr.Get) == "function") and sr:Get(0) or sr[1]
                                            if r and r.Radius then
                                                r.Radius = r.Radius * sc
                                                if type(sr.Set) == "function" then sr:Set(0, r) else sr[1] = r end
                                                if ag then bs.AggGeom = ag else bs.SphereElems = sr end
                                            end
                                        end
                                    end)
                                end
                            end
                            _G._MBones[an] = true
                            if m.RecreatePhysicsState then m:RecreatePhysicsState() end
                        end
                    end
                end
            end
        end
    end)
end

local function RestoreMagicBullet()
    pcall(function()
        local c = GameplayData.GetPlayerCharacter()
        if not sluaIsValid(c) then return end
        local all = Game:GetAllPlayerPawns() or {}
        for _, p in pairs(all) do
            if sluaIsValid(p) and p ~= c then
                local m = p.Mesh
                if sluaIsValid(m) then
                    local pa = m.PhysicsAssetOverride
                    if not sluaIsValid(pa) and sluaIsValid(m.SkeletalMesh) then
                        pa = m.SkeletalMesh.PhysicsAsset
                    end
                    if sluaIsValid(pa) and pa.SkeletalBodySetups then
                        local an = (pa.GetName and pa:GetName()) or tostring(pa)
                        local saved = _G._MBOriginalSizes and _G._MBOriginalSizes[an]
                        if saved then
                            local setups = pa.SkeletalBodySetups
                            for i, entry in pairs(saved) do
                                local bs = nil
                                pcall(function()
                                    bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i]
                                end)
                                if bs and sluaIsValid(bs) then
                                    local ag = bs.AggGeom
                                    if entry.box.X then
                                        pcall(function()
                                            local bx = (ag and ag.BoxElems) or bs.BoxElems
                                            if bx then
                                                local b = (type(bx.Get) == "function") and bx:Get(0) or bx[1]
                                                if b then
                                                    b.X = entry.box.X b.Y = entry.box.Y b.Z = entry.box.Z
                                                    if type(bx.Set) == "function" then bx:Set(0, b) else bx[1] = b end
                                                    if ag then bs.AggGeom = ag else bs.BoxElems = bx end
                                                end
                                            end
                                        end)
                                    end
                                    if entry.sph.Radius then
                                        pcall(function()
                                            local sp = (ag and ag.SphylElems) or bs.SphylElems
                                            if sp then
                                                local s = (type(sp.Get) == "function") and sp:Get(0) or sp[1]
                                                if s then
                                                    s.Radius = entry.sph.Radius s.Length = entry.sph.Length
                                                    if type(sp.Set) == "function" then sp:Set(0, s) else sp[1] = s end
                                                    if ag then bs.AggGeom = ag else bs.SphylElems = sp end
                                                end
                                            end
                                        end)
                                    end
                                    if entry.sphr.Radius then
                                        pcall(function()
                                            local sr = (ag and ag.SphereElems) or bs.SphereElems
                                            if sr then
                                                local r = (type(sr.Get) == "function") and sr:Get(0) or sr[1]
                                                if r then
                                                    r.Radius = entry.sphr.Radius
                                                    if type(sr.Set) == "function" then sr:Set(0, r) else sr[1] = r end
                                                    if ag then bs.AggGeom = ag else bs.SphereElems = sr end
                                                end
                                            end
                                        end)
                                    end
                                end
                            end
                            _G._MBones[an] = nil
                        end
                    end
                    if m.RecreatePhysicsState then
                        pcall(function() m:RecreatePhysicsState() end)
                    end
                end
            end
        end
        _G._MBones = {}
    end)
end

-- ==========================================
-- ENEMY COUNTER
-- ==========================================
local ECP = {"https://i.postimg.cc/C5dTxh0y/ic-danger-enemy.png"}
local ECB = {"https://i.postimg.cc/HnjDkYgq/ic-danger-boot.png"}
local ECCache = {}

local function FileExists(p)
    if not p or p == "" then return false end
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
end

local _pathCache = {}
local function GetPossibleLocalPaths(fn)
    local cached = _pathCache[fn]
    if cached then return cached end
    local r = { fn, "UI/" .. fn, "Texture/" .. fn }
    _pathCache[fn] = r
    return r
end

local CounterData = {
    ImgPlayer = nil, SlotPlayer = nil, ImgBot = nil, SlotBot = nil,
    TxtPlayer = nil, SlotTxtPlayer = nil, TxtBot = nil, SlotTxtBot = nil,
    LastPlayerCount = -1, LastBotCount = -1, bCreated = false
}

_G.IsABot = function(c)
    if not IsValid(c) then return false end
    local is = false
    pcall(function()
        if c.IsAI and c:IsAI() then is = true
        elseif c.bEnsure or c.IsAIControlled == true then is = true
        elseif c.PlayerName and string_match(tostring(c.PlayerName), "AI_") then is = true
        else
            local p = (c.PlayerState and c.PlayerState.Ping) or c.Ping or -1
            if p >= 0 and p <= 3 then is = true end
        end
    end)
    return is
end

local IsABot = _G.IsABot

local _visIgnore = {}
local _visHit = {}
local _visHitColor = FLinearColor(1,0,0,1)
local _visTraceColor = FLinearColor(0,1,0,1)

local function IsVisibleToPlayer(PC, TA)
    if not PC or not IsValid(PC) or not TA or not IsValid(TA) then return true end
    if type(PC.LineOfSightTo) == "function" then return PC:LineOfSightTo(TA) end
    local VP = PC.GetPawn and PC:GetPawn()
    if not IsValid(VP) then return true end
    local sL = VP.K2_GetActorLocation and VP:K2_GetActorLocation()
    local eL = TA.K2_GetActorLocation and TA:K2_GetActorLocation()
    if not sL or not eL then return true end
    local dx, dy, dz = sL.X - eL.X, sL.Y - eL.Y, sL.Z - eL.Z
    if dx*dx + dy*dy + dz*dz > 225000000 then return true end
    sL.Z = sL.Z + 50
    eL.Z = eL.Z + 50
    _visIgnore[1] = VP
    _visIgnore[2] = TA
    if UKismetSystemLibrary and UKismetSystemLibrary.LineTraceSingle_ForScript then
        local r = UKismetSystemLibrary.LineTraceSingle_ForScript(
            TA, sL, eL, 0, false, _visIgnore, 0, _visHit, true,
            _visHitColor, _visTraceColor, 0.03)
        if r and _visHit and _visHit.bBlockingHit then return false end
    end
    return true
end

-- ==========================================
-- WALLHACK (Legacy - with proper restore)
-- ==========================================
local WH_SCALE_OFFSET = { R = 3, G = 3, B = 0, A = 0, r = 3, g = 3, b = 0, a = 0 }
local WH_COLOR_PARAMS = {
    "颜色", "Extra Light Color", "Para_Color", "Para_ColorTint", "Para_Color_1",
    "Tint", "Color", "BaseColor", "BodyColor", "MainColor", "DiffuseColor", "EmissiveColor"
}

local function ApplyVisualMods(lp, e, pc, cfg)

    if not IsValid(e) or not cfg.Enabled then return end
    local ib = IsABot(e)
    if not cfg.ShowAI and ib then return end

    e.WH_Meshes = e.WH_Meshes or {}
    if #e.WH_Meshes == 0 then
        SafeCall(function()
            if IsValid(e.Mesh) then table_insert(e.WH_Meshes, e.Mesh) end
            local SK = import("SkeletalMeshComponent")
            if SK then
                local ch = e:GetComponentsByClass(SK)
                if ch then
                    local n = type(ch.Num) == "function" and ch:Num() or #ch
                    for c = 1, n do
                        local comp = type(ch.Get) == "function" and ch:Get(c-1) or ch[c]
                        if IsValid(comp) and comp ~= e.Mesh then table_insert(e.WH_Meshes, comp) end
                    end
                end
            end
        end)
    end
    local dt = (cfg.BlendMode == 2)
    local bm = cfg.BlendMode
    SafeCall(function()
        for i = 1, #e.WH_Meshes do
            local c = e.WH_Meshes[i]
            if IsValid(c) then
                local s, mi = SafeCall(function() return c:GetMaterial(0) end)
                if s and IsValid(mi) then
                    local s2, bmat = SafeCall(function() return mi:GetBaseMaterial() end)
                    if s2 and IsValid(bmat) then
                        if bmat.bDisableDepthTest ~= dt then bmat.bDisableDepthTest = dt end
                        if bmat.BlendMode ~= bm then bmat.BlendMode = bm end
                    end
                end
            end
        end
    end)
    SafeCall(function()
        for i = 1, #e.WH_Meshes do
            local c = e.WH_Meshes[i]
            if IsValid(c) then
                c.UseScopeDistanceCulling = false
                c.PrimitiveShadingStrategy = 1
                c.ShadingRate = 6
            end
        end
        local vis = IsVisibleToPlayer(pc, e)
        local fc = ib and (vis and cfg.BotVisibleColor or cfg.BotHiddenColor)
            or (vis and cfg.VisibleColor or cfg.HiddenColor)
        e.WH_MIDs = e.WH_MIDs or {}
        local changed = (e.WH_LastColorR ~= fc.R) or (e.WH_LastColorG ~= fc.G) or (e.WH_LastBlendMode ~= bm)
        for mi_idx = 1, #e.WH_Meshes do
            local c = e.WH_Meshes[mi_idx]
            if IsValid(c) then
                local k = tostring(c)
                e.WH_MIDs[k] = e.WH_MIDs[k] or {}
                e.WH_OriginalMaterials = e.WH_OriginalMaterials or {}
                if not e.WH_OriginalMaterials[k] then
                    e.WH_OriginalMaterials[k] = {}
                    for oi = 0, 10 do
                        local s, om = SafeCall(function() return c:GetMaterial(oi) end)
                        if not s or not IsValid(om) then break end
                        e.WH_OriginalMaterials[k][oi] = om
                    end
                end
                for i = 0, 10 do
                    local s, mi = SafeCall(function() return c:GetMaterial(i) end)
                    if not s or not IsValid(mi) then break end
                    local isNew, need = false, false
                    local cc = e.WH_MIDs[k][i]
                    if not IsValid(cc) then
                        local s2, nm = SafeCall(function() return c:CreateAndSetMaterialInstanceDynamic(i) end)
                        if s2 and IsValid(nm) then
                            e.WH_MIDs[k][i] = nm cc = nm isNew = true need = true
                        end
                    elseif mi ~= cc then
                        SafeCall(function() c:SetMaterial(i, cc) end)
                        need = true
                    end
                    if IsValid(cc) and (changed or isNew or need) then
                        SafeCall(function()
                            for p = 1, #WH_COLOR_PARAMS do
                                cc:SetVectorParameterValue(WH_COLOR_PARAMS[p], fc)
                            end
                            cc:SetVectorParameterValue("ParaScaleOffset", WH_SCALE_OFFSET)
                        end)
                    end
                end
            end
        end
        if changed then
            e.WH_LastColorR = fc.R
            e.WH_LastColorG = fc.G
            e.WH_LastBlendMode = bm
        end
    end)
end

local function RestoreWallhack()
    pcall(function()
        local all = Game:GetAllPlayerPawns() or {}
        for _, e in pairs(all) do
            if IsValid(e) and e.WH_Meshes then
                for i = 1, #e.WH_Meshes do
                    local c = e.WH_Meshes[i]
                    if IsValid(c) then
                        if e.WH_OriginalMaterials then
                            local k = tostring(c)
                            local orig = e.WH_OriginalMaterials[k]
                            if orig then
                                for idx, mat in pairs(orig) do
                                    if IsValid(mat) then
                                        pcall(function() c:SetMaterial(idx, mat) end)
                                    end
                                end
                            end
                        end
                        if e.WH_MIDs then
                            local k = tostring(c)
                            local mids = e.WH_MIDs[k]
                            if mids then
                                for idx, mid in pairs(mids) do
                                    if IsValid(mid) then
                                        pcall(function() mid:ConditionalBeginDestroy() end)
                                    end
                                end
                                e.WH_MIDs[k] = nil
                            end
                        end
                    end
                end
                e.WH_LastColorR = nil
                e.WH_LastColorG = nil
                e.WH_LastBlendMode = nil
            end
        end
    end)
end

local function WallhackTick()
    SafeCall(function()
        if not CheatConfig.Wallhack.Enabled then return end
        local lp = GameplayData and GameplayData.GetPlayerCharacter()
        if not IsValid(lp) then return end
        local mt = lp.TeamID or 0
        local all = Game:GetAllPlayerPawns()
        if not all then return end
        local cfg = CheatConfig.Wallhack
        local md = (cfg.MaxDistance or 300) * 100
        local pc = nil
        SafeCall(function() pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() end)
        for _, e in pairs(all) do
            if IsValid(e) and e ~= lp then
                if (e.TeamID or 0) ~= mt then
                    local d = 0
                    SafeCall(function() d = lp:GetDistanceTo(e) end)
                    if d <= md then
                        local a = false
                        SafeCall(function() a = e:IsAlive() end)
                        if a then ApplyVisualMods(lp, e, pc, cfg) end
                    end
                end
            end
        end
    end)
end

local function StartWallhackTimer()
    local pc = nil
    SafeCall(function() pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() end)
    if IsValid(pc) and pc.AddGameTimer then
        if _G._WallhackTimer then SafeCall(function() pc:RemoveGameTimer(_G._WallhackTimer) end) end
        SafeCall(function() _G._WallhackTimer = pc:AddGameTimer(0.3, true, WallhackTick) end)
    end
end
SafeCall(function() StartWallhackTimer() end)

-- ==========================================
-- PLAYER MAP MARKER
-- ==========================================
local PlayerMapMarker = {
    SnapLineWidgets = {}, ESPCanvas = nil, bActive = false,
    _cachedViewportW = 1920, _cachedViewportH = 1080,
    _CanvasScaleX = 1.0, _CanvasScaleY = 1.0, _CanvasOffsetX = 0.0, _CanvasOffsetY = 0.0,
    _EnemyCache = {}
}
_G.PlayerMapMarker = PlayerMapMarker

local TitleWidget, TitleWidget2, TitleWidget3

function PlayerMapMarker.GetGameplayData()

    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGameplayData = GDP return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if GDP then pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end) end
    if not (PC and IsValid(PC)) then
        pcall(function() if slua_GameFrontendHUD then PC = slua_GameFrontendHUD:GetPlayerController() end end)
    end
    if PC and IsValid(PC) then PlayerMapMarker._CachedPC = PC end
    return PC
end

function PlayerMapMarker.GetCGameState()
    if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then return PlayerMapMarker._CachedCGameState end
    local ok, GS = pcall(function() return require("GameLua.GameCore.Data.CGameState") end)
    if ok and GS then PlayerMapMarker._CachedCGameState = GS return GS end
    return nil
end

PlayerMapMarker._CharBuf = {}
function PlayerMapMarker.GetAllCharacters()
    local A = PlayerMapMarker._CharBuf
    for k in pairs(A) do A[k] = nil end
    pcall(function()
        local P = Game:GetAllPlayerPawns()
        if P then
            for _, p in pairs(P) do
                if p and sluaIsValid(p) then
                    local k = nil
                    if p.GetPlayerKey then k = p:GetPlayerKey() end
                    if not k and p.PlayerKey then k = p.PlayerKey end
                    if not k and p.PlayerState and p.PlayerState.PlayerKey then k = p.PlayerState.PlayerKey end
                    if k then A[k] = p end
                end
            end
        end
    end)
    if not next(A) then
        local GS = PlayerMapMarker.GetCGameState()
        if GS and GS.GetAllCharacters then pcall(function() A = GS:GetAllCharacters() end) end
    end
    return A
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return nil end
    local k = nil
    pcall(function()
        if PC.GetPlayerKey then k = PC:GetPlayerKey()
        elseif PC.PlayerState and PC.PlayerState.PlayerKey then k = PC.PlayerState.PlayerKey end
    end)
    return k
end

function PlayerMapMarker.IsMe(C, PK, MK)
    local me = false
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            if C == GDP.GetLocalCharacter() then me = true return end
        end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if PC and PC.GetPawn then
            if C == PC:GetPawn() then me = true return end
        end
    end)
    if not me and MK ~= nil and PK ~= nil then
        me = (tostring(PK) == tostring(MK))
    end
    return me
end

function PlayerMapMarker.IsAlive(C)
    local a = true
    pcall(function()
        if C.HealthStatus then a = SecurityCommonUtils.IsHealthStatusAlive(C.HealthStatus)
        elseif C.IsAlive then a = C:IsAlive()
        elseif C.Health ~= nil then a = C.Health > 0
        elseif C.HP ~= nil then a = C.HP > 0 end
    end)
    return a
end

function PlayerMapMarker.GetTeamID(C)
    if not IsValid(C) then return nil end
    local t = nil
    pcall(function() if C.GetTeamID then t = C:GetTeamID() end end)
    if not t then
        pcall(function()
            local PS = nil
            if C.GetPlayerStateSafety then PS = C:GetPlayerStateSafety()
            elseif C.GetPlayerState then PS = C:GetPlayerState() end
            if IsValid(PS) then
                if PS.GetTeamID then t = PS:GetTeamID()
                elseif PS.TeamID then t = PS.TeamID end
            end
        end)
    end
    if not t then pcall(function() if C.TeamID then t = C.TeamID end end) end
    return t
end

function PlayerMapMarker.GetCharacterLocation(C)
    if not IsValid(C) then return nil end
    local L = nil
    pcall(function() if C.K2_GetActorLocation then L = C:K2_GetActorLocation() end end)
    if not L then pcall(function() if Game and Game.GetActorLocation then L = Game:GetActorLocation(C) end end) end
    return L
end

function PlayerMapMarker.GetESPLocation(C)
    if not IsValid(C) then return nil end
    local L = PlayerMapMarker.GetCharacterLocation(C)
    if L then
        local h = 85
        pcall(function()
            if C.bIsCrouched then h = 60 end
            if C.IsProne and C:IsProne() then h = 30 end
        end)
        pcall(function() L.Z = L.Z + h end)
    end
    return L
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local T = nil
    pcall(function() T = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not T then return false end
    local M = nil
    pcall(function() M = T.GetMainControlBaseUI() end)
    if not M or not Game:IsValid(M) then return false end
    local P = nil
    pcall(function()
        if M.CanvasPanel_0 and Game:IsValid(M.CanvasPanel_0) then P = M.CanvasPanel_0
        elseif M.CanvasPanel_42 and Game:IsValid(M.CanvasPanel_42) then P = M.CanvasPanel_42 end
    end)
    if not P then return false end
    PlayerMapMarker.ESPCanvas = P
    return true
end

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local s = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local p0 = SBL.AbsoluteToLocal(cg, FVector2D(0, 0))
                local p1 = SBL.AbsoluteToLocal(cg, FVector2D(100, 100))
                if p0 and p1 then
                    PlayerMapMarker._CanvasScaleX = (p1.X - p0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (p1.Y - p0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = p0.X
                    PlayerMapMarker._CanvasOffsetY = p0.Y
                    s = true
                end
            end
        end
    end)
    if not s then
        local sc = 1.0
        local W = WidgetLayoutLibrary
        if W and W.GetViewportScale then sc = W.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / sc
        PlayerMapMarker._CanvasScaleY = 1.0 / sc
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, P)
    if not P then return FVector2D(0, 0) end
    return FVector2D(P.X * (PlayerMapMarker._CanvasScaleX or 1.0) + (PlayerMapMarker._CanvasOffsetX or 0),
        P.Y * (PlayerMapMarker._CanvasScaleY or 1.0) + (PlayerMapMarker._CanvasOffsetY or 0))
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WL)
    if not IsValid(PC) or not WL then return false, FVector2D(0, 0) end
    local P = FVector2D(0, 0)
    local ok = false
    pcall(function()
        local r = PC:ProjectWorldLocationToScreen(WL, P, true)
        if r == true or r == 1 or (P and (P.X ~= 0 or P.Y ~= 0)) then ok = true end
    end)
    if not ok or not P or (P.X == 0 and P.Y == 0) then return false, FVector2D(0, 0) end
    return true, PlayerMapMarker.ScreenPixelToCanvasLocal(PC, P)
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
    local W, H = 0, 0
    local sc = 1.0
    pcall(function()
        if PC and PC.GetViewportSize then
            local v = FVector2D(0, 0)
            PC:GetViewportSize(v)
            if v and v.X and v.X > 200 then W = v.X H = v.Y end
        end
    end)
    if W <= 200 then
        pcall(function()
            local W2 = WidgetLayoutLibrary
            if W2 and W2.GetViewportSize then
                local v = W2.GetViewportSize(PC)
                if v and v.X and v.X > 200 then W = v.X H = v.Y end
            end
        end)
    end
    pcall(function()
        local W2 = WidgetLayoutLibrary
        if W2 and W2.GetViewportScale then
            local s = W2.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then sc = s end
        end
    end)
    if W <= 200 then
        W = (PlayerMapMarker._cachedViewportW or 1920) * sc
        H = (PlayerMapMarker._cachedViewportH or 1080) * sc
    end
    if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D(0, 0) end
    PlayerMapMarker._CachedTopCenterPixel.X = W / 2.0
    PlayerMapMarker._CachedTopCenterPixel.Y = 0.0
    local f = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
    return f.X + (SnapLineConfig.SnapLineOriginOffsetX or 0),
           f.Y + (SnapLineConfig.SnapLineOriginOffsetY or 0)
end

-- ==========================================
-- BADGE TEXTURES
-- ==========================================
local function LoadBadgeTexture(img, urls, fn, tk)
    if not img or not IsValid(img) then return end
    if ECCache[tk] and IsValid(ECCache[tk]) then
        pcall(function()
            img:SetBrushFromTexture(ECCache[tk], false)
            img:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        return
    end
    local function apply(tex)
        if tex and IsValid(tex) and IsValid(img) then
            ECCache[tk] = tex _textureCache[urls[1]] = tex
            pcall(function()
                img:SetBrushFromTexture(tex, false)
                img:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            return true
        end
        return false
    end
    for _, p in ipairs(GetPossibleLocalPaths(fn)) do
        if FileExists(p) then
            local tex = nil
            pcall(function()
                local a = package.loaded["common.asset_util"] or require("common.asset_util")
                if a and a.GetAssetSync then tex = a:GetAssetSync(p) end
            end)
            if not tex then pcall(function() if CGame and CGame.LoadObject then tex = CGame:LoadObject(p) end end) end
            if tex and apply(tex) then return end
        end
    end
    local function try(i)
        if i > #urls then return end
        local u = urls[i]
        local g = false
        pcall(function()
            local A = import("AsyncTaskDownloadImage") or import("/Script/UMG.AsyncTaskDownloadImage")
            if A and A.DownloadImage then
                local t = A.DownloadImage(u)
                if t and t.OnSuccess then
                    t.OnSuccess:Add(function(tex) if not g and tex then g = true apply(tex) end end)
                    if t.OnFail then t.OnFail:Add(function() if not g then try(i + 1) end end) end
                end
            end
        end)
        if not g then
            pcall(function()
                local mm = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                if not mm then pcall(function() mm = require("GameLua.GameCore.Module.ModuleManager") end) end
                local im = nil
                if mm and mm.GetModule and mm.CommonModuleConfig then im = mm.GetModule(mm.CommonModuleConfig.image_download_mgr) end
                if not im then pcall(function() im = require("client.slua.logic.image_download.image_download_mgr") end) end
                if im and im.DownloadImageByHttpWrapper then
                    im:DownloadImageByHttpWrapper(u, function(tex) if not g and tex then g = true apply(tex) end end,
                        function() if not g then try(i + 1) end end)
                end
            end)
        end
    end
    try(1)
end

local function CreateEnemyCounter(P, cX, tY)
    local CD = CounterData
    if CD.ImgPlayer and sluaIsValid(CD.ImgPlayer) and CD.ImgBot and sluaIsValid(CD.ImgBot) then return true end
    local cfg = EnemyCounterConfig
    local W = cfg.BaseWidth * cfg.Scale
    local H = cfg.BaseHeight * cfg.Scale
    local fx = cX + (cfg.OffsetX or 0)
    local fy = tY + (cfg.YOffset or 0)
    local ip = CGame:NewObjectFromPath("/Script/UMG.Image", P)
    local sp = nil
    if ip and sluaIsValid(ip) then
        ip:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        sp = P:AddChildToCanvas(ip)
        if sp then sp:SetAutoSize(false) sp:SetSize(FVector2D(W, H)) sp:SetPosition(FVector2D(fx - W, fy)) sp:SetZOrder(1005) end
    end
    local ib = CGame:NewObjectFromPath("/Script/UMG.Image", P)
    local sb = nil
    if ib and sluaIsValid(ib) then
        ib:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        sb = P:AddChildToCanvas(ib)
        if sb then sb:SetAutoSize(false) sb:SetSize(FVector2D(W, H)) sb:SetPosition(FVector2D(fx, fy)) sb:SetZOrder(1005) end
    end
    local function MakeT(px, py)
        local t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", P)
        local s = nil
        if t and sluaIsValid(t) then
            t:SetText("0")
            pcall(function()
                if t.SetFontSize then t:SetFontSize(10)
                elseif t.SetFont then local f = t.Font or {} f.Size = 10 t:SetFont(f) end
            end)
            t:SetJustification(1)
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            s = P:AddChildToCanvas(t)
            if s then s:SetAutoSize(true) s:SetAlignment(FVector2D(0.5, 0.5)) s:SetPosition(FVector2D(px, py)) s:SetZOrder(1010) end
        end
        return t, s
    end
    local tp, stp = MakeT(fx - (W * 0.25), fy + (H * 0.5))
    local tb, stb = MakeT(fx + (W * 0.65), fy + (H * 0.5))
    LoadBadgeTexture(ip, ECP, "ic-danger-enemy.png", "Player")
    LoadBadgeTexture(ib, ECB, "ic-danger-boot.png", "Bot")
    CD.ImgPlayer = ip CD.SlotPlayer = sp CD.ImgBot = ib CD.SlotBot = sb
    CD.TxtPlayer = tp CD.SlotTxtPlayer = stp CD.TxtBot = tb CD.SlotTxtBot = stb
    CD.bCreated = true
    return true
end

local function UpdateEnemyCounterDisplay(rc, bc, P, cX, tY)

    local CD = CounterData
    local cfg = EnemyCounterConfig
    if not Config.EnemyCounter_Enabled or not Config.ESPGlobal_Enabled then
        if CD.bCreated then
            pcall(function()
                local c = UEnums.ESlateVisibility.Collapsed
                if CD.ImgPlayer and sluaIsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(c) end
                if CD.ImgBot and sluaIsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(c) end
                if CD.TxtPlayer and sluaIsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(c) end
                if CD.TxtBot and sluaIsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(c) end
            end)
        end
        return
    end
    if not CreateEnemyCounter(P, cX, tY) then return end
    local W = cfg.BaseWidth * cfg.Scale
    local H = cfg.BaseHeight * cfg.Scale
    local fx = cX + (cfg.OffsetX or 0)
    local fy = tY + (cfg.YOffset or 0)
    pcall(function()
        if CD.SlotPlayer then CD.SlotPlayer:SetSize(FVector2D(W, H)) CD.SlotPlayer:SetPosition(FVector2D(fx - W, fy)) end
        if CD.SlotBot then CD.SlotBot:SetSize(FVector2D(W, H)) CD.SlotBot:SetPosition(FVector2D(fx, fy)) end
        if CD.SlotTxtPlayer then CD.SlotTxtPlayer:SetPosition(FVector2D(fx - (W * 0.25), fy + (H * 0.5))) end
        if CD.SlotTxtBot then CD.SlotTxtBot:SetPosition(FVector2D(fx + (W * 0.65), fy + (H * 0.5))) end
        if CD.LastPlayerCount ~= rc then
            if CD.TxtPlayer and sluaIsValid(CD.TxtPlayer) then CD.TxtPlayer:SetText(tostring(rc)) end
            CD.LastPlayerCount = rc
        end
        if CD.LastBotCount ~= bc then
            if CD.TxtBot and sluaIsValid(CD.TxtBot) then CD.TxtBot:SetText(tostring(bc)) end
            CD.LastBotCount = bc
        end
        local v = UEnums.ESlateVisibility.SelfHitTestInvisible
        if CD.ImgPlayer and sluaIsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(v) end
        if CD.ImgBot and sluaIsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(v) end
        if CD.TxtPlayer and sluaIsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(v) end
        if CD.TxtBot and sluaIsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(v) end
    end)
end

-- ==========================================
-- TITLE TEXT
-- ==========================================
local function UpdateTitleText(fx, fy, canvas)
    local function rmAll()
        for _, w in ipairs({TitleWidget, TitleWidget2, TitleWidget3}) do
            if w and sluaIsValid(w) then pcall(function()
                w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                w:RemoveFromParent()
            end) end
        end
        TitleWidget, TitleWidget2, TitleWidget3 = nil, nil, nil
    end
    if not Config.ESPGlobal_Enabled then rmAll() return end
    local oC = ColorConfig.Title_Old
    local nC = ColorConfig.Title_New
    local function ensure(w)
        if not w and canvas and Game:IsValid(canvas) then
            w = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas)
            if w and sluaIsValid(w) then
                local s = canvas:AddChildToCanvas(w)
                if s then s:SetAutoSize(true) s:SetZOrder(10) end
                w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end
        end
        return w
    end
    TitleWidget = ensure(TitleWidget)
    TitleWidget2 = ensure(TitleWidget2)
    TitleWidget3 = ensure(TitleWidget3)
    local function apply(w, px, py, txt, col)
        if not w or not sluaIsValid(w) then return end
        local lc = FLinearColor(col.R/255, col.G/255, col.B/255, col.A/255)
        local fc = FSlateColor and FSlateColor(lc) or lc
        pcall(function()
            local s = WidgetLayoutLibrary and WidgetLayoutLibrary.SlotAsCanvasSlot(w)
            if s then s:SetPosition(FVector2D(px, py)) end
            if w.SetText then w:SetText(txt) elseif w.SetTextString then w:SetTextString(txt) end
            w:SetColorAndOpacity(fc)
            w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
    apply(TitleWidget, fx + oC.Position.X, fy + oC.Position.Y, oC.Text, oC.Color)
    apply(TitleWidget2, fx + nC.Position.X, fy + nC.Position.Y, nC.Line1, nC.Color)
    apply(TitleWidget3, fx + nC.Position.X, fy + nC.Position.Y + (nC.LineSpacing or 18), nC.Line2, nC.Line2Color or nC.Color)
end

-- ==========================================
-- SNAP LINE
-- ==========================================
function PlayerMapMarker.CreateSnapLine()

    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local B = nil
    pcall(function() B = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not B or not sluaIsValid(B) then return nil end
    pcall(function() B:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() B:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)
    local S = nil
    pcall(function()
        S = PlayerMapMarker.ESPCanvas:AddChildToCanvas(B)
        if S then S:SetAutoSize(false) S:SetZOrder(1) end
    end)
    return { Widget = B, Slot = S }
end

function PlayerMapMarker.UpdateSnapLine(k, cp, on, fx, fy, C, PC)
    if not Config.SnapLine_Enabled or not Config.ESPGlobal_Enabled
        or not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
        if next(PlayerMapMarker.SnapLineWidgets) then PlayerMapMarker.ClearAllSnapLines() end
        return
    end
    local LD = PlayerMapMarker.SnapLineWidgets[k]
    if not on or not cp then
        if LD and LD.Widget and sluaIsValid(LD.Widget) then
            pcall(function() LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end
    local isNew = false
    if not LD then
        LD = PlayerMapMarker.CreateSnapLine()
        if not LD or not LD.Widget or not LD.Slot then return end
        PlayerMapMarker.SnapLineWidgets[k] = LD
        isNew = true
    end
    local W, S = LD.Widget, LD.Slot
    local colors = SnapLineConfig.Colors
    local vis = IsVisibleToPlayer(PC, C)
    local sc
    if IsABot(C) then sc = vis and colors.BotVisible or colors.BotHidden
    else sc = vis and colors.PlayerVisible or colors.PlayerHidden end
    local fc = FLinearColor(sc.R/255, sc.G/255, sc.B/255, (sc.A/255) * (SnapLineConfig.SnapLineOpacity or 0.9))
    pcall(function()
        W:SetBrushColor(fc)
        W:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    if not LD._PivotSet then
        pcall(function() W:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)
        LD._PivotSet = true
    end
    local toX = cp.X + (SnapLineConfig.SnapLineHeadOffsetX or 0)
    local toY = cp.Y + (SnapLineConfig.SnapLineHeadOffsetY or 0)
    local dx, dy = toX - fx, toY - fy
    local len = math_sqrt(dx*dx + dy*dy)
    local t = SnapLineConfig.SnapLineThickness or 3.0
    local a = safe_atan2(dy, dx) * (180.0 / math_pi)
    if not LD._CachedPosVec then
        LD._CachedPosVec = FVector2D(fx, fy - t/2.0)
        LD._CachedSizeVec = FVector2D(len, t)
    else
        LD._CachedPosVec.X = fx LD._CachedPosVec.Y = fy - t/2.0
        LD._CachedSizeVec.X = len LD._CachedSizeVec.Y = t
    end
    pcall(function()
        S:SetPosition(LD._CachedPosVec)
        S:SetSize(LD._CachedSizeVec)
        if isNew then S:SetZOrder(1) end
    end)
    pcall(function() W:SetRenderAngle(a) end)
end

function PlayerMapMarker.RemoveSnapLine(k)
    local LD = PlayerMapMarker.SnapLineWidgets[k]
    if LD and LD.Widget and sluaIsValid(LD.Widget) then
        pcall(function()
            LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            LD.Widget:RemoveFromParent()
            LD.Widget:ConditionalBeginDestroy()
        end)
    end
    PlayerMapMarker.SnapLineWidgets[k] = nil
end

function PlayerMapMarker.ClearAllSnapLines()
    for k, LD in pairs(PlayerMapMarker.SnapLineWidgets) do
        if LD and LD.Widget and sluaIsValid(LD.Widget) then
            pcall(function()
                LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                LD.Widget:RemoveFromParent()
                LD.Widget:ConditionalBeginDestroy()
            end)
        end
    end
    PlayerMapMarker.SnapLineWidgets = {}
    PlayerMapMarker._EnemyCache = {}
end

function PlayerMapMarker.ScanAndUpdate()
    if not Config.ESPGlobal_Enabled then
        PlayerMapMarker.ClearAllSnapLines()
        return
    end
    if not Config.SnapLine_Enabled then
        if next(PlayerMapMarker.SnapLineWidgets) then PlayerMapMarker.ClearAllSnapLines() end
    end
    if not (Config.SnapLine_Enabled or Config.EnemyCounter_Enabled or Config.Title_Enabled) then return end
    if not PlayerMapMarker.InitESPCanvas() then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)
    local fx, fy = PlayerMapMarker.GetSnapLineStartPos(PC)
    local All = PlayerMapMarker.GetAllCharacters()
    if not All then return end
    local MK = PlayerMapMarker.GetMyPlayerKey()
    local MC = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MC = GDP.GetLocalCharacter()
        elseif PC and PC.GetPawn then MC = PC:GetPawn() end
    end)
    local MT = PlayerMapMarker.GetTeamID(MC)
    local Seen = {}
    local rP, bC = 0, 0
    for K, C in pairs(All) do
        if IsValid(C) then
            local me = PlayerMapMarker.IsMe(C, K, MK)
            local ks = tostring(K)
            local al = PlayerMapMarker.IsAlive(C)
            local ti = PlayerMapMarker.GetTeamID(C)
            local skip = me
            if MT ~= nil and ti == MT and not me then skip = true end
            if not al then skip = true end
            if not skip then
                Seen[ks] = true
                PlayerMapMarker._EnemyCache[ks] = C
                if IsABot(C) then bC = bC + 1 else rP = rP + 1 end
                if Config.SnapLine_Enabled then
                    local L = PlayerMapMarker.GetESPLocation(C)
                    if L then
                        local ok, cp = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, L)
                        PlayerMapMarker.UpdateSnapLine(ks, cp, ok, fx, fy, C, PC)
                    end
                end
            end
        end
    end
    UpdateTitleText(fx, fy, PlayerMapMarker.ESPCanvas)
    local tY = 0
    pcall(function()
        local W = WidgetLayoutLibrary
        local sc = (W and W.GetViewportScale and W.GetViewportScale(PC)) or 1.0
        tY = 10 * (1.0 / sc)
    end)
    UpdateEnemyCounterDisplay(rP, bC, PlayerMapMarker.ESPCanvas, fx, tY)
    for ks in pairs(PlayerMapMarker.SnapLineWidgets) do
        if not Seen[ks] then
            PlayerMapMarker.RemoveSnapLine(ks)
            PlayerMapMarker._EnemyCache[ks] = nil
        end
    end
end

function PlayerMapMarker.UpdateLight()
    if not Config.SnapLine_Enabled or not Config.ESPGlobal_Enabled then
        if next(PlayerMapMarker.SnapLineWidgets) then PlayerMapMarker.ClearAllSnapLines() end
        return
    end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)
    local fx, fy = PlayerMapMarker.GetSnapLineStartPos(PC)
    for ks, C in pairs(PlayerMapMarker._EnemyCache) do
        if IsValid(C) and PlayerMapMarker.IsAlive(C) then
            local L = PlayerMapMarker.GetESPLocation(C)
            if L then
                local ok, cp = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, L)
                PlayerMapMarker.UpdateSnapLine(ks, cp, ok, fx, fy, C, PC)
            end
        else
            PlayerMapMarker.RemoveSnapLine(ks)
            PlayerMapMarker._EnemyCache[ks] = nil
        end
    end
end

function PlayerMapMarker.AttachTimers()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if not sluaIsValid(pc) or not pc.AddGameTimer then
            local now = os_time()
            if PlayerMapMarker._AttachPending and PlayerMapMarker._AttachPendingTime
                and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end
            PlayerMapMarker._AttachPending = true
            PlayerMapMarker._AttachPendingTime = now
            pcall(function()
                require("timer").SetGameTimer(1.0, false, function()
                    PlayerMapMarker._AttachPending = nil
                    PlayerMapMarker._AttachPendingTime = nil
                    PlayerMapMarker.AttachTimers()
                end)
            end)
            return
        end
        PlayerMapMarker._AttachPending = nil
        PlayerMapMarker._AttachPendingTime = nil
        local now = os_time()
        local lastPC = PlayerMapMarker._ActiveTimerPC
        if lastPC and sluaIsValid(lastPC) and lastPC == pc then
            if PlayerMapMarker._ActiveTimerTick and (now - PlayerMapMarker._ActiveTimerTick) < 5 then return end
        end
        PlayerMapMarker._ActiveTimerPC = pc
        PlayerMapMarker._ActiveTimerTick = now
        pcall(function()
            pc:AddGameTimer(SnapLineConfig.nUpdateInterval or 0.5, true, function()
                PlayerMapMarker._ActiveTimerTick = os_time()
                if PlayerMapMarker.bActive and Config.ESPGlobal_Enabled then
                    pcall(function() PlayerMapMarker.ScanAndUpdate() end)
                end
            end)
        end)
        pcall(function()
            pc:AddGameTimer(SnapLineConfig._LightUpdateInterval or 0.05, true, function()
                PlayerMapMarker._ActiveTimerTick = os_time()
                if PlayerMapMarker.bActive and Config.ESPGlobal_Enabled then
                    pcall(function() PlayerMapMarker.UpdateLight() end)
                end
            end)
        end)
        pcall(function() require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers) end)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.AttachTimers()
end

function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    PlayerMapMarker.ClearAllSnapLines()
    PlayerMapMarker._EnemyCache = {}
    PlayerMapMarker.ESPCanvas = nil
end

-- ==========================================
-- BOX ESP
-- ==========================================
local BoxESP = {
    bActive = true, ESPCanvas = nil, BoxWidgets = {},
    _CanvasScaleX = 1.0, _CanvasScaleY = 1.0, _CanvasOffsetX = 0.0, _CanvasOffsetY = 0.0,
    _LastCanvas = nil, _LastTransformTime = 0, _LastHeavyUpdateTime = 0,
    _ColorCache = {}
}
_G.BoxESP = BoxESP

local TempProjVec2D = FVector2D and FVector2D(0, 0) or nil
local FlagCache = {}

local function GetCachedColor(r, g, b, a)
    local key = math_floor(r*1000) * 1000000000 + math_floor(g*1000) * 1000000 + math_floor(b*1000) * 1000 + math_floor(a*1000)
    local c = BoxESP._ColorCache[key]
    if not c then
        c = FLinearColor(r, g, b, a)
        BoxESP._ColorCache[key] = c
    end
    return c
end

function BoxESP.GetMainCanvas()
    if BoxESP.ESPCanvas and IsValid(BoxESP.ESPCanvas) then return BoxESP.ESPCanvas end
    local T = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
    if not T then pcall(function() T = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end) end
    if not T then return nil end
    local M = nil
    if T.GetMainControlBaseUI then M = T.GetMainControlBaseUI() end
    if not IsValid(M) then return nil end
    local P = nil
    if M.CanvasPanel_0 and IsValid(M.CanvasPanel_0) then P = M.CanvasPanel_0
    elseif M.CanvasPanel_42 and IsValid(M.CanvasPanel_42) then P = M.CanvasPanel_42 end
    if P then BoxESP.ESPCanvas = P BoxESP._LastCanvas = P end
    return P
end

function BoxESP.CreateESPWidget(P)

    if not FLinearColor or not FVector2D then return nil end
    local CC = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", P)
    if not IsValid(CC) then return nil end
    local CMS = P:AddChildToCanvas(CC)
    if not CMS then return nil end
    CMS:SetAutoSize(false) CMS:SetZOrder(995) CMS:SetAlignment(FVector2D(0.5, 0.5))
    local function MakeL()
        local b = CGame:NewObjectFromPath("/Script/UMG.Border", CC)
        if b and IsValid(b) then
            b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = CC:AddChildToCanvas(b)
            if s then s:SetAutoSize(false) end
            return { widget = b, slot = s }
        end
    end
    local C = {
        TopLeft_H = MakeL(), TopLeft_V = MakeL(),
        TopRight_H = MakeL(), TopRight_V = MakeL(),
        BottomLeft_H = MakeL(), BottomLeft_V = MakeL(),
        BottomRight_H = MakeL(), BottomRight_V = MakeL()
    }
    local function MakeT(fs, al)
        local t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", P)
        local s = nil
        if t and IsValid(t) then
            t:SetText("")
            local sz = math_floor(fs or 10)
            if t.Font then
                local nf = t.Font
                nf.Size = sz
                if nf.OutlineSettings then nf.OutlineSettings.OutlineSize = 1 nf.OutlineSettings.OutlineColor = FLinearColor(0,0,0,1) end
                if t.SetFont then t:SetFont(nf) else t.Font = nf end
            end
            if t.SetFontSize then t:SetFontSize(sz) end
            t:SetJustification(1)
            if t.SetHorizontalAlignment then t:SetHorizontalAlignment(1) end
            if t.SetVerticalAlignment then t:SetVerticalAlignment(1) end
            if t.SetAutoWrapText then t:SetAutoWrapText(false) end
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            s = P:AddChildToCanvas(t)
            if s then s:SetAutoSize(true) s:SetZOrder(1000) s:SetAlignment(al or FVector2D(0.5, 0)) end
        end
        return t, s
    end
    local N, NS = MakeT(10, FVector2D(0.5, 0))
    local D, DS = MakeT(10, FVector2D(0.5, 0))
    local Bg, BgS, Hl, HlS = HealthBarModule.CreateHealthWidgets(P)
    local Wp, WpS = MakeT(10, FVector2D(0.5, 1))
    local Fg = CGame:NewObjectFromPath("/Script/UMG.Image", P)
    local FgS = nil
    if Fg and IsValid(Fg) then
        Fg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        FgS = P:AddChildToCanvas(Fg)
        if FgS then
            FgS:SetAutoSize(false)
            FgS:SetSize(FVector2D(24, 16))
            FgS:SetZOrder(1000)
            FgS:SetAlignment(FVector2D(0.5, 1))
        end
    end
    local St, StS = MakeT(10, FVector2D(0.5, 0))

    return {
        CornerContainer = CC, CornerSlot = CMS, Corners = C,
        NameWidget = N, NameSlot = NS, DistWidget = D, DistSlot = DS,
        BgWidget = Bg, BgSlot = BgS, HealthWidget = Hl, HealthSlot = HlS,
        WeaponWidget = Wp, WeaponSlot = WpS, _cachedWeapon = nil,
        FlagWidget   = Fg, FlagSlot   = FgS, _cachedNation = nil,
        StateWidget  = St, StateSlot  = StS, _cachedState  = nil,
        _cachedName = "", _cachedDist = "", lastW = 0, lastH = 0, bVisible = true
    }
end

function BoxESP.UpdateCornerDimensions(bd, w, h)
    if bd.lastW and bd.lastH then
        if math_abs(w - bd.lastW) < 1.5 and math_abs(h - bd.lastH) < 1.5 then return end
    end
    bd.lastW = w
    bd.lastH = h
    local cfg = BoxESPConfig
    local t = cfg.CornerThickness
    local cl = math_max(7, math_min(w, h) * cfg.CornerLengthRatio)
    local C = bd.Corners
    bd.CornerSlot:SetSize(FVector2D(w, h))
    local function setL(l, p, s) if l and l.slot then l.slot:SetPosition(p) l.slot:SetSize(s) end end
    setL(C.TopLeft_H, FVector2D(0, 0), FVector2D(cl, t))
    setL(C.TopLeft_V, FVector2D(0, 0), FVector2D(t, cl))
    setL(C.TopRight_H, FVector2D(w - cl, 0), FVector2D(cl, t))
    setL(C.TopRight_V, FVector2D(w - t, 0), FVector2D(t, cl))
    setL(C.BottomLeft_H, FVector2D(0, h - t), FVector2D(cl, t))
    setL(C.BottomLeft_V, FVector2D(0, h - cl), FVector2D(t, cl))
    setL(C.BottomRight_H, FVector2D(w - cl, h - t), FVector2D(cl, t))
    setL(C.BottomRight_V, FVector2D(w - t, h - cl), FVector2D(t, cl))
end

function BoxESP.UpdateCanvasTransform(PC)
    if not BoxESP.ESPCanvas or not IsValid(BoxESP.ESPCanvas) then return end
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
        local cg = BoxESP.ESPCanvas:GetCachedGeometry()
        if cg then
            local p0 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(0, 0))
            local p1 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(100, 100))
            if p0 and p1 then
                BoxESP._CanvasScaleX = (p1.X - p0.X) / 100
                BoxESP._CanvasScaleY = (p1.Y - p0.Y) / 100
                BoxESP._CanvasOffsetX = p0.X
                BoxESP._CanvasOffsetY = p0.Y
            end
        end
    end
end

function BoxESP.ProjectWorldToCanvasLocal(PC, WL)
    if not IsValid(PC) or not WL or not TempProjVec2D then return false, 0, 0 end
    local r = PC:ProjectWorldLocationToScreen(WL, TempProjVec2D, true)
    if (r == true or r == 1) and (TempProjVec2D.X ~= 0 or TempProjVec2D.Y ~= 0) then
        return true,
            TempProjVec2D.X * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX,
            TempProjVec2D.Y * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
    end
    return false, 0, 0
end

function BoxESP.HideWidget(bd)
    if not bd or not bd.bVisible then return end
    bd.bVisible = false
    local c = UEnums.ESlateVisibility.Collapsed
    local list = { bd.CornerContainer, bd.NameWidget, bd.DistWidget, bd.BgWidget, bd.HealthWidget,
                   bd.WeaponWidget, bd.FlagWidget, bd.StateWidget }
    for i = 1, #list do
        if list[i] and IsValid(list[i]) then list[i]:SetWidgetVisibility(c) end
    end
end

function BoxESP.UpdateESP()
    if not BoxESP.bActive or not Config.ESPGlobal_Enabled then
        for _, bd in pairs(BoxESP.BoxWidgets) do BoxESP.HideWidget(bd) end
        pcall(SkeletonModule.DestroyAll)
        return
    end
    local bBox = Config.BoxESP_Enabled
    local bN = Config.ShowName_Enabled
    local bD = Config.ShowDistance_Enabled
    local bH = Config.HealthBar_Enabled
    local bS = SkeletonConfig and SkeletonConfig.Enabled
    local bW = _G.ESP and _G.ESP.WEAPON
    local bF = _G.ESP and _G.ESP.FLAG
    local bSt = _G.ESP and _G.ESP.STATE
    if not (bBox or bN or bD or bH or bS or bW or bF or bSt) then
        for _, bd in pairs(BoxESP.BoxWidgets) do BoxESP.HideWidget(bd) end
        pcall(SkeletonModule.DestroyAll)
        return
    end
    local P = BoxESP.GetMainCanvas()
    if not P then return end
    local LP = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
    if not IsValid(LP) then return end
    local CT = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
    if not IsValid(CT) then return end
    local cur = os_clock()
    if BoxESP._LastCanvas ~= P or (cur - BoxESP._LastTransformTime > 1.0) then
        BoxESP.UpdateCanvasTransform(CT)
        BoxESP._LastCanvas = P
        BoxESP._LastTransformTime = cur
    end
    local heavy = (cur - BoxESP._LastHeavyUpdateTime > 0.15)
    if heavy then BoxESP._LastHeavyUpdateTime = cur end
    local tid = LP.TeamID or (LP.GetTeamID and LP:GetTeamID()) or 0
    local Pawns = (Game and Game.GetAllPlayerPawns and Game:GetAllPlayerPawns()) or {}
    local Seen = {}
    local bc = BoxESPConfig.Colors
    for K, Pawn in pairs(Pawns) do
        if IsValid(Pawn) and Pawn ~= LP then
            local pt = Pawn.TeamID or (Pawn.GetTeamID and Pawn:GetTeamID()) or -1
            local al = (Pawn.Health and Pawn.Health > 0) or (Pawn.IsAlive and Pawn:IsAlive())
            if al and pt ~= tid then
                local ks = tostring(K)
                Seen[ks] = true
                local isB = IsABot(Pawn)
                local vis = IsVisibleToPlayer(CT, Pawn)
                local cc
                if isB then cc = vis and bc.BotVisible or bc.BotHidden
                else cc = vis and bc.PlayerVisible or bc.PlayerHidden end
                local lc = GetCachedColor(cc.R, cc.G, cc.B, cc.A)
                local sc = FSlateColor and FSlateColor(lc) or lc
                local L = Pawn.K2_GetActorLocation and Pawn:K2_GetActorLocation()
                if not L and Pawn.RootComponent then L = Pawn.RootComponent:K2_GetComponentLocation() end
                if L then
                    local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
                    local top, bot = nil, nil
                    if mesh and mesh.GetSocketLocation then
                        local hl = mesh:GetSocketLocation("Head") or mesh:GetSocketLocation("head")
                        if hl then top = FVector(hl.X, hl.Y, hl.Z + 15) end
                        local rl = mesh:GetSocketLocation("root") or mesh:GetSocketLocation("Root")
                        if rl then bot = rl end
                    end
                    if not top or not bot then
                        top = FVector(L.X, L.Y, L.Z + 88)
                        bot = FVector(L.X, L.Y, L.Z - 90)
                    end
                    local tOK, tX, tY = BoxESP.ProjectWorldToCanvasLocal(CT, top)
                    local bOK, bX, bY = BoxESP.ProjectWorldToCanvasLocal(CT, bot)
                    local bd = BoxESP.BoxWidgets[ks]
                    if not bd then
                        bd = BoxESP.CreateESPWidget(P)
                        if bd then BoxESP.BoxWidgets[ks] = bd end
                    end
                    if bd and IsValid(bd.CornerContainer) then
                        if tOK and bOK then
                            local bh = math_max(28, math_abs(bY - tY))
                            local bw = math_max(15, bh * 0.55)
                            local cX = (tX + bX) * 0.5
                            local cY = (tY + bY) * 0.5
                            local btY = cY - (bh * 0.5)
                            local bbY = cY + (bh * 0.5)
                            bd.bVisible = true

                            if bBox then
                                BoxESP.UpdateCornerDimensions(bd, bw, bh)
                                bd.CornerSlot:SetPosition(FVector2D(cX, cY))
                                for _, li in pairs(bd.Corners) do
                                    if li and li.widget and IsValid(li.widget) then li.widget:SetBrushColor(lc) end
                                end
                                bd.CornerContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            else
                                bd.CornerContainer:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                            end

                            if bN and bd.NameWidget and IsValid(bd.NameWidget) then
                                bd.NameWidget:SetColorAndOpacity(sc)
                                bd.NameSlot:SetPosition(FVector2D(cX, bbY + 22.0))
                                bd.NameWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                if heavy or bd._cachedName == "" then
                                    local pn = isB and "Bot" or (Pawn.PlayerName or Pawn.PlayerNamePublic or "Player")
                                    pn = tostring(pn)
                                    if bd._cachedName ~= pn then bd.NameWidget:SetText(pn) bd._cachedName = pn end
                                end
                            else
                                if bd.NameWidget then bd.NameWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                            end

                            if bW and bd.WeaponWidget and IsValid(bd.WeaponWidget) then
                                if heavy or not bd._cachedWeapon then
                                    local wep = (Pawn.GetCurrentWeapon and Pawn:GetCurrentWeapon())
                                        or (Pawn.GetCurrentShootWeapon and Pawn:GetCurrentShootWeapon())
                                        or (Pawn.WeaponManagerComponent
                                            and Pawn.WeaponManagerComponent.CurrentWeaponReplicated)
                                    local weaponName = "Fist"
                                    if wep and IsValid(wep) then
                                        local wn = (type(wep.GetWeaponName) == "function" and wep:GetWeaponName())
                                                or wep.WeaponName
                                        if wn and wn ~= "" then
                                            weaponName = tostring(wn)
                                                :gsub("^BP_", ""):gsub("_C$", ""):gsub("_Wrapper$", "")
                                        end
                                    end
                                    if bd._cachedWeapon ~= weaponName then
                                        bd.WeaponWidget:SetText(weaponName)
                                        bd._cachedWeapon = weaponName
                                    end
                                end
                                bd.WeaponWidget:SetColorAndOpacity(sc)
                                bd.WeaponSlot:SetPosition(FVector2D(cX, btY - 2.0))
                                bd.WeaponWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            elseif bd.WeaponWidget and IsValid(bd.WeaponWidget) then
                                bd.WeaponWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                            end

                            if bF and bd.FlagWidget and IsValid(bd.FlagWidget) then
                                if heavy or not bd._cachedNation then
                                    local nation = (Pawn.PlayerState and Pawn.PlayerState.Nation)
                                                or Pawn.Nation or ""
                                    nation = tostring(nation or "")
                                    if nation == "" or nation == "nil" or nation == "0" then
                                        nation = "G1"
                                    end
                                    if bd._cachedNation ~= nation then
                                        local cfg = (CDataTable and CDataTable.GetTableData)
                                                and CDataTable.GetTableData("RegionConfig", nation)
                                        if not cfg or not cfg.res_path or cfg.res_path == "" then
                                            cfg = (CDataTable and CDataTable.GetTableData)
                                               and CDataTable.GetTableData("RegionConfig", "G1")
                                        end
                                        local flagPath = (cfg and cfg.res_path)
                                            or "/Game/UMG/Texture/Atlas/NationalflagUI/Frames/T_icon_flag_iland_png.T_icon_flag_iland_png"
                                        local set = false
                                        if FlagCache[flagPath] and IsValid(FlagCache[flagPath]) then
                                            bd.FlagWidget:SetBrushFromTexture(FlagCache[flagPath], false)
                                            set = true
                                        end
                                        if not set and bd.FlagWidget.SetBrushResourceFromPathSync then
                                            bd.FlagWidget:SetBrushResourceFromPathSync(flagPath, false); set = true
                                        end
                                        if not set and bd.FlagWidget.SetBrushFromPathAsync then
                                            bd.FlagWidget:SetBrushFromPathAsync(flagPath, false); set = true
                                        end
                                        if not set then
                                            local util = package.loaded["client.slua_ui_framework.util"]
                                            if not util then pcall(function()
                                                util = require("client.slua_ui_framework.util")
                                            end) end
                                            if util and util.SetTexture then
                                                util.SetTexture(bd.FlagWidget, flagPath, { sync = true })
                                                set = true
                                            end
                                        end
                                        if not set then
                                            local au = package.loaded["common.asset_util"]
                                            if not au then pcall(function()
                                                au = require("common.asset_util")
                                            end) end
                                            local tex = (au and au.GetAssetSync and au.GetAssetSync(flagPath))
                                                     or (CGame and CGame.LoadObject and CGame:LoadObject(flagPath))
                                            if tex and bd.FlagWidget.SetBrushFromTexture then
                                                bd.FlagWidget:SetBrushFromTexture(tex, false)
                                                FlagCache[flagPath] = tex
                                            end
                                        end
                                        bd._cachedNation = nation
                                    end
                                end
                                bd.FlagSlot:SetPosition(FVector2D(cX, btY - 18.0))
                                bd.FlagWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            elseif bd.FlagWidget and IsValid(bd.FlagWidget) then
                                bd.FlagWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                            end

                            if bD and bd.DistWidget and IsValid(bd.DistWidget) then
                                bd.DistWidget:SetColorAndOpacity(sc)
                                bd.DistSlot:SetPosition(FVector2D(cX, bbY + 6.0))
                                bd.DistWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                local dv = math_floor(LP:GetDistanceTo(Pawn) / 100.0)
                                local ds = tostring(dv) .. "m"
                                if bd._cachedDist ~= ds then bd.DistWidget:SetText(ds) bd._cachedDist = ds end
                            else
                                if bd.DistWidget then bd.DistWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                            end

                            if bSt and bd.StateWidget and IsValid(bd.StateWidget) then
                                if heavy or not bd._cachedState then
                                    local isKnocked = (Pawn.HealthStatus == 1 or Pawn.bIsKnocked
                                                    or (Pawn.IsKnocked and Pawn:IsKnocked()))
                                    local stateStr, slateCol = "Open", SlateColorEmerald
                                    if isKnocked then
                                        stateStr, slateCol = "Knocked", SlateColorCrimson
                                    elseif not vis then
                                        stateStr, slateCol = "Cover", SlateColorCrimson
                                    end
                                    if bd._cachedState ~= stateStr then
                                        bd.StateWidget:SetText(stateStr)
                                        bd.StateWidget:SetColorAndOpacity(slateCol)
                                        bd._cachedState = stateStr
                                    end
                                end
                                bd.StateSlot:SetPosition(FVector2D(cX, bbY + 38.0))
                                bd.StateWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            elseif bd.StateWidget and IsValid(bd.StateWidget) then
                                bd.StateWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                            end

                            if bH then
                                HealthBarModule.HealthBarWidth = CheatConfig.HealthBar.Width or 2.0
                                pcall(function() HealthBarModule.UpdateHealthBar(bd, Pawn, cX, bw, bh, bbY, true) end)
                            else
                                pcall(function() HealthBarModule.UpdateHealthBar(bd, Pawn, cX, bw, bh, bbY, false) end)
                            end

                            if bS then
                                local sk = SkeletonConfig
                                local st
                                if isB then st = vis and sk.BotVisible or sk.BotHidden
                                else st = vis and sk.PlayerVisible or sk.PlayerHidden end
                                local skc = FLinearColor(st.R, st.G, st.B, st.A)
                                pcall(function()
                                    SkeletonModule.UpdateSkeleton(ks, Pawn, CT, P, skc,
                                        function(pc, wl) return BoxESP.ProjectWorldToCanvasLocal(pc, wl) end)
                                end)
                            else
                                pcall(function() SkeletonModule.HideSkeleton(ks) end)
                            end
                        else
                            if bd then
                                local col = UEnums.ESlateVisibility.Collapsed
                                if bd.CornerContainer then bd.CornerContainer:SetWidgetVisibility(col) end
                                if bd.NameWidget then bd.NameWidget:SetWidgetVisibility(col) end
                                if bd.DistWidget then bd.DistWidget:SetWidgetVisibility(col) end
                                if bd.BgWidget then bd.BgWidget:SetWidgetVisibility(col) end
                                if bd.HealthWidget then bd.HealthWidget:SetWidgetVisibility(col) end
                                if bd.WeaponWidget then bd.WeaponWidget:SetWidgetVisibility(col) end
                                if bd.FlagWidget then bd.FlagWidget:SetWidgetVisibility(col) end
                                if bd.StateWidget then bd.StateWidget:SetWidgetVisibility(col) end
                            end
                            pcall(function() SkeletonModule.HideSkeleton(ks) end)
                        end
                    end
                end
            end
        end
    end
    for ks, bd in pairs(BoxESP.BoxWidgets) do
        if not Seen[ks] then
            BoxESP.HideWidget(bd)
            pcall(function() SkeletonModule.DestroySkeleton(ks) end)
        end
    end
end

-- =========================================================
-- MENU UI
-- =========================================================
local MC = {
    bg_main      = FLinearColor(0.02, 0.02, 0.08, 0.96),
    bg_header    = FLinearColor(0.55, 0.05, 0.15, 1.00),
    bg_row       = FLinearColor(0.06, 0.03, 0.12, 0.92),
    bg_scroll    = FLinearColor(0.02, 0.01, 0.05, 0.90),
    bg_tabbar    = FLinearColor(0.10, 0.02, 0.18, 1.00),
    tab_active_bg   = FLinearColor(0.85, 0.10, 0.25, 1.0),
    tab_inactive_bg = FLinearColor(0.05, 0.02, 0.10, 1.0),
    tab_active_text   = FLinearColor(1.00, 1.00, 1.00, 1.0),
    tab_inactive_text = FLinearColor(0.50, 0.30, 0.60, 1.0),
    tab_indicator     = FLinearColor(1.00, 0.30, 0.50, 1.0),
    blue_accent  = FLinearColor(0.95, 0.20, 0.35, 1.0),
    green_active = FLinearColor(0.00, 0.95, 0.50, 1.0),
    red_accent   = FLinearColor(1.00, 0.25, 0.30, 1.0),
    white      = FLinearColor(1.00, 1.00, 1.00, 1.0),
    text_label = FLinearColor(0.95, 0.90, 1.00, 1.0),
    text_dim   = FLinearColor(0.55, 0.35, 0.65, 1.0),
    transparent = FLinearColor(0, 0, 0, 0.001),
    switch_off_bg = FLinearColor(0.35, 0.35, 0.45, 1.0),
    switch_on_bg  = FLinearColor(0.00, 0.95, 0.50, 1.0),
    switch_knob   = FLinearColor(1.00, 1.00, 1.00, 1.0),
}

local M_W, M_H = 450, 620
local HEADER_H = 72
local TABBAR_H = 44
local FOOTER_H = 30
local ROW_H = 46
local ROW_GAP = 6
local CONTENT_PAD = 10

local isMenuOpen, menuBuilt = false, false
local menuCanvas = nil
local activeTab = "ESP"
local tabScrolls = {}
local tabButtons = {}
local toggleRows = {}
local bgPanel = nil

local function GetMenuCanvas()
    if menuCanvas and Game:IsValid(menuCanvas) then return menuCanvas end
    if InGameUITools then
        local M = InGameUITools.GetMainControlBaseUI()
        if M and Game:IsValid(M) then
            menuCanvas = M.CanvasPanel_0 or M.CanvasPanel_42
        end
    end
    return menuCanvas
end

local function MLayer(parent, x, y, w, h, color, z)
    local b = nil
    pcall(function()
        b = CGame:NewObjectFromPath("/Script/UMG.Border", parent)
        if b and sluaIsValid(b) then
            b:SetBrushColor(color)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = parent:AddChildToCanvas(b)
            if s then s:SetAutoSize(false) s:SetPosition(FVector2D(x, y)) s:SetSize(FVector2D(w, h)) s:SetZOrder(z or 0) end
        end
    end)
    return b
end

local function MText(parent, txt, x, y, size, color, z, ax, ay)
    local t = nil
    pcall(function()
        t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", parent)
        if t and sluaIsValid(t) then
            t:SetText(txt)
            if FSlateColor then t:SetColorAndOpacity(FSlateColor(color)) else t:SetColorAndOpacity(color) end
            if t.Font then local f = t.Font f.Size = size t.Font = f end
            t:SetRenderTransformPivot(FVector2D(ax or 0.5, ay or 0.5))
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = parent:AddChildToCanvas(t)
            if s then
                s:SetAutoSize(true)
                s:SetAlignment(FVector2D(ax or 0.5, ay or 0.5))
                s:SetPosition(FVector2D(x, y))
                s:SetZOrder(z or 100)
            end
        end
    end)
    return t
end

local function MBtn(parent, x, y, w, h, z, onClick)
    local b = nil
    pcall(function()
        b = CGame:NewObjectFromPath("/Script/UMG.Button", parent)
        if b and sluaIsValid(b) then
            b:SetColorAndOpacity(MC.transparent)
            b:SetBackgroundColor(MC.transparent)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
            local s = parent:AddChildToCanvas(b)
            if s then s:SetAutoSize(false) s:SetPosition(FVector2D(x, y)) s:SetSize(FVector2D(w, h)) s:SetZOrder(z or 900) end
            if onClick and b.OnClicked then b.OnClicked:Add(function() pcall(onClick) end) end
        end
    end)
    return b
end

local function SyncToggleToConfig(key, value)
    if not Config then return end
    if key == "Mod_MISC_Global" then Config.ESPGlobal_Enabled = value
    elseif key == "Mod_ESP_Counter" then Config.EnemyCounter_Enabled = value
    elseif key == "Mod_ESP_Line" then
        Config.SnapLine_Enabled = value
        if not value and PlayerMapMarker and PlayerMapMarker.ClearAllSnapLines then
            pcall(PlayerMapMarker.ClearAllSnapLines)
        end
    elseif key == "Mod_ESP_Box" then Config.BoxESP_Enabled = value
    elseif key == "Mod_ESP_Health" then
        Config.HealthBar_Enabled = value
        if CheatConfig and CheatConfig.HealthBar then CheatConfig.HealthBar.Enabled = value end
    elseif key == "Mod_ESP_Name" then Config.ShowName_Enabled = value
    elseif key == "Mod_ESP_Skeleton" then
        Config.Skeleton_Enabled = value
        if SkeletonConfig then SkeletonConfig.Enabled = value end
        if not value and SkeletonModule and SkeletonModule.DestroyAll then pcall(SkeletonModule.DestroyAll) end
    elseif key == "Mod_ESP_Distance" then Config.ShowDistance_Enabled = value
    elseif key == "Mod_ESP_Wallhack" then
        if CheatConfig and CheatConfig.Wallhack then CheatConfig.Wallhack.Enabled = value end
        if not value then pcall(RestoreWallhack) end
    elseif key == "Mod_MAGIC_Enabled" then
        Config.MagicBullet_Enabled = value
        if CheatConfig and CheatConfig.MagicBullet then CheatConfig.MagicBullet.Enabled = value end
        if not value then pcall(RestoreMagicBullet) end
    elseif key == "Mod_ESP_Weapon" then _G.ESP.WEAPON = value
    elseif key == "Mod_ESP_Flag" then _G.ESP.FLAG = value
    elseif key == "Mod_ESP_State" then _G.ESP.STATE = value
    elseif key == "Mod_SDK_WideView" then
        Config.WideView_Enabled = value
        WideViewModule.TargetFOV = tonumber(_G.Mod_SDK_FOVValue) or 120
        local lp = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if IsValid(lp) then
            WideViewModule.Apply(lp, true)
        end
        print("[WIDEVIEW] Toggle = " .. tostring(value) .. " FOV=" .. tostring(WideViewModule.TargetFOV))
    elseif key == "Mod_SDK_Crosshair" then Config.Crosshair_Enabled = value
    elseif key == "Mod_SDK_NewWH" then
        Config.NewWallhack_Enabled = value
        if value then
            if _G.StartNewWallhack then _G.StartNewWallhack() end
        else
            if _G._pbc_Cleanup then _G._pbc_Cleanup() end
        end
    elseif key == "Mod_SDK_165FPS" then
        Config.FPS165_Enabled = value
        if value then
            Enable165FPS()
            Apply165FPSInGame()
        else
            Disable165FPS()
        end
    elseif key == "Mod_SDK_BlackSky" then
        Config.BlackSky_Enabled = value
        if value then pcall(BlackSkyModule.Apply) else pcall(BlackSkyModule.Reset) end
    end
    if SaveSystem and SaveSystem.AutoSave then pcall(SaveSystem.AutoSave) end
end

local MENU_TABS = {
    {
        id = "ESP", title = "ESP",
        options = {
            {label = "All Esp Active",   key = "Mod_MISC_Global"},
            {label = "Enemy Counter",   key = "Mod_ESP_Counter"},
            {label = "Show Line",       key = "Mod_ESP_Line"},
            {label = "Show Box",        key = "Mod_ESP_Box"},
            {label = "Show Health",     key = "Mod_ESP_Health"},
            {label = "Show Name",       key = "Mod_ESP_Name"},
            {label = "Show Skeleton(LAG)", key = "Mod_ESP_Skeleton"},
            {label = "Show Distance",   key = "Mod_ESP_Distance"},
            {label = "Show Weapon",     key = "Mod_ESP_Weapon"},
            {label = "Show Flag",       key = "Mod_ESP_Flag"},
            {label = "Show State",      key = "Mod_ESP_State"},
        }
    },
    {
        id = "SDK", title = "SDK",
        options = {
            {label = "Wide View",key = "Mod_SDK_WideView"},
            {label = "Magic Bullet", key = "Mod_MAGIC_Enabled"},
            {label = "Wallhack",   key = "Mod_ESP_Wallhack"},
            {label = "Wallhack/chams", key = "Mod_SDK_NewWH"},
            {label = "No Recoil Crosshair", key = "Mod_SDK_Crosshair"},
            {label = "Black Sky (No Light)",key = "Mod_SDK_BlackSky"},
            {label = "Enable 165 FPS",      key = "Mod_SDK_165FPS"},
        }
    },
}

local function MakeFOVRow(vbox)
    local ROW_W = M_W - CONTENT_PAD * 2
    local outer = nil
    pcall(function()
        outer = CGame:NewObjectFromPath("/Script/UMG.Border", vbox)
        if outer and sluaIsValid(outer) then
            outer:SetBrushColor(MC.bg_row)
            outer:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
            local s = vbox:AddChildToVerticalBox(outer)
            if s then
                s:SetPadding(FMargin(0, 0, 0, ROW_GAP))
                if s.SetHeightOverride then s:SetHeightOverride(ROW_H) end
                if s.SetHorizontalAlignment then s:SetHorizontalAlignment(UEnums.EHorizontalAlignment.HAlign_Fill) end
            end
        end
    end)
    if not outer then return end
    local rc = nil
    pcall(function()
        rc = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", outer)
        if rc and sluaIsValid(rc) then outer:AddChild(rc) end
    end)
    if not rc then return end

    pcall(function()
        local lbl = CGame:NewObjectFromPath("/Script/UMG.TextBlock", rc)
        if lbl and sluaIsValid(lbl) then
            lbl:SetText("Wide View FOV")
            if lbl.Font then local f = lbl.Font f.Size = 16 lbl.Font = f end
            if FSlateColor then lbl:SetColorAndOpacity(FSlateColor(MC.text_label)) else lbl:SetColorAndOpacity(MC.text_label) end
            lbl:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = rc:AddChildToCanvas(lbl)
            if s then s:SetAutoSize(true) s:SetAlignment(FVector2D(0, 0.5)) s:SetPosition(FVector2D(18, ROW_H * 0.5)) s:SetZOrder(100) end
        end
    end)

    if _G.Mod_SDK_FOVValue == nil then _G.Mod_SDK_FOVValue = 120 end

    local valTxt = nil
    pcall(function()
        valTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", rc)
        if valTxt and sluaIsValid(valTxt) then
            valTxt:SetText(tostring(_G.Mod_SDK_FOVValue))
            if valTxt.Font then local f = valTxt.Font f.Size = 16 valTxt.Font = f end
            if FSlateColor then valTxt:SetColorAndOpacity(FSlateColor(MC.white)) else valTxt:SetColorAndOpacity(MC.white) end
            valTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = rc:AddChildToCanvas(valTxt)
            if s then s:SetAutoSize(true) s:SetAlignment(FVector2D(0.5, 0.5)) s:SetPosition(FVector2D(ROW_W - 90, ROW_H * 0.5)) s:SetZOrder(100) end
        end
    end)

    local function step(delta)
        local v = (tonumber(_G.Mod_SDK_FOVValue) or 120) + delta
        if v < 80 then v = 80 end
        if v > 140 then v = 140 end
        _G.Mod_SDK_FOVValue = v
        WideViewModule.TargetFOV = v
        if valTxt and sluaIsValid(valTxt) then
            valTxt:SetText(tostring(v))
        end
        WideViewModule.SetFOV(v)
        print("[WIDEVIEW] step delta=" .. tostring(delta) .. " newFOV=" .. tostring(v))
        if SaveSystem and SaveSystem.AutoSave then pcall(SaveSystem.AutoSave) end
    end

    MLayer(rc, ROW_W - 160, (ROW_H - 30) * 0.5, 30, 30, MC.tab_inactive_bg, 200)
    MText(rc, "-", ROW_W - 160 + 15, ROW_H * 0.5, 20, MC.white, 500, 0.5, 0.5)
    MBtn(rc, ROW_W - 160, (ROW_H - 30) * 0.5, 30, 30, 910, function() step(-5) end)

    MLayer(rc, ROW_W - 45, (ROW_H - 30) * 0.5, 30, 30, MC.tab_inactive_bg, 200)
    MText(rc, "+", ROW_W - 45 + 15, ROW_H * 0.5, 20, MC.white, 500, 0.5, 0.5)
    MBtn(rc, ROW_W - 45, (ROW_H - 30) * 0.5, 30, 30, 910, function() step(5) end)
end

local function MakeToggleRow(vbox, label, toggleKey)
    -- Config → _G সিঙ্ক (মেনু তৈরি হওয়ার আগে)
    if Config then
        if toggleKey == "Mod_MISC_Global" then _G[toggleKey] = Config.ESPGlobal_Enabled or false
        elseif toggleKey == "Mod_ESP_Counter" then _G[toggleKey] = Config.EnemyCounter_Enabled or false
        elseif toggleKey == "Mod_ESP_Line" then _G[toggleKey] = Config.SnapLine_Enabled or false
        elseif toggleKey == "Mod_ESP_Box" then _G[toggleKey] = Config.BoxESP_Enabled or false
        elseif toggleKey == "Mod_ESP_Health" then _G[toggleKey] = Config.HealthBar_Enabled or false
        elseif toggleKey == "Mod_ESP_Name" then _G[toggleKey] = Config.ShowName_Enabled or false
        elseif toggleKey == "Mod_ESP_Skeleton" then _G[toggleKey] = Config.Skeleton_Enabled or false
        elseif toggleKey == "Mod_ESP_Distance" then _G[toggleKey] = Config.ShowDistance_Enabled or false
        elseif toggleKey == "Mod_ESP_Wallhack" then _G[toggleKey] = (CheatConfig.Wallhack and CheatConfig.Wallhack.Enabled) or false
        elseif toggleKey == "Mod_MAGIC_Enabled" then _G[toggleKey] = Config.MagicBullet_Enabled or false
        elseif toggleKey == "Mod_ESP_Weapon" then _G[toggleKey] = _G.ESP and _G.ESP.WEAPON or false
        elseif toggleKey == "Mod_ESP_Flag" then _G[toggleKey] = _G.ESP and _G.ESP.FLAG or false
        elseif toggleKey == "Mod_ESP_State" then _G[toggleKey] = _G.ESP and _G.ESP.STATE or false
        elseif toggleKey == "Mod_SDK_WideView" then _G[toggleKey] = Config.WideView_Enabled or false
        elseif toggleKey == "Mod_SDK_Crosshair" then _G[toggleKey] = Config.Crosshair_Enabled or false
        elseif toggleKey == "Mod_SDK_NewWH" then _G[toggleKey] = Config.NewWallhack_Enabled or false
        elseif toggleKey == "Mod_SDK_165FPS" then _G[toggleKey] = Config.FPS165_Enabled or false
        elseif toggleKey == "Mod_SDK_BlackSky" then _G[toggleKey] = Config.BlackSky_Enabled or false
        end
    end

    if _G[toggleKey] == nil then _G[toggleKey] = false end
    local ROW_W = M_W - CONTENT_PAD * 2
    local SW_W, SW_H, KNOB_SZ, PAD = 62, 32, 26, 3
    local kOFF, kON = PAD, SW_W - KNOB_SZ - PAD
    local outer = nil
    pcall(function()
        outer = CGame:NewObjectFromPath("/Script/UMG.Border", vbox)
        if outer and sluaIsValid(outer) then
            outer:SetBrushColor(MC.bg_row)
            outer:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
            local s = vbox:AddChildToVerticalBox(outer)
            if s then
                s:SetPadding(FMargin(0, 0, 0, ROW_GAP))
                if s.SetHeightOverride then s:SetHeightOverride(ROW_H) end
                if s.SetHorizontalAlignment then s:SetHorizontalAlignment(UEnums.EHorizontalAlignment.HAlign_Fill) end
            end
        end
    end)
    if not outer then return end
    local rc = nil
    pcall(function()
        rc = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", outer)
        if rc and sluaIsValid(rc) then outer:AddChild(rc) end
    end)
    if not rc then return end
    pcall(function()
        local l = CGame:NewObjectFromPath("/Script/UMG.TextBlock", rc)
        if l and sluaIsValid(l) then
            l:SetText(label)
            if l.Font then local f = l.Font f.Size = 16 l.Font = f end
            if FSlateColor then l:SetColorAndOpacity(FSlateColor(MC.text_label)) else l:SetColorAndOpacity(MC.text_label) end
            l:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = rc:AddChildToCanvas(l)
            if s then s:SetAutoSize(true) s:SetAlignment(FVector2D(0, 0.5)) s:SetPosition(FVector2D(18, ROW_H * 0.5)) s:SetZOrder(100) end
        end
    end)
    local swX = ROW_W - SW_W - 15
    local swY = (ROW_H - SW_H) * 0.5
    local track = nil
    pcall(function()
        track = CGame:NewObjectFromPath("/Script/UMG.Border", rc)
        if track and sluaIsValid(track) then
            track:SetBrushColor(_G[toggleKey] and MC.switch_on_bg or MC.switch_off_bg)
            track:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = rc:AddChildToCanvas(track)
            if s then s:SetAutoSize(false) s:SetPosition(FVector2D(swX, swY)) s:SetSize(FVector2D(SW_W, SW_H)) s:SetZOrder(200) end
        end
    end)
    local knob, kSlot = nil, nil
    pcall(function()
        knob = CGame:NewObjectFromPath("/Script/UMG.Border", rc)
        if knob and sluaIsValid(knob) then
            knob:SetBrushColor(MC.switch_knob)
            knob:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            kSlot = rc:AddChildToCanvas(knob)
            if kSlot then
                kSlot:SetAutoSize(false)
                local sx = _G[toggleKey] and kON or kOFF
                kSlot:SetPosition(FVector2D(swX + sx, swY + PAD))
                kSlot:SetSize(FVector2D(KNOB_SZ, KNOB_SZ))
                kSlot:SetZOrder(300)
            end
        end
    end)
    pcall(function()
        local b = CGame:NewObjectFromPath("/Script/UMG.Button", rc)
        if b and sluaIsValid(b) then
            b:SetColorAndOpacity(MC.transparent)
            b:SetBackgroundColor(MC.transparent)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
            local s = rc:AddChildToCanvas(b)
            if s then s:SetAutoSize(false) s:SetPosition(FVector2D(swX - 10, swY - 5)) s:SetSize(FVector2D(SW_W + 20, SW_H + 10)) s:SetZOrder(900) end
            local function doT()
                _G[toggleKey] = not _G[toggleKey]
                local on = _G[toggleKey]
                if track and sluaIsValid(track) then
                    pcall(function() track:SetBrushColor(on and MC.switch_on_bg or MC.switch_off_bg) end)
                end
                if kSlot and kSlot.SetPosition then
                    local nx = on and kON or kOFF
                    pcall(function() kSlot:SetPosition(FVector2D(swX + nx, swY + PAD)) end)
                end
                pcall(SyncToggleToConfig, toggleKey, on)
            end
            if b.OnClicked then b.OnClicked:Add(doT) end
        end
    end)
    toggleRows[toggleKey] = { key = toggleKey }
end

local function CreateTabScrollBoxes(parentPanel, contentY, contentH)
    local map = {}
    for _, tab in ipairs(MENU_TABS) do
        local wrapper = nil
        pcall(function()
            wrapper = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", parentPanel)
            if wrapper and sluaIsValid(wrapper) then
                local s = parentPanel:AddChildToCanvas(wrapper)
                if s then
                    s:SetAutoSize(false)
                    s:SetPosition(FVector2D(CONTENT_PAD, contentY))
                    s:SetSize(FVector2D(M_W - CONTENT_PAD * 2, contentH))
                    s:SetZOrder(10)
                end
                wrapper:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end
        end)
        if wrapper then
            local scroll = nil
            pcall(function()
                scroll = CGame:NewObjectFromPath("/Script/UMG.ScrollBox", wrapper)
                if scroll and sluaIsValid(scroll) then
                    local s = wrapper:AddChildToCanvas(scroll)
                    if s then s:SetAutoSize(false) s:SetPosition(FVector2D(0, 0)) s:SetSize(FVector2D(M_W - CONTENT_PAD * 2, contentH)) end
                    scroll:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
                end
            end)
            local vbox = nil
            pcall(function()
                vbox = CGame:NewObjectFromPath("/Script/UMG.VerticalBox", scroll)
                if vbox and sluaIsValid(vbox) then
                    scroll:AddChild(vbox)
                    vbox:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
            end)
            map[tab.id] = { scroll = wrapper, vbox = vbox }
            if vbox and tab.options then
                if tab.id == "SDK" then
                    MakeFOVRow(vbox)
                end
                for _, opt in ipairs(tab.options) do
                    MakeToggleRow(vbox, opt.label, opt.key)
                end
            end
        end
    end
    return map
end

local SwitchTab
SwitchTab = function(tid)
    activeTab = tid
    for id, s in pairs(tabScrolls) do
        if s.scroll and sluaIsValid(s.scroll) then
            s.scroll:SetWidgetVisibility(id == tid and UEnums.ESlateVisibility.Visible or UEnums.ESlateVisibility.Collapsed)
        end
    end
    for id, d in pairs(tabButtons) do
        local on = (id == tid)
        if d.bg and sluaIsValid(d.bg) then d.bg:SetBrushColor(on and MC.tab_active_bg or MC.tab_inactive_bg) end
        if d.label and sluaIsValid(d.label) then
            local c = on and MC.tab_active_text or MC.tab_inactive_text
            pcall(function()
                if FSlateColor then d.label:SetColorAndOpacity(FSlateColor(c)) else d.label:SetColorAndOpacity(c) end
            end)
        end
        if d.indicator and sluaIsValid(d.indicator) then
            d.indicator:SetWidgetVisibility(on and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end
    end
end

local function MakeTabButton(parent, tid, title, x, y, w, h)
    local d = {}
    d.bg = MLayer(parent, x, y, w, h, MC.tab_inactive_bg, 3)
    MLayer(parent, x, y, w, 2, FLinearColor(0.4, 0.1, 0.15, 0.8), 4)
    MLayer(parent, x, y + h - 2, w, 2, FLinearColor(0, 0, 0, 0.6), 4)
    d.indicator = MLayer(parent, x + 6, y + h - 3, w - 12, 3, MC.tab_indicator, 6)
    if d.indicator and sluaIsValid(d.indicator) then
        d.indicator:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    end
    d.label = MText(parent, title, x + w * 0.5, y + h * 0.5, 15, MC.tab_inactive_text, 500, 0.5, 0.5)
    d.btn = MBtn(parent, x, y, w, h, 910, function() SwitchTab(tid) end)
    tabButtons[tid] = d
    return d
end

_G.MRMenu_Reset = function()
    print("[MRMENU] Reset triggered")
    local ks = {"Mod_MISC_Global", "Mod_ESP_Counter", "Mod_ESP_Line",
        "Mod_ESP_Box", "Mod_ESP_Health", "Mod_ESP_Name", "Mod_ESP_Skeleton",
        "Mod_ESP_Distance", "Mod_ESP_Wallhack", "Mod_MAGIC_Enabled",
        "Mod_ESP_Weapon", "Mod_ESP_Flag", "Mod_ESP_State",
        "Mod_SDK_WideView", "Mod_SDK_Crosshair", "Mod_SDK_NewWH",
        "Mod_SDK_165FPS", "Mod_SDK_BlackSky"}
    for i = 1, #ks do _G[ks[i]] = false end
    if Config then
        Config.ESPGlobal_Enabled = false
        Config.ESP_Enabled = false
        Config.BoxESP_Enabled = false
        Config.SnapLine_Enabled = false
        Config.EnemyCounter_Enabled = false
        Config.Title_Enabled = true
        Config.HealthBar_Enabled = false
        Config.ShowName_Enabled = false
        Config.ShowDistance_Enabled = false
        Config.Skeleton_Enabled = false
        Config.MagicBullet_Enabled = false
        Config.WideView_Enabled = false
        Config.Crosshair_Enabled = false
        Config.NewWallhack_Enabled = false
        Config.FPS165_Enabled = false
        Config.BlackSky_Enabled = false
    end
    if CheatConfig then
        if CheatConfig.Wallhack then CheatConfig.Wallhack.Enabled = false end
        if CheatConfig.MagicBullet then CheatConfig.MagicBullet.Enabled = false end
        if CheatConfig.HealthBar then CheatConfig.HealthBar.Enabled = false end
    end
    if SkeletonConfig then SkeletonConfig.Enabled = false end
    if _G.ESP then
        _G.ESP.WEAPON = false
        _G.ESP.FLAG = false
        _G.ESP.STATE = false
    end
    _G.Mod_SDK_FOVValue = 120
    pcall(function() if PlayerMapMarker and PlayerMapMarker.ClearAllSnapLines then PlayerMapMarker.ClearAllSnapLines() end end)
    pcall(function()
        if BoxESP and BoxESP.BoxWidgets then
            for _, bd in pairs(BoxESP.BoxWidgets) do
                if bd then
                    local col = UEnums.ESlateVisibility.Collapsed
                    local list = {bd.CornerContainer, bd.NameWidget, bd.DistWidget, bd.BgWidget,
                                  bd.HealthWidget, bd.WeaponWidget, bd.FlagWidget, bd.StateWidget}
                    for i = 1, #list do
                        if list[i] and IsValid(list[i]) then list[i]:SetWidgetVisibility(col) end
                    end
                end
            end
        end
    end)
    pcall(function() if SkeletonModule and SkeletonModule.DestroyAll then SkeletonModule.DestroyAll() end end)
    pcall(RestoreMagicBullet)
    pcall(RestoreWallhack)
    pcall(function() if _G._pbc_Cleanup then _G._pbc_Cleanup() end end)
    pcall(Disable165FPS)
    pcall(BlackSkyModule.Reset)
    pcall(function() if SaveSystem and SaveSystem.Reset then SaveSystem.Reset() end end)
    if bgPanel and sluaIsValid(bgPanel) then
        bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        menuBuilt = false
        bgPanel = nil
        tabScrolls = {}
        tabButtons = {}
        toggleRows = {}
        isMenuOpen = false
    end
    Notify("[MRMOD] Settings Reset!")
end

local function BuildMenu()
    if menuBuilt and bgPanel and sluaIsValid(bgPanel) then
        bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        SwitchTab(activeTab)
        return
    end
    local canvas = GetMenuCanvas()
    if not canvas then return end
    pcall(function()
        bgPanel = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas)
        if bgPanel and sluaIsValid(bgPanel) then
            local s = canvas:AddChildToCanvas(bgPanel)
            if s then
                s:SetAutoSize(false)
                s:SetZOrder(10000)
                s:SetAnchors(FAnchors(1, 0, 1, 0))
                s:SetAlignment(FVector2D(1, 0))
                s:SetPosition(FVector2D(-20, 50))
                s:SetSize(FVector2D(M_W, M_H))
            end
        end
    end)
    if not bgPanel then return end

    MLayer(bgPanel, 6, 6, M_W, M_H, FLinearColor(0, 0, 0, 0.55), 0)
    MLayer(bgPanel, 3, 3, M_W, M_H, FLinearColor(0, 0, 0, 0.35), 0)

    MLayer(bgPanel, 0, 0, M_W, M_H, MC.bg_main, 1)
    MLayer(bgPanel, 0, 0, M_W, HEADER_H, MC.bg_header, 2)
    MLayer(bgPanel, 0, HEADER_H - 2, M_W, 2, MC.blue_accent, 7)

    local BTN_SIZE  = 50
    local BTN_PAD   = 8
    local BTN_Y     = (HEADER_H - BTN_SIZE) * 0.5

    local resetX = BTN_PAD
    local resetY = BTN_Y
    MLayer(bgPanel, resetX + 3, resetY + 3, BTN_SIZE, BTN_SIZE,
        FLinearColor(0, 0, 0, 0.6), 4)
    MLayer(bgPanel, resetX, resetY, BTN_SIZE, BTN_SIZE,
        FLinearColor(0.90, 0.15, 0.20, 1.0), 5)
    MLayer(bgPanel, resetX, resetY, BTN_SIZE, 3,
        FLinearColor(1.0, 0.4, 0.45, 0.6), 6)
    MText(bgPanel, "R", resetX + BTN_SIZE * 0.5, resetY + BTN_SIZE * 0.5,
        22, MC.white, 500, 0.5, 0.5)
    MBtn(bgPanel, resetX, resetY, BTN_SIZE, BTN_SIZE, 910, function()
        pcall(function()
            local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
                or require("client.slua.logic.common.logic_common_msg_box")
            if Msg and type(Msg.Show) == "function" then
                Msg.Show(3, "RESET", "Reset all features?",
                    function(ok) if ok and _G.MRMenu_Reset then pcall(_G.MRMenu_Reset) end end)
                return
            end
        end)
        if _G.MRMenu_Reset then pcall(_G.MRMenu_Reset) end
    end)

    local closeX = M_W - BTN_PAD - BTN_SIZE
    local closeY = BTN_Y
    MLayer(bgPanel, closeX + 3, closeY + 3, BTN_SIZE, BTN_SIZE,
        FLinearColor(0, 0, 0, 0.6), 4)
    MLayer(bgPanel, closeX, closeY, BTN_SIZE, BTN_SIZE,
        FLinearColor(0.65, 0.08, 0.15, 1.0), 5)
    MLayer(bgPanel, closeX, closeY, BTN_SIZE, 3,
        FLinearColor(1.0, 0.35, 0.40, 0.5), 6)
    MText(bgPanel, "X", closeX + BTN_SIZE * 0.5, closeY + BTN_SIZE * 0.5,
        22, MC.white, 500, 0.5, 0.5)
    MBtn(bgPanel, closeX, closeY, BTN_SIZE, BTN_SIZE, 900, function()
        isMenuOpen = false
        bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    end)

    local titleX = M_W * 0.5
    local titleY = HEADER_H * 0.5
    MText(bgPanel, "MR VIP MENU", titleX + 2, titleY + 2,
        26, FLinearColor(0, 0, 0, 0.9), 499, 0.5, 0.5)
    local titleWidget = MText(bgPanel, "MR VIP MENU", titleX, titleY,
        26, FLinearColor(1.0, 0.92, 0.60, 1.0), 500, 0.5, 0.5)
    if titleWidget and sluaIsValid(titleWidget) then
        pcall(function()
            if titleWidget.Font then
                local f = titleWidget.Font
                f.Size = 26
                f.TypefaceFontName = "Bold"
                if titleWidget.SetFont then titleWidget:SetFont(f) else titleWidget.Font = f end
            end
        end)
    end

    MLayer(bgPanel, 0, HEADER_H, M_W, TABBAR_H, MC.bg_tabbar, 2)
    local tg = 5
    local tw = (M_W - tg * (#MENU_TABS + 1)) / #MENU_TABS
    for i, tab in ipairs(MENU_TABS) do
        local tx = tg + (i - 1) * (tw + tg)
        MakeTabButton(bgPanel, tab.id, tab.title, tx, HEADER_H, tw, TABBAR_H)
    end
    MLayer(bgPanel, 0, HEADER_H + TABBAR_H - 2, M_W, 2, MC.green_active, 7)

    local cY2 = HEADER_H + TABBAR_H + CONTENT_PAD
    local cH = M_H - cY2 - CONTENT_PAD - FOOTER_H
    MLayer(bgPanel, CONTENT_PAD, cY2, M_W - CONTENT_PAD * 2, cH, MC.bg_scroll, 8)
    tabScrolls = CreateTabScrollBoxes(bgPanel, cY2, cH)

    local fY = M_H - FOOTER_H
    MLayer(bgPanel, 0, fY, M_W, FOOTER_H, MC.bg_header, 3)
    MLayer(bgPanel, 0, fY, M_W, 2, MC.blue_accent, 7)
    MText(bgPanel, "v4.4 • @mr_ownerX • ACTIVE", M_W * 0.5, fY + FOOTER_H * 0.5, 12, MC.text_dim, 100, 0.5, 0.5)

    menuBuilt = true
    isMenuOpen = true
    SwitchTab(activeTab)
end

_G.MRMenu_Toggle = function()
    if not menuCanvas or not Game:IsValid(menuCanvas) then
        if InGameUITools then
            local M = InGameUITools.GetMainControlBaseUI()
            if M and Game:IsValid(M) then menuCanvas = M.CanvasPanel_0 or M.CanvasPanel_42 end
        end
    end
    if not menuCanvas then return end
    if bgPanel and sluaIsValid(bgPanel) then
        if isMenuOpen then
            bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            isMenuOpen = false
        else
            bgPanel:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            isMenuOpen = true
        end
    else
        BuildMenu()
    end
end

-- ==========================================
-- FLOATING BUTTON
-- ==========================================
function FloatingMenu.CreateButton()
    if IsValid(FloatingMenu.MasterButton) then return end
    SafeCall(function()
        local T = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not T then return end
        local M = T.GetMainControlBaseUI()
        if not IsValid(M) then return end
        local P = M.CanvasPanel_0 or M.CanvasPanel_42
        if not IsValid(P) then return end
        local cfg = FloatingMenu.Config
        local ox = (cfg.SizeImage.X - cfg.SizeBg.X) / 2
        local oy = (cfg.SizeImage.Y - cfg.SizeBg.Y) / 2

        local MI = CGame:NewObjectFromPath("/Script/UMG.Image", P)
        if IsValid(MI) then
            MI:SetWidgetVisibility(FloatingMenu.MasterButtonShow and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
            if MI.SetColorAndOpacity then MI:SetColorAndOpacity(FLinearColor(1,1,1,1)) end
            local s = P:AddChildToCanvas(MI)
            if s then
                s:SetAutoSize(false) s:SetSize(cfg.SizeImage)
                s:SetPosition(FVector2D(cfg.MasterPos.X - ox, cfg.MasterPos.Y - oy))
                s:SetZOrder(10000)
            end
            FloatingMenu.MasterImage = MI
        end
        local MB = CGame:NewObjectFromPath("/Script/UMG.Button", P)
        if IsValid(MB) then
            pcall(function()
                local st = MB:GetStyle()
                if st then
                    local T2 = FLinearColor(0,0,0,0)
                    if st.Normal and st.Normal.TintColor then st.Normal.TintColor = T2 end
                    if st.Hovered and st.Hovered.TintColor then st.Hovered.TintColor = T2 end
                    if st.Pressed and st.Pressed.TintColor then st.Pressed.TintColor = T2 end
                    MB:SetStyle(st)
                end
            end)
            local s = P:AddChildToCanvas(MB)
            if s then
                s:SetAutoSize(false) s:SetSize(cfg.SizeBg)
                s:SetPosition(FVector2D(cfg.MasterPos.X, cfg.MasterPos.Y))
                s:SetZOrder(9999)
            end
            MB:SetWidgetVisibility(FloatingMenu.MasterButtonShow and UEnums.ESlateVisibility.Visible or UEnums.ESlateVisibility.Collapsed)
            MB.OnClicked:Add(function() if _G.MRMenu_Toggle then pcall(_G.MRMenu_Toggle) end end)
            FloatingMenu.MasterButton = MB
        end
        LoadFloatingTexture("https://i.postimg.cc/XYYYRQFC/Mr-Logo.png", function(tex)
            if IsValid(FloatingMenu.MasterImage) then
                FloatingMenu.MasterImage:SetBrushFromTexture(tex, false)
            end
        end)
    end)
end

-- ==========================================
-- STARTUP / TIMERS
-- ==========================================
local _ActivePC = nil

local function StartAll()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if IsValid(pc) and pc ~= _ActivePC then
            _ActivePC = pc
            PlayerMapMarker.Start()
            FloatingMenu.CreateButton()
            StartWallhackTimer()
            Apply165FPSInGame()
        end
    end)
end

pcall(function()
    StartAll()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if IsValid(pc) then pc:AddGameTimer(1.0, true, StartAll) end
    end
end)

-- Combined tick: BoxESP + WideView + BlackSky (force reapply প্রতি 2s)
pcall(function()
    local PC = nil
    if slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
        PC = slua_GameFrontendHUD:GetPlayerController()
    end
    if not IsValid(PC) then
        local GDP = require("GameLua.GameCore.Data.GameplayData")
        if GDP and GDP.GetPlayerController then PC = GDP:GetPlayerController() end
    end

    local _bskyReapplyAcc = 0
    local function CombinedTick()
        pcall(BoxESP.UpdateESP)
        pcall(WideViewCrosshairTick)
        if Config.BlackSky_Enabled then
            _bskyReapplyAcc = _bskyReapplyAcc + 1
            if _bskyReapplyAcc >= 60 then -- প্রতি ~2 সেকেন্ড
                _bskyReapplyAcc = 0
                pcall(BlackSkyModule.ForceReapply)
            else
                pcall(BlackSkyModule.Apply)
            end
        end
    end

    if IsValid(PC) and PC.AddGameTimer then
        PC:AddGameTimer(0.03, true, CombinedTick)
    else
        require("timer").SetGameTimer(0.03, true, CombinedTick)
    end
end)

-- Magic Bullet timer
pcall(function()
    local function StartMagicTimer()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if sluaIsValid(pc) and pc.AddGameTimer then
            local iv = CheatConfig.MagicBullet.UpdateInterval or 1.0
            pc:AddGameTimer(iv, true, function()
                if CheatConfig.MagicBullet.Enabled then pcall(ApplyMagicBullet) end
            end)
        else
            require("timer").SetGameTimer(1.0, false, StartMagicTimer)
        end
    end
    StartMagicTimer()
end)

-- ==========================================
-- STARTUP: সেভ লোড + autosave timer
-- ==========================================
pcall(function()
    SaveSystem.Load()
    SaveSystem.ApplyLoadedFeatures()
end)

pcall(function()
    local function doAutoSave() pcall(SaveSystem.AutoSave) end
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if IsValid(pc) and pc.AddGameTimer then
        pc:AddGameTimer(3.0, true, doAutoSave)
    else
        require("timer").SetGameTimer(3.0, true, doAutoSave)
    end
end)

--============================================
--End Function
--=============================================
