-- AngardUI: блок 4 — здоровье и ресурс (мана, ярость, энергия) двумя полосками.
-- В бою эти значения «секретные»: сравнивать и считать их нельзя, но StatusBar и
-- форматированный текст их принимают — поэтому числа передаются игре как есть.
local _, ns = ...
local C = ns.C
local P = ns.Plain
local S = C.layout.square
local PAD, GAP = 7, 6
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local HEALTH_COLOR = { 0.15, 0.80, 0.20 }
local POWER_COLORS = {
	MANA = { 0.20, 0.45, 1.00 },
	RAGE = { 0.90, 0.15, 0.15 },
	ENERGY = { 1.00, 0.90, 0.20 },
	FOCUS = { 1.00, 0.55, 0.25 },
}

local block = ns:NewBlock("vitals", S, C.layout.lowerDefault)

local function Bar(color)
	local bar = CreateFrame("StatusBar", nil, block)
	bar:SetStatusBarTexture(TEXTURE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.text = ns.Font(bar, 12, 1, 1, 1, "CENTER")
	bar.text:SetPoint("CENTER", 0, 0)
	function bar:SetColor(c)
		self:SetStatusBarColor(c[1], c[2], c[3])
		self.bg:SetColorTexture(c[1] * 0.22, c[2] * 0.22, c[3] * 0.22, 0.9)
	end
	bar:SetColor(color)
	return bar
end

local health = Bar(HEALTH_COLOR)
local power = Bar(POWER_COLORS.MANA)

-- Высота блока зависит от карточки: полоски делят её пополам.
block:SetScript("OnSizeChanged", function(self, w, h)
	local barH = (h - PAD * 2 - GAP) / 2
	if barH < 4 then barH = 4 end
	health:ClearAllPoints()
	health:SetPoint("TOPLEFT", PAD, -PAD)
	health:SetSize(w - PAD * 2, barH)
	power:ClearAllPoints()
	power:SetPoint("BOTTOMLEFT", PAD, PAD)
	power:SetSize(w - PAD * 2, barH)
end)

-- Без сравнений и арифметики: значения могут быть секретными.
local function fill(bar, cur, maxv)
	bar:SetMinMaxValues(0, maxv)
	bar:SetValue(cur)
	bar.text:SetFormattedText("%d / %d", cur, maxv)
end

local function Set(bar, cur, maxv)
	if not pcall(fill, bar, cur, maxv) then bar.text:SetText("") end
end

local function UpdateHealth()
	Set(health, UnitHealth("player"), UnitHealthMax("player"))
end

local function UpdatePower()
	Set(power, UnitPower("player"), UnitPowerMax("player"))
end

local function UpdatePowerType()
	local _, token = UnitPowerType("player")
	token = P(token)
	local c = token and POWER_COLORS[token]
	if not c and token and type(PowerBarColor) == "table" and PowerBarColor[token] then
		local p = PowerBarColor[token]
		if p.r then c = { p.r, p.g, p.b } end
	end
	power:SetColor(c or POWER_COLORS.MANA)
end

function block:Refresh()
	UpdatePowerType()
	UpdateHealth()
	UpdatePower()
end

local function onHealth(_, unit)
	if unit == "player" and ns.db and block:IsShown() then UpdateHealth() end
end
local function onPower(_, unit)
	if unit == "player" and ns.db and block:IsShown() then UpdatePower() end
end

ns:On("UNIT_HEALTH", onHealth)
ns:On("UNIT_MAXHEALTH", onHealth)
ns:On("UNIT_POWER_UPDATE", onPower)
ns:On("UNIT_MAXPOWER", onPower)
ns:On("UNIT_DISPLAYPOWER", function(_, unit)
	if unit == "player" and ns.db and block:IsShown() then
		UpdatePowerType()
		UpdatePower()
	end
end)
