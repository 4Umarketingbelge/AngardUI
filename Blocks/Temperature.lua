-- AngardUI: виджет «Температура» — вертикальный термометр, значение и статус.
local _, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor
local Y = C.yellow

-- ключи строк; сам текст берётся при показе, чтобы смена языка действовала сразу
local STATUS_KEY = { chill = "T_CHILL", normal = "T_NORMAL", fever = "T_FEVER", overheat = "T_OVERHEAT" }
local STATUS_COLOR = {
	chill = { 0.55, 0.80, 1.00 },
	normal = { Y[1], Y[2], Y[3] },
	fever = { 1.00, 0.60, 0.10 },
	overheat = { 1.00, 0.20, 0.20 },
}

-- Температура в выбранных единицах: 36.6 -> "36,6" или "97,9°F"
function ns.FormatBodyTemp(celsius)
	if ns.db.med.unit == "F" then
		return ns.Decimal(celsius * 9 / 5 + 32, 1) .. "°F"
	end
	return ns.Decimal(celsius, 1)
end

local function Build(view)
	-- термометр: трубка, столбик и круглая колба
	local tube = CreateFrame("Frame", nil, view)
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

	local bulb = view:CreateTexture(nil, "ARTWORK", nil, 2)
	bulb:SetSize(12, 12)
	bulb:SetPoint("CENTER", tube, "BOTTOM", 0, -3)
	bulb:SetColorTexture(1, 1, 1, 1)
	local mask = view:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(bulb)
	bulb:AddMaskTexture(mask)

	local value = ns.Font(view, 19)
	value:SetPoint("TOPLEFT", 30, -14)

	local status = ns.Font(view, 11)
	status:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -3)

	local shownTenths, shownStatus = -1, nil

	function view:UpdateTemp(force)
		local t = ns.med.temp
		local tenths = floor(t * 10 + 0.5)
		if tenths == shownTenths and not force then return end
		shownTenths = tenths
		value:SetText(ns.FormatBodyTemp(t))

		local c = C.temp
		local frac = (t - c.min) / (c.max - c.min)
		if frac < 0.02 then frac = 0.02 elseif frac > 1 then frac = 1 end
		local h = frac * (tube:GetHeight() or 0)
		column:SetHeight(h > 1 and h or 1)

		local st = ns.TempStatus()
		if st ~= shownStatus or force then
			shownStatus = st
			local col = STATUS_COLOR[st]
			value:SetTextColor(col[1], col[2], col[3])
			status:SetTextColor(col[1], col[2], col[3])
			status:SetText(L[STATUS_KEY[st]])
			column:SetColorTexture(col[1], col[2], col[3], 1)
			bulb:SetVertexColor(col[1], col[2], col[3])
		end
	end
end

ns:RegisterWidget("temp", {
	titleKey = "W_TEMP",
	interval = 1,
	usesSim = true,
	Build = Build,
	Update = function(view, force) view:UpdateTemp(force) end,
	Tooltip = function(tt) ns.TempTooltip(tt) end,
})
