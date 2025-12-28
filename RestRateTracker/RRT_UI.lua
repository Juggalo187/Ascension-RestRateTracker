-- RestRateTracker UI Module
RRT_UI = RRT_UI or {}

-- Import modules
local RRT_Config = RRT_Config or {}
local RRT_Utilities = RRT_Utilities or {}
local RRT_Data = RRT_Data or {}

-- Global sort mode (should be in main, but referenced here)
RRT_SORT_MODE = RRT_SORT_MODE or "name"

-- Create data display frame
local dataFrame = nil
function RRT_UI.CreateDataDisplayFrame()
    if dataFrame then return dataFrame end
    
    dataFrame = CreateFrame("Frame", "RRTDataFrame", UIParent)
    dataFrame:SetSize(750, 500)
    dataFrame:SetPoint("CENTER")
    dataFrame:SetFrameStrata("HIGH")
    dataFrame:SetMovable(true)
    dataFrame:EnableMouse(true)
    dataFrame:RegisterForDrag("LeftButton")
    dataFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dataFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Black background with thin grey outline
    dataFrame.bg = dataFrame:CreateTexture(nil, "BACKGROUND")
    dataFrame.bg:SetAllPoints(true)
    dataFrame.bg:SetColorTexture(0, 0, 0, 1)
    
    -- Thin grey border (1 pixel)
    dataFrame.border = CreateFrame("Frame", nil, dataFrame)
    dataFrame.border:SetPoint("TOPLEFT", -1, 1)
    dataFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    dataFrame.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    dataFrame.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title
    dataFrame.title = dataFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dataFrame.title:SetPoint("TOP", 0, -10)
    dataFrame.title:SetText("|cFF00FF00Rest Rate Tracker - All Characters|r")
    dataFrame.title:SetTextColor(1, 1, 1)
    
    -- Close button
    dataFrame.closeButton = CreateFrame("Button", nil, dataFrame, "UIPanelCloseButton")
    dataFrame.closeButton:SetPoint("TOPRIGHT", 0, 0)
    dataFrame.closeButton:SetSize(32, 32)
    dataFrame.closeButton:SetScript("OnClick", function() dataFrame:Hide() end)
    
    -- Filter edit box
    dataFrame.filterEdit = CreateFrame("EditBox", "RRTFilterEdit", dataFrame, "InputBoxTemplate")
    dataFrame.filterEdit:SetSize(180, 20)
    dataFrame.filterEdit:SetPoint("TOPLEFT", 10, -35)
    dataFrame.filterEdit:SetAutoFocus(false)
    dataFrame.filterEdit:SetText("")
    dataFrame.filterEdit:SetScript("OnTextChanged", function(self)
        local db = RRT_Data.GetDB()
        if db then
            db.settings.filterText = self:GetText()
            RRT_UI.ShowAllCharacterData()
        end
    end)
    dataFrame.filterEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Filter Characters", 1, 1, 1)
        GameTooltip:AddLine("Type to filter by name, realm, or location", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Press Escape to clear", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    dataFrame.filterEdit:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Filter label
    dataFrame.filterLabel = dataFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataFrame.filterLabel:SetPoint("BOTTOMLEFT", dataFrame.filterEdit, "TOPLEFT", 0, 2)
    dataFrame.filterLabel:SetText("|cFFAAAAAAFilter:|r")
    dataFrame.filterLabel:SetTextColor(0.8, 0.8, 0.8)
    
    -- Clear filter button
    dataFrame.clearFilterButton = CreateFrame("Button", nil, dataFrame, "UIPanelButtonTemplate")
    dataFrame.clearFilterButton:SetSize(60, 20)
    dataFrame.clearFilterButton:SetPoint("LEFT", dataFrame.filterEdit, "RIGHT", 5, 0)
    dataFrame.clearFilterButton:SetText("Clear")
    dataFrame.clearFilterButton:SetScript("OnClick", function()
        dataFrame.filterEdit:SetText("")
        dataFrame.filterEdit:ClearFocus()
        local db = RRT_Data.GetDB()
        if db then
            db.settings.filterText = ""
        end
        RRT_UI.ShowAllCharacterData()
    end)
    
    -- Compact mode toggle
    dataFrame.compactButton = CreateFrame("Button", nil, dataFrame, "UIPanelButtonTemplate")
    dataFrame.compactButton:SetSize(100, 20)
    dataFrame.compactButton:SetPoint("TOPLEFT", dataFrame.filterEdit, "BOTTOMLEFT", 0, -10)
    dataFrame.compactButton:SetText("Compact: OFF")
    dataFrame.compactButton:SetScript("OnClick", function()
        local db = RRT_Data.GetDB()
        if db then
            db.settings.frameCompactMode = not db.settings.frameCompactMode
            dataFrame.compactButton:SetText("Compact: " .. (db.settings.frameCompactMode and "ON" or "OFF"))
            RRT_UI.ShowAllCharacterData()
        end
    end)
    
    -- Scroll frame
    dataFrame.scrollFrame = CreateFrame("ScrollFrame", "RRTDataScrollFrame", dataFrame, "UIPanelScrollFrameTemplate")
    dataFrame.scrollFrame:SetPoint("TOPLEFT", 10, -90)
    dataFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    -- Scroll child
    dataFrame.scrollChild = CreateFrame("Frame", nil, dataFrame.scrollFrame)
    dataFrame.scrollChild:SetSize(700, 1)
    dataFrame.scrollFrame:SetScrollChild(dataFrame.scrollChild)
    
    -- Footer with summary
    dataFrame.footer = dataFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataFrame.footer:SetPoint("BOTTOMLEFT", 10, 10)
    dataFrame.footer:SetText("")
    dataFrame.footer:SetTextColor(0.8, 0.8, 0.8)
    
    return dataFrame
end

-- Function to show character data in the frame
-- Function to show character data in the frame
function RRT_UI.ShowAllCharacterData()
    local db = RRT_Data.GetDB()
    if not db then return end
    
    -- Get rest rates at the beginning of the function
    local restRates = RRT_Config.GetRestRates() or {INN_CITY = 2.5, ELSEWHERE = 0.625}
    
    local frame = RRT_UI.CreateDataDisplayFrame()
    
    -- Update compact button text
    frame.compactButton:SetText("Compact: " .. (db.settings.frameCompactMode and "ON" or "OFF"))
    
    -- Update filter text
    frame.filterEdit:SetText(db.settings.filterText or "")
    
    -- Clear previous content by recreating scroll child
    if frame.scrollChild then
        local scrollChild = frame.scrollChild
        frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
        frame.scrollChild:SetSize(700, 1)
        frame.scrollFrame:SetScrollChild(frame.scrollChild)
        scrollChild:Hide()
        scrollChild:ClearAllPoints()
    else
        frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
        frame.scrollChild:SetSize(700, 1)
        frame.scrollFrame:SetScrollChild(frame.scrollChild)
    end
    
    local yOffset = -10
    local contentHeight = 0
    
    -- Add header with background
    local headerBG = frame.scrollChild:CreateTexture(nil, "BACKGROUND")
    headerBG:SetPoint("TOPLEFT", 5, yOffset + 5)
    headerBG:SetPoint("TOPRIGHT", -5, yOffset - 20)
    headerBG:SetColorTexture(0.1, 0.1, 0.1, 1)
    
    -- Column headers with better spacing
    local headerButton = CreateFrame("Button", nil, frame.scrollChild)
    headerButton:SetPoint("TOPLEFT", 10, yOffset)
    headerButton:SetSize(680, 20)
    
    local headerText
    if db.settings.frameCompactMode then
		headerText = "|cFFFFAA00Character|r | |cFF00FFFFLvl|r | |cFFFFFF00R%|r | |cFF00AAFFLoc|r | |cFF00FF00Rate|r | To Full | |cFFFFFF00S|r | |cFF00FFFFWR|r"
	else
		headerText = "|cFFFFAA00Character|r | |cFF00FFFFLvl|r | |cFFFFFF00RXP|r | |cFF00FF00%|r | |cFF00AAFFLocation|r | |cFFFFFF00Time|r | |cFF00FF00Rate|r | To Full | |cFFFFFF00Status|r | |cFF00FFFFWR|r"
	end
    
    local headers = headerButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headers:SetAllPoints()
    headers:SetText(headerText)
    headers:SetTextColor(1, 1, 1)
    
    -- Make headers clickable for sorting
    headerButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- Cycle through sort modes
            if RRT_SORT_MODE == "name" then
                RRT_SORT_MODE = "level"
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Sorting by Level")
            elseif RRT_SORT_MODE == "level" then
                RRT_SORT_MODE = "rested"
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Sorting by Rested %")
            elseif RRT_SORT_MODE == "rested" then
                RRT_SORT_MODE = "realm"
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Sorting by Realm")
            elseif RRT_SORT_MODE == "realm" then
                RRT_SORT_MODE = "time"
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Sorting by Time")
            else
                RRT_SORT_MODE = "name"
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Sorting by Name")
            end
            RRT_UI.ShowAllCharacterData()
        end
    end)
    
    headerButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Click to change sort order", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. RRT_SORT_MODE, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    headerButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    yOffset = yOffset - 25
    contentHeight = contentHeight + 25
    
    -- Header separator line
    local separator = frame.scrollChild:CreateTexture(nil, "OVERLAY")
    separator:SetPoint("TOPLEFT", 5, yOffset)
    separator:SetPoint("TOPRIGHT", -5, yOffset)
    separator:SetHeight(1)
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    yOffset = yOffset - 10
    contentHeight = contentHeight + 10
    
    -- Get and sort characters
    local characters = {}
    local filterText = (db.settings.filterText or ""):lower()
    
    for charKey, data in pairs(db.logoutData) do
        if data and data.maxXP and data.maxXP > 0 then
            -- Apply filter
            if filterText == "" or 
               charKey:lower():find(filterText, 1, true) or
               (data.location and data.location:lower():find(filterText, 1, true)) then
                table.insert(characters, {key = charKey, data = data})
            end
        end
    end
    
    -- Sort based on current sort mode
    table.sort(characters, function(a, b)
        local nameA, realmA = RRT_Utilities.SplitCharacterKey(a.key)
        local nameB, realmB = RRT_Utilities.SplitCharacterKey(b.key)
        
        -- NORMALIZE realm names for comparison
        local normalizedRealmA = RRT_Utilities.NormalizeRealmName(realmA)
        local normalizedRealmB = RRT_Utilities.NormalizeRealmName(realmB)
        
        if RRT_SORT_MODE == "level" then
            if a.data.level ~= b.data.level then
                return a.data.level > b.data.level  -- Higher level first
            end
            -- If same level, sort by normalized realm, then name
            if normalizedRealmA ~= normalizedRealmB then
                return normalizedRealmA < normalizedRealmB
            end
            return nameA < nameB
        elseif RRT_SORT_MODE == "rested" then
            if a.data.restPercent ~= b.data.restPercent then
                return a.data.restPercent > b.data.restPercent  -- Higher rested % first
            end
            -- If same rested %, sort by normalized realm, then name
            if normalizedRealmA ~= normalizedRealmB then
                return normalizedRealmA < normalizedRealmB
            end
            return nameA < nameB
        elseif RRT_SORT_MODE == "realm" then
            -- Sort by NORMALIZED realm name
            if normalizedRealmA ~= normalizedRealmB then
                return normalizedRealmA < normalizedRealmB
            end
            return nameA < nameB
        elseif RRT_SORT_MODE == "time" then
            if a.data.timestamp and b.data.timestamp then
                return a.data.timestamp > b.data.timestamp  -- Most recent first
            end
            -- If same timestamp, sort by normalized realm, then name
            if normalizedRealmA ~= normalizedRealmB then
                return normalizedRealmA < normalizedRealmB
            end
            return nameA < nameB
        else  -- "name" or default
            -- For name sort, still group by normalized realm first
            if normalizedRealmA ~= normalizedRealmB then
                return normalizedRealmA < normalizedRealmB
            end
            return nameA < nameB
        end
    end)
    
    -- Show current character first in name sort mode
    if RRT_SORT_MODE == "name" then
        local currentName = UnitName("player")
        local currentRealm = GetRealmName()
        local currentCharKey = currentName and currentRealm and currentName .. "-" .. currentRealm
        
        if currentCharKey then
            for i, char in ipairs(characters) do
                if char.key == currentCharKey then
                    table.remove(characters, i)
                    table.insert(characters, 1, char)
                    break
                end
            end
        end
    end
    
    -- Track realms for grouping - ALWAYS group by realm regardless of compact mode
    local lastRealm = nil
    local displayedCount = 0
    
    -- Display each character
    for i, char in ipairs(characters) do
        local data = char.data
        local charName, realm = RRT_Utilities.SplitCharacterKey(char.key)
        charName = string.match(charName, "^([^-]+)") or charName
        
        -- Calculate estimated current values based on elapsed time
        local estimatedRestPercent = data.restPercent or 0
        local estimatedRestedXP = data.restedXP or 0
        local elapsedHours = 0
        local estimatedWellRestedRemaining = data.wellRestedRemaining or 0
        
        if data.timestamp and not data.isMaxLevel then
            local timeDiff = time() - data.timestamp
            elapsedHours = timeDiff / 3600
            
            -- Only update if we have valid data
            if data.maxXP and data.maxXP > 0 then
                local rate = 0
                if data.isInInn == 1 or data.isInCity == 1 then
                    rate = restRates.INN_CITY
                else
                    rate = restRates.ELSEWHERE
                end
                
                -- Calculate accumulated rest percentage
                local accumulatedPercent = rate * elapsedHours
                
                -- Update estimated values
                estimatedRestPercent = math.min(150, (data.restPercent or 0) + accumulatedPercent)
                
                -- Calculate estimated rested XP (percentage of maxXP)
                estimatedRestedXP = math.floor((estimatedRestPercent / 100) * data.maxXP)
            end
            
            -- Also estimate Well Rested buff remaining
            if estimatedWellRestedRemaining > 0 and elapsedHours > 0 then
                estimatedWellRestedRemaining = math.max(0, estimatedWellRestedRemaining - (elapsedHours * 3600))
            end
        end
        
        -- ALWAYS group by realm (even in compact mode)
        if realm ~= lastRealm then
            -- Add realm header with background
            local realmBG = frame.scrollChild:CreateTexture(nil, "BACKGROUND")
            realmBG:SetPoint("TOPLEFT", 5, yOffset + 2)
            realmBG:SetPoint("TOPRIGHT", -5, yOffset - 18)
            realmBG:SetColorTexture(0.15, 0.15, 0.15, 1)
            
            -- Get proper realm name for display
            local properRealm = RRT_Utilities.GetProperRealmName(realm)
            
            local realmHeader = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            realmHeader:SetPoint("TOPLEFT", 10, yOffset)
            realmHeader:SetText("|cFFFFAA00" .. properRealm .. "|r")
            realmHeader:SetTextColor(0.8, 0.8, 0.8)
            yOffset = yOffset - 20
            contentHeight = contentHeight + 20
            lastRealm = realm
        end
        
        -- Alternating row background
        if displayedCount % 2 == 0 then
            local rowBG = frame.scrollChild:CreateTexture(nil, "BACKGROUND")
            rowBG:SetPoint("TOPLEFT", 5, yOffset + 2)
            rowBG:SetPoint("BOTTOMRIGHT", -5, yOffset - 18)
            rowBG:SetColorTexture(0.15, 0.15, 0.15, 1)
        end
        
        -- Create character entry as a button for tooltips
        local entryButton = CreateFrame("Button", nil, frame.scrollChild)
        entryButton:SetPoint("TOPLEFT", 10, yOffset)
        entryButton:SetSize(680, 18)
        
        -- Create the text display inside the button
        local entry = entryButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        entry:SetAllPoints()
        entry:SetJustifyH("LEFT")
        
        -- Get class color
        local className = data.class or "UNKNOWN"
        local classColor = RRT_Utilities.GetClassColor(className)
        
        -- Highlight current character
        local currentName = UnitName("player")
        local currentRealm = GetRealmName()
        local currentCharKey = currentName and currentRealm and currentName .. "-" .. currentRealm
        
        if char.key == currentCharKey then
            charName = "|cFFFFFF00>>|r " .. classColor .. charName .. "|r |cFFFFFF00<<|r"
        else
            charName = classColor .. charName .. "|r"
        end
        
        -- Use saved max level status from character data
        local isMaxLevel = data.isMaxLevel == true
        
        -- Format columns based on compact mode and max level status
        local line
        if isMaxLevel then
            -- Max level characters: show only name and level with MAX indicator
            local levelText = string.format("|cFF00FFFF%2d|r", data.level or 0)
            local locationText = string.format("|cFF00AAFF%-1s|r", (data.location or "Unknown"):sub(1, 30))
            if db.settings.frameCompactMode then
                line = string.format("%-18s | %s | |cFFAAAAAAMAX|r | %s |", charName, levelText, locationText)
            else
                line = string.format("%-18s | %s | |cFFAAAAAAMAX|r | %s |", charName, levelText, locationText)
            end
        else
            -- Non-max level characters: show full information
            if db.settings.frameCompactMode then
                -- Compact mode: shorter columns
                local levelText = string.format("|cFF00FFFF%1d|r", data.level or 0)
                local percentText = string.format("|cFFFFFF00%1d%%|r", math.floor(estimatedRestPercent))
                local locationText = string.format("|cFF00AAFF%-1s|r", (data.location or "Unknown"):sub(1, 30))
                
                -- Time since last save
                local timeText = "|cFFFFAA00Now|r"
                if data.timestamp then
                    local timeDiff = time() - data.timestamp
                    if timeDiff > 0 then
                        if timeDiff < 60 then
                            timeText = string.format("|cFFFFFF00%1ds|r", timeDiff)
                        elseif timeDiff < 3600 then
                            timeText = string.format("|cFFFFFF00%1dm|r", math.floor(timeDiff / 60))
                        elseif timeDiff < 86400 then
                            local hours = math.floor(timeDiff / 3600)
                            local minutes = math.floor((timeDiff % 3600) / 60)
                            timeText = string.format("|cFFFFFF00%dh%02d|r", hours, minutes)
                        else
                            local days = math.floor(timeDiff / 86400)
                            local hours = math.floor((timeDiff % 86400) / 3600)
                            timeText = string.format("|cFFFFFF00%dd%dh|r", days, hours)
                        end
                    end
                end
                
                -- Get rate
                local rate = 0
                if data.isInInn == 1 or data.isInCity == 1 then
                    rate = restRates.INN_CITY
                else
                    rate = restRates.ELSEWHERE
                end
                local rateText = string.format("|cFF00FF00%1.2f%%|r", rate)
                
                -- Calculate time to full rest - UPDATED: accounts for elapsed time since logout
                local toFullText = "|cFF00FF00FULL|r"
                if estimatedRestPercent < 150 then
                    local hoursToFull = (150 - estimatedRestPercent) / rate
                    
                    if hoursToFull < 24 then
                        local hours = math.floor(hoursToFull)
                        local minutes = math.floor((hoursToFull - hours) * 60)
                        if hours > 0 then
                            toFullText = string.format("|cFFFFAA00%dh%02dm|r", hours, minutes)
                        else
                            toFullText = string.format("|cFFFF0000%dm|r", minutes)
                        end
                    else
                        local days = math.floor(hoursToFull / 24)
                        local remainingHours = hoursToFull % 24
                        local hours = math.floor(remainingHours)
                        local minutes = math.floor((remainingHours - hours) * 60)
                        toFullText = string.format("|cFF00AAFF%dd%dh%02dm|r", days, hours, minutes)
                    end
                end
                
                -- Status icon (single character)
                local statusIcon = "|cFFFF0000[World]|r"
                if data.isInInn == 1 then
                    statusIcon = "|cFF00FF00[Inn]|r"
                elseif data.isInCity == 1 then
                    statusIcon = "|cFF00FF00[City]|r"
                end
                
                -- Add Well Rested status column
				local wellRestedText = "|cFFAAAAAA-|r"
				if data.hasWellRested == 1 then
					if estimatedWellRestedRemaining > 0 then
						local remaining = estimatedWellRestedRemaining
						if remaining > 3600 then
							local hours = math.floor(remaining / 3600)
							local minutes = math.floor((remaining % 3600) / 60)
							wellRestedText = string.format("|cFF00FFFFBuffed[%dh%02dm]|r", hours, minutes)
						else
							local minutes = math.ceil(remaining / 60)
							wellRestedText = string.format("|cFF00FFFFBuffed[%dm]|r", minutes)
						end
					else
						wellRestedText = "|cFF00FFFFBuffed|r"
					end
				end
				
				-- Add the icon to the end of the compact mode line
				line = string.format("%-18s | %s | %s | %s | %s | %-12s | %s | %s",
					charName, levelText, percentText, locationText, rateText, toFullText, statusIcon, wellRestedText)
					
            else
                -- Full mode: detailed columns
                local levelText = string.format("|cFF00FFFF%1d|r", data.level or 0)
                local restedText = string.format("|cFFFFFF00%1d|r", estimatedRestedXP)
                local percentText = string.format("|cFF00FF00%1d%%|r", math.floor(estimatedRestPercent))
                local locationText = string.format("|cFF00AAFF%-1s|r", (data.location or "Unknown"):sub(1, 30))
                
                -- Time since last save
                local timeText = "|cFFFFAA00Now|r"
                if data.timestamp then
                    local timeDiff = time() - data.timestamp
                    if timeDiff > 0 then
                        if timeDiff < 60 then
                            timeText = string.format("|cFFFFFF00%1ds|r", timeDiff)
                        elseif timeDiff < 3600 then
                            timeText = string.format("|cFFFFFF00%1dm|r", math.floor(timeDiff / 60))
                        elseif timeDiff < 86400 then
                            local hours = math.floor(timeDiff / 3600)
                            local minutes = math.floor((timeDiff % 3600) / 60)
                            timeText = string.format("|cFFFFFF00%dh%02dm|r", hours, minutes)
                        else
                            local days = math.floor(timeDiff / 86400)
                            local hours = math.floor((timeDiff % 86400) / 3600)
                            local minutes = math.floor(((timeDiff % 86400) % 3600) / 60)
                            timeText = string.format("|cFFFFFF00%dd%dh%02dm|r", days, hours, minutes)
                        end
                    end
                end
                
                -- Get rate
                local rate = 0
                if data.isInInn == 1 or data.isInCity == 1 then
                    rate = restRates.INN_CITY
                else
                    rate = restRates.ELSEWHERE
                end
                local rateText = string.format("|cFF00FF00%1.2f%%|r", rate)
                
                -- Calculate time to full rest - UPDATED: accounts for elapsed time since logout
                local toFullText = "|cFF00FF00FULL|r"
                if estimatedRestPercent < 150 then
                    local hoursToFull = (150 - estimatedRestPercent) / rate
                    
                    if hoursToFull < 24 then
                        local hours = math.floor(hoursToFull)
                        local minutes = math.floor((hoursToFull - hours) * 60)
                        if hours > 0 then
                            toFullText = string.format("|cFFFFAA00%dh%02dm|r", hours, minutes)
                        else
                            toFullText = string.format("|cFFFF0000%dm|r", minutes)
                        end
                    else
                        local days = math.floor(hoursToFull / 24)
                        local remainingHours = hoursToFull % 24
                        local hours = math.floor(remainingHours)
                        local minutes = math.floor((remainingHours - hours) * 60)
                        toFullText = string.format("|cFF00AAFF%dd%dh%02dm|r", days, hours, minutes)
                    end
                end
                
                -- Status icon
                local statusIcon = "|cFFFF0000[World]|r"
                if data.isInInn == 1 then
                    statusIcon = "|cFF00FF00[Inn]|r"
                elseif data.isInCity == 1 then
                    statusIcon = "|cFF00FF00[City]|r"
                end
                
                local wellRestedText = "|cFFAAAAAA-|r"
				if data.hasWellRested == 1 then
					if estimatedWellRestedRemaining > 0 then
						local remaining = estimatedWellRestedRemaining
						if remaining > 3600 then
							local hours = math.floor(remaining / 3600)
							local minutes = math.floor((remaining % 3600) / 60)
							wellRestedText = string.format("|cFF00FFFFBuffed[%dh%02dm]|r", hours, minutes)
						else
							local minutes = math.ceil(remaining / 60)
							wellRestedText = string.format("|cFF00FFFFBuffed[%dm]|r", minutes)
						end
					else
						wellRestedText = "|cFF00FFFFBuffed|r"
					end
				end
				
				-- Add the Well Rested column
				 line = string.format("%-18s | %s | %s | %s | %s | %s | %s | %-14s | %s | %s",
        charName, levelText, restedText, percentText, locationText, timeText, rateText, toFullText, statusIcon, wellRestedText)
            end
        end
        
        entry:SetText(line)
        
        -- Add tooltip with detailed information to the button
        entryButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            
            -- Get proper realm name for display
            local properRealm = RRT_Utilities.GetProperRealmName(realm)
            local properCharKey = charName .. "-" .. properRealm
            
            GameTooltip:AddLine(properCharKey, 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            -- Check if character is at max level (using saved data)
            if data.isMaxLevel then
                GameTooltip:AddLine("|cFF00FF00MAX LEVEL|r", 0, 1, 0)
                GameTooltip:AddLine("This character has reached the server max level.", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("XP tracking is disabled for max level characters.", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Server Max: Level " .. (data.serverMaxLevel or "Unknown"), 0.6, 0.6, 0.6)
                GameTooltip:Show()
                return
            end
            
            GameTooltip:AddDoubleLine("Level:", data.level, 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("Current XP:", string.format("%d / %d (%.1f%%)", 
                data.currentXP or 0, data.maxXP or 0, data.xpPercent or 0), 0.8, 0.8, 0.8, 1, 1, 1)
            
            -- Show both saved and estimated rested values
            GameTooltip:AddDoubleLine("Rested XP (saved):", string.format("%d (%.1f%%)", 
                data.restedXP or 0, data.restPercent or 0), 0.8, 0.8, 0.8, 0.6, 0.6, 0.6)
            
            GameTooltip:AddDoubleLine("Rested XP (estimated):", string.format("%d (%.1f%%)", 
                estimatedRestedXP, estimatedRestPercent), 0.8, 0.8, 0.8, 0, 1, 0)
            
            if data.location then
                GameTooltip:AddDoubleLine("Location:", data.location, 0.8, 0.8, 0.8, 0, 0.8, 1)
            end
            
            if data.timestamp then
                GameTooltip:AddDoubleLine("Last Updated:", date("%Y-%m-%d %H:%M", data.timestamp), 0.8, 0.8, 0.8, 1, 1, 1)
                
                local timeDiff = time() - data.timestamp
                if timeDiff > 0 then
                    GameTooltip:AddDoubleLine("Time Since:", RRT_Utilities.FormatTime(timeDiff), 0.8, 0.8, 0.8, 1, 1, 1)
                    GameTooltip:AddDoubleLine("Time elapsed:", string.format("%.1f hours", elapsedHours), 0.8, 0.8, 0.8, 1, 1, 1)
                end
            end
            
            -- Add rest status
            local restStatus = "In World (" .. string.format("%.3f%%/h", restRates.ELSEWHERE) .. ")"
            if data.isInInn == 1 then
                restStatus = "In Inn (" .. string.format("%.3f%%/h", restRates.INN_CITY) .. ")"
            elseif data.isInCity == 1 then
                restStatus = "In City (" .. string.format("%.3f%%/h", restRates.INN_CITY) .. ")"
            end
            GameTooltip:AddDoubleLine("Rest Status:", restStatus, 0.8, 0.8, 0.8, 
                data.isInInn == 1 and 0 or 1, data.isInInn == 1 and 1 or 0, 0)
            
            -- Show time to full calculation (using estimated values)
            if estimatedRestPercent < 150 then
                local rate = (data.isInInn == 1 or data.isInCity == 1) and 
                             restRates.INN_CITY or 
                             restRates.ELSEWHERE
                local hoursToFull = (150 - estimatedRestPercent) / rate
                GameTooltip:AddDoubleLine("Time to Full (est):", RRT_Utilities.FormatTime(hoursToFull * 3600), 0.8, 0.8, 0.8, 1, 1, 0)
                GameTooltip:AddLine("(Based on " .. string.format("%.1f", elapsedHours) .. "h elapsed since logout)", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddDoubleLine("Time to Full (est):", "FULL (reached while offline)", 0.8, 0.8, 0.8, 0, 1, 0)
            end
            
            -- Show server max level info (use saved data)
            if data.serverMaxLevel then
                GameTooltip:AddDoubleLine("Server Max:", "Level " .. data.serverMaxLevel, 0.8, 0.8, 0.8, 0.5, 0.5, 1)
            end
			
			-- Show Well Rested status in tooltip
			if data.hasWellRested == 1 then
                if estimatedWellRestedRemaining > 0 then
                    if estimatedWellRestedRemaining > 3600 then
                        -- 1 hour or more: show hours and minutes
                        local hours = math.floor(estimatedWellRestedRemaining / 3600)
                        local minutes = math.floor((estimatedWellRestedRemaining % 3600) / 60)
                        GameTooltip:AddLine("|cFF00FFFFWell Rested Buff|r (" .. string.format("|cFF00FFFF%dh%02dm|r remaining)", hours, minutes), 0, 1, 1)
                    else
                        -- Less than 1 hour: show only minutes
                        local minutes = math.ceil(estimatedWellRestedRemaining / 60)
                        GameTooltip:AddLine("|cFF00FFFFWell Rested Buff|r (" .. string.format("|cFF00FFFF%dm|r remaining)", minutes), 0, 1, 1)
                    end
                else
                    GameTooltip:AddLine("|cFF00FFFFWell Rested Buff|r (Duration unknown or expired)", 0.6, 0.6, 0.6)
                end
			else
				GameTooltip:AddLine("|cFFAAAAAANo Well Rested Buff|r", 0.8, 0.8, 0.8)
			end
            
            GameTooltip:Show()
        end)
        
        entryButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        yOffset = yOffset - 20
        contentHeight = contentHeight + 20
        displayedCount = displayedCount + 1
    end
    
    -- Add color legend if we have characters
    if displayedCount > 0 then
        yOffset = yOffset - 15
        local legend = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        legend:SetPoint("TOPLEFT", 10, yOffset)
        legend:SetText("|cFFAAAAAALegend:|r |cFFFFAA00Name|r=Class, |cFFFFFF00Time|r=Since Update, |cFF00FFFFTo Full:|r |cFFFF0000<1h|r |cFFFFAA001-24h|r |cFF00AAFF>1d|r |cFF00FF00FULL|r, |cFFAAAAAAMAX|r=Max Level, |cFF00FFFFWR|r=Well Rested")
        legend:SetTextColor(0.7, 0.7, 0.7)
        yOffset = yOffset - 20
        contentHeight = contentHeight + 20
    end
    
    -- Add summary footer
    local totalRested = 0
    local maxLevel = 0
    local innCount = 0
    local cityCount = 0
    local worldCount = 0
    local maxLevelCount = 0
    
    for _, char in ipairs(characters) do
        local data = char.data
        totalRested = totalRested + (data.restedXP or 0)
        maxLevel = math.max(maxLevel, data.level or 0)
        
        if data.level == data.serverMaxLevel then
            maxLevelCount = maxLevelCount + 1
        elseif data.isInInn == 1 then
            innCount = innCount + 1
        elseif data.isInCity == 1 then
            cityCount = cityCount + 1
        else
            worldCount = worldCount + 1
        end
    end
    
    local footerText = string.format("|cFFAAAAAAShowing %d/%d characters | Max Level Chars: %d | Inns: %d | Cities: %d | World: %d", 
        displayedCount, 
        #characters,
        maxLevelCount,
        innCount,
        cityCount,
        worldCount)
    
    frame.footer:SetText(footerText)
    
    -- Adjust scroll child height
    frame.scrollChild:SetHeight(math.max(400, contentHeight))
    
    -- Show frame
    frame:Show()
end

-- Mini-map icon with simple round appearance for Classic WoW
function RRT_UI.CreateMinimapIcon()
    local icon = CreateFrame("Button", "RRTMinimapButton", Minimap)
    icon:SetFrameStrata("HIGH")
    icon:SetWidth(31)
    icon:SetHeight(31)
    icon:SetMovable(true)
    icon:SetPoint("CENTER", Minimap, "TOPLEFT", 12, -80)
    
    -- Create background for round appearance
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints(icon)
    icon.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    icon.bg:SetTexCoord(0, 1, 0, 1)
    
    -- Create the icon texture
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetWidth(20)
    icon.texture:SetHeight(20)
    icon.texture:SetPoint("CENTER", icon, "CENTER")
    
    -- Try to use the addon icon
    icon.texture:SetTexture("Interface\\AddOns\\RestRateTracker\\icon.tga")
    
    -- If custom icon doesn't exist, use a default book icon
    if not icon.texture:GetTexture() then
        icon.texture:SetTexture("Interface\\Icons\\Inv_misc_book_09")
    end
    
    -- Create circular border using the tracking border texture
    icon.border = icon:CreateTexture(nil, "BORDER")
    icon.border:SetAllPoints(icon)
    icon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Highlight texture
    icon.highlight = icon:CreateTexture(nil, "HIGHLIGHT")
    icon.highlight:SetAllPoints(icon)
    icon.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    icon.highlight:SetBlendMode("ADD")
    
    -- Click handler - LEFT click opens the character data frame
    icon:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            RRT_UI.ShowAllCharacterData()
        elseif button == "RightButton" then
            SlashCmdList["RESTRATE"]("current")
        end
    end)
    
    -- Tooltip
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Rest Rate Tracker", 1, 1, 1)
        GameTooltip:AddLine("Left-click: View all characters", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Current status", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("/rrt help for more commands", 0.6, 0.6, 0.6)
        
        local data = RRT_Data.GetCurrentRestData()
        if data then
            local _, class = UnitClass("player")
            local serverMaxLevel = RRT_Utilities.GetServerMaxLevel()
            
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Level " .. data.level .. " " .. (class or ""), 0.8, 0.8, 0.8)
            
            -- Check if player is at max level
            if data.level == serverMaxLevel then
                GameTooltip:AddLine("|cFF00FF00MAX LEVEL|r", 0, 1, 0)
                GameTooltip:AddLine("Server Max: Level " .. serverMaxLevel, 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("XP: " .. data.currentXP .. "/" .. data.maxXP, 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Rested: " .. string.format("%.1f%%", data.restPercent), 0, 1, 0)
                
                -- Get default rate for current location
                local currentRate = 0
                local restRates = RRT_Config.GetRestRates() or {INN_CITY = 2.5, ELSEWHERE = 0.625}
                if IsResting() then
                    currentRate = restRates.INN_CITY
                elseif data.location and (data.location == "Stormwind" or data.location == "Orgrimmar" or 
                       string.find(data.location, "City") or string.find(data.location, "Sanctuary") or
                       data.location == "Ironforge" or data.location == "Darnassus" or 
                       data.location == "Undercity" or data.location == "Thunder Bluff" or
                       data.location == "Shattrath City" or data.location == "Dalaran") then
                    currentRate = restRates.INN_CITY
                else
                    currentRate = restRates.ELSEWHERE
                end
                
                if data.restPercent < 150 then
                    local secondsToFull, rate = RRT_Data.CalculateTimeToFull(data.restPercent, nil, data.location)
                    GameTooltip:AddLine("To full: " .. RRT_Utilities.FormatTimeShort(secondsToFull/3600), 1, 1, 0)
                    GameTooltip:AddLine("Rate: " .. string.format("%.2f%%/h", rate) .. " (default)", 0.8, 0.8, 0.8)
					if data.hasWellRested == 1 then
						GameTooltip:AddLine("|cFF00FFFFWell Rested Buff Active|r", 0, 1, 1)
						if data.wellRestedExpires and data.wellRestedExpires > time() then
							local remaining = data.wellRestedExpires - time()
							GameTooltip:AddLine("Time remaining: " .. RRT_Utilities.FormatTime(remaining), 0.8, 0.8, 0.8)
						end
					end
                else
                    GameTooltip:AddLine("Full rested!", 0, 1, 0)
                end
            end
        end
        
        GameTooltip:Show()
    end)
    
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Make it draggable
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then
            self.isMoving = true
            self:StartMoving()
        end
    end)
    
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and self.isMoving then
            self.isMoving = false
            self:StopMovingOrSizing()
        end
    end)
    
    return icon
end

-- Mini-map icon with simple round appearance for Classic WoW
function RRT_UI.CreateMinimapIcon()
    local icon = CreateFrame("Button", "RRTMinimapButton", Minimap)
    icon:SetFrameStrata("HIGH")
    icon:SetWidth(31)
    icon:SetHeight(31)
    icon:SetMovable(true)
    icon:SetPoint("CENTER", Minimap, "TOPLEFT", 12, -80)
    
    -- Create background for round appearance
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints(icon)
    icon.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    icon.bg:SetTexCoord(0, 1, 0, 1)
    
    -- Create the icon texture
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetWidth(20)
    icon.texture:SetHeight(20)
    icon.texture:SetPoint("CENTER", icon, "CENTER")
    
    -- Try to use the addon icon
    icon.texture:SetTexture("Interface\\AddOns\\RestRateTracker\\icon.tga")
    
    -- If custom icon doesn't exist, use a default book icon
    if not icon.texture:GetTexture() then
        icon.texture:SetTexture("Interface\\Icons\\Inv_misc_book_09")
    end
    
    -- Create circular border using the tracking border texture
    icon.border = icon:CreateTexture(nil, "BORDER")
    icon.border:SetAllPoints(icon)
    icon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Highlight texture
    icon.highlight = icon:CreateTexture(nil, "HIGHLIGHT")
    icon.highlight:SetAllPoints(icon)
    icon.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    icon.highlight:SetBlendMode("ADD")
    
    -- Click handler - LEFT click opens the character data frame
    icon:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            RRT_UI.ShowAllCharacterData()
        elseif button == "RightButton" then
            SlashCmdList["RESTRATE"]("current")
        end
    end)
    
    -- Tooltip
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Rest Rate Tracker", 1, 1, 1)
        GameTooltip:AddLine("Left-click: View all characters", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Current status", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("/rrt help for more commands", 0.6, 0.6, 0.6)
        
        local data = RRT_Data.GetCurrentRestData()
        if data then
            local _, class = UnitClass("player")
            local serverMaxLevel = RRT_Utilities.GetServerMaxLevel()
            
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Level " .. data.level .. " " .. (class or ""), 0.8, 0.8, 0.8)
            
            -- Check if player is at max level
            if data.level == serverMaxLevel then
                GameTooltip:AddLine("|cFF00FF00MAX LEVEL|r", 0, 1, 0)
                GameTooltip:AddLine("Server Max: Level " .. serverMaxLevel, 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("XP: " .. data.currentXP .. "/" .. data.maxXP, 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Rested: " .. string.format("%.1f%%", data.restPercent), 0, 1, 0)
                
                -- Get default rate for current location
                local currentRate = 0
                local restRates = RRT_Config.GetRestRates()
                if IsResting() then
                    currentRate = restRates.INN_CITY
                elseif data.location and (data.location == "Stormwind" or data.location == "Orgrimmar" or 
                       string.find(data.location, "City") or string.find(data.location, "Sanctuary") or
                       data.location == "Ironforge" or data.location == "Darnassus" or 
                       data.location == "Undercity" or data.location == "Thunder Bluff" or
                       data.location == "Shattrath City" or data.location == "Dalaran") then
                    currentRate = restRates.INN_CITY
                else
                    currentRate = restRates.ELSEWHERE
                end
                
                if data.restPercent < 150 then
                    local secondsToFull, rate = RRT_Data.CalculateTimeToFull(data.restPercent, nil, data.location)
                    GameTooltip:AddLine("To full: " .. RRT_Utilities.FormatTimeShort(secondsToFull/3600), 1, 1, 0)
                    GameTooltip:AddLine("Rate: " .. string.format("%.2f%%/h", rate) .. " (default)", 0.8, 0.8, 0.8)
					if data.hasWellRested == 1 then
						GameTooltip:AddLine("|cFF00FFFFWell Rested Buff Active|r", 0, 1, 1)
						if data.wellRestedExpires and data.wellRestedExpires > time() then
							local remaining = data.wellRestedExpires - time()
							GameTooltip:AddLine("Time remaining: " .. RRT_Utilities.FormatTime(remaining), 0.8, 0.8, 0.8)
						end
					end
                else
                    GameTooltip:AddLine("Full rested!", 0, 1, 0)
                end
            end
        end
        
        GameTooltip:Show()
    end)
    
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Make it draggable
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then
            self.isMoving = true
            self:StartMoving()
        end
    end)
    
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "MiddleButton" and self.isMoving then
            self.isMoving = false
            self:StopMovingOrSizing()
        end
    end)
    
    return icon
end