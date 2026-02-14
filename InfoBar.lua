local FPS_UPDATERATE = 0.5
local TOKEN_UPDATE_RATE = 5 * 60



BIB_SavedVars = BIB_SavedVars or {}
local SavedVars_Chars = nil
local SavedVars_Player = nil
local SavedVars_History = nil
local SavedVars_PreviousMonth = nil
local SavedVars_CurrentMonth = nil


InfoBarFrameMixin = {}

function InfoBarFrameMixin:OnLoad()
    self.playerName = "_no_char_"
    self.month = 0
    self.day = 0
    self.year = 0
    self.averageMoneyMonth = 0
    self.averageMoneyDay = 0
    self.totalMoney = 0
    self.goldText = ""
    self.tokenPriceText = "N/A"
    self.restedXpText = ""
    self.playTime = 0
    self.levelPlayTime = 0
    self.playTimeText = ""
    self.fpsTicker = nil
    self.tokenTicker = nil

    local backdrop_header = {
        bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 5, right = 5, top = 5, bottom = 5}
    }
    self:SetBackdrop(backdrop_header)
    self:SetBackdropBorderColor(0.5, 0.5, 0.5)
    self:SetBackdropColor(0.5, 0.5, 0.5, 1)

    self:SetFrameStrata("BACKGROUND")

    self:RegisterEvent("VARIABLES_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_XP_UPDATE")
    self:RegisterEvent("TIME_PLAYED_MSG")
    self:RegisterEvent("PLAYER_LOGOUT")
end

function InfoBarFrameMixin:OnEvent(event, ...)
    if event == "VARIABLES_LOADED" then
        BIB_SavedVars["Char"] = BIB_SavedVars["Char"] or {}
        SavedVars_Chars = BIB_SavedVars["Char"]
        BIB_SavedVars["History"] = BIB_SavedVars["History"] or {}
        SavedVars_History = BIB_SavedVars["History"]
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            local curDate = C_DateAndTime.GetCurrentCalendarTime()
            self.day = tonumber(curDate.monthDay)
            self.month = tonumber(curDate.month)
            self.year = tonumber(curDate.year)
            self.playerName = GetRealmName().."-"..UnitName("player")

            SavedVars_Chars[self.playerName] = SavedVars_Chars[self.playerName] or {}
            SavedVars_Player = SavedVars_Chars[self.playerName]
            SavedVars_Player.Money = SavedVars_Player.Money or 0
            SavedVars_Player.PlayTime = SavedVars_Player.PlayTime or 0
            SavedVars_Player.LevelPlayTime = SavedVars_Player.LevelPlayTime or 0
            SavedVars_History[self.year] = SavedVars_History[self.year] or {}
            SavedVars_History[self.year][self.month] = SavedVars_History[self.year][self.month] or {}
            SavedVars_CurrentMonth = SavedVars_History[self.year][self.month]
            SavedVars_CurrentMonth.Gains = SavedVars_CurrentMonth.Gains or 0
            SavedVars_CurrentMonth.Token = SavedVars_CurrentMonth.Token or 0
            SavedVars_CurrentMonth.PlayTime = SavedVars_CurrentMonth.PlayTime or 0

            if self.month > 1 then
                SavedVars_History[self.year][self.month - 1] = SavedVars_History[self.year][self.month - 1] or {}
                SavedVars_PreviousMonth = SavedVars_History[self.year][self.month - 1]
            else
                local prevYear = SavedVars_History[self.year - 1]
                SavedVars_PreviousMonth = (prevYear and prevYear[12]) or {}
            end
            SavedVars_PreviousMonth.Gains = SavedVars_PreviousMonth.Gains or 0
            SavedVars_PreviousMonth.PlayTime = SavedVars_PreviousMonth.PlayTime or 0

            self:CalculateRestedXp()

            self:CalculateMoney()

            RequestTimePlayed()

            if self.fpsTicker then self.fpsTicker:Cancel() end
            if self.tokenTicker then self.tokenTicker:Cancel() end

            self.fpsTicker = C_Timer.NewTicker(FPS_UPDATERATE, function() self:UpdateFps() end)
            self.tokenTicker = C_Timer.NewTicker(TOKEN_UPDATE_RATE, function() self:UpdateTokenPrice() end)

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    elseif event == "PLAYER_MONEY" then
        self:CalculateMoney()
    elseif event == "PLAYER_XP_UPDATE" then
        self:CalculateRestedXp()
    elseif event == "PLAYER_LOGOUT" then
        self:RequestTimePlayed()
    elseif event == "TIME_PLAYED_MSG" then
        local totalTime, levelTime = ...
        self:CalculatePlayTime(totalTime, levelTime)
    end
end

function InfoBarFrameMixin:OnEnter()
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Gold Balance")
    GameTooltip:AddDoubleLine("Total:", GetMoneyString(self.totalMoney, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Month: ", GetMoneyString(SavedVars_CurrentMonth.Gains, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Previous Month: ", GetMoneyString(SavedVars_PreviousMonth.Gains, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Month: ", GetMoneyString(self.averageMoneyMonth, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Average Day: ", GetMoneyString(self.averageMoneyDay, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine("\nPlayed time")
    GameTooltip:AddDoubleLine("Total: ", self:FormatTimePlayed(self.playTime), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Current Month: ", self:FormatTimePlayed(SavedVars_CurrentMonth.PlayTime), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Previous Month: ", self:FormatTimePlayed(SavedVars_PreviousMonth.PlayTime), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end

function InfoBarFrameMixin:OnLeave()
    GameTooltip:Hide()
end

function InfoBarFrameMixin:UpdateFps()
    local fps = math.floor(GetFramerate() + 0.5)
    local fpsText = format("|cff%s%d|r fps", self:GetThresholdHexColor(fps / 60), fps)

    local _, _, lagHome, lagWorld = GetNetStats()
    local lagHomeText = format("|cff%s%d|r ms", self:GetThresholdHexColor(lagHome, 1000, 500, 250, 100, 0), lagHome)
    local lagWorldText = format("|cff%s%d|r ms", self:GetThresholdHexColor(lagWorld, 1000, 500, 250, 100, 0), lagWorld)

    self.text:SetText(fpsText.." | |cFF99CC33H:|r"..lagHomeText.." | |cFF99CC33W:|r"..lagWorldText.." | "..self.goldText.." | "..self.tokenPriceText..self.restedXpText)
end

function InfoBarFrameMixin:UpdateTokenPrice()
    if UnitAffectingCombat("player") then return end

    C_WowTokenPublic.UpdateMarketPrice()

    C_Timer.After(2, function()
        local text = "N/A"
        local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()

        if tokenPrice and tokenPrice > 0 then
            text = GetMoneyString(tokenPrice, true).." ("..math.floor(self.totalMoney / tokenPrice) ..")"

            SavedVars_CurrentMonth.Token = math.min(SavedVars_CurrentMonth.Token, tokenPrice)
        end

        self.tokenPriceText = text
    end)
end

function InfoBarFrameMixin:CalculateMoney()
    local moneyBefore = SavedVars_Player.Money or 0
    local moneyAfter = GetMoney()

    SavedVars_Player.Money = moneyAfter

    SavedVars_CurrentMonth.Gains = SavedVars_CurrentMonth.Gains + (moneyAfter - moneyBefore)

    self.averageMoneyMonth = self:CalculateAverageMonthlyGains(SavedVars_History)
    self.averageMoneyDay = SavedVars_CurrentMonth.Gains / self.day

    self.totalMoney = 0
    for _, data in pairs(SavedVars_Chars) do
        self.totalMoney = self.totalMoney + data.Money
    end

    self.goldText = GetMoneyString((math.floor(self.totalMoney / 10000) * 10000), true)
end

function InfoBarFrameMixin:CalculateRestedXp()
    local restedXp = GetXPExhaustion()
    self.restedXpText = ""

    if restedXp then
        local restXpPer = math.floor(restedXp / UnitXPMax("player") * 100 + 0.5)

        if restXpPer >= 1 then
            self.restedXpText = " | "..restXpPer.."%"
        end
    end
end

function InfoBarFrameMixin:CalculatePlayTime(totalTime, levelTime)
    SavedVars_Player.PlayTime = totalTime
    SavedVars_Player.LevelPlayTime = levelTime

    self.playTime = 0
    self.levelPlayTime = 0
    for _, data in pairs(SavedVars_Chars) do
        self.playTime = self.playTime + data.PlayTime
        self.levelPlayTime = self.levelPlayTime + data.LevelPlayTime
    end

    SavedVars_CurrentMonth.PlayTime = self.playTime - SavedVars_PreviousMonth.PlayTime
end

function InfoBarFrameMixin:FormatTimePlayed(totalSeconds)
    local years = math.floor(totalSeconds / 31536000) -- 365 days * 24 hours * 3600 seconds
    local remainingAfterYears = totalSeconds % 31536000

    local days = math.floor(remainingAfterYears / 86400) -- 24 hours * 3600 seconds
    local remainingAfterDays = remainingAfterYears % 86400

    local hours = math.floor(remainingAfterDays / 3600)
    local minutes = math.floor((remainingAfterDays % 3600) / 60)

    if years > 0 then
        return string.format("%dy %dd %dh", years, days, hours)
    elseif days > 0 then
        return string.format("%dd %dh %dm", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

function InfoBarFrameMixin:CalculateAverageMonthlyGains(savedVarsPreviousMoney)
    local total = 0
    local count = 0

    for _, months in pairs(savedVarsPreviousMoney) do
        for _, monthData in pairs(months) do
            if monthData.Gains and monthData.Gains ~= 0 then
                total = total + monthData.Gains
                count = count + 1
            end
        end
    end

    return count > 0 and (total / count) or 0
end

local function GetThresholdPercentage(quality, ...)
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
        if quality <= worst then return 0 end
        if quality >= best  then return 1 end
        local last = worst
        for i = 2, n - 1 do
            local value = select(i, ...)
            if quality <= value then
                return ((i - 2) + (quality - last) / (value - last)) / (n - 1)
            end
            last = value
        end
        local value = select(n, ...)
        return ((n - 2) + (quality - last) / (value - last)) / (n - 1)
    else
        if quality >= worst then return 0 end
        if quality <= best  then return 1 end
        local last = worst
        for i = 2, n - 1 do
            local value = select(i, ...)
            if quality >= value then
                return ((i - 2) + (quality - last) / (value - last)) / (n - 1)
            end
            last = value
        end
        local value = select(n, ...)
        return ((n - 2) + (quality - last) / (value - last)) / (n - 1)
    end
end

local function GetThresholdColor(quality, ...)
    local inf = 10000000
    if quality ~= quality or quality == inf or quality == -inf then
        return 1, 1, 1
    end

    local percent = GetThresholdPercentage(quality, ...)

    if percent <= 0 then
        return 1, 0, 0
    elseif percent <= 0.5 then
        return 1, percent * 2, 0
    elseif percent >= 1 then
        return 0, 1, 0
    else
        return 2 - percent * 2, 1, 0
    end
end

function InfoBarFrameMixin:GetThresholdHexColor(quality, ...)
    local r, g, b = GetThresholdColor(quality, ...)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end