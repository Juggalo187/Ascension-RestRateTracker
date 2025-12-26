-- RestRateTracker Data Module
RRT_Data = RRT_Data or {}

-- Local variables
local db = nil

-- Initialize saved variables on first load
local function InitializeSavedVariables()
    -- Try to get saved vars name from config, but don't crash if not available yet
    local savedVarsName = "RestRateTrackerDB"  -- Default hardcoded value
    
    if RRT_Config and RRT_Config.GetSavedVarsName then
        local configName = RRT_Config.GetSavedVarsName()
        if configName then
            savedVarsName = configName
        end
    end
    
    if not _G[savedVarsName] then
        _G[savedVarsName] = {
            version = 2,
            logoutData = {},
            history = {},
            settings = {
                showOnLogin = true,
                showRatePerHour = true,
                showTimeToFull = true,
                debugMode = false,
                frameCompactMode = false,
                filterText = "",
            }
        }
    end
    
    -- Handle version upgrades
    local savedDB = _G[savedVarsName]
    
    -- Version 1 to 2 upgrade (if needed)
    if savedDB.version == 1 then
        savedDB.version = 2
        if not savedDB.settings then
            savedDB.settings = {
                showOnLogin = true,
                showRatePerHour = true,
                showTimeToFull = true,
                debugMode = false,
                frameCompactMode = false,
                filterText = "",
            }
        end
    end
    
    -- Initialize new settings if they don't exist
    if savedDB.settings.frameCompactMode == nil then
        savedDB.settings.frameCompactMode = false
    end
    if savedDB.settings.filterText == nil then
        savedDB.settings.filterText = ""
    end
    
    db = savedDB
    return db
end

-- Getter function for database
function RRT_Data.GetDB()
    if not db then
        db = InitializeSavedVariables()
    end
    return db
end

-- Helper function to check if player data is valid
local function IsValidPlayerData()
    local level = UnitLevel("player")
    local maxXP = UnitXPMax("player")
    
    -- Check if we have valid data
    if level <= 0 or maxXP <= 0 then
        return false
    end
    
    -- Check if we're actually in the game world (not at character select)
    if not UnitName("player") or UnitName("player") == "Unknown" then
        return false
    end
    
    return true
end

function RRT_Data.GetCurrentRestData()
    -- Check if we have valid player data
    if not IsValidPlayerData() then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Warning: Invalid player data, skipping save")
        end
        return nil
    end
    
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local rested = GetXPExhaustion() or 0
    local isInInn = IsResting()
    local isInCity = false
    
    -- Double-check data validity
    if maxXP <= 0 or currentXP < 0 then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Error: Invalid XP values - currentXP: " .. currentXP .. ", maxXP: " .. maxXP)
        end
        return nil
    end
    
    -- Check if we're in a major city (for rate calculation)
    local zone = GetZoneText()
    local isCapital = zone == "Stormwind" or zone == "Orgrimmar" or 
                      zone == "Ironforge" or zone == "Darnassus" or 
                      zone == "Undercity" or zone == "Thunder Bluff" or
                      zone == "Shattrath City" or zone == "Dalaran" or
                      zone == "Exodar" or zone == "Silvermoon City" or
                      zone == "Shrine of Two Moons" or zone == "Shrine of Seven Stars" or
                      zone == "Stormshield" or zone == "Warspear" or
                      zone == "Boralus" or zone == "Dazar'alor" or
                      zone == "Oribos" or zone == "Valdrakken"
    
    -- Calculate current XP percentage
    local xpPercent = 0
    if maxXP > 0 then
        xpPercent = math.floor((currentXP / maxXP) * 1000) / 10
    end
    
    -- Calculate rest percentage
    local restPercent = 0
    if maxXP > 0 and rested > 0 then
        restPercent = math.floor((rested / maxXP) * 1000) / 10
    end
    
    -- Get player class
    local _, class = UnitClass("player")
    
    -- Get server max level for THIS character's realm
    local serverMaxLevel = 70  -- Default fallback
    if RRT_Utilities and RRT_Utilities.GetServerMaxLevel then
        serverMaxLevel = RRT_Utilities.GetServerMaxLevel() or 70
    end
    local isMaxLevel = UnitLevel("player") == serverMaxLevel
    
    return {
        timestamp = time(),
        level = UnitLevel("player"),
        currentXP = currentXP,
        maxXP = maxXP,
        xpPercent = xpPercent,
        restedXP = rested,
        restPercent = restPercent,
        location = GetRealZoneText() or GetZoneText(),
        subLocation = GetSubZoneText(),
        isInInn = isInInn and 1 or 0,
        isInCity = isCapital and 1 or 0,
        zone = zone,
        isResting = isInInn,
        class = class or "UNKNOWN",
        isMaxLevel = isMaxLevel,
        serverMaxLevel = serverMaxLevel
    }
end

function RRT_Data.CalculateRestRate(loginData, logoutData)
    if not loginData or not logoutData then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Missing data for calculation")
        end
        return nil
    end
    
    -- Validate data
    if not loginData.maxXP or loginData.maxXP <= 0 or not logoutData.maxXP or logoutData.maxXP <= 0 then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Invalid XP data in calculation")
        end
        return nil
    end
    
    -- Time difference in seconds
    local timeDiff = loginData.timestamp - logoutData.timestamp
    if timeDiff <= 60 then  -- Less than 1 minute, ignore
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Time difference too small: " .. timeDiff .. " seconds")
        end
        return nil
    end
    
    -- Rest XP difference
    local restDiff = loginData.restedXP - logoutData.restedXP
    
    -- Handle level changes
    if loginData.level > logoutData.level then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Player leveled up from " .. logoutData.level .. " to " .. loginData.level)
        end
        -- Adjust calculation for level changes
        restDiff = loginData.restedXP  -- Got full new level's rest
    end
    
    -- If no rest XP gained or negative (shouldn't happen), return minimal data
    if restDiff < 0 then
        restDiff = 0
    end
    
    -- Calculate rates
    local timeHours = timeDiff / 3600
    local ratePerHour = restDiff / timeHours
    
    -- Calculate percentage per hour based on maxXP (matches UI calculation)
    local percentPerHour = 0
    if logoutData.maxXP > 0 then
        percentPerHour = ((restDiff / logoutData.maxXP) * 100) / timeHours
    end
    
    return {
        ratePerHour = ratePerHour,
        totalGained = restDiff,
        timeHours = timeHours,
        wasInInn = logoutData.isInInn == 1,
        wasInCity = logoutData.isInCity == 1,
        percentPerHour = percentPerHour,
        loginRestPercent = loginData.restPercent,
        logoutRestPercent = logoutData.restPercent,
        logoutLocation = logoutData.location,
        loginXP = loginData.currentXP,
        loginMaxXP = loginData.maxXP,
        logoutXP = logoutData.currentXP,
        logoutMaxXP = logoutData.maxXP
    }
end

local function GetCurrentRate(location)
    local restRates = {
        INN_CITY = 2.5,
        ELSEWHERE = 0.625
    }
    
    -- Try to get from config if available
    if RRT_Config and RRT_Config.GetRestRates then
        local configRates = RRT_Config.GetRestRates()
        if configRates then
            restRates = configRates
        end
    end
    
    local rate = 0
    
    if IsResting() then
        rate = restRates.INN_CITY
    elseif location and (location == "Stormwind" or location == "Orgrimmar" or 
           string.find(location, "City") or string.find(location, "Sanctuary") or
           location == "Ironforge" or location == "Darnassus" or 
           location == "Undercity" or location == "Thunder Bluff" or
           location == "Shattrath City" or location == "Dalaran") then
        rate = restRates.INN_CITY
    else
        rate = restRates.ELSEWHERE
    end
    
    return rate
end

function RRT_Data.CalculateTimeToFull(currentPercent, customRate, location)
    -- Use custom rate if provided, otherwise get appropriate rate for location
    local ratePerHour = customRate or GetCurrentRate(location)
    
    local fullRestPercent = 150  -- Default value
    if RRT_Config and RRT_Config.GetFullRestPercent then
        fullRestPercent = RRT_Config.GetFullRestPercent() or 150
    end
    
    local percentNeeded = fullRestPercent - currentPercent
    if percentNeeded <= 0 then
        return 0, ratePerHour  -- Already at full rest
    end
    
    local hoursNeeded = percentNeeded / ratePerHour
    local secondsNeeded = hoursNeeded * 3600
    
    return secondsNeeded, ratePerHour
end

function RRT_Data.ShowRestReport(rateData)
    if not rateData then return end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Rest Rate Tracker]|r Offline Rest Report:")
    
    -- Format time safely
    local timeText = "Unknown time"
    if RRT_Utilities and RRT_Utilities.FormatTime then
        timeText = RRT_Utilities.FormatTime(rateData.timeHours * 3600)
    else
        timeText = string.format("%.1f hours", rateData.timeHours)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAAOffline Time:|r " .. timeText)
    
    if rateData.totalGained > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAARested XP Gained:|r " .. rateData.totalGained .. " XP")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAARate:|r " .. string.format("%.1f XP/hour", rateData.ratePerHour))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAAPercent/Hour:|r " .. string.format("%.2f%%", rateData.percentPerHour) .. " of level")
        
        -- Show actual measured rate more prominently
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00✓ Measured Rate:|r " .. string.format("%.2f%%/hour", rateData.percentPerHour) .. " (actual)")
        
        if rateData.wasInInn then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[I]|r Logged out in inn/rest area")
        elseif rateData.wasInCity then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[C]|r Logged out in city (rest area)")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[W]|r Logged out in non-rested area")
        end
        
        -- Show accuracy note
        if rateData.timeHours < 1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Note:|r Rate estimate based on " .. 
                string.format("%.0f minutes", rateData.timeHours * 60) .. " - less accurate")
        elseif rateData.timeHours < 4 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Note:|r Rate estimate based on " .. 
                string.format("%.1f hours", rateData.timeHours) .. " - moderately accurate")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Note:|r Rate estimate based on " .. 
                string.format("%.1f hours", rateData.timeHours) .. " - good accuracy")
        end
        
        -- Show time to full based on default rate
        local db = RRT_Data.GetDB()
        if db.settings.showTimeToFull then
            local currentPercent = rateData.loginRestPercent
            local currentRate = rateData.percentPerHour
            local location = GetRealZoneText()
            
            local secondsToFull, effectiveRate = RRT_Data.CalculateTimeToFull(currentPercent, currentRate, location)
            
            if secondsToFull > 0 then
                local fullTimeText = "Unknown time"
                if RRT_Utilities and RRT_Utilities.FormatTime then
                    fullTimeText = RRT_Utilities.FormatTime(secondsToFull)
                else
                    fullTimeText = string.format("%.1f hours", secondsToFull / 3600)
                end
                
                DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAATime to full rest:|r " .. fullTimeText .. 
                    " (at " .. string.format("%.2f%%/hour", effectiveRate) .. ")")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00✓|r You have full rested XP!") 
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000No rest XP gained while offline|r")
        if not rateData.wasInInn and not rateData.wasInCity then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000You were not in a rested area!|r")
        end
    end
    
    -- Store in history
    local db = RRT_Data.GetDB()
    table.insert(db.history, 1, {
        timestamp = time(),
        rateData = rateData,
        location = rateData.logoutLocation or GetMinimapZoneText(),
        xpValues = {
            loginXP = rateData.loginXP,
            loginMaxXP = rateData.loginMaxXP,
            logoutXP = rateData.logoutXP,
            logoutMaxXP = rateData.logoutMaxXP
        },
        class = UnitClass("player")  -- Add class to history
    })
    
    -- Keep only last 50 entries
    while #db.history > 50 do
        table.remove(db.history)
    end
end

-- Function to clean up invalid saved data
function RRT_Data.CleanupSavedData()
    local db = RRT_Data.GetDB()
    if RRT_Utilities and RRT_Utilities.DebugPrint then
        RRT_Utilities.DebugPrint("Cleaning up saved data...")
    end
    
    -- Clean up invalid logout data
    local removedCount = 0
    for charKey, data in pairs(db.logoutData) do
        if not data or not data.maxXP or data.maxXP <= 0 then
            if RRT_Utilities and RRT_Utilities.DebugPrint then
                RRT_Utilities.DebugPrint("Removing invalid data for: " .. charKey)
            end
            db.logoutData[charKey] = nil
            removedCount = removedCount + 1
        end
    end
    
    -- Clean up invalid history entries
    for i = #db.history, 1, -1 do
        local entry = db.history[i]
        if not entry or not entry.rateData or not entry.rateData.logoutMaxXP or entry.rateData.logoutMaxXP <= 0 then
            table.remove(db.history, i)
            if RRT_Utilities and RRT_Utilities.DebugPrint then
                RRT_Utilities.DebugPrint("Removed invalid history entry")
            end
            removedCount = removedCount + 1
        end
    end
    
    return removedCount
end

-- Function to save current character's data (with optional silent mode)
function RRT_Data.SaveCurrentCharacterData(silent)
    -- Get current character info
    local db = RRT_Data.GetDB()
    local currentName = UnitName("player")
    local currentRealm = GetRealmName()
    
    if not currentName or currentName == "Unknown" or not currentRealm then
        if RRT_Utilities and RRT_Utilities.DebugPrint then
            RRT_Utilities.DebugPrint("Cannot save data: Invalid player info")
        end
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Cannot save data: Invalid player info")
        end
        return false
    end
    
    -- Clean realm name (remove spaces from formatting)
    currentRealm = currentRealm:gsub("%s+", " ")  -- Replace multiple spaces with single space
    currentRealm = currentRealm:trim()  -- Remove leading/trailing spaces
    
    -- Create character key - use the same format as WoW uses
    local charKey = currentName .. "-" .. currentRealm
    local data = RRT_Data.GetCurrentRestData()
    
    if data and data.maxXP and data.maxXP > 0 then
        db.logoutData[charKey] = data
        
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r ✓ Saved data for: " .. charKey .. 
                       " (Level: " .. data.level .. 
                       ", XP: " .. data.currentXP .. "/" .. data.maxXP .. 
                       ", Rest: " .. data.restedXP .. ")")
            
            -- Debug: Show all saved characters
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r All saved characters:")
            local count = 0
            for key, savedData in pairs(db.logoutData) do
                count = count + 1
                DEFAULT_CHAT_FRAME:AddMessage("  " .. count .. ". " .. key .. " - Level: " .. (savedData.level or "nil"))
            end
        end
        
        return true
    else
        if not silent then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Failed to save data for " .. charKey .. " - invalid data")
        end
        return false
    end
end

-- Slash command handler function (simplified version for now)
function RRT_Data.HandleCommand(msg)
    local db = RRT_Data.GetDB()
    local command, arg = strsplit(" ", strlower(msg or ""), 2)
    
    if command == "debug" then
        db.settings.debugMode = not db.settings.debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT] Debug mode: |r" .. (db.settings.debugMode and "ON" or "OFF"))
        
    elseif command == "xp" or command == "details" then
        local data = RRT_Data.GetCurrentRestData()
        if not data then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Could not get XP data. Try again in a moment.")
            return
        end
        
        -- Check if player is at max level
        local serverMaxLevel = 70  -- Default for Area 52
        if RRT_Utilities and RRT_Utilities.GetServerMaxLevel then
            serverMaxLevel = RRT_Utilities.GetServerMaxLevel() or 70
        end
        
        if data.level == serverMaxLevel then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Character at max level (Level " .. serverMaxLevel .. ")")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00XP tracking is disabled for max level characters.|r")
            return
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Detailed XP Information:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAALevel:|r " .. data.level .. " (Server Max: " .. serverMaxLevel .. ")")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAACurrent XP:|r " .. data.currentXP .. " / " .. data.maxXP .. 
            " (" .. data.xpPercent .. "%)")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAARested XP:|r " .. data.restedXP .. " / " .. math.floor(data.maxXP * 1.5))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAAPercent Rested:|r " .. data.restPercent .. "% of level")
        
        -- Calculate XP to next level
        local xpToLevel = data.maxXP - data.currentXP
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAAXP to Next Level:|r " .. xpToLevel .. " XP")
        
        -- Calculate how much rested XP can be used
        local usableRested = math.min(data.restedXP, xpToLevel)
        if xpToLevel > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAARested XP Usable:|r " .. usableRested .. " XP (" .. 
                math.floor((usableRested / xpToLevel) * 100) .. "% of needed XP)")
        end
        
        -- Show location info
        local isRestingText = data.isResting and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"
        local isCityText = data.isInCity == 1 and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAALocation:|r " .. data.location .. " (" .. (data.subLocation or "none") .. ")")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAAResting:|r " .. isRestingText)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAACity:|r " .. isCityText)
        
    elseif command == "save" then
        local success = RRT_Data.SaveCurrentCharacterData()
        if success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Saved current character data.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Failed to save character data.")
        end
        
    elseif command == "frame" or command == "show" then
        if RRT_UI and RRT_UI.ShowAllCharacterData then
            RRT_UI.ShowAllCharacterData()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r UI module not loaded")
        end
        
    elseif command == "help" or command == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA/rrt|r - Show this help")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA/rrt xp|r - Show detailed XP information")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA/rrt save|r - Force save current character data")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA/rrt debug|r - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA/rrt frame|r - Show character data frame")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA(More commands coming soon)|r")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RRT]|r Unknown command. Type |cFF00FF00/rrt help|r for commands.")
    end
end