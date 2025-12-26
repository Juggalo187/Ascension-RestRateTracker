-- RestRateTracker Utilities Module
RRT_Utilities = RRT_Utilities or {}

-- Import config
local RRT_Config = RRT_Config or {}

-- Function to properly split character key into name and realm
function RRT_Utilities.SplitCharacterKey(charKey)
    -- Find the last hyphen in the string (character names can have hyphens too)
    -- Character keys are stored as "Name-Realm"
    local lastHyphen = charKey:find("-[^-]*$")
    
    if lastHyphen then
        local name = charKey:sub(1, lastHyphen - 1)
        local realm = charKey:sub(lastHyphen + 1)
        return name, realm
    end
    
    -- Fallback: try to split by first hyphen (old method)
    local name, realm = strsplit("-", charKey, 2)
    return name or charKey, realm or "Unknown Realm"
end

-- Add trim function if it doesn't exist
if not string.trim then
    function string.trim(str)
        return str:match("^%s*(.-)%s*$")
    end
end

function RRT_Utilities.GetProperRealmName(displayName)
    if not displayName then return "Unknown Realm" end
    
    displayName = displayName:lower():trim()
    
    -- Map display names to proper server names
    if displayName:find("warcraft reborn") then
        return "Bronzebeard"
    elseif displayName:find("pick") then
        return "Area 52"
    elseif displayName:find("elune") then
        return "Elune"
    elseif displayName:find("rexxar") then
        return "Rexxar"
    elseif displayName:find("grizzly hills") or displayName:find("grizzlyhills") then
        return "Grizzly Hills"
    elseif displayName:find("ptr") then
        return "PTR"
    else
        -- Return the original display name, but capitalized properly
        return displayName:gsub("^%l", string.upper):gsub(" %l", string.upper)
    end
end

function RRT_Utilities.NormalizeRealmName(realmName)
    if not realmName then return "Unknown" end
    
    realmName = realmName:lower():trim()
    
    -- Remove common suffixes first
    realmName = realmName:gsub("%-free$", "")
    realmName = realmName:gsub("%-ptr$", "")
    realmName = realmName:gsub("%-test$", "")
    
    -- Normalize all variations to the same display name
    if realmName:find("bronzebeard") or realmName:find("warcraft reborn") then
        return "Bronzebeard"
    elseif realmName:find("area 52") or realmName:find("area52") or realmName:find("pick") then
        return "Area 52"
    elseif realmName:find("elune") then
        return "Elune"
    elseif realmName:find("rexxar") then
        return "Rexxar"
    elseif realmName:find("grizzly hills") or realmName:find("grizzlyhills") then
        return "Grizzly Hills"
    elseif realmName:find("ptr") then
        return "PTR"
    else
        -- Return the original name capitalized properly
        return realmName:gsub("^%l", string.upper):gsub(" %l", string.upper)
    end
end

function RRT_Utilities.GetClassColor(class)
    local CLASS_COLORS = RRT_Config.GetClassColors()
    if class and CLASS_COLORS[class] then
        local color = CLASS_COLORS[class]
        return string.format("|cFF%02x%02x%02x", 
            math.floor(color.r * 255), 
            math.floor(color.g * 255), 
            math.floor(color.b * 255))
    end
    return "|cFFFFFFFF"  -- Default white
end

function RRT_Utilities.DebugPrint(msg)
    local RRT_Data = RRT_Data or {}
    if RRT_Data.GetDB then
        local db = RRT_Data.GetDB()
        if db and db.settings and db.settings.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[RRT Debug]:|r " .. msg)
        end
    end
end

function RRT_Utilities.GetServerMaxLevel(realmName)
    -- If no realm provided, use current realm
    if not realmName then
        realmName = GetRealmName() or ""
    end
    
    realmName = realmName:lower():trim()
    RRT_Utilities.DebugPrint("Checking realm for max level: " .. realmName)
    
    -- Static max level assignments - handle both display names and actual server names
    if realmName:find("bronzebeard") or realmName:find("warcraft reborn") then
        RRT_Utilities.DebugPrint("Detected Bronzebeard/Warcraft Reborn server: 60")
        return 60
    elseif realmName:find("area 52") or realmName:find("area52") or realmName:find("pick") then
        RRT_Utilities.DebugPrint("Detected Area 52/Pick server: 70")
        return 70
    elseif realmName:find("elune") then
        RRT_Utilities.DebugPrint("Detected Elune server: 70")
        return 70
    elseif realmName:find("rexxar") then
        RRT_Utilities.DebugPrint("Detected Rexxar server: 55")
        return 55
    elseif realmName:find("grizzly hills") or realmName:find("grizzlyhills") then
        RRT_Utilities.DebugPrint("Detected Grizzly Hills server: 80")
        return 80
    elseif realmName:find("ptr") then
        RRT_Utilities.DebugPrint("Detected PTR server, using 60")
        return 60
    end
    
    -- Default fallback for unknown servers
    RRT_Utilities.DebugPrint("Unknown server, using fallback max level: 60")
    return 60
end

function RRT_Utilities.FormatTime(seconds)
    if not seconds or seconds <= 0 then return "0 seconds" end
    
    if seconds < 60 then
        return string.format("%.0f seconds", seconds)
    elseif seconds < 3600 then
        local minutes = seconds / 60
        return string.format("%.0f minutes", minutes)
    elseif seconds < 86400 then
        local hours = seconds / 3600
        if hours < 10 then
            return string.format("%.1f hours", hours)
        else
            return string.format("%.0f hours", hours)
        end
    else
        local days = seconds / 86400
        if days < 10 then
            return string.format("%.1f days", days)
        else
            return string.format("%.0f days", days)
        end
    end
end

function RRT_Utilities.FormatTimeShort(hours)
    if hours < 1 then
        return string.format("%.0fm", hours * 60)
    elseif hours < 24 then
        return string.format("%.1fh", hours)
    else
        return string.format("%.1fd", hours / 24)
    end
end