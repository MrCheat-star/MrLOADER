-- ==========================================
-- 1. EXPIRATION & WELCOME POPUP MODULE
-- ==========================================
local function CheckAndShowStatus()
    local expireTime = os.time({year = 2026, month = 11, day = 7, hour = 23, min = 59, sec = 59})
    local currentTime = os.time()
    
    local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] 
             or require("client.slua.logic.common.logic_common_msg_box")

    if currentTime > expireTime then
        local function ShowExpiredPopup()
            pcall(function()
                Msg.Show(
                    4, 
                    "STATUS ALERT", 
                    "VIP BYPASS\n\n• STATUS: EXPIRED\n\nContact: @mr_ownerX", 
                    function()
                        ShowExpiredPopup()
                    end
                )
            end)
        end

        ShowExpiredPopup()
        return false
    else
        if not _G.WelcomeShown then
            pcall(function()
                Msg.Show(
                    4, 
                    "BYPASS MODULE", 
                    "VIP BYPASS\n\n• STATUS: ACTIVE\n\nPlay Safe Avoid Report", 
                    function() end
                )
                _G.WelcomeShown = true
            end)
        end
        return true
    end
end

-- ==========================================
-- 2. BYPASS & HOOK MODULE
-- ==========================================
local function MRMOD_INSTALL()
    local tssSuccess, tssErr = pcall(function()
        if rawget(_G, "Tss") and type(_G.Tss) == "table" then
            _G.Tss.GetUserTag4Lua = function() return "" end
            _G.Tss.GetDeviceFeature = function() return "VALID_DEVICE" end
            _G.Tss.EigenArrayObfuscationVerify = function() return "VALID" end
            _G.Tss.SendEigeninfoData = function() return 0 end
        end
    end)
    
    if not tssSuccess then
        print("[MRMOD] TSS Bypass Warning: " .. tostring(tssErr))
    end

    local filterList = {
        ["GetApplicationVersion"] = true,
        ["GetAppVersion"] = true,
        ["ProjectSavedDir"] = true,
        ["ProjectContentDir"] = true,
        ["IsWindowOB"] = true,
        ["GetDevicePlatformName"] = true,
        ["GetPhoneType"] = true,
        ["GetMemorySize"] = true,
        ["GetPublishRegion"] = true,
        ["IsEmulator"] = true,
    }

    local sluaSuccess, config = pcall(function() 
        return require("client.slua.config.CacheCPPAPI.CacheCPPAPIConfig")
    end)

    if sluaSuccess and config then
        for _, content in pairs(config) do
            if content.LuaTableName and _G[content.LuaTableName] then
                for _, funcName in ipairs(content.CacheFunctions) do
                    if filterList[funcName] then
                        print("* [SKIP] " .. tostring(funcName))
                    else
                        print("* Hook: " .. tostring(funcName))
                        _G[content.LuaTableName][funcName] = function(...)
                            local lfn = string.lower(funcName)
                            if lfn:find("crc") or lfn:find("hash") then
                                return 0
                            end
                            return true
                        end
                    end
                end
            end
        end
    else
  end
end

-- ==========================================
-- 3. MAIN SCRIPT EXECUTION
-- ==========================================
if CheckAndShowStatus() then
    pcall(MRMOD_INSTALL)
else
end
