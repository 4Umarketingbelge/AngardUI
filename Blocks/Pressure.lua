-- AngardUI: блок 4 — давление: цифры, шкала-градиент с маркером и статус.
local _, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor
local S = C.layout.square

local COLORS = {
	normal = { 1.00, 1.00, 1.00 },
	high = { 1.00, 0.65, 0.10 },
	crisis = { 1.00, 0.20, 0.20 },
}
local STATUS_TEXT = { normal = L.BP_NORMAL, high = L.BP_HIGH, crisis = L.BP_CRISIS }

local block = ns:NewBlock("pressure", S, C.layout.lowerDefault)

local heart = ns.Heart(block, 17)
heart:SetPoint("TOPLEFT", 7, -8)

local value = ns.Font(block, 19)
value:SetPoint("LEFT", heart, "RIGHT", 5, 0)

-- шкала: зелёный -> жёлтый -> красный (две половины с градиентом)
local BAR_W = S - 16
local bar = CreateFrame("Frame", nil, block)
bar:SetSize(BAR_W, 5)
bar:SetPoint("LEFT", block, "LEFT", 8, -4)

local function half(point, c1, c2)
	local t = bar:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(1, 1, 1, 1)
	t:SetSize(BAR_W / 2, 5)
	t:SetPoint(point)
	local ok = pcall(function()
		t:SetGradient("HORIZONTAL", CreateColor(c1[1], c1[2], c1[3], 1), CreateColor(c2[1], c2[2], c2[3], 1))
	end)
	if not ok then t:SetColorTexture(c2[1], c2[2], c2[3], 1) end
end
half("LEFT", { 0.15, 0.80, 0.25 }, { 0.95, 0.85, 0.15 })
half("RIGHT", { 0.95, 0.85, 0.15 }, { 0.90, 0.15, 0.15 })

local marker = bar:CreateTexture(nil, "OVERLAY")
marker:SetColorTexture(1, 1, 1, 1)
marker:SetSize(3, 13)

local status = ns.Font(block, 11)
status:SetPoint("BOTTOMLEFT", 8, 7)

local shownSys, shownDia, shownStatus = -1, -1, nil

function block:Update()
	local med = ns.med
	local sys, dia = floor(med.sys + 0.5), floor(med.dia + 0.5)
	if sys == shownSys and dia == shownDia then return end
	shownSys, shownDia = sys, dia
	value:SetText(sys .. "/" .. dia)

	local b = C.bp
	local frac = (sys - b.scaleMin) / (b.scaleMax - b.scaleMin)
	if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
	marker:ClearAllPoints()
	marker:SetPoint("CENTER", bar, "LEFT", frac * BAR_W, 0)

	local st = ns.PressureStatus()
	if st ~= shownStatus then
		shownStatus = st
		local c = COLORS[st]
		value:SetTextColor(c[1], c[2], c[3])
		status:SetTextColor(c[1], c[2], c[3])
		status:SetText(STATUS_TEXT[st])
		if st == "normal" then heart:SetVertexColor(0.90, 0.15, 0.20) else heart:SetVertexColor(c[1], c[2], c[3]) end
	end
end

function block:Refresh()
	shownSys, shownStatus = -1, nil
	self:Update()
end
