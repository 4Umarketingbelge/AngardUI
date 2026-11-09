-- AngardUI: блок 7 — портрет активного питомца (вдвое меньше портрета игрока).
-- Обычный незащищённый фрейм: появляется и исчезает по UNIT_PET, в том числе в бою.
local _, ns = ...
local P = ns.Plain
local S = ns.C.layout.square / 2

local block = ns:NewBlock("pet", S, S)
local portrait = ns.CreatePortrait(block)
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

function block:Refresh()
	ns.state.hasPet = P(UnitExists("pet"), false) and true or false
	if not ns.state.hasPet then
		dead = false
		return
	end
	portrait:SetUnit("pet")
	UpdateDead(true)
end

local function petChanged()
	if not ns.db then return end
	block:Refresh()
	ns:Layout()
	if ns.state.hasPet and block:IsShown() then
		portrait:SetUnit("pet")
		UpdateDead(true)
	end
end

ns:On("UNIT_PET", function(_, unit)
	if unit ~= "player" then return end
	petChanged()
	-- модель нового питомца может догрузиться чуть позже
	C_Timer.After(0.5, function() ns.Safe(petChanged) end)
end)

ns:On("UNIT_MODEL_CHANGED", function(_, unit)
	if unit == "pet" and ns.db and block:IsShown() then
		portrait:SetUnit("pet")
		UpdateDead(true)
	end
end)

local function healthEvent(_, unit)
	if unit == "pet" and ns.db and block:IsShown() then UpdateDead() end
end
ns:On("UNIT_HEALTH", healthEvent)
ns:On("UNIT_FLAGS", healthEvent)
