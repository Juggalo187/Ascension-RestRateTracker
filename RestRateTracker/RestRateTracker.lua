-- RestRateTracker - Tracks rest XP accumulation rate while offline
local addonName = "RestRateTracker"
local RRT = {}  -- Explicitly create the RRT table

-- Saved Variables Name (must match .toc file)
local ADDON_NAME = "RestRateTracker"
local SAVED_VARS_NAME = ADDON_NAME .. "DB"

-- Make modules accessible (only if modules exist)
if RRT_Config then RRT.Config = RRT_Config end
if RRT_Utilities then RRT.Utilities = RRT_Utilities end
if RRT_Data then RRT.Data = RRT_Data end
if RRT_UI then RRT.UI = RRT_UI end

-- Initialize modules with config
if RRT_Config and RRT_Config.Initialize then
    RRT_Config.Initialize(SAVED_VARS_NAME)
end

-- Global sort mode
RRT_SORT_MODE = "name"

-- Frame for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")

-- Local variables
local loginProcessed = false

-- Helper function to safely call module functions
local function SafeCall(module, funcName, ...)
    if module and module[funcName] then
        return module[funcName](...)
    end
    return nil
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    SafeCall(RRT_Utilities, "DebugPrint", "Event fired: " .. event)
    
    if event == "PLAYER_LOGIN" then
        -- Prevent duplicate processing
        if loginProcessed then
            SafeCall(RRT_Utilities, "DebugPrint", "Login already processed, skipping")
            return
        end
        
        loginProcessed = true
        
        -- Wait for player data to be fully loaded
        C_Timer.After(3, function()
            local currentPlayerName = UnitName("player")
            local currentPlayerRealm = GetRealmName()
            
            if not currentPlayerName or currentPlayerName == "Unknown" or not currentPlayerRealm then
                SafeCall(RRT_Utilities, "DebugPrint", "Error: Player data not loaded properly")
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Player data not loaded properly")
                return
            end
            
            -- Clean realm name
            currentPlayerRealm = currentPlayerRealm:gsub("%s+", " "):trim()
            
            SafeCall(RRT_Utilities, "DebugPrint", "Character logged in: " .. currentPlayerName .. "-" .. currentPlayerRealm)
            
            -- Save current state (silent mode to avoid duplicate messages)
            SafeCall(RRT_Data, "SaveCurrentCharacterData", true)
            
            -- Check if we have previous data for this character
            local db = SafeCall(RRT_Data, "GetDB")
            if db then
                local charKey = currentPlayerName .. "-" .. currentPlayerRealm
                local previousData = db.logoutData[charKey]
                
                if previousData and previousData.maxXP and previousData.maxXP > 0 then
                    SafeCall(RRT_Utilities, "DebugPrint", "Found previous data for " .. charKey)
                    
                    -- Get current data
                    local currentData = SafeCall(RRT_Data, "GetCurrentRestData")
                    
                    if currentData and currentData.maxXP > 0 then
                        -- Check if character was at max level in previous session
                        local serverMaxLevel = SafeCall(RRT_Utilities, "GetServerMaxLevel")
                        if serverMaxLevel and previousData.level == serverMaxLevel then
                            SafeCall(RRT_Utilities, "DebugPrint", "Previous session was at max level, skipping rest calculation")
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Character was at max level in previous session")
                        else
                            -- Calculate rest rate between logout and login
                            local rateData = SafeCall(RRT_Data, "CalculateRestRate", currentData, previousData)
                            
                            -- Show report if configured
                            if db.settings.showOnLogin and rateData then
                                SafeCall(RRT_Data, "ShowRestReport", rateData)
                            end
                        end
                    end
                else
                    SafeCall(RRT_Utilities, "DebugPrint", "No previous data found for " .. charKey)
                    -- Show welcome message for new character
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rest Rate Tracker]|r Tracking started for " .. charKey)
                end
            end
        end)
        
    elseif event == "PLAYER_LOGOUT" then
        SafeCall(RRT_Utilities, "DebugPrint", "Player logging out - saving data")
        
        -- Reset login flag for next session
        loginProcessed = false
        
        -- Save data for the character being logged out (silent mode)
        SafeCall(RRT_Data, "SaveCurrentCharacterData", true)
        
    elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_XP_UPDATE" then
        -- Update stored data when XP changes (silent mode)
        SafeCall(RRT_Data, "SaveCurrentCharacterData", true)
        
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        -- Update if player enters/exits rested area (silent mode)
        SafeCall(RRT_Data, "SaveCurrentCharacterData", true)
    elseif event == "PLAYER_UPDATE_RESTING" then
        SafeCall(RRT_Data, "SaveCurrentCharacterData", true)
    end
end)

-- Slash command handler
SLASH_RESTRATE1 = "/rrt"
SLASH_RESTRATE2 = "/restrate"
SLASH_RESTRATE3 = "/rrtxp"

local function HandleSlashCommand(msg)
    if RRT_Data and RRT_Data.HandleCommand then
        RRT_Data.HandleCommand(msg)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Command module not loaded")
    end
end

SlashCmdList["RESTRATE"] = HandleSlashCommand

-- Initialization message
local function OnAddonLoaded()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rest Rate Tracker]|r loaded. Type |cFF00FF00/rrt help|r for commands.")
    
    -- Initialize UI
    if RRT_UI and RRT_UI.CreateMinimapIcon then
        C_Timer.After(5, RRT_UI.CreateMinimapIcon)
    end
    
    -- Show current status on login (delayed to avoid conflict with login processing)
    C_Timer.After(8, function()
        -- Only show if we're not in the middle of processing login
        if loginProcessed then
            local data = SafeCall(RRT_Data, "GetCurrentRestData")
            if data then
                local serverMaxLevel = SafeCall(RRT_Utilities, "GetServerMaxLevel")
                if serverMaxLevel and data.level == serverMaxLevel then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Character at max level (Level " .. serverMaxLevel .. ")")
                elseif data.restPercent < 150 then
                    local secondsToFull, rate = SafeCall(RRT_Data, "CalculateTimeToFull", data.restPercent, nil, data.location)
                    if secondsToFull and secondsToFull > 0 then
                        local timeText = SafeCall(RRT_Utilities, "FormatTime", secondsToFull) or "Unknown time"
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Time to full rest: " .. timeText .. 
                            " (use |cFF00FF00/rrt full|r for details)")
                    end
                end
            end
        end
    end)
end

-- Delay initialization message
C_Timer.After(2, OnAddonLoaded)

-- Make RRT globally accessible (optional, for debugging)
_G.RRT = RRT