-- AngardUI: эффекты панели.
-- 1. Блик при новом уровне: наклонная полоса света проходит по всей панели, как отблеск на щите.
-- 2. Тревога: в бою рамки из золотых (или фракционных) становятся красными,
--    а при здоровье ниже 50% поверх них бьётся яркая подсветка в такт пульсу.
--    В бою здоровье для аддонов секретное, поэтому «ниже 50%?» считает сама игра:
--    UnitHealthPercent с кривой-ступенькой возвращает секретные 1 или 0, и это значение
--    уходит прямо в прозрачность подсветки. Аддон сравнивать его не может и не сравнивает.
-- Оба эффекта крутят OnUpdate только пока что-то меняется; в покое кадры не тратятся.
local _, ns = ...
local root = ns.root
local issecret = ns.issecret
local sin, exp, pi, min, max = math.sin, math.exp, math.pi, math.min, math.max

------------------------------------------------------------------------
-- Блик при новом уровне
------------------------------------------------------------------------

local BAND = 70        -- ширина полосы света
local SKEW = 45        -- наклон: верх полосы сдвинут вправо на столько пикселей
local DURATION = 1.25  -- секунды на проход
local GLOW = { 1, 0.86, 0.52 }
local PEAK = 0.55      -- яркость середины полосы
local FLASH = 0.16     -- общая золотая вспышка по панели

-- Рамка-маска: всё, что вылезает за панель, обрезается
local clip = CreateFrame("Frame", nil, root)
clip:SetAllPoints(root)
clip:SetFrameLevel(root:GetFrameLevel() + 60)
if clip.SetClipsChildren then pcall(clip.SetClipsChildren, clip, true) end
clip:Hide()

local flash = clip:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints()
flash:SetColorTexture(GLOW[1], GLOW[2], GLOW[3], 1)
flash:SetBlendMode("ADD")
flash:SetAlpha(0)

local band = CreateFrame("Frame", nil, clip)
band:SetWidth(BAND)

local function half(fromAlpha, toAlpha, anchor)
	local t = band:CreateTexture(nil, "OVERLAY")
	t:SetColorTexture(1, 1, 1, 1)
	t:SetBlendMode("ADD")
	t:SetWidth(BAND / 2)
	t:SetPoint("TOP" .. anchor)
	t:SetPoint("BOTTOM" .. anchor)
	if t.SetGradient and CreateColor then
		pcall(t.SetGradient, t, "HORIZONTAL",
			CreateColor(GLOW[1], GLOW[2], GLOW[3], fromAlpha),
			CreateColor(GLOW[1], GLOW[2], GLOW[3], toAlpha))
	else
		t:SetAlpha(PEAK * 0.5)
	end
	-- верхние вершины (1 — левая, 3 — правая) уходят вправо: полоса наклоняется
	if t.SetVertexOffset then
		pcall(t.SetVertexOffset, t, 1, SKEW, 0)
		pcall(t.SetVertexOffset, t, 3, SKEW, 0)
	end
	return t
end
half(0, PEAK, "LEFT")
half(PEAK, 0, "RIGHT")

local shineTime = 0
local function placeBand(x)
	band:ClearAllPoints()
	band:SetPoint("TOPLEFT", clip, "TOPLEFT", x, 0)
	band:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", x, 0)
end

clip:SetScript("OnUpdate", function(self, dt)
	shineTime = shineTime + dt
	local p = shineTime / DURATION
	if p >= 1 then
		self:Hide()
		return
	end
	-- плавный разгон и торможение
	local e = p < 0.5 and 2 * p * p or 1 - (2 - 2 * p) ^ 2 / 2
	local from = -BAND - SKEW
	placeBand(from + (root:GetWidth() - from) * e)
	flash:SetAlpha(sin(pi * p) * FLASH)
end)

function ns:PlayShine()
	if not root:IsShown() then return end
	shineTime = 0
	placeBand(-BAND - SKEW)
	flash:SetAlpha(0)
	clip:Show()
end

ns:On("PLAYER_LEVEL_UP", function()
	if ns.db and ns.db.fx.levelShine then ns:PlayShine() end
end)

------------------------------------------------------------------------
-- Красные рамки в бою и при низком здоровье
------------------------------------------------------------------------

local RED = { 0.95, 0.12, 0.08 }
local FADE = 2.5        -- скорость перехода цвета (доля в секунду)
local LOW_HP = 0.5

local tint, target = 0, 0  -- 0 — обычный цвет рамки, 1 — красный
local throb = false        -- подсветка бьётся (здоровье ниже 50% или неизвестно, но игра его проверит сама)
local beat = 0             -- фаза сердечного цикла 0..1

-- кривая-ступенька: 1 ниже LOW_HP, 0 от LOW_HP и выше
local curve
local function lowCurve()
	if curve == nil then
		curve = false
		local CU = C_CurveUtil
		local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
		if CU and CU.CreateCurve and step then
			local ok, c = pcall(CU.CreateCurve)
			if ok and c
				and pcall(c.SetType, c, step)
				and pcall(c.AddPoint, c, 0, 1)
				and pcall(c.AddPoint, c, LOW_HP, 0)
				and pcall(c.AddPoint, c, 1, 0) then
				curve = c
			end
		end
	end
	return curve or nil
end

-- 1 или 0 — здоровье ниже 50% (обычное число); секретное значение — решает игра; nil — неизвестно
local function lowValue()
	if ns.Plain(UnitIsDeadOrGhost("player"), false) then return 0 end
	local h, m = UnitHealth("player"), UnitHealthMax("player")
	if type(h) == "number" and type(m) == "number" and not issecret(h) and not issecret(m) and m > 0 then
		return h / m < LOW_HP and 1 or 0
	end
	if type(UnitHealthPercent) == "function" and lowCurve() then
		local ok, v = pcall(UnitHealthPercent, "player", true, curve)
		-- секретное значение нельзя ни сравнивать, ни проверять в условии — только передать дальше
		if ok and (issecret(v) or type(v) == "number") then return v end
	end
	return nil
end

-- удар сердца: сильный «тук» и слабый «тук» следом, между ними тишина
local function heartbeat(f)
	local a = exp(-((f - 0.06) / 0.07) ^ 2)
	local b = 0.6 * exp(-((f - 0.30) / 0.08) ^ 2)
	return max(a, b)
end

local layers = ns.alertLayers

local function setGlow(v)
	for i = 1, #layers do
		local e = layers[i].edges
		for j = 1, #e do pcall(e[j].SetAlpha, e[j], v) end
	end
end

local function setBeat(a)
	for i = 1, #layers do layers[i]:SetAlpha(a) end
end

local alert = CreateFrame("Frame")
alert:Hide()

local function paint()
	local r, g, b = ns.BorderColor()
	ns.PaintBorders(r + (RED[1] - r) * tint, g + (RED[2] - g) * tint, b + (RED[3] - b) * tint)
end

alert:SetScript("OnUpdate", function(self, dt)
	if tint < target then tint = min(target, tint + dt * FADE)
	elseif tint > target then tint = max(target, tint - dt * FADE) end
	if throb then
		local bpm = ns.med and ns.Plain(ns.med.pulse, nil)
		if type(bpm) ~= "number" or bpm < 40 then bpm = 110 end
		beat = (beat + dt * bpm / 60) % 1
		setBeat(heartbeat(beat))
	end
	paint()
	if tint == target and not throb then self:Hide() end
end)

-- Пересчитать тревогу; вызывается из событий и из ApplyBorders
function ns.UpdateAlert()
	if not ns.db then return end
	local on = ns.db.fx.combatBorders
	local v = nil
	if on then v = lowValue() end
	local secret = issecret(v)
	local low = not secret and v == 1
	target = (on and (ns.state.inCombat or low)) and 1 or 0
	throb = (secret or low) and true or false
	if throb then
		setGlow(v)
	else
		setBeat(0)
	end
	if tint ~= target or throb then alert:Show() else alert:Hide() end
	paint()
end

local function onUnit(_, unit)
	if unit == nil or unit == "player" then ns.UpdateAlert() end
end
ns:On("PLAYER_REGEN_DISABLED", ns.UpdateAlert)
ns:On("PLAYER_REGEN_ENABLED", ns.UpdateAlert)
ns:On("UNIT_HEALTH", onUnit)
ns:On("UNIT_MAXHEALTH", onUnit)
ns:On("PLAYER_DEAD", ns.UpdateAlert)
ns:On("PLAYER_ALIVE", ns.UpdateAlert)
ns:On("PLAYER_UNGHOST", ns.UpdateAlert)
