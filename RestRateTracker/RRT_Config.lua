-- RestRateTracker Configuration Module
RRT_Config = RRT_Config or {}

local CONFIG = {
    SAVED_VARIABLES = nil, -- Will be set during initialization
    MIN_LEVEL = 1,
    FULL_REST_PERCENT = 150,  -- Maximum rest is 150% of level XP (when calculated as rested/maxXP)
    DEFAULT_REST_RATES = {
        INN_CITY = 2.5,    -- Standard rate: 2.5% per hour in inn/city (of maxXP)
        ELSEWHERE = 0.625, -- Reduced rate: 0.625% per hour elsewhere
    },
	WELL_RESTED_BUFF_NAME = "Well Rested",
}

local CLASS_COLORS = {
    WARRIOR     = {r = 0.78, g = 0.61, b = 0.43},
    PALADIN     = {r = 0.96, g = 0.55, b = 0.73},
    HUNTER      = {r = 0.67, g = 0.83, b = 0.45},
    ROGUE       = {r = 1.00, g = 0.96, b = 0.41},
    PRIEST      = {r = 1.00, g = 1.00, b = 1.00},
    DEATHKNIGHT = {r = 0.77, g = 0.12, b = 0.23},
    SHAMAN      = {r = 0.00, g = 0.44, b = 0.87},
    MAGE        = {r = 0.25, g = 0.78, b = 0.92},
    WARLOCK     = {r = 0.53, g = 0.53, b = 0.93},
    DRUID       = {r = 1.00, g = 0.49, b = 0.04},
    HERO        = {r = 0.00, g = 0.55, b = 0.55},
}

-- Public interface
function RRT_Config.Initialize(savedVarsName)
    CONFIG.SAVED_VARIABLES = savedVarsName
end

function RRT_Config.GetConfig()
    return CONFIG
end

function RRT_Config.GetClassColors()
    return CLASS_COLORS
end

function RRT_Config.GetRestRates()
    return CONFIG.DEFAULT_REST_RATES
end

function RRT_Config.GetRate(locationType)
    if locationType == "inn" or locationType == "city" then
        return CONFIG.DEFAULT_REST_RATES.INN_CITY
    else
        return CONFIG.DEFAULT_REST_RATES.ELSEWHERE
    end
end

function RRT_Config.GetSavedVarsName()
    return CONFIG.SAVED_VARIABLES
end

function RRT_Config.GetFullRestPercent()
    return CONFIG.FULL_REST_PERCENT
end

function RRT_Config.GetWellRestedBuffName()
    return CONFIG.WELL_RESTED_BUFF_NAME
end