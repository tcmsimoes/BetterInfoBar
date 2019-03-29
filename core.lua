local myFrame = CreateFrame("Frame", "BetterInfoBarFrame", UIParent)
myFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 32, 22)
myFrame:SetHeight(22)
myFrame:SetWidth(550)
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

myFrame.realmName = "_no_realm_"
myFrame.playerName = "_no_char_"
myFrame.month = 0
myFrame.day = 0
myFrame.averageMoneyMonth = 0
myFrame.averageMoneyDay = 0
myFrame.totalMoney = 0
myFrame.goldText = ""
myFrame.tokenPriceText = ""
myFrame.restedXpText = ""
myFrame.fpsLastUpdate = 100000
myFrame.tokenLastUpdate = 100000

SavedVars = {}

myFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" then
        self.playerName = UnitName("player")
        self.realmName = GetRealmName()

        if not SavedVars[self.realmName] then
            SavedVars[self.realmName] = {}
        end
        if not SavedVars[self.realmName]["Char"] then
            SavedVars[self.realmName]["Char"] = {}
        end
        if not SavedVars[self.realmName]["Char"][self.playerName] then
            SavedVars[self.realmName]["Char"][self.playerName] = 0
        end
        if not SavedVars[self.realmName]["CurrentMonthMoney"] then
            SavedVars[self.realmName]["CurrentMonthMoney"] = 0
        end
        if not SavedVars[self.realmName]["PreviousMonthMoney"] then
            SavedVars[self.realmName]["PreviousMonthMoney"] = 0
        end
        if not SavedVars["CurrentMonth"] then
            SavedVars["CurrentMonth"] = self.month
        end
    elseif event == "PLAYER_LOGIN" then
        local curDate = C_Calendar.GetDate()
        self.day, self.month = curDate.monthDay, curDate.month
        self.playerName = UnitName("player")
        self.realmName = GetRealmName()

        CalculateRestedXp(self)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MONEY" then
        CalculateMoney(self)
    elseif event == "PLAYER_XP_UPDATE" then
        CalculateRestedXp(self)
    end
end)

FPS_UPDATERATE = 1.0
TOKEN_UPDATERATE = 5 * 60 * 1.0
myFrame:SetScript("OnUpdate", function(self, elapsed)
    self.fpsLastUpdate = self.fpsLastUpdate + elapsed
    self.tokenLastUpdate = self.tokenLastUpdate + elapsed

    if (self.fpsLastUpdate >= FPS_UPDATERATE) then
        local fps = floor(GetFramerate() + 0.5)
        local fpsText = format("|cff%s%d|r fps", GetThresholdHexColor(fps / 60), fps)
                    
        local _, _, lagHome, lagWorld = GetNetStats()
        local lagHomeText = format("|cff%s%d|r ms", GetThresholdHexColor(lagHome, 1000, 500, 250, 100, 0), lagHome)
        local lagWorldText = format("|cff%s%d|r ms", GetThresholdHexColor(lagWorld, 1000, 500, 250, 100, 0), lagWorld)

        self.text:SetText(fpsText.." | |cFF99CC33H:|r"..lagHomeText.." | |cFF99CC33W:|r"..lagWorldText.." | "..self.goldText.." | "..self.tokenPriceText..self.restedXpText)

        self.fpsLastUpdate = 0
    end

    if (self.tokenLastUpdate >= TOKEN_UPDATERATE) then
        self.tokenPriceText = CalculateTokenPrice(self.totalMoney)

        self.tokenLastUpdate = 0
    end
end)

myFrame:SetScript("OnEnter", function(self)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("Gold Balance")
    GameTooltip:AddDoubleLine("Total:", GetCoinTextureStringExt(self.totalMoney), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Month: ", GetCoinTextureStringExt(tonumber(SavedVars[self.realmName]["CurrentMonthMoney"])), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Previous Month: ", GetCoinTextureStringExt(tonumber(SavedVars[self.realmName]["PreviousMonthMoney"])), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Month: ", GetCoinTextureStringExt(self.averageMoneyMonth), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Day: ", GetCoinTextureStringExt(self.averageMoneyDay), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end)

myFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

function CalculateTokenPrice(totalMoney)
    C_WowTokenPublic.UpdateMarketPrice()
    local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()

    if tokenPrice and tokenPrice > 0 then
        tokenPrice = GetCoinTextureStringExt(tokenPrice) .. " ("..math.floor(totalMoney / tokenPrice) ..")"
    else
        tokenPrice = "N/A"
    end

    return tokenPrice
end

function CalculateMoney(self)
    local moneyBefore = tonumber(SavedVars[self.realmName]["Char"][self.playerName]) or 0
    local moneyAfter = GetMoney()

    Initialize(self)

    if self.initialized then
        SavedVars[self.realmName]["CurrentMonthMoney"] = tonumber(SavedVars[self.realmName]["CurrentMonthMoney"]) + (moneyAfter - moneyBefore)
        self.averageMoneyMonth = (tonumber(SavedVars[self.realmName]["PreviousMonthMoney"]) + tonumber(SavedVars[self.realmName]["CurrentMonthMoney"])) / 2
        self.averageMoneyDay = tonumber(SavedVars[self.realmName]["CurrentMonthMoney"]) / self.day

        SavedVars[self.realmName]["Char"][self.playerName] = moneyAfter
    end

    self.totalMoney = 0
    for character, money in pairs(SavedVars[self.realmName]["Char"]) do
        self.totalMoney = self.totalMoney + tonumber(money)
    end
    
    self.goldText = GetCoinTextureStringExt(math.floor(self.totalMoney / 10000) * 10000)
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
        local curDate = C_Calendar.GetDate()
        self.day, self.month = curDate.monthDay, curDate.month
        
        if self.month > 0 and self.month <= 12 then
            self.initialized = true

            if tonumber(SavedVars["CurrentMonth"]) ~= self.month then
                SavedVars["CurrentMonth"] = self.month
                SavedVars[self.realmName]["PreviousMonthMoney"] = SavedVars[self.realmName]["CurrentMonthMoney"]
                SavedVars[self.realmName]["CurrentMonthMoney"] = 0
            end
        end
    end
end

function GetThresholdHexColor(quality, ...)
    local r, g, b = GetThresholdColor(quality, ...)
    return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function GetThresholdColor(quality, ...)
    local inf = 1/0
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

function AddCommas(pre, post)
    return pre..post:reverse():gsub("(%d%d%d)","%1"..LARGE_NUMBER_SEPERATOR):reverse()
end
function SplitDecimal(str)
    return str:gsub("^(%d)(%d+)", AddCommas)
end
function ReformatNumberString(str)
    return str:gsub("[%d%.]+", SplitDecimal)
end
function GetCoinTextureStringExt(money)
    if money >= 0 then
        return ReformatNumberString(GetCoinTextureString(money), 12)
    else
        return "-"..ReformatNumberString(GetCoinTextureString(money * -1), 12)
    end
end