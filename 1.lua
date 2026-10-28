local local_os_clock = os.clock
local local_math_sqrt = math.sqrt
local local_math_max = math.max
local local_math_min = math.min
local local_math_floor = math.floor
local local_tostring = tostring
local local_math_atan = math.atan
local local_math_atan2 = math.atan2
local local_math_pi = math.pi

local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local FVector2D = nil
local FVector = nil
local FLinearColor = nil
local FSlateColor = nil

pcall(function()
    SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
    WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")
    FVector2D = import("Vector2D")
    FVector = import("Vector")
    FLinearColor = import("LinearColor")
    FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
end)

local function IsValid(obj)
    if not obj then return false end
    if slua and slua.isValid then
        return slua.isValid(obj)
    end
    return true
end

local TempProjVec2D = FVector2D and FVector2D(0, 0) or nil

-- ========== Base Colors ==========
local ColorWhite      = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or nil
local ColorCrimson    = FLinearColor and FLinearColor(1.0, 0.15, 0.3, 1.0) or nil
local ColorGold       = FLinearColor and FLinearColor(1.0, 0.85, 0.15, 1.0) or nil
local ColorNeonCyan   = FLinearColor and FLinearColor(0.0, 0.85, 1.0, 1.0) or nil
local ColorHealthBg   = FLinearColor and FLinearColor(0.05, 0.05, 0.05, 0.9) or nil

-- ========== Real Player vs Bot Color Palette ==========
local ColorRealVisible = FLinearColor and FLinearColor(0.0, 0.85, 1.0, 1.0) or nil
local ColorRealHidden  = FLinearColor and FLinearColor(1.0, 0.0, 1.0, 1.0) or nil
local ColorBotVisible  = FLinearColor and FLinearColor(1.0, 0.85, 0.15, 1.0) or nil
local ColorBotHidden   = FLinearColor and FLinearColor(1.0, 0.45, 0.0, 1.0) or nil

local SlateColorCrimson     = (FSlateColor and ColorCrimson) and FSlateColor(ColorCrimson) or ColorCrimson
local SlateColorRealVisible = (FSlateColor and ColorRealVisible) and FSlateColor(ColorRealVisible) or ColorRealVisible
local SlateColorRealHidden  = (FSlateColor and ColorRealHidden) and FSlateColor(ColorRealHidden) or ColorRealHidden
local SlateColorBotVisible  = (FSlateColor and ColorBotVisible) and FSlateColor(ColorBotVisible) or ColorBotVisible
local SlateColorBotHidden   = (FSlateColor and ColorBotHidden) and FSlateColor(ColorBotHidden) or ColorBotHidden

-- ========== Enemy Counter Image Loader ==========
local ENEMY_COUNTER_PLAYER_URLS = {
    "https://i.postimg.cc/Y0BscTvV/ic-danger-enemy.png",
}
local ENEMY_COUNTER_BOT_URLS = {
    "https://i.postimg.cc/qqH5fWN5/ic-danger-boot.png",
}

local EnemyCounterTextureCache = {}
local BADGE_WIDTH = 48
local BADGE_HEIGHT = 22

local function FileExists(path)
    if not path or path == "" then return false end
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function GetPossibleLocalPaths(filename)
    return {
        "/storage/emulated/0/Android/data/com.tencent.ig/files/" .. filename,
        "/storage/emulated/0/Android/data/com.pubg.krmobile/files/" .. filename,
        "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/" .. filename,
        "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/" .. filename,
        "/storage/emulated/0/Android/data/com.tencent.tmgp.pubgmhd/files/" .. filename,
        filename
    }
end

local function LoadBadgeTexture(imgWidget, urls, filename, typeKey, counterData)
    if not imgWidget or not IsValid(imgWidget) then return end

    if EnemyCounterTextureCache[typeKey] and IsValid(EnemyCounterTextureCache[typeKey]) then
        pcall(function()
            imgWidget:SetBrushFromTexture(EnemyCounterTextureCache[typeKey], false)
            imgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        if counterData then
            if typeKey == "Player" then counterData.PlayerLoaded = true end
            if typeKey == "Bot" then counterData.BotLoaded = true end
        end
        return
    end

    local function applyTex(tex)
        if tex and IsValid(tex) and IsValid(imgWidget) then
            EnemyCounterTextureCache[typeKey] = tex
            if counterData then
                if typeKey == "Player" then counterData.PlayerLoaded = true end
                if typeKey == "Bot" then counterData.BotLoaded = true end
            end
            pcall(function()
                imgWidget:SetBrushFromTexture(tex, false)
                imgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            return true
        end
        return false
    end

    local localPaths = GetPossibleLocalPaths(filename)
    for _, localPath in ipairs(localPaths) do
        if FileExists(localPath) then
            local tex = nil
            pcall(function()
                local asset_util = package.loaded["common.asset_util"] or require("common.asset_util")
                if asset_util and asset_util.GetAssetSync then tex = asset_util.GetAssetSync(localPath) end
            end)
            if not tex then
                pcall(function() if CGame and CGame.LoadObject then tex = CGame:LoadObject(localPath) end end)
            end
            if tex and applyTex(tex) then return end
        end
    end

    local function tryDownloadUrl(urlIndex)
        if urlIndex > #urls then return end
        local url = urls[urlIndex]
        local bDownloaded = false

        pcall(function()
            local AsyncTaskDownloadImage = import("AsyncTaskDownloadImage") or import("/Script/UMG.AsyncTaskDownloadImage")
            if AsyncTaskDownloadImage and AsyncTaskDownloadImage.DownloadImage then
                local task = AsyncTaskDownloadImage.DownloadImage(url)
                if task and task.OnSuccess then
                    task.OnSuccess:Add(function(tex)
                        if not bDownloaded and tex then
                            bDownloaded = true
                            applyTex(tex)
                        end
                    end)
                    if task.OnFail then
                        task.OnFail:Add(function()
                            if not bDownloaded then tryDownloadUrl(urlIndex + 1) end
                        end)
                    end
                end
            end
        end)

        if not bDownloaded then
            pcall(function()
                local mm = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                if not mm then pcall(function() mm = require("GameLua.GameCore.Module.ModuleManager") end) end
                local imgMgr = nil
                if mm and mm.GetModule and mm.CommonModuleConfig then
                    imgMgr = mm.GetModule(mm.CommonModuleConfig.image_download_mgr)
                end
                if not imgMgr then pcall(function() imgMgr = require("client.slua.logic.image_download.image_download_mgr") end) end
                if imgMgr and imgMgr.DownloadImageByHttpWrapper then
                    imgMgr:DownloadImageByHttpWrapper(url, function(tex)
                        if not bDownloaded and tex then bDownloaded = true; applyTex(tex) end
                    end, function()
                        if not bDownloaded then tryDownloadUrl(urlIndex + 1) end
                    end)
                end
            end)
        end

        if not bDownloaded then
            pcall(function()
                local util = package.loaded["client.slua_ui_framework.util"]
                if not util then pcall(function() util = require("client.slua_ui_framework.util") end) end
                if util and util.SetTexture then
                    util.SetTexture(imgWidget, url, {
                        sync = false,
                        onDownloadSuccess = function(tex)
                            if not bDownloaded and tex then bDownloaded = true; applyTex(tex) end
                        end
                    })
                end
            end)
        end
    end

    tryDownloadUrl(1)
end

-- ============================================================================
-- SKELETON MODULE (added)
-- ============================================================================
local SkeletonModule = {
    BoneThickness = 1.0,
    Lines = {},
    BoneAliases = {
        head = {"head", "b_head", "Head"},
        neck = {"neck_01", "b_neck", "Neck"},
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
        {"neck", "head"},
        {"pelvis", "neck"},
        {"upperarm_l", "neck"}, {"lowerarm_l", "upperarm_l"}, {"hand_l", "lowerarm_l"},
        {"upperarm_r", "neck"}, {"lowerarm_r", "upperarm_r"}, {"hand_r", "lowerarm_r"},
        {"thigh_r", "thigh_l"},
        {"calf_l", "thigh_l"}, {"foot_l", "calf_l"},
        {"calf_r", "thigh_r"}, {"foot_r", "calf_r"},
    }
}

-- Precompute bone key list once
local BoneKeyList = {}
local BoneAliasCache = {}
for k, v in pairs(SkeletonModule.BoneAliases) do
    BoneKeyList[#BoneKeyList + 1] = k
    BoneAliasCache[#BoneAliasCache + 1] = v
end
local BoneKeyCount = #BoneKeyList

local function safe_atan2(y, x)
    if local_math_atan2 then return local_math_atan2(y, x) end
    if x > 0 then return local_math_atan(y / x)
    elseif x < 0 then return (y >= 0) and (local_math_atan(y / x) + local_math_pi) or (local_math_atan(y / x) - local_math_pi)
    else
        if y > 0 then return local_math_pi / 2
        elseif y < 0 then return -local_math_pi / 2
        else return 0 end
    end
end

function SkeletonModule.CreateBundle(ParentCanvas)
    local b = { lineDatas = {} }
    for i = 1, #SkeletonModule.SkeletonBones do
        local bo = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
        if bo and IsValid(bo) then
            bo:SetBrushColor(FLinearColor(1, 1, 1, 1))
            bo:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            bo:SetRenderTransformPivot(FVector2D(0.0, 0.5))
            local s = ParentCanvas:AddChildToCanvas(bo)
            if s then
                s:SetAutoSize(false)
                s:SetZOrder(1002)
            end
            b.lineDatas[i] = { Widget = bo, Slot = s, bVisible = true, _lastColor = nil }
        end
    end
    return b
end

function SkeletonModule.HideSkeleton(k)
    local sk = SkeletonModule.Lines[k]
    if not sk then return end
    for i = 1, #sk.lineDatas do
        local ln = sk.lineDatas[i]
        if ln and ln.Widget and IsValid(ln.Widget) and ln.bVisible then
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
        if ln and ln.Widget and IsValid(ln.Widget) then
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
    for k, _ in pairs(SkeletonModule.Lines) do
        SkeletonModule.DestroySkeleton(k)
    end
    SkeletonModule.Lines = {}
end

function SkeletonModule.UpdateSkeleton(k, Pawn, PC, ParentCanvas, color, ProjFunc)
    local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
    if not mesh or not mesh.GetSocketLocation then
        SkeletonModule.HideSkeleton(k)
        return
    end
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

    local thickness = SkeletonModule.BoneThickness or 1.0
    local bones = SkeletonModule.SkeletonBones
    for i = 1, #bones do
        local pair = bones[i]
        local ck, pk = pair[1], pair[2]
        local c, p = pr[ck], pr[pk]
        local ln = sk.lineDatas[i]
        if c and p and ln and ln.Widget and IsValid(ln.Widget) then
            local dx = c.x - p.x
            local dy = c.y - p.y
            local len = local_math_sqrt(dx * dx + dy * dy)
            local a = safe_atan2(dy, dx) * (180.0 / local_math_pi)
            local t = thickness
            if not ln._pos then
                ln._pos = FVector2D(p.x, p.y - t * 0.5)
                ln._size = FVector2D(len, t)
            else
                ln._pos.X = p.x
                ln._pos.Y = p.y - t * 0.5
                ln._size.X = len
                ln._size.Y = t
            end
            pcall(function()
                ln.Slot:SetPosition(ln._pos)
                ln.Slot:SetSize(ln._size)
                ln.Widget:SetRenderAngle(a)
                if ln._lastColor ~= color then
                    ln.Widget:SetBrushColor(color or FLinearColor(1, 1, 1, 1))
                    ln._lastColor = color
                end
                if not ln.bVisible then
                    ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    ln.bVisible = true
                end
            end)
        else
            if ln and ln.Widget and IsValid(ln.Widget) and ln.bVisible then
                ln.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                ln.bVisible = false
            end
        end
    end
end
-- ============================================================================
-- END SKELETON MODULE
-- ============================================================================

-- ========== BoxESP Master Table ==========
local BoxESP = {
    bShowCounter   = true,
    bShowLines     = true,
    bShowBox       = true,
    bShowHealthBar = true,
    bShowName      = true,
    bShowDistance  = true,
    bShowWeapon    = true,
    bShowFlag      = true,
    bShowState     = true,
    bShowSkeleton  = true,  -- NEW

    ESPCanvas = nil,
    BoxWidgets = {},
    LineWidgets = {},
    Skeleton = SkeletonModule,  -- NEW: expose

    CounterData = {
        ImgPlayer = nil,
        SlotPlayer = nil,
        ImgBot = nil,
        SlotBot = nil,
        TxtPlayer = nil,
        SlotTxtPlayer = nil,
        TxtBot = nil,
        SlotTxtBot = nil,
        LastPlayerCount = -1,
        LastBotCount = -1,
        PlayerLoaded = false,
        BotLoaded = false,
        LastDownloadRetry = 0,
        bCreated = false
    },

    HealthColor = { R = 0.05, G = 1.0, B = 0.45, A = 1.0 },
    HealthBgColor = { R = 0.05, G = 0.05, B = 0.05, A = 0.9 },
    HealthBarWidth = 2.0,
    CornerColor = { R = 0.0, G = 0.85, B = 1.0, A = 1.0 },
    CornerThickness = 1.2,
    CornerLengthRatio = 0.28,
    SnapLineThickness = 3.0,
    SnapLineOriginY = 72,

    _CanvasScaleX = 1.0,
    _CanvasScaleY = 1.0,
    _CanvasOffsetX = 0.0,
    _CanvasOffsetY = 0.0,
    _LastCanvas = nil,
    _LastTransformTime = 0,
    _LastHeavyUpdateTime = 0,
    _LastVisCheckTime = 0,
    _VisCheckCache = {}
}

-- ========== Toggle ==========
function BoxESP.Toggle(feature)
    local map = {
        box     = "bShowBox",
        health  = "bShowHealthBar",
        name    = "bShowName",
        dist    = "bShowDistance",
        weapon  = "bShowWeapon",
        flag    = "bShowFlag",
        state   = "bShowState",
        lines   = "bShowLines",
        counter = "bShowCounter",
        skeleton = "bShowSkeleton",  -- NEW
    }
    local key = map[feature]
    if key then
        BoxESP[key] = not BoxESP[key]
        print("[BoxESP]", feature, "=", local_tostring(BoxESP[key]))

        -- Skeleton বন্ধ করলে সব hide
        if feature == "skeleton" and not BoxESP.bShowSkeleton then
            for KeyStr in pairs(SkeletonModule.Lines) do
                SkeletonModule.HideSkeleton(KeyStr)
            end
        end
    end
end

function BoxESP.GetMainCanvas()
    if BoxESP.ESPCanvas and IsValid(BoxESP.ESPCanvas) then
        return BoxESP.ESPCanvas
    end

    local InGameUITools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
    if not InGameUITools then
        pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    end
    if not InGameUITools then return nil end

    local MainUI = nil
    if InGameUITools.GetMainControlBaseUI then
        MainUI = InGameUITools.GetMainControlBaseUI()
    end
    if not IsValid(MainUI) then return nil end

    local ParentCanvas = nil
    if MainUI.CanvasPanel_0 and IsValid(MainUI.CanvasPanel_0) then
        ParentCanvas = MainUI.CanvasPanel_0
    elseif MainUI.CanvasPanel_42 and IsValid(MainUI.CanvasPanel_42) then
        ParentCanvas = MainUI.CanvasPanel_42
    end

    if ParentCanvas then
        BoxESP.ESPCanvas = ParentCanvas
        BoxESP._LastCanvas = ParentCanvas
    end
    return ParentCanvas
end

function BoxESP.CreateESPWidget(ParentCanvas)
    if not FLinearColor or not FVector2D then return nil end

    local CornerContainer = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
    if not IsValid(CornerContainer) then return nil end

    local CornerMainSlot = ParentCanvas:AddChildToCanvas(CornerContainer)
    if not CornerMainSlot then return nil end

    CornerMainSlot:SetAutoSize(false)
    CornerMainSlot:SetZOrder(995)
    CornerMainSlot:SetAlignment(FVector2D(0.5, 0.5))

    local cornerColorObj = FLinearColor(
        BoxESP.CornerColor.R,
        BoxESP.CornerColor.G,
        BoxESP.CornerColor.B,
        BoxESP.CornerColor.A
    )

    local function CreateBorderLine()
        local border = CGame:NewObjectFromPath("/Script/UMG.Border", CornerContainer)
        if border and IsValid(border) then
            border:SetBrushColor(cornerColorObj)
            border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local slot = CornerContainer:AddChildToCanvas(border)
            if slot then slot:SetAutoSize(false) end
            return { widget = border, slot = slot }
        end
        return nil
    end

    local CornerLines = {
        TopLeft_H = CreateBorderLine(),
        TopLeft_V = CreateBorderLine(),
        TopRight_H = CreateBorderLine(),
        TopRight_V = CreateBorderLine(),
        BottomLeft_H = CreateBorderLine(),
        BottomLeft_V = CreateBorderLine(),
        BottomRight_H = CreateBorderLine(),
        BottomRight_V = CreateBorderLine()
    }

    local BgImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not IsValid(BgImage) then return nil end
    BgImage:SetColorAndOpacity(ColorHealthBg)
    BgImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

    local BgSlot = ParentCanvas:AddChildToCanvas(BgImage)
    if not BgSlot then return nil end
    BgSlot:SetAutoSize(false)
    BgSlot:SetZOrder(998)
    BgSlot:SetAlignment(FVector2D(0.5, 1.0))

    local HealthImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not IsValid(HealthImage) then return nil end
    HealthImage:SetColorAndOpacity(ColorCrimson)
    HealthImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

    local HealthSlot = ParentCanvas:AddChildToCanvas(HealthImage)
    if not HealthSlot then return nil end
    HealthSlot:SetAutoSize(false)
    HealthSlot:SetZOrder(999)
    HealthSlot:SetAlignment(FVector2D(0.5, 1.0))

    local function CreateStyledTextBlock(defaultColor, fontSize, alignment)
        local txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
        local slot = nil
        if txt and IsValid(txt) then
            txt:SetText("")
            local intSize = local_math_floor(fontSize or 10)
            if txt.Font then
                local newFont = txt.Font
                newFont.Size = intSize
                if newFont.OutlineSettings then
                    newFont.OutlineSettings.OutlineSize = 1
                    newFont.OutlineSettings.OutlineColor = FLinearColor(0.0, 0.0, 0.0, 1.0)
                end
                if txt.SetFont then txt:SetFont(newFont) else txt.Font = newFont end
            end

            if txt.SetFontSize then txt:SetFontSize(intSize) end
            txt:SetJustification(1)
            if txt.SetHorizontalAlignment then txt:SetHorizontalAlignment(1) end
            if txt.SetVerticalAlignment then txt:SetVerticalAlignment(1) end
            if txt.SetAutoWrapText then txt:SetAutoWrapText(false) end

            if FSlateColor then
                txt:SetColorAndOpacity(FSlateColor(defaultColor))
            else
                txt:SetColorAndOpacity(defaultColor)
            end

            if txt.SetShadowOffset then txt:SetShadowOffset(FVector2D(0.0, 0.0)) end
            if txt.SetShadowColorAndOpacity then txt:SetShadowColorAndOpacity(FLinearColor(0.0, 0.0, 0.0, 0.0)) end
            txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

            slot = ParentCanvas:AddChildToCanvas(txt)
            if slot then
                slot:SetAutoSize(true)
                slot:SetZOrder(1000)
                slot:SetAlignment(alignment or FVector2D(0.5, 0.0))
            end
        end
        return txt, slot
    end

    local WeaponWidget, WeaponSlot = CreateStyledTextBlock(ColorGold, 10, FVector2D(0.5, 1.0))
    local NameWidget, NameSlot = CreateStyledTextBlock(ColorNeonCyan, 10, FVector2D(0.5, 0.0))
    local DistWidget, DistSlot = CreateStyledTextBlock(ColorWhite, 10, FVector2D(0.5, 0.0))
    local StateWidget, StateSlot = CreateStyledTextBlock(ColorRealVisible, 10, FVector2D(0.5, 0.0))

    local FlagImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    local FlagSlot = nil
    if FlagImage and IsValid(FlagImage) then
        FlagImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        FlagSlot = ParentCanvas:AddChildToCanvas(FlagImage)
        if FlagSlot then
            FlagSlot:SetAutoSize(false)
            FlagSlot:SetSize(FVector2D(14, 16))
            FlagSlot:SetZOrder(1000)
            FlagSlot:SetAlignment(FVector2D(0.5, 1.0))
        end
    end

    return {
        CornerContainer = CornerContainer,
        CornerSlot = CornerMainSlot,
        Corners = CornerLines,
        BgWidget = BgImage,
        BgSlot = BgSlot,
        HealthWidget = HealthImage,
        HealthSlot = HealthSlot,
        WeaponWidget = WeaponWidget,
        WeaponSlot = WeaponSlot,
        FlagWidget = FlagImage,
        FlagSlot = FlagSlot,
        NameWidget = NameWidget,
        NameSlot = NameSlot,
        DistWidget = DistWidget,
        DistSlot = DistSlot,
        StateWidget = StateWidget,
        StateSlot = StateSlot,
        _cachedWeapon = "",
        _cachedNation = nil,
        _cachedName = "",
        _cachedDist = "",
        _cachedState = "",
        _cachedBoxKey = nil,
        _lastScanTime = 0,
        lastW = 0,
        lastH = 0,
        bVisible = true
    }
end

-- ========== Corner Box Update (with Bot/Player color) ==========
function BoxESP.UpdateCornerDimensions(boxData, width, height, isBot, isVisible)
    local typeKey = (isBot and "B" or "P") .. (isVisible and "V" or "H")
    if boxData._cachedBoxKey ~= typeKey then
        local targetColor
        if isBot then
            targetColor = isVisible and ColorBotVisible or ColorBotHidden
        else
            targetColor = isVisible and ColorRealVisible or ColorRealHidden
        end

        for _, corner in pairs(boxData.Corners) do
            if corner and corner.widget and IsValid(corner.widget) then
                corner.widget:SetBrushColor(targetColor)
            end
        end
        boxData._cachedBoxKey = typeKey
    end

    if boxData.lastW and boxData.lastH then
        if math.abs(width - boxData.lastW) < 1.5 and math.abs(height - boxData.lastH) < 1.5 then
            return
        end
    end
    boxData.lastW = width
    boxData.lastH = height

    local t = BoxESP.CornerThickness
    local cLen = local_math_max(7, local_math_min(width, height) * BoxESP.CornerLengthRatio)
    local C = boxData.Corners

    boxData.CornerSlot:SetSize(FVector2D(width, height))

    if C.TopLeft_H and C.TopLeft_H.slot then
        C.TopLeft_H.slot:SetPosition(FVector2D(0, 0))
        C.TopLeft_H.slot:SetSize(FVector2D(cLen, t))
    end
    if C.TopLeft_V and C.TopLeft_V.slot then
        C.TopLeft_V.slot:SetPosition(FVector2D(0, 0))
        C.TopLeft_V.slot:SetSize(FVector2D(t, cLen))
    end

    if C.TopRight_H and C.TopRight_H.slot then
        C.TopRight_H.slot:SetPosition(FVector2D(width - cLen, 0))
        C.TopRight_H.slot:SetSize(FVector2D(cLen, t))
    end
    if C.TopRight_V and C.TopRight_V.slot then
        C.TopRight_V.slot:SetPosition(FVector2D(width - t, 0))
        C.TopRight_V.slot:SetSize(FVector2D(t, cLen))
    end

    if C.BottomLeft_H and C.BottomLeft_H.slot then
        C.BottomLeft_H.slot:SetPosition(FVector2D(0, height - t))
        C.BottomLeft_H.slot:SetSize(FVector2D(cLen, t))
    end
    if C.BottomLeft_V and C.BottomLeft_V.slot then
        C.BottomLeft_V.slot:SetPosition(FVector2D(0, height - cLen))
        C.BottomLeft_V.slot:SetSize(FVector2D(t, cLen))
    end

    if C.BottomRight_H and C.BottomRight_H.slot then
        C.BottomRight_H.slot:SetPosition(FVector2D(width - cLen, height - t))
        C.BottomRight_H.slot:SetSize(FVector2D(cLen, t))
    end
    if C.BottomRight_V and C.BottomRight_V.slot then
        C.BottomRight_V.slot:SetPosition(FVector2D(width - t, height - cLen))
        C.BottomRight_V.slot:SetSize(FVector2D(t, cLen))
    end
end

function BoxESP.UpdateCanvasTransform(PC)
    if not BoxESP.ESPCanvas or not IsValid(BoxESP.ESPCanvas) then return end

    local success = false
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
        local cg = BoxESP.ESPCanvas:GetCachedGeometry()
        if cg then
            local pt0 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(0, 0))
            local pt1 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(100, 100))
            if pt0 and pt1 then
                BoxESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                BoxESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                BoxESP._CanvasOffsetX = pt0.X
                BoxESP._CanvasOffsetY = pt0.Y
                success = true
            end
        end
    end

    if not success and WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local scale = WidgetLayoutLibrary.GetViewportScale(PC) or 1.0
        BoxESP._CanvasScaleX = 1.0 / scale
        BoxESP._CanvasScaleY = 1.0 / scale
        BoxESP._CanvasOffsetX = 0
        BoxESP._CanvasOffsetY = 0
    end
end

function BoxESP.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc or not TempProjVec2D then return false, 0, 0 end

    local res = PC:ProjectWorldLocationToScreen(WorldLoc, TempProjVec2D, true)
    if (res == true or res == 1) and (TempProjVec2D.X ~= 0 or TempProjVec2D.Y ~= 0) then
        local finalX = TempProjVec2D.X * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX
        local finalY = TempProjVec2D.Y * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
        return true, finalX, finalY
    end
    return false, 0, 0
end

-- ========== Snap Line ==========
function BoxESP.GetSnapLineStartPos(PC, ParentCanvas)
    local screenPixelW, screenPixelH = 0, 0
    local scale = 1.0

    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D(0, 0)
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then
                screenPixelW = vs.X
                screenPixelH = vs.Y
            end
        end
    end)

    if screenPixelW <= 200 then
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                local vs = WidgetLayoutLibrary.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then
                    screenPixelW = vs.X
                    screenPixelH = vs.Y
                end
            end
        end)
    end

    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
            local s = WidgetLayoutLibrary.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)

    if screenPixelW <= 200 then
        screenPixelW = 1920 * scale
        screenPixelH = 1080 * scale
    end

    local centerPixelX = screenPixelW / 2.0
    local centerPixelY = BoxESP.SnapLineOriginY * scale

    local fromX = centerPixelX * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX
    local fromY = centerPixelY * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
    return fromX, fromY
end

function BoxESP.CreateSnapLine(ParentCanvas)
    if not IsValid(ParentCanvas) then return nil end
    local border = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
    if not IsValid(border) then return nil end

    border:SetBrushColor(ColorNeonCyan)
    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    border.RenderTransformPivot = FVector2D(0.0, 0.5)
    border:SetRenderTransformPivot(FVector2D(0.0, 0.5))

    local slot = ParentCanvas:AddChildToCanvas(border)
    if slot then
        slot:SetAutoSize(false)
        slot:SetZOrder(990)
    end
    return { Widget = border, Slot = slot, bVisible = true }
end

function BoxESP.UpdateSnapLine(KeyStr, toX, toY, fromX, fromY, CustomColor, ParentCanvas)
    local lineData = BoxESP.LineWidgets[KeyStr]
    if not lineData or not IsValid(lineData.Widget) then
        lineData = BoxESP.CreateSnapLine(ParentCanvas)
        if not lineData or not lineData.Widget or not lineData.Slot then return end
        BoxESP.LineWidgets[KeyStr] = lineData
    end

    if not lineData.bVisible then
        lineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        lineData.bVisible = true
    end

    if CustomColor then
        pcall(function() lineData.Widget:SetBrushColor(CustomColor) end)
    end

    local dx = toX - fromX
    local dy = toY - fromY
    local length = local_math_sqrt(dx * dx + dy * dy)
    local angle = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
    local t = BoxESP.SnapLineThickness or 1.0

    if not lineData._CachedPosVec then
        lineData._CachedPosVec = FVector2D(fromX, fromY - t * 0.5)
        lineData._CachedSizeVec = FVector2D(length, t)
    else
        lineData._CachedPosVec.X = fromX
        lineData._CachedPosVec.Y = fromY - t * 0.5
        lineData._CachedSizeVec.X = length
        lineData._CachedSizeVec.Y = t
    end

    pcall(function()
        lineData.Slot:SetPosition(lineData._CachedPosVec)
        lineData.Slot:SetSize(lineData._CachedSizeVec)
        lineData.Widget:SetRenderAngle(angle)
    end)
end

function BoxESP.HideSnapLine(KeyStr)
    local lineData = BoxESP.LineWidgets[KeyStr]
    if lineData and lineData.Widget and IsValid(lineData.Widget) and lineData.bVisible then
        lineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        lineData.bVisible = false
    end
end

-- ========== Enemy Counter ==========
function BoxESP.CreateEnemyCounter(ParentCanvas, centerX, topY)
    local CD = BoxESP.CounterData
    if CD.ImgPlayer and IsValid(CD.ImgPlayer) and CD.ImgBot and IsValid(CD.ImgBot) then
        return true
    end

    local imgPlayer = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    local slotPlayer = nil
    if imgPlayer and IsValid(imgPlayer) then
        imgPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        slotPlayer = ParentCanvas:AddChildToCanvas(imgPlayer)
        if slotPlayer then
            slotPlayer:SetAutoSize(false)
            slotPlayer:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
            slotPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH, topY))
            slotPlayer:SetZOrder(1005)
        end
    end

    local imgBot = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    local slotBot = nil
    if imgBot and IsValid(imgBot) then
        imgBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        slotBot = ParentCanvas:AddChildToCanvas(imgBot)
        if slotBot then
            slotBot:SetAutoSize(false)
            slotBot:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
            slotBot:SetPosition(FVector2D(centerX, topY))
            slotBot:SetZOrder(1005)
        end
    end

    local function MakeCounterText(posX, posY, textColor)
        local txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
        local sl = nil
        if txt and IsValid(txt) then
            txt:SetText("0")
            if txt.Font then
                local font = txt.Font
                font.Size = 10
                if font.OutlineSettings then
                    font.OutlineSettings.OutlineSize = 1
                    font.OutlineSettings.OutlineColor = FLinearColor(0, 0, 0, 1)
                end
                txt.Font = font
            end
            if txt.SetFontSize then txt:SetFontSize(10) end
            txt:SetJustification(1)
            pcall(function() txt:SetAutoWrapText(false) end)
            if FSlateColor then
                txt:SetColorAndOpacity(FSlateColor(textColor or ColorWhite))
            else
                txt:SetColorAndOpacity(textColor or ColorWhite)
            end
            txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            sl = ParentCanvas:AddChildToCanvas(txt)
            if sl then
                sl:SetAutoSize(true)
                sl:SetAlignment(FVector2D(0.5, 0.5))
                sl:SetPosition(FVector2D(posX, posY))
                sl:SetZOrder(1010)
            end
        end
        return txt, sl
    end

    local txtPlayer, slotTxtPlayer = MakeCounterText(
        centerX - (BADGE_WIDTH * 0.25), topY + (BADGE_HEIGHT * 0.5), ColorRealVisible)
    local txtBot, slotTxtBot = MakeCounterText(
        centerX + (BADGE_WIDTH * 0.65), topY + (BADGE_HEIGHT * 0.5), ColorBotVisible)

    LoadBadgeTexture(imgPlayer, ENEMY_COUNTER_PLAYER_URLS, "ic_danger_enemy.png", "Player", CD)
    LoadBadgeTexture(imgBot, ENEMY_COUNTER_BOT_URLS, "ic_clear_boot.png", "Bot", CD)

    CD.ImgPlayer = imgPlayer
    CD.SlotPlayer = slotPlayer
    CD.ImgBot = imgBot
    CD.SlotBot = slotBot
    CD.TxtPlayer = txtPlayer
    CD.SlotTxtPlayer = slotTxtPlayer
    CD.TxtBot = txtBot
    CD.SlotTxtBot = slotTxtBot
    CD.bCreated = true
    return true
end

function BoxESP.UpdateEnemyCounterDisplay(realCount, botCount, ParentCanvas, centerX, topY)
    local CD = BoxESP.CounterData
    if not BoxESP.bShowCounter then
        local col = UEnums.ESlateVisibility.Collapsed
        if CD.ImgPlayer and IsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(col) end
        if CD.ImgBot and IsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(col) end
        if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(col) end
        if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(col) end
        return
    end

    if not BoxESP.CreateEnemyCounter(ParentCanvas, centerX, topY) then return end

    local now = local_os_clock()
    if (not CD.PlayerLoaded or not CD.BotLoaded) and (now - CD.LastDownloadRetry > 2.0) then
        CD.LastDownloadRetry = now
        if not CD.PlayerLoaded and CD.ImgPlayer then LoadBadgeTexture(CD.ImgPlayer, ENEMY_COUNTER_PLAYER_URLS, "ic_danger_enemy.png", "Player", CD) end
        if not CD.BotLoaded and CD.ImgBot then LoadBadgeTexture(CD.ImgBot, ENEMY_COUNTER_BOT_URLS, "ic_clear_boot.png", "Bot", CD) end
    end

    pcall(function()
        if CD.SlotPlayer then
            CD.SlotPlayer:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
            CD.SlotPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH, topY))
        end
        if CD.SlotBot then
            CD.SlotBot:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
            CD.SlotBot:SetPosition(FVector2D(centerX, topY))
        end
        if CD.SlotTxtPlayer then
            CD.SlotTxtPlayer:SetPosition(FVector2D(centerX - (BADGE_WIDTH * 0.25), topY + (BADGE_HEIGHT * 0.5)))
        end
        if CD.SlotTxtBot then
            CD.SlotTxtBot:SetPosition(FVector2D(centerX + (BADGE_WIDTH * 0.65), topY + (BADGE_HEIGHT * 0.5)))
        end

        if CD.LastPlayerCount ~= realCount then
            if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetText(local_tostring(realCount)) end
            CD.LastPlayerCount = realCount
        end

        if CD.LastBotCount ~= botCount then
            if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetText(local_tostring(botCount)) end
            CD.LastBotCount = botCount
        end

        local vis = UEnums.ESlateVisibility.SelfHitTestInvisible
        if CD.ImgPlayer and IsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(vis) end
        if CD.ImgBot and IsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(vis) end
        if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(vis) end
        if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(vis) end
    end)
end

function BoxESP.HideWidget(boxData)
    if not boxData or not boxData.bVisible then return end
    boxData.bVisible = false
    local collapsed = UEnums.ESlateVisibility.Collapsed
    if boxData.CornerContainer then boxData.CornerContainer:SetWidgetVisibility(collapsed) end
    if boxData.BgWidget then boxData.BgWidget:SetWidgetVisibility(collapsed) end
    if boxData.HealthWidget then boxData.HealthWidget:SetWidgetVisibility(collapsed) end
    if boxData.WeaponWidget then boxData.WeaponWidget:SetWidgetVisibility(collapsed) end
    if boxData.FlagWidget then boxData.FlagWidget:SetWidgetVisibility(collapsed) end
    if boxData.NameWidget then boxData.NameWidget:SetWidgetVisibility(collapsed) end
    if boxData.DistWidget then boxData.DistWidget:SetWidgetVisibility(collapsed) end
    if boxData.StateWidget then boxData.StateWidget:SetWidgetVisibility(collapsed) end
end

-- ========== Feature Visibility ==========
function BoxESP.ShowWidget(boxData)
    if not boxData then return end
    boxData.bVisible = true
    local vis = UEnums.ESlateVisibility.SelfHitTestInvisible
    local col = UEnums.ESlateVisibility.Collapsed

    if boxData.CornerContainer then
        boxData.CornerContainer:SetWidgetVisibility(BoxESP.bShowBox and vis or col)
    end
    if boxData.BgWidget then
        boxData.BgWidget:SetWidgetVisibility(BoxESP.bShowHealthBar and vis or col)
    end
    if boxData.HealthWidget then
        boxData.HealthWidget:SetWidgetVisibility(BoxESP.bShowHealthBar and vis or col)
    end
    if boxData.WeaponWidget then
        boxData.WeaponWidget:SetWidgetVisibility(BoxESP.bShowWeapon and vis or col)
    end
    if boxData.FlagWidget then
        boxData.FlagWidget:SetWidgetVisibility(BoxESP.bShowFlag and vis or col)
    end
    if boxData.NameWidget then
        boxData.NameWidget:SetWidgetVisibility(BoxESP.bShowName and vis or col)
    end
    if boxData.DistWidget then
        boxData.DistWidget:SetWidgetVisibility(BoxESP.bShowDistance and vis or col)
    end
    if boxData.StateWidget then
        boxData.StateWidget:SetWidgetVisibility(BoxESP.bShowState and vis or col)
    end
end

function BoxESP.IsAnyFeatureEnabled()
    return BoxESP.bShowBox
        or BoxESP.bShowHealthBar
        or BoxESP.bShowName
        or BoxESP.bShowDistance
        or BoxESP.bShowWeapon
        or BoxESP.bShowFlag
        or BoxESP.bShowState
        or BoxESP.bShowLines
        or BoxESP.bShowCounter
        or BoxESP.bShowSkeleton  -- NEW
end

function BoxESP.HideEverything()
    local col = UEnums.ESlateVisibility.Collapsed

    for _, boxData in pairs(BoxESP.BoxWidgets) do
        BoxESP.HideWidget(boxData)
    end
    for KeyStr in pairs(BoxESP.LineWidgets) do
        BoxESP.HideSnapLine(KeyStr)
    end

    -- Skeleton hide
    for KeyStr in pairs(SkeletonModule.Lines) do
        SkeletonModule.HideSkeleton(KeyStr)
    end

    local CD = BoxESP.CounterData
    if CD.ImgPlayer and IsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(col) end
    if CD.ImgBot and IsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(col) end
    if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(col) end
    if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(col) end
end

-- ========== Main Update Loop ==========
function BoxESP.UpdateESP()
    if not BoxESP.IsAnyFeatureEnabled() then
        BoxESP.HideEverything()
        return
    end

    local ParentCanvas = BoxESP.GetMainCanvas()
    if not ParentCanvas then return end

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or _G.GameplayData
    if not GameplayData then return end

    local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
    if not IsValid(LocalPlayer) then return end

    local PC = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
    if not IsValid(PC) then return end

    local curTime = local_os_clock()
    if BoxESP._LastCanvas ~= ParentCanvas or (curTime - BoxESP._LastTransformTime > 1.0) then
        BoxESP.UpdateCanvasTransform(PC)
        BoxESP._LastCanvas = ParentCanvas
        BoxESP._LastTransformTime = curTime
    end

    local bRunHeavyTasks = (curTime - BoxESP._LastHeavyUpdateTime > 0.15)
    if bRunHeavyTasks then
        BoxESP._LastHeavyUpdateTime = curTime
    end

    local bUpdateVisCheck = (curTime - BoxESP._LastVisCheckTime > 0.12)
    if bUpdateVisCheck then
        BoxESP._LastVisCheckTime = curTime
    end

    local fromX, fromY = BoxESP.GetSnapLineStartPos(PC, ParentCanvas)

    local TeamID = LocalPlayer.TeamID or (LocalPlayer.GetTeamID and LocalPlayer:GetTeamID()) or 0
    local AllPawns = (Game and Game.GetAllPlayerPawns and Game:GetAllPlayerPawns()) or {}
    local SeenKeys = {}
    local RealPlayerCount = 0
    local BotCount = 0

    for Key, Pawn in pairs(AllPawns) do
        if IsValid(Pawn) and Pawn ~= LocalPlayer then
            local pawnTeam = Pawn.TeamID or (Pawn.GetTeamID and Pawn:GetTeamID()) or -1
            local isAlive = (Pawn.Health and Pawn.Health > 0) or (Pawn.IsAlive and Pawn:IsAlive())

            if isAlive and pawnTeam ~= TeamID then
                local KeyStr = local_tostring(Key)
                SeenKeys[KeyStr] = true

                local ping = (Pawn.PlayerState and Pawn.PlayerState.Ping) or Pawn.Ping or (Pawn.GetPing and Pawn:GetPing()) or -1
                ping = tonumber(ping) or -1
                local isBot = (ping >= 0 and ping <= 3) or Pawn.bIsAI or Pawn.bIsAIBot or Pawn.bIsABot or (Game and Game.IsAI and Game:IsAI(Pawn))

                if isBot then
                    BotCount = BotCount + 1
                else
                    RealPlayerCount = RealPlayerCount + 1
                end

                local Loc = Pawn.K2_GetActorLocation and Pawn:K2_GetActorLocation()
                if not Loc and Pawn.RootComponent then
                    Loc = Pawn.RootComponent:K2_GetComponentLocation()
                end

                if Loc then
                    local topWorldPos = nil
                    local bottomWorldPos = nil

                    local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
                    if mesh and mesh.GetSocketLocation then
                        local hLoc = mesh:GetSocketLocation("Head") or mesh:GetSocketLocation("head")
                        if hLoc and (hLoc.X ~= 0 or hLoc.Y ~= 0 or hLoc.Z ~= 0) then
                            topWorldPos = FVector(hLoc.X, hLoc.Y, hLoc.Z + 15)
                        end
                        local rLoc = mesh:GetSocketLocation("root") or mesh:GetSocketLocation("Root")
                        if rLoc and (rLoc.X ~= 0 or rLoc.Y ~= 0 or rLoc.Z ~= 0) then
                            bottomWorldPos = rLoc
                        end
                    end

                    local isProne = false
                    local isCrouch = false
                    if Pawn.bIsProning or Pawn.bIsProne or (Pawn.IsProne and Pawn:IsProne()) or Pawn.PoseState == 2 or Pawn.PoseState == "Prone" then
                        isProne = true
                    elseif Pawn.bIsCrouched or (Pawn.IsCrouched and Pawn:IsCrouched()) or Pawn.PoseState == 1 or Pawn.PoseState == "Crouch" then
                        isCrouch = true
                    end

                    if not topWorldPos or not bottomWorldPos then
                        local topOffset = isProne and 18 or (isCrouch and 50 or 88)
                        local bottomOffset = isProne and -22 or (isCrouch and -68 or -90)
                        topWorldPos = topWorldPos or FVector(Loc.X, Loc.Y, Loc.Z + topOffset)
                        bottomWorldPos = bottomWorldPos or FVector(Loc.X, Loc.Y, Loc.Z + bottomOffset)
                    end

                    local bTopOk, topX, topY = BoxESP.ProjectWorldToCanvasLocal(PC, topWorldPos)
                    local bBottomOk, bottomX, bottomY = BoxESP.ProjectWorldToCanvasLocal(PC, bottomWorldPos)

                    if bUpdateVisCheck or BoxESP._VisCheckCache[KeyStr] == nil then
                        BoxESP._VisCheckCache[KeyStr] = (PC and PC.LineOfSightTo and PC:LineOfSightTo(Pawn)) or false
                    end
                    local isVisible = BoxESP._VisCheckCache[KeyStr]

                    -- ===== Skeleton Update (NEW) =====
                    if BoxESP.bShowSkeleton then
                        local skelColor
                        if isBot then
                            skelColor = isVisible and ColorBotVisible or ColorBotHidden
                        else
                            skelColor = isVisible and ColorRealVisible or ColorRealHidden
                        end
                        SkeletonModule.UpdateSkeleton(
                            KeyStr, Pawn, PC, ParentCanvas, skelColor,
                            BoxESP.ProjectWorldToCanvasLocal
                        )
                    elseif SkeletonModule.Lines[KeyStr] then
                        SkeletonModule.HideSkeleton(KeyStr)
                    end

                    local boxData = BoxESP.BoxWidgets[KeyStr]
                    if not boxData then
                        boxData = BoxESP.CreateESPWidget(ParentCanvas)
                        if boxData then BoxESP.BoxWidgets[KeyStr] = boxData end
                    end

                    if boxData and IsValid(boxData.CornerContainer) then
                        if bTopOk and bBottomOk then
                            local boxHeight = local_math_max(28, math.abs(bottomY - topY))
                            local boxWidth = local_math_max(15, boxHeight * (isProne and 1.1 or (isCrouch and 0.7 or 0.55)))

                            local centerX = (topX + bottomX) * 0.5
                            local centerY = (topY + bottomY) * 0.5
                            local boxTopY = centerY - (boxHeight * 0.5)
                            local boxBottomY = centerY + (boxHeight * 0.5)

                            BoxESP.UpdateCornerDimensions(boxData, boxWidth, boxHeight, isBot, isVisible)
                            boxData.CornerSlot:SetPosition(FVector2D(centerX, centerY))
                            BoxESP.ShowWidget(boxData)

                            local healthBarWidth = BoxESP.HealthBarWidth or 2.0
                            local healthCenterX = centerX - (boxWidth * 0.5) - 2.5 - (healthBarWidth * 0.5)
                            local health = Pawn.Health or (Pawn.GetHealth and Pawn:GetHealth()) or 100
                            local healthMax = Pawn.HealthMax or (Pawn.GetHealthMax and Pawn:GetHealthMax()) or 100
                            if healthMax <= 0 then healthMax = 100 end

                            local healthPercent = local_math_max(0, local_math_min(1, health / healthMax))
                            local currentHealthHeight = boxHeight * healthPercent

                            boxData.BgSlot:SetSize(FVector2D(healthBarWidth, boxHeight))
                            boxData.BgSlot:SetPosition(FVector2D(healthCenterX, boxBottomY))
                            boxData.HealthSlot:SetSize(FVector2D(healthBarWidth, currentHealthHeight))
                            boxData.HealthSlot:SetPosition(FVector2D(healthCenterX, boxBottomY))

                            if bRunHeavyTasks or boxData._cachedWeapon == "" then
                                local wep = (Pawn.GetCurrentWeapon and Pawn:GetCurrentWeapon())
                                    or (Pawn.GetCurrentShootWeapon and Pawn:GetCurrentShootWeapon())
                                    or (Pawn.WeaponManagerComponent and Pawn.WeaponManagerComponent.CurrentWeaponReplicated)
                                local weaponName = "Fist"
                                if wep and IsValid(wep) then
                                    local wn = (type(wep.GetWeaponName) == "function" and wep:GetWeaponName()) or wep.WeaponName
                                    if wn and wn ~= "" then
                                        weaponName = local_tostring(wn):gsub("^BP_", ""):gsub("_C$", ""):gsub("_Wrapper$", "")
                                    end
                                end
                                if boxData._cachedWeapon ~= weaponName then
                                    boxData.WeaponWidget:SetText(weaponName)
                                    boxData._cachedWeapon = weaponName
                                end
                            end
                            boxData.WeaponSlot:SetPosition(FVector2D(centerX, boxTopY - 3.5))

                            if bRunHeavyTasks or not boxData._cachedNation then
                                local playerNation = (Pawn.PlayerState and Pawn.PlayerState.Nation) or Pawn.Nation or ""
                                playerNation = local_tostring(playerNation or "")
                                if playerNation == "" or playerNation == "nil" or playerNation == "0" then
                                    playerNation = "G1"
                                end

                                if boxData._cachedNation ~= playerNation then
                                    local cfg = (CDataTable and CDataTable.GetTableData) and CDataTable.GetTableData("RegionConfig", playerNation)
                                    if not cfg or not cfg.res_path or cfg.res_path == "" then
                                        cfg = (CDataTable and CDataTable.GetTableData) and CDataTable.GetTableData("RegionConfig", "G1")
                                    end
                                    local flagPath = (cfg and cfg.res_path) or "/Game/UMG/Texture/Atlas/NationalflagUI/Frames/T_icon_flag_iland_png.T_icon_flag_iland_png"

                                    if boxData.FlagWidget and IsValid(boxData.FlagWidget) then
                                        local bSet = false
                                        if boxData.FlagWidget.SetBrushResourceFromPathSync then
                                            boxData.FlagWidget:SetBrushResourceFromPathSync(flagPath, false)
                                            bSet = true
                                        end
                                        if not bSet and boxData.FlagWidget.SetBrushFromPathAsync then
                                            boxData.FlagWidget:SetBrushFromPathAsync(flagPath, false)
                                            bSet = true
                                        end
                                        if not bSet then
                                            local util = package.loaded["client.slua_ui_framework.util"]
                                            if not util then pcall(function() util = require("client.slua_ui_framework.util") end) end
                                            if util and util.SetTexture then
                                                util.SetTexture(boxData.FlagWidget, flagPath, { sync = true })
                                                bSet = true
                                            end
                                        end
                                        if not bSet then
                                            local asset_util = package.loaded["common.asset_util"]
                                            if not asset_util then pcall(function() asset_util = require("common.asset_util") end) end
                                            local flagTex = (asset_util and asset_util.GetAssetSync and asset_util.GetAssetSync(flagPath))
                                                         or (CGame and CGame.LoadObject and CGame:LoadObject(flagPath))
                                            if flagTex and boxData.FlagWidget.SetBrushFromTexture then
                                                boxData.FlagWidget:SetBrushFromTexture(flagTex, false)
                                                bSet = true
                                            end
                                        end
                                        boxData.FlagWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                    end
                                    boxData._cachedNation = playerNation
                                end
                            end
                            if boxData.FlagSlot then
                                boxData.FlagSlot:SetPosition(FVector2D(centerX, boxTopY - 22.0))
                            end

                            if bRunHeavyTasks or boxData._cachedName == "" then
                                local playerName = isBot and "Bot" or (Pawn.PlayerName or Pawn.PlayerNamePublic or (Pawn.GetPlayerName and Pawn:GetPlayerName()) or "Player")
                                playerName = local_tostring(playerName)
                                if boxData._cachedName ~= playerName then
                                    boxData.NameWidget:SetText(playerName)
                                    local nameColor = isBot and ColorBotVisible or ColorRealVisible
                                    if FSlateColor then
                                        boxData.NameWidget:SetColorAndOpacity(FSlateColor(nameColor))
                                    else
                                        boxData.NameWidget:SetColorAndOpacity(nameColor)
                                    end
                                    boxData._cachedName = playerName
                                end
                            end
                            boxData.NameSlot:SetPosition(FVector2D(centerX, boxBottomY + 4.0))

                            local distVal = local_math_floor(LocalPlayer:GetDistanceTo(Pawn) / 100.0)
                            local distStr = local_tostring(distVal) .. "m"
                            if boxData._cachedDist ~= distStr then
                                boxData.DistWidget:SetText(distStr)
                                local distColor = isBot and ColorBotVisible or ColorRealVisible
                                if FSlateColor then
                                    boxData.DistWidget:SetColorAndOpacity(FSlateColor(distColor))
                                else
                                    boxData.DistWidget:SetColorAndOpacity(distColor)
                                end
                                boxData._cachedDist = distStr
                            end
                            boxData.DistSlot:SetPosition(FVector2D(centerX, boxBottomY + 20.5))

                            if bRunHeavyTasks or boxData._cachedState == "" then
                                local isKnocked = (Pawn.HealthStatus == 1 or Pawn.bIsKnocked or (Pawn.IsKnocked and Pawn:IsKnocked()))
                                local stateStr = "Open"

                                local slateCol
                                if isBot then
                                    slateCol = isVisible and SlateColorBotVisible or SlateColorBotHidden
                                else
                                    slateCol = isVisible and SlateColorRealVisible or SlateColorRealHidden
                                end

                                if isKnocked then
                                    stateStr = "Knocked"
                                    slateCol = SlateColorCrimson
                                elseif not isVisible then
                                    stateStr = "Cover"
                                end

                                if boxData._cachedState ~= stateStr then
                                    boxData.StateWidget:SetText(stateStr)
                                    boxData.StateWidget:SetColorAndOpacity(slateCol)
                                    boxData._cachedState = stateStr
                                end
                            end
                            boxData.StateSlot:SetPosition(FVector2D(centerX, boxBottomY + 37.0))

                            if BoxESP.bShowLines then
                                local lineColor
                                if isBot then
                                    lineColor = isVisible and ColorBotVisible or ColorBotHidden
                                else
                                    lineColor = isVisible and ColorRealVisible or ColorRealHidden
                                end
                                BoxESP.UpdateSnapLine(KeyStr, centerX, boxTopY, fromX, fromY, lineColor, ParentCanvas)
                            else
                                BoxESP.HideSnapLine(KeyStr)
                            end
                        else
                            BoxESP.HideWidget(boxData)
                            BoxESP.HideSnapLine(KeyStr)
                        end
                    end
                end
            end
        end
    end

    for KeyStr, boxData in pairs(BoxESP.BoxWidgets) do
        if not SeenKeys[KeyStr] then
            BoxESP.HideWidget(boxData)
        end
    end
    for KeyStr, _ in pairs(BoxESP.LineWidgets) do
        if not SeenKeys[KeyStr] then
            BoxESP.HideSnapLine(KeyStr)
            BoxESP._VisCheckCache[KeyStr] = nil
        end
    end
    -- Skeleton hide for missing pawns
    for KeyStr, _ in pairs(SkeletonModule.Lines) do
        if not SeenKeys[KeyStr] then
            SkeletonModule.HideSkeleton(KeyStr)
        end
    end

    local counterTopY = fromY - BADGE_HEIGHT - 2
    if counterTopY < 10 then counterTopY = 48 end
    BoxESP.UpdateEnemyCounterDisplay(RealPlayerCount, BotCount, ParentCanvas, fromX, counterTopY)
end

pcall(function()
    local PC = nil
    if slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
        PC = slua_GameFrontendHUD:GetPlayerController()
    end
    if IsValid(PC) and PC.AddGameTimer then
        PC:AddGameTimer(0.02, true, BoxESP.UpdateESP)
    end
end)

pcall(function()
    local Ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
    if Ticker and Ticker.AddTimerLoop then
        Ticker.AddTimerLoop(function()
            BoxESP.UpdateESP()
            return true
        end, 0.02)
    end
end)

_G.BoxESP = BoxESP

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")