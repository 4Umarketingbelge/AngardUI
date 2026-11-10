-- AngardUI: блок 7 — питомец: портрет (вдвое меньше портрета игрока), справа полоска
-- здоровья и «корм» — ряд кусочков, который съедается в сторону портрета, когда питомец
-- голоден. Обычные незащищённые фреймы: появляются и исчезают по UNIT_PET, в том числе в бою.
local _, ns = ...
local L, C = ns.L, ns.C
local P = ns.Plain
local lay = C.layout
local H = lay.square / 2
local W = lay.square * 2 + lay.gap
local GAP = lay.gap
local RIGHT_W = W - H - GAP
local FOOD_H = 22
local HP_H = H - FOOD_H - GAP
local PIECE = 16

-- сам блок — прозрачный контейнер; рамки у трёх внутренних частей
local block = ns:NewBlock("pet", W, H, true)

local portraitBox = CreateFrame("Frame", nil, block)
portraitBox:SetSize(H, H)
portraitBox:SetPoint("TOPLEFT")
ns.Skin(portraitBox)
local portrait = ns.CreatePortrait(portraitBox)

------------------------------------------------------------------------
-- Здоровье
------------------------------------------------------------------------

local hpBox = CreateFrame("Frame", nil, block)
hpBox:SetSize(RIGHT_W, HP_H)
hpBox:SetPoint("TOPLEFT", H + GAP, 0)
ns.Skin(hpBox)

local hp = CreateFrame("StatusBar", nil, hpBox)
hp:SetPoint("TOPLEFT", 4, -4)
hp:SetPoint("BOTTOMRIGHT", -4, 4)
hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
hp:SetStatusBarColor(0.15, 0.80, 0.20)
hp:SetMinMaxValues(0, 1)
hp:SetValue(1)
local hpBg = hp:CreateTexture(nil, "BACKGROUND")
hpBg:SetAllPoints()
hpBg:SetColorTexture(0.03, 0.18, 0.05, 0.9)
local nameText = ns.Font(hp, 12)
nameText:SetPoint("LEFT", 6, 0)
nameText:SetPoint("RIGHT", hp, "CENTER", 10, 0)
nameText:SetWordWrap(false)
local hpText = ns.Font(hp, 12, 1, 1, 1, "RIGHT")
hpText:SetPoint("RIGHT", -6, 0)

-- Значения здоровья в бою секретные: передаём их игре как есть, без вычислений.
local function fillHealth(cur, maxv)
	hp:SetMinMaxValues(0, maxv)
	hp:SetValue(cur)
	hpText:SetFormattedText("%d / %d", cur, maxv)
end

local function UpdateHealth()
	if not pcall(fillHealth, UnitHealth("pet"), UnitHealthMax("pet")) then hpText:SetText("") end
end

------------------------------------------------------------------------
-- Сытость
------------------------------------------------------------------------

local foodBox = CreateFrame("Frame", nil, block)
foodBox:SetSize(RIGHT_W, FOOD_H)
foodBox:SetPoint("BOTTOMLEFT", H + GAP, 0)
ns.Skin(foodBox)
foodBox:EnableMouse(true)
ns.Tooltip(foodBox, function(tt, self)
	tt:AddLine(L.PET_MOOD, C.gold[1], C.gold[2], C.gold[3])
	if self.mood then tt:AddLine(L["PET_MOOD_" .. self.mood], 1, 1, 1) end
end, true)

local pieces = {}
for i = 1, C.pet.pieces do
	local t = foodBox:CreateTexture(nil, "ARTWORK")
	t:SetSize(PIECE, PIECE)
	t:SetPoint("LEFT", 5 + (i - 1) * (PIECE + 4), 0)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pieces[i] = t
end

-- Настроение питомца охотника: 1 — недоволен, 2 — доволен, 3 — счастлив.
-- У питомцев без сытости (например, у чернокнижника) функция ничего не возвращает.
local function GetHappiness()
	local h = C_PetInfo and ns.Call(C_PetInfo.GetPetHappiness)
	if h == nil then h = ns.Call(GetPetHappiness) end
	h = P(h)
	if type(h) == "number" and h >= 1 and h <= 3 then return h end
	return nil
end

local function UpdateFood()
	local happiness = GetHappiness()
	foodBox:SetShown(happiness ~= nil)
	foodBox.mood = happiness
	if not happiness then return end

	local style = C.petFood[ns.db.pet.food] or C.petFood.meat
	local whole = ns.Icon(style.icon)
	local eaten = style.eaten and ns.Icon(style.eaten) or nil
	local left = C.pet.byHappiness[happiness] or #pieces
	for i = 1, #pieces do
		local t = pieces[i]
		if i <= left then
			-- целые куски остаются со стороны портрета
			t:SetTexture(whole)
			t:SetDesaturated(false)
			t:SetAlpha(1)
		elseif eaten then
			t:SetTexture(eaten) -- обглоданная кость или скелет
			t:SetDesaturated(false)
			t:SetAlpha(0.55)
		else
			t:SetTexture(whole) -- просто бледный след
			t:SetDesaturated(true)
			t:SetAlpha(0.22)
		end
	end
end

------------------------------------------------------------------------
-- Портрет и общее обновление
------------------------------------------------------------------------

local dead, applied = false, nil

local function UpdateDead(force)
	-- в бою признак смерти может быть недоступен — тогда оставляем прежний
	local d = P(UnitIsDead("pet"))
	if d ~= nil then dead = d and true or false end
	if force or dead ~= applied then
		applied = dead
		portrait:SetDead(dead)
	end
end

local function UpdateAll()
	portrait:SetUnit("pet")
	UpdateDead(true)
	nameText:SetText(P(UnitName("pet"), ""))
	UpdateHealth()
	UpdateFood()
end

function block:Refresh()
	ns.state.hasPet = P(UnitExists("pet"), false) and true or false
	if not ns.state.hasPet then
		dead = false
		return
	end
	UpdateAll()
end

local function petChanged()
	if not ns.db then return end
	block:Refresh()
	ns:Layout()
end

local function active(unit)
	return unit == "pet" and ns.db and block:IsShown()
end

ns:On("UNIT_PET", function(_, unit)
	if unit ~= "player" then return end
	petChanged()
	-- модель нового питомца может догрузиться чуть позже
	C_Timer.After(0.5, function() ns.Safe(petChanged) end)
end)

ns:On("UNIT_MODEL_CHANGED", function(_, unit)
	if active(unit) then
		portrait:SetUnit("pet")
		UpdateDead(true)
	end
end)

local function healthEvent(_, unit)
	if active(unit) then
		UpdateHealth()
		UpdateDead()
	end
end
ns:On("UNIT_HEALTH", healthEvent)
ns:On("UNIT_MAXHEALTH", healthEvent)
ns:On("UNIT_FLAGS", function(_, unit) if active(unit) then UpdateDead() end end)
ns:On("UNIT_HAPPINESS", function(_, unit) if active(unit) then UpdateFood() end end)
ns:On("UNIT_NAME_UPDATE", function(_, unit)
	if active(unit) then nameText:SetText(P(UnitName("pet"), "")) end
end)
