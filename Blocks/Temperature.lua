-- AngardUI: блок 5 — температура: вертикальный термометр, значение и статус.
local _, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor
local S = C.layout.square
local Y = C.yellow

local STATUS_TEXT = { chill = L.T_CHILL, normal = L.T_NORMAL, fever = L.T_FEVER, overheat = L.T_OVERHEAT }
local STATUS_COLOR = {
	chill = { 0.55, 0.80, 1.00 },
	normal = { Y[1], Y[2], Y[3] },
	fever = { 1.00, 0.60, 0.10 },
	overheat = { 1.00, 0.20, 0.20 },
}

local block = ns:NewBlock("temp", S, C.layout.lowerDefault)

-- термометр: трубка, столбик и круглая колба
local tube = CreateFrame("Frame", nil, block)
tube:SetWidth(4)
tube:SetPoint("TOPLEFT", 14, -8)
tube:SetPoint("BOTTOMLEFT", 14, 18)

local tubeBg = tube:CreateTexture(nil, "ARTWORK", nil, 0)
tubeBg:SetAllPoints()
tubeBg:SetColorTexture(1, 1, 1, 0.22)

local column = tube:CreateTexture(nil, "ARTWORK", nil, 1)
column:SetPoint("BOTTOMLEFT")
column:SetPoint("BOTTOMRIGHT")
column:SetHeight(1)

local bulb = block:CreateTexture(nil, "ARTWORK", nil, 2)
bulb:SetSize(12, 12)
bulb:SetPoint("CENTER", tube, "BOTTOM", 0, -3)
bulb:SetColorTexture(1, 1, 1, 1)
local mask = block:CreateMaskTexture()
mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(bulb)
bulb:AddMaskTexture(mask)

local value = ns.Font(block, 19)
value:SetPoint("TOPLEFT", 30, -14)

local status = ns.Font(block, 11)
status:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -3)

local shownTenths, shownStatus = -1, nil

function block:Update()
	local t = ns.med.temp
	local tenths = floor(t * 10 + 0.5)
	if tenths == shownTenths then return end
	shownTenths = tenths

	if ns.db.med.unit == "F" then
		value:SetText(ns.Decimal(t * 9 / 5 + 32, 1) .. "°F")
	else
		value:SetText(ns.Decimal(t, 1))
	end

	local c = C.temp
	local frac = (t - c.min) / (c.max - c.min)
	if frac < 0.02 then frac = 0.02 elseif frac > 1 then frac = 1 end
	column:SetHeight(frac * tube:GetHeight())

	local st = ns.TempStatus()
	if st ~= shownStatus then
		shownStatus = st
		local col = STATUS_COLOR[st]
		value:SetTextColor(col[1], col[2], col[3])
		status:SetTextColor(col[1], col[2], col[3])
		status:SetText(STATUS_TEXT[st])
		column:SetColorTexture(col[1], col[2], col[3], 1)
		bulb:SetVertexColor(col[1], col[2], col[3])
	end
end

function block:Refresh()
	shownTenths, shownStatus = -1, nil
	self:Update()
end

-- высота блока зависит от карточки — столбик пересчитывается при изменении размера
block:SetScript("OnSizeChanged", function(self)
	if ns.db then self:Refresh() end
end)
