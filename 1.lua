local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  if Client then
    self:AddGameTimer(1.0, false, function() end)
  end
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
end

-- ============================================
-- WELCOME POPUP
-- ============================================
if not _G.WelcomeShown then
  pcall(function()
    local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
    Msg.Show(4, "BULLET TRACK ONLY", "✅ BULLET TRACK LOADED\n\n• HEAD TRACK\n• NECK AIM\n• VISIBLE ONLY\n• ALL GUNS SUPPORT", function() end)
    _G.WelcomeShown = true
  end)
end

local GameplayData = require("GameLua.GameCore.Data.GameplayData")

-- ============================================
-- BULLET TRACK SYSTEM - ONLY THIS FEATURE
-- ============================================

local _btLastShootId = -1
local _btLastWeapon  = nil
local _btPendingFire = false
local _btDeferFrames = 0

-- ============================================
-- GET ENEMIES
-- ============================================
local function GetEnemyTargets()
  local result = {}
  local player = GameplayData.GetPlayerCharacter()
  if not slua.isValid(player) then return result end

  local myTeam = player:GetTeamID() or 0

  pcall(function()
    local ASTExtra = import("STExtraPlayerCharacter")
    if not ASTExtra then return end
    local actors = Game:GetActorsByClass(ASTExtra)
    if not actors then return end
    local count = actors:Num() or 0
    for i = 0, count - 1 do
      local actor = actors:Get(i)
      if slua.isValid(actor) and actor ~= player then
        if actor.GetTeamID and actor:GetTeamID() ~= myTeam then
          if actor.IsAlive and actor:IsAlive() then
            table.insert(result, actor)
          end
        end
      end
    end
  end)

  if #result == 0 then
    pcall(function()
      local chars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters()
      if not chars then return end
      for _, c in pairs(chars) do
        if slua.isValid(c) and c ~= player then
          local team = c.GetTeamID and c:GetTeamID() or (c.TeamID or 0)
          if team ~= myTeam and c.Health and c.Health > 0 then
            table.insert(result, c)
          end
        end
      end
    end)
  end

  return result
end

-- ============================================
-- GET HEAD POSITION
-- ============================================
local function GetHeadPosition(actor)
  local headPos = nil
  local boneNames = {"Head", "neck_01", "Neck", "head", "Bip001-Head", "Bip01-Head"}
  for _, bone in ipairs(boneNames) do
    if not headPos then
      pcall(function() headPos = actor:GetBonePos(bone, {X=0,Y=0,Z=0}) end)
    end
  end
  if not headPos then
    pcall(function() headPos = actor:GetHeadLocation(false) end)
  end
  if not headPos then
    pcall(function()
      local loc = actor:K2_GetActorLocation()
      if loc then
        headPos = {X = loc.X, Y = loc.Y, Z = loc.Z + 160}
      end
    end)
  end
  return headPos
end

-- ============================================
-- EXECUTE SHOT - CORE AIMBOT LOGIC
-- ============================================
local function ExecuteShot(player, weapon, pc, camLoc)
  pcall(function()
    local shootComp = weapon.ShootWeaponComponent
    if not shootComp then return end

    local curId = shootComp.CurShootID or -1
    if curId == _btLastShootId then return end
    _btLastShootId = curId

    local ui_util = require("client.common.ui_util")
    if not ui_util then return end
    local vp = ui_util.GetViewportSize()
    if not vp then return end

    local cx = vp.X * 0.5
    local cy = vp.Y * 0.5

    local enemies = GetEnemyTargets()
    local bestDist    = 99999
    local bestHeadPos = nil

    for _, enemy in pairs(enemies) do
      if slua.isValid(enemy) then
        local isAlive = false
        pcall(function() isAlive = enemy:IsAlive() end)
        if not isAlive then goto continue end

        local knocked = false
        pcall(function() knocked = enemy:IsNearDeath() end)
        if knocked then goto continue end

        local vis = false
        pcall(function() vis = pc:LineOfSightTo(enemy, camLoc, true) end)
        if not vis then goto continue end

        local headPos = GetHeadPosition(enemy)
        if not headPos then goto continue end

        local screen = import("Vector2D")()
        local ok = pc:ProjectWorldLocationToScreen(headPos, screen, false)
        if not ok then goto continue end
        if screen.X <= 0 or screen.Y <= 0 then goto continue end

        local dx = screen.X - cx
        local dy = screen.Y - cy
        local d  = math.sqrt(dx*dx + dy*dy)

        if d < bestDist then
          bestDist    = d
          bestHeadPos = headPos
        end

        ::continue::
      end
    end

    if not bestHeadPos then return end

    -- Get muzzle position
    local muzzlePos = nil

    pcall(function()
      local weaponEntity = weapon.ShootWeaponEntityComp
      if weaponEntity and weaponEntity.GetMuzzleLocation then
        muzzlePos = weaponEntity:GetMuzzleLocation()
      end
    end)

    if not muzzlePos then
      pcall(function()
        local weaponLoc = weapon:K2_GetActorLocation()
        local weaponRot = weapon:K2_GetActorRotation()
        if weaponLoc and weaponRot then
          local forward = weaponRot:GetForwardVector()
          muzzlePos = {
            X = weaponLoc.X + forward.X * 150,
            Y = weaponLoc.Y + forward.Y * 150,
            Z = weaponLoc.Z + forward.Z * 50
          }
        end
      end)
    end

    if not muzzlePos then
      pcall(function()
        muzzlePos = player:GetBonePos("head", {X=0,Y=0,Z=0})
        if muzzlePos then muzzlePos.Z = muzzlePos.Z - 20 end
      end)
    end

    if not muzzlePos then return end

    -- Calculate aim rotation
    local rot = import("KismetMathLibrary").FindLookAtRotation(muzzlePos, bestHeadPos)
    if not rot then return end

    -- Minimal spread to avoid detection
    local spread = 0.0003
    rot.Pitch = rot.Pitch + (math.random() - 0.5) * spread
    rot.Yaw   = rot.Yaw   + (math.random() - 0.5) * spread

    -- Fire bullet at head
    shootComp:ShootBulletInner(bestHeadPos, rot, curId)
  end)
end

-- ============================================
-- MAIN BULLET TRACK LOOP
-- ============================================
local function BulletTrack()
  pcall(function()
    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return end

    local wm = player.WeaponManagerComponent
    if not wm then return end
    local weapon = wm.CurrentWeaponReplicated
    if not slua.isValid(weapon) then return end

    -- Weapon swap: reset state
    if weapon ~= _btLastWeapon then
      _btLastWeapon   = weapon
      _btLastShootId  = -1
      _btPendingFire  = false
      _btDeferFrames  = 0
    end

    local pc = player:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return end

    local camManager = import("GameplayStatics").GetPlayerCameraManager(pc, 0)
    if not slua.isValid(camManager) then return end
    local camLoc = camManager:GetCameraLocation()
    if not camLoc then return end

    -- Detect shot across ALL fire modes
    local shootComp = weapon.ShootWeaponComponent
    if not shootComp then return end
    local curId = shootComp.CurShootID or -1

    local newShot = (curId ~= _btLastShootId and curId ~= -1)
                 or player.bIsWeaponFiring

    if newShot and not _btPendingFire then
      _btPendingFire = true
      _btDeferFrames = 1
      return
    end

    -- Deferred execution
    if _btPendingFire then
      if _btDeferFrames > 0 then
        _btDeferFrames = _btDeferFrames - 1
        return
      end

      _btPendingFire = false
      ExecuteShot(player, weapon, pc, camLoc)
    end
  end)
end

-- ============================================
-- START BULLET TRACK LOOP ONLY
-- ============================================
if not _G._AKModLoopRunning then
    _G._AKModLoopRunning = true

    local ticker = require("common.time_ticker")

    -- ONLY BulletTrack loop - 0.016s interval (60 FPS)
    local function _btLoop()
        pcall(BulletTrack)
        ticker.AddTimerOnce(0.016, _btLoop)
    end

    ticker.AddTimerOnce(0.5, _btLoop)

    print("[BULLET TRACK] Loaded successfully!")
    print("[BULLET TRACK] ONLY bullet track - @THUNDER_CHEATS")
end

print("✅ BULLET TRACK ONLY LOADED!")

-- ============================================
-- CLASS EXPORT
-- ============================================
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
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")