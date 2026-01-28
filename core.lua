local myFrame = CreateFrame("Frame", "BetterInfoBarFrame", UIParent, "BackdropTemplate")
myFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 32, 22)
myFrame:SetHeight(22)
myFrame:SetWidth(500)
myFrame:SetFrameStrata(BACKGROUND)

local backdrop_header = {bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile=1, tileSize=16, edgeSize = 16,
    insets = {left = 5, right = 5, top = 5, bottom = 5}}

myFrame:SetBackdrop(backdrop_header)
myFrame:SetBackdropBorderColor(0.5, 0.5, 0.5)
myFrame:SetBackdropColor(0.5, 0.5, 0.5, 0.6)

myFrame.text = myFrame:CreateFontString("$parentText", "ARTWORK", "GameFontNormalSmall")
myFrame.text:SetPoint("CENTER", myFrame, "CENTER", 0, 0)
myFrame.text:Show()

myFrame:RegisterEvent("VARIABLES_LOADED")
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
myFrame:RegisterEvent("PLAYER_MONEY")
myFrame:RegisterEvent("PLAYER_XP_UPDATE")

myFrame.playerName = "_no_char_"
myFrame.month = 0
myFrame.day = 0
myFrame.averageMoneyMonth = 0
myFrame.averageMoneyDay = 0
myFrame.totalMoney = 0
myFrame.goldText = ""
myFrame.tokenPriceText = ""
myFrame.restedXpText = ""

BIB_SavedVars = {}

local FPS_UPDATERATE = 0.5
local TOKEN_UPDATE_RATE = 5 * 60

local function UpdateTokenPrice()
    myFrame.tokenPriceText = CalculateTokenPrice(myFrame.totalMoney)

    C_Timer.After(TOKEN_UPDATE_RATE, UpdateTokenPrice)
end

local function UpdateFps()
    local fps = floor(GetFramerate() + 0.5)
    local fpsText = format("|cff%s%d|r fps", GetThresholdHexColor(fps / 60), fps)
                
    local _, _, lagHome, lagWorld = GetNetStats()
    local lagHomeText = format("|cff%s%d|r ms", GetThresholdHexColor(lagHome, 1000, 500, 250, 100, 0), lagHome)
    local lagWorldText = format("|cff%s%d|r ms", GetThresholdHexColor(lagWorld, 1000, 500, 250, 100, 0), lagWorld)

    myFrame.text:SetText(fpsText.." | |cFF99CC33H:|r"..lagHomeText.." | |cFF99CC33W:|r"..lagWorldText.." | "..myFrame.goldText.." | "..myFrame.tokenPriceText..myFrame.restedXpText)

    C_Timer.After(FPS_UPDATERATE, UpdateFps)
end

myFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if event == "VARIABLES_LOADED" then
        self.playerName = GetRealmName().."-"..UnitName("player")

        if not BIB_SavedVars["Char"] then
            BIB_SavedVars["Char"] = {}
        end
        if not BIB_SavedVars["Char"][self.playerName] then
            BIB_SavedVars["Char"][self.playerName] = 0
        end
        if not BIB_SavedVars["CurrentMonthMoney"] then
            BIB_SavedVars["CurrentMonthMoney"] = 0
        end
        if not BIB_SavedVars["PreviousMonthMoney"] then
            BIB_SavedVars["PreviousMonthMoney"] = 0
        end
        if not BIB_SavedVars["CurrentMonth"] then
            BIB_SavedVars["CurrentMonth"] = self.month
        end
    elseif event == "PLAYER_LOGIN" then
        local curDate = C_DateAndTime.GetCurrentCalendarTime()
        self.day, self.month = curDate.monthDay, curDate.month
        self.playerName = GetRealmName().."-"..UnitName("player")

        CalculateRestedXp(self)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if isInitialLogin or isReloadingUi then
            CalculateMoney(self)

            C_Timer.After(1, UpdateFps)
            C_Timer.After(1, UpdateTokenPrice)

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    elseif event == "PLAYER_MONEY" then
        CalculateMoney(self)
    elseif event == "PLAYER_XP_UPDATE" then
        CalculateRestedXp(self)
    end
end)

myFrame:SetScript("OnEnter", function(self)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("Gold Balance")
    GameTooltip:AddDoubleLine("Total:", GetMoneyString(self.totalMoney, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Month: ", GetMoneyString(tonumber(BIB_SavedVars["CurrentMonthMoney"]), true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Previous Month: ", GetMoneyString(tonumber(BIB_SavedVars["PreviousMonthMoney"]), true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Month: ", GetMoneyString(self.averageMoneyMonth, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Day: ", GetMoneyString(self.averageMoneyDay, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end)

myFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

function CalculateTokenPrice(totalMoney)
    C_WowTokenPublic.UpdateMarketPrice()
    local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()

    if tokenPrice and tokenPrice > 0 then
        tokenPrice = GetMoneyString(tokenPrice, true) .. " ("..math.floor(totalMoney / tokenPrice) ..")"
    else
        tokenPrice = "N/A"
    end

    return tokenPrice
end

function CalculateMoney(self)
    local moneyBefore = tonumber(BIB_SavedVars["Char"][self.playerName]) or 0
    local moneyAfter = GetMoney()

    Initialize(self)

    if self.initialized then
        BIB_SavedVars["CurrentMonthMoney"] = tonumber(BIB_SavedVars["CurrentMonthMoney"]) + (moneyAfter - moneyBefore)
        self.averageMoneyMonth = (tonumber(BIB_SavedVars["PreviousMonthMoney"]) + tonumber(BIB_SavedVars["CurrentMonthMoney"])) / 2
        self.averageMoneyDay = tonumber(BIB_SavedVars["CurrentMonthMoney"]) / self.day

        BIB_SavedVars["Char"][self.playerName] = moneyAfter
    end

    self.totalMoney = 0
    for character, money in pairs(BIB_SavedVars["Char"]) do
        self.totalMoney = self.totalMoney + tonumber(money)
    end
    
    self.goldText = GetMoneyString((math.floor(self.totalMoney / 10000) * 10000), true)
end

function CalculateRestedXp(self)
    local restedXp = GetXPExhaustion()
    self.restedXpText = ""

    if restedXp  then
        local restXpPer = math.floor(restedXp / UnitXPMax("player") * 100 + 0.5)
    
        if restXpPer >= 1 then
            self.restedXpText = " | "..restXpPer.."%"
        end
    end
end

function Initialize(self)
    if not self.initialized then
        local curDate = C_DateAndTime.GetCurrentCalendarTime()
        self.day, self.month = curDate.monthDay, curDate.month
        
        if self.month > 0 and self.month <= 12 then
            self.initialized = true

            if tonumber(BIB_SavedVars["CurrentMonth"]) ~= self.month then
                BIB_SavedVars["CurrentMonth"] = self.month
                BIB_SavedVars["PreviousMonthMoney"] = BIB_SavedVars["CurrentMonthMoney"]
                BIB_SavedVars["CurrentMonthMoney"] = 0
            end
        end
    end
end

function GetThresholdHexColor(quality, ...)
    local r, g, b = GetThresholdColor(quality, ...)
    return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function GetThresholdColor(quality, ...)
    local inf = 10000000
    if quality ~= quality or quality == inf or quality == -inf then
        return 1, 1, 1
    end

    local percent = GetThresholdPercentage(quality, ...)

    if percent <= 0 then
        return 1, 0, 0
    elseif percent <= 0.5 then
        return 1, percent*2, 0
    elseif percent >= 1 then
        return 0, 1, 0
    else
        return 2 - percent*2, 1, 0
    end
end

function GetThresholdPercentage(quality, ...)
    local n = select('#', ...)
    if n <= 1 then
        return GetThresholdPercentage(quality, 0, ... or 1)
    end

    local worst = ...
    local best = select(n, ...)

    if worst == best and quality == worst then
        return 0.5
    end

    if worst <= best then
        if quality <= worst then
            return 0
        elseif quality >= best then
            return 1
        end
        local last = worst
        for i = 2, n-1 do
            local value = select(i, ...)
            if quality <= value then
                return ((i-2) + (quality - last) / (value - last)) / (n-1)
            end
            last = value
        end

        local value = select(n, ...)
        return ((n-2) + (quality - last) / (value - last)) / (n-1)
    else
        if quality >= worst then
            return 0
        elseif quality <= best then
            return 1
        end
        local last = worst
        for i = 2, n-1 do
            local value = select(i, ...)
            if quality >= value then
                return ((i-2) + (quality - last) / (value - last)) / (n-1)
            end
            last = value
        end

        local value = select(n, ...)
        return ((n-2) + (quality - last) / (value - last)) / (n-1)
    end
end
