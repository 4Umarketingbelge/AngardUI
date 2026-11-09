-- AngardUI: остальные виджеты для сменных квадратов: давление, часы, погода, координаты,
-- скорость, опыт, производительность, сумки, прочность, сессия.
local _, ns = ...
local L, C = ns.L, ns.C
local P = ns.Plain
local floor, max, min = math.floor, math.max, math.min

local GREEN, YELLOW, ORANGE, RED = { 0.25, 0.85, 0.30 }, C.yellow, { 1.00, 0.65, 0.10 }, { 1.00, 0.22, 0.20 }

-- цвет по доле «хорошего»: 1 — зелёный, 0 — красный
local function grade(frac)
	if frac >= 0.5 then return GREEN end
	if frac >= 0.2 then return ORANGE end
	return RED
end

------------------------------------------------------------------------
-- Давление (симуляция: пульс + стресс)
------------------------------------------------------------------------

local BP_TEXT = { normal = L.BP_NORMAL, high = L.BP_HIGH, crisis = L.BP_CRISIS }
local BP_COLOR = { normal = { 1, 1, 1 }, high = ORANGE, crisis = RED }

ns:RegisterSimpleWidget("pressure", L.W_PRESSURE, "heart", C.intervals.sim, function(view, force)
	local med = ns.med
	local sys, dia = floor(med.sys + 0.5), floor(med.dia + 0.5)
	if sys == view.sys and dia == view.dia and not force then return end
	view.sys, view.dia = sys, dia
	local st = ns.PressureStatus()
	local c = BP_COLOR[st]
	view:Set(sys .. "/" .. dia, BP_TEXT[st], c[1], c[2], c[3])
	local b = C.bp
	local barColor = (st == "normal") and GREEN or c
	view:SetBar((sys - b.scaleMin) / (b.scaleMax - b.scaleMin), barColor[1], barColor[2], barColor[3])
end)

------------------------------------------------------------------------
-- Часы: местное время и время игрового мира
------------------------------------------------------------------------

ns:RegisterSimpleWidget("clock", L.W_CLOCK, "time", 1, function(view)
	local h, m = GetGameTime()
	local sub = (type(h) == "number" and type(m) == "number") and L.W_SERVER:format(h, m) or nil
	view:Set(date("%H:%M"), sub)
end)

------------------------------------------------------------------------
-- Погода: выдумана по климату зоны и времени суток (у игры нет такого API)
------------------------------------------------------------------------

local function isDay(hour)
	local day = C_DateAndTime and ns.Call(C_DateAndTime.IsDayTime)
	if type(day) == "boolean" then return day end
	return hour >= 6 and hour < 19
end

ns:RegisterSimpleWidget("weather", L.W_WEATHER, nil, 10, function(view)
	local W = C.weather
	local kind = ns.env.climateKind or "mild"
	local hour = P(GetGameTime(), 12)
	local day = isDay(hour)
	local zone = ns.Call(GetRealZoneText) or ""

	local air = (W.air[kind] or W.air.mild) + (day and 0 or W.night) + ((hour * 7) % 5 - 2)

	local cond
	if kind == "snow" then
		cond = "snow"
	elseif kind == "lava" then
		cond = "ash"
	elseif kind == "desert" and day then
		cond = "heat"
	else
		-- осадки: одинаковы для всех в зоне в течение игрового часа
		local roll = (#zone * 31 + (zone:byte(1) or 0) + hour * 17) % 100
		if roll < (W.rain[kind] or 0) * 100 then
			cond = (kind == "swamp") and "fog" or "rain"
		else
			cond = day and "clear" or "night"
		end
	end

	local text
	if ns.db.med.unit == "F" then
		text = ("%+d°F"):format(floor(air * 9 / 5 + 32 + 0.5))
	else
		text = ("%+d°C"):format(air)
	end
	view:SetIcon("wx_" .. cond)
	view:Set(text, L["WX_" .. cond:upper()])
end)

------------------------------------------------------------------------
-- Координаты
------------------------------------------------------------------------

local function mapXY()
	local map = C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return nil end
	return pos:GetXY()
end

ns:RegisterSimpleWidget("coords", L.W_COORDS, "map", 0.5, function(view)
	local ok, x, y = pcall(mapXY)
	local zone = ns.Call(GetMinimapZoneText)
	if type(zone) ~= "string" or zone == "" then zone = ns.Call(GetRealZoneText) end
	if ok and type(x) == "number" and type(y) == "number" and not ns.issecret(x) then
		view:Set(("%.1f  %.1f"):format(x * 100, y * 100), zone)
	else
		view:Set("—", zone)
	end
end)

------------------------------------------------------------------------
-- Скорость передвижения
------------------------------------------------------------------------

ns:RegisterSimpleWidget("speed", L.W_SPEED, "steps", 0.2, function(view)
	local speed = P(GetUnitSpeed("player"), 0)
	local pct = floor(speed / 7 * 100 + 0.5)
	local state
	if P(UnitOnTaxi("player"), false) then
		state = L.SP_TAXI
	elseif P(IsFlying(), false) then
		state = L.SP_FLY
	elseif P(IsSwimming(), false) then
		state = L.SP_SWIM
	elseif P(IsMounted(), false) then
		state = L.SP_MOUNT
	elseif speed > 0 then
		state = L.SP_RUN
	else
		state = L.SP_STAND
	end
	view:Set(pct .. "%", state)
	view:SetBar(pct / 200, YELLOW[1], YELLOW[2], YELLOW[3])
end)

------------------------------------------------------------------------
-- Опыт
------------------------------------------------------------------------

ns:RegisterSimpleWidget("xp", L.W_XP, "xp", 2, function(view)
	local cur, maxv = P(UnitXP("player"), 0), P(UnitXPMax("player"), 0)
	if maxv <= 0 then
		view:Set(L.W_XP_MAX, nil)
		view:SetBar(nil)
		return
	end
	local rested = P(ns.Call(GetXPExhaustion))
	local sub
	if type(rested) == "number" and rested > 0 then
		sub = L.W_RESTED:format(floor(rested / maxv * 100 + 0.5))
	else
		sub = L.W_LEFT:format(ns.Group(maxv - cur))
	end
	view:Set(floor(cur / maxv * 100) .. "%", sub)
	view:SetBar(cur / maxv, 0.62, 0.35, 0.95)
end)

------------------------------------------------------------------------
-- Производительность: кадры в секунду и задержка
------------------------------------------------------------------------

ns:RegisterSimpleWidget("perf", L.W_PERF, "gear", 1, function(view)
	local fps = floor(P(GetFramerate(), 0) + 0.5)
	local _, _, home, world = GetNetStats()
	local ping = max(P(home, 0), P(world, 0))
	local c = (fps >= 50) and GREEN or (fps >= 25 and ORANGE or RED)
	view:Set(fps .. " fps", L.W_PING:format(ping), c[1], c[2], c[3])
end)

------------------------------------------------------------------------
-- Свободное место в сумках
------------------------------------------------------------------------

local function bagSlots()
	local CC = C_Container
	local freeFn = CC and CC.GetContainerNumFreeSlots or GetContainerNumFreeSlots
	local sizeFn = CC and CC.GetContainerNumSlots or GetContainerNumSlots
	local free, total = 0, 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		free = free + (P(ns.Call(freeFn, bag), 0))
		total = total + (P(ns.Call(sizeFn, bag), 0))
	end
	return free, total
end

ns:RegisterSimpleWidget("bags", L.W_BAGS, "bag", 3, function(view)
	local free, total = bagSlots()
	local c = (free <= 3) and RED or (free <= 8 and ORANGE or GREEN)
	view:Set(free .. " / " .. total, L.W_FREE, c[1], c[2], c[3])
	view:SetBar(total > 0 and (total - free) / total or 0, c[1], c[2], c[3])
end)
ns:On("BAG_UPDATE_DELAYED", function() if ns.db then ns:UpdateWidgets("bags") end end)

------------------------------------------------------------------------
-- Прочность экипировки: самая изношенная вещь
------------------------------------------------------------------------

ns:RegisterSimpleWidget("durability", L.W_DURABILITY, "anvil", 5, function(view)
	local worst
	for slot = 1, 18 do
		local cur, maxv = GetInventoryItemDurability(slot)
		cur, maxv = P(cur), P(maxv)
		if type(cur) == "number" and type(maxv) == "number" and maxv > 0 then
			local frac = cur / maxv
			if not worst or frac < worst then worst = frac end
		end
	end
	if not worst then
		view:Set("—", L.W_DUR_NONE)
		view:SetBar(nil)
		return
	end
	local c = grade(worst)
	view:Set(floor(worst * 100 + 0.5) .. "%", L.W_DUR_WORST, c[1], c[2], c[3])
	view:SetBar(worst, c[1], c[2], c[3])
end)
ns:On("UPDATE_INVENTORY_DURABILITY", function() if ns.db then ns:UpdateWidgets("durability") end end)

------------------------------------------------------------------------
-- Сессия: время в игре с момента входа и изменение денег
------------------------------------------------------------------------

ns:RegisterSimpleWidget("session", L.W_SESSION, "money", 5, function(view)
	local elapsed = GetTime() - (ns.state.loginTime or GetTime())
	local delta = P(GetMoney(), 0) - (ns.state.loginMoney or 0)
	local sign = (delta < 0) and "-" or "+"
	view:Set(ns.FormatDuration(elapsed), sign .. ns.Coins(delta < 0 and -delta or delta))
end)
ns:On("PLAYER_MONEY", function() if ns.db then ns:UpdateWidgets("session") end end)
