local myFrame = CreateFrame("Frame", "BetterInfoBarFrame", DEFAULT_CHAT_FRAME)
myFrame:SetPoint("TOPLEFT", DEFAULT_CHAT_FRAME, "BOTTOMLEFT", -4, -30)
myFrame:SetHeight(22)
myFrame:SetWidth(DEFAULT_CHAT_FRAME:GetWidth() + 30)

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

myFrame.playerName = "_no_char_"
myFrame.month = 0
myFrame.day = 0
myFrame.averageMoneyMonth = 0
myFrame.averageMoneyDay = 0
myFrame.totalMoney = 0
myFrame.tokenPrice = 0
myFrame.fpsLastUpdate = 100000
myFrame.tokenLastUpdate = 100000

SavedVars = {
    ["MoneyPerChar"] = {},
    ["MoneyMonthly"] = {}
}

myFrame:SetScript("OnEvent", function(self, event, ...)
    if GetRealmName() ~= "Draenor" then
        return
    end

    if event == "VARIABLES_LOADED" then
        if not SavedVars["MoneyPerChar"][self.playerName] then
            SavedVars["MoneyPerChar"][self.playerName] = 0
        end
        if not SavedVars["MoneyMonthly"]["CurrentMonth"] then
            SavedVars["MoneyMonthly"]["CurrentMonth"] = self.month
            SavedVars["MoneyMonthly"]["PreviousMonthMoney"] = 0
            SavedVars["MoneyMonthly"]["CurrentMonthMoney"] = 0
        end
    elseif event == "PLAYER_LOGIN" then
        local curDate = C_Calendar.GetDate()
        self.day, self.month = curDate.monthDay, curDate.month
        self.playerName = UnitName("player")

        if tonumber(SavedVars["MoneyMonthly"]["CurrentMonth"]) ~= self.month then
            SavedVars["MoneyMonthly"]["CurrentMonth"] = self.month
            SavedVars["MoneyMonthly"]["PreviousMonthMoney"] = SavedVars["MoneyMonthly"]["CurrentMonthMoney"]
            SavedVars["MoneyMonthly"]["CurrentMonthMoney"] = 0
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MONEY" then
        CalculateMoney(self)
    end
end)

FPS_UPDATERATE = 1.0
TOKEN_UPDATERATE = 5 * 60.0
myFrame:SetScript("OnUpdate", function(self, elapsed)
    self.fpsLastUpdate = self.fpsLastUpdate + elapsed

    if (self.fpsLastUpdate >= FPS_UPDATERATE) then
        local fps = floor(GetFramerate() + 0.5)
        local fpsText = format("|cff%s%d|r fps", GetThresholdHexColor(fps / 60), fps)
                    
        local _, _, lagHome, lagWorld = GetNetStats()
        local lagHomeText = format("|cff%s%d|r ms", GetThresholdHexColor(lagHome, 1000, 500, 250, 100, 0), lagHome)
        local lagWorldText = format("|cff%s%d|r ms", GetThresholdHexColor(lagWorld, 1000, 500, 250, 100, 0), lagWorld)

        local goldText = GetCoinTextureStringExt(self.totalMoney)

        local tokenText = self.tokenPrice

        self.text:SetText(fpsText.." | |cFF99CC33H:|r"..lagHomeText.." | |cFF99CC33W:|r"..lagWorldText.." | "..goldText.." | "..tokenText)

        self.fpsLastUpdate = 0
    end

    if (self.tokenLastUpdate >= TOKEN_UPDATERATE) then
        self.tokenPrice = GetTokenPrice()

        self.tokenLastUpdate = 0
    end
end)

myFrame:SetScript("OnEnter", function(self)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("Gold Balance")
    GameTooltip:AddDoubleLine("Total:", GetCoinTextureStringExt(self.totalMoney), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Month: ", GetCoinTextureStringExt(tonumber(SavedVars["MoneyMonthly"]["CurrentMonthMoney"])), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Previous Month: ", GetCoinTextureStringExt(tonumber(SavedVars["MoneyMonthly"]["PreviousMonthMoney"])), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Month: ", GetCoinTextureStringExt(self.averageMoneyMonth), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Day: ", GetCoinTextureStringExt(self.averageMoneyDay), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end)

myFrame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

function GetTokenPrice()
    C_WowTokenPublic.UpdateMarketPrice()
    local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()

    if tokenPrice and tokenPrice > 0 then
        tokenPrice = GetCoinTextureStringExt(tokenPrice)
    else
        tokenPrice = "N/A"
    end

    return tokenPrice
end

function CalculateMoney(self)
    local moneyBefore = tonumber(SavedVars["MoneyPerChar"][self.playerName]) or 0
    local moneyAfter = GetMoney()

    SavedVars["MoneyMonthly"]["CurrentMonthMoney"] = tonumber(SavedVars["MoneyMonthly"]["CurrentMonthMoney"]) + (moneyAfter - moneyBefore)
    self.averageMoneyMonth = (tonumber(SavedVars["MoneyMonthly"]["PreviousMonthMoney"]) + tonumber(SavedVars["MoneyMonthly"]["CurrentMonthMoney"])) / 2
    self.averageMoneyDay = tonumber(SavedVars["MoneyMonthly"]["CurrentMonthMoney"]) / self.day

    SavedVars["MoneyPerChar"][self.playerName] = moneyAfter

    self.totalMoney = 0
    for character, money in pairs(SavedVars["MoneyPerChar"]) do
        self.totalMoney = self.totalMoney + tonumber(money)
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