-- AngardUI: симуляция «медицины». Чистая выдумка по игровым событиям: аддон только
-- читает состояние персонажа и ничего не делает в игре.
-- Все коэффициенты — в Config.lua (ns.C.pulse / stress / bp / temp).
local _, ns = ...
local C = ns.C
local P, issecret = ns.Plain, ns.issecret
local exp, min, max, random = math.exp, math.min, math.max, math.random

-- Текущие показатели (их читают блоки)
local med = { pulse = 68, sys = 118, dia = 76, temp = 36.6, stress = 0, rest = 68, dead = false }
ns.med = med

-- Наблюдаемое состояние
local env = {
	hp = 1, hpKnown = false,
	combatTime = 0, attackers = 0,
	targetElite = false, targetBoss = false, levelDiff = 0, targetSkull = false,
	breath = false, sitting = false, eating = false, sick = false,
	drunk = 0, drunkAt = 0,
	climate = 0, impulse = 0, sustain = 0,
	aurasDirty = true,
}
ns.env = env

local raw = { pulse = 68, sys = 118, dia = 76, temp = 36.6 }
local noise = { pulse = 0, bp = 0, temp = 0 }

local sim = {}
ns.modules[#ns.modules + 1] = sim

local function approach(cur, target, dt, tau)
	return cur + (target - cur) * (1 - exp(-dt / tau))
end

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

-- медленно блуждающий шум в пределах ±amp
local function wander(key, amp)
	local n = noise[key] * 0.9 + (random() - 0.5) * amp * 0.6
	n = clamp(n, -amp, amp)
	noise[key] = n
	return n
end

------------------------------------------------------------------------
-- Сбор данных
------------------------------------------------------------------------

-- Климат зоны: сравниваем название подзоны/зоны с названиями из таблицы AreaID.
local climateByName
local function UpdateZone()
	if not climateByName then
		climateByName = {}
		local getInfo = C_Map and C_Map.GetAreaInfo
		for areaID, kind in pairs(C.zones) do
			local name = ns.Call(getInfo, areaID)
			if type(name) == "string" and name ~= "" then climateByName[name] = kind end
		end
	end
	local kind = climateByName[ns.Call(GetSubZoneText) or ""] or climateByName[ns.Call(GetRealZoneText) or ""]
	env.climate = kind and C.temp.climate[kind] or 0
	env.climateKind = kind or "mild"
end

-- Дебаффы болезнь/яд и ауры еды/питья. В бою поля аур могут быть секретными —
-- тогда оставляем прежнее значение.
local function ScanAuras()
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then return end
	local sick, eating, unknown = false, false, false
	for i = 1, 40 do
		local a = get("player", i, "HARMFUL")
		if not a then break end
		local d = a.dispelName
		if issecret(d) then
			unknown = true
		elseif d == "Disease" or d == "Poison" then
			sick = true
		end
	end
	for i = 1, 40 do
		local a = get("player", i, "HELPFUL")
		if not a then break end
		local name = a.name
		if issecret(name) then
			unknown = true
		elseif name and C.foodAuras[name] then
			eating = true
		end
	end
	if sick or not unknown then env.sick = sick end
	if eating or not unknown then env.eating = eating end
end

-- Число атакующих: враждебные индикаторы здоровья, у которых игрок в списке угрозы.
-- Боевой журнал аддонам недоступен, поэтому это приближение.
local function CountAttackers()
	local n = 0
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		for i = 1, #plates do
			local unit = plates[i].namePlateUnitToken
			if unit then
				local threat = UnitThreatSituation("player", unit)
				-- проверка на истинность разрешена и для секретного числа (nil = нет угрозы)
				if threat then n = n + 1 end
			end
		end
	end
	return n
end

local function UpdateTarget()
	env.targetElite, env.targetBoss, env.targetSkull, env.levelDiff = false, false, false, 0
	if not P(UnitExists("target"), false) then return end
	if not P(UnitCanAttack("player", "target"), false) then return end
	if P(UnitIsDead("target"), false) then return end
	local class = P(UnitClassification("target"), "normal")
	if class == "worldboss" then
		env.targetBoss = true
	elseif class == "elite" or class == "rareelite" then
		env.targetElite = true
	end
	local lvl, mine = P(UnitLevel("target"), 0), P(UnitLevel("player"), 0)
	if lvl == -1 then
		env.targetSkull = true
	elseif lvl > 0 and mine > 0 then
		env.levelDiff = lvl - mine
	end
end

-- Раз в секунду: всё, что не нужно читать чаще
local function SlowScan()
	if not ns.root:IsShown() then return end
	if env.aurasDirty then
		env.aurasDirty = false
		pcall(ScanAuras)
	end
	if ns.state.inCombat then
		local ok, n = pcall(CountAttackers)
		env.attackers = max(ok and n or 0, 1)
	else
		env.attackers = 0
	end
	pcall(UpdateTarget)
	if env.drunk > 0 and GetTime() - env.drunkAt > C.temp.drunkFade then
		env.drunk = env.drunk - 1
		env.drunkAt = GetTime()
	end
end

------------------------------------------------------------------------
-- Шаг симуляции
------------------------------------------------------------------------

local function Tick(dt)
	if not ns.root:IsShown() then return end
	if dt > 2 then dt = 2 end
	local Cp, Cs, Cb, Ct = C.pulse, C.stress, C.bp, C.temp
	local sens = C.sensitivity[ns.db.med.sens] or 1
	local inCombat = ns.state.inCombat

	local dead = P(UnitIsDeadOrGhost("player"), false) and true or false
	med.dead = dead

	-- здоровье (в бою может быть секретным — тогда держим последнее известное)
	local h, m = UnitHealth("player"), UnitHealthMax("player")
	if type(h) == "number" and type(m) == "number" and not issecret(h) and not issecret(m) and m > 0 then
		local hp = h / m
		if env.hpKnown and hp < env.hp then
			env.impulse = env.impulse + (env.hp - hp) * Cs.lossGain * sens
		end
		env.hp, env.hpKnown = hp, true
	else
		env.hpKnown = false
	end

	local speed = P(GetUnitSpeed("player"), 0)
	local moving = speed > 0
	local mounted = P(IsMounted(), false) or P(UnitOnTaxi("player"), false)
	local swimming = P(IsSwimming(), false)
	local falling = P(IsFalling(), false)
	if moving or falling or mounted or swimming then env.sitting = false end

	if inCombat then env.combatTime = env.combatTime + dt else env.combatTime = 0 end

	-- СТРЕСС: затухающие импульсы + постоянная составляющая
	env.impulse = env.impulse * exp(-dt / Cs.decay)
	local sustain = 0
	if env.targetSkull then
		sustain = sustain + Cs.skull
	elseif env.levelDiff >= Cs.levelDiff then
		sustain = sustain + Cs.higherLevel
	end
	if P(UnitIsPVP("player"), false) then sustain = sustain + Cs.pvp end
	env.sustain = approach(env.sustain, sustain * sens, dt, Cs.tau)
	med.stress = clamp(env.impulse + env.sustain, 0, Cs.max)

	-- ПУЛЬС
	local up, down = 0, 0
	if inCombat then
		up = up + Cp.combat + min(env.attackers, Cp.maxAttackers) * Cp.perAttacker
	end
	if env.targetBoss or env.targetSkull then
		up = up + Cp.boss
	elseif env.targetElite then
		up = up + Cp.elite
	end
	up = up + (1 - env.hp) * Cp.lowHealth
	if swimming then
		up = up + Cp.swim
	elseif moving and not mounted then
		up = up + Cp.run
	end
	if falling then up = up + Cp.fall end
	if env.breath then up = up + Cp.breath end
	if not inCombat then
		if env.sitting or env.eating then down = down + Cp.sit end
		if env.eating then down = down + Cp.eat end
		if P(IsResting(), false) then down = down + Cp.rest end
	end

	local target = dead and 0 or clamp(med.rest + up * sens + med.stress * Cp.perStress + down, Cp.min, Cp.max)
	local tau = dead and Cp.tauDeath or (target > raw.pulse and Cp.tauUp or Cp.tauDown)
	raw.pulse = approach(raw.pulse, target, dt, tau)
	if dead then
		med.pulse = raw.pulse < 3 and 0 or raw.pulse
	else
		med.pulse = clamp(raw.pulse + wander("pulse", Cp.noise), Cp.min, Cp.max)
	end

	-- ДАВЛЕНИЕ: пульс сверх покоя + стресс
	local over = max(raw.pulse - med.rest, 0)
	local sysT = dead and 0 or (Cb.sysBase + over * Cb.sysPerBpm + med.stress * Cb.sysPerStress)
	local diaT = dead and 0 or (Cb.diaBase + over * Cb.diaPerBpm + med.stress * Cb.diaPerStress)
	raw.sys = approach(raw.sys, sysT, dt, dead and Cp.tauDeath or Cb.tau)
	raw.dia = approach(raw.dia, diaT, dt, dead and Cp.tauDeath or Cb.tau)
	local bpNoise = dead and 0 or wander("bp", Cb.noise)
	med.sys = max(raw.sys + bpNoise, 0)
	med.dia = max(raw.dia + bpNoise * 0.6, 0)

	-- ТЕМПЕРАТУРА
	local climate = env.climate
	if P(IsIndoors(), false) then climate = climate * Ct.indoorsFactor end
	local tT = Ct.base + climate
	local heat = 0
	if env.sick then heat = heat + Ct.sick end
	heat = heat + env.drunk * Ct.drunkPerLevel
	heat = heat + min(env.combatTime / Ct.combatRamp, 1) * Ct.combatMax
	if moving and not mounted and not swimming then heat = heat + Ct.run end
	tT = tT + heat * sens
	if swimming then tT = tT + Ct.swim end
	raw.temp = approach(raw.temp, clamp(tT, Ct.min, Ct.max), dt, Ct.tau)
	med.temp = clamp(raw.temp + wander("temp", Ct.noise), Ct.min, Ct.max)
end

------------------------------------------------------------------------
-- Статусы (их используют блоки)
------------------------------------------------------------------------

-- "normal" / "high" / "crisis"
function ns.PressureStatus()
	local b = C.bp
	if med.dead then return "crisis" end
	if med.sys < b.normalSys and med.dia < b.normalDia then return "normal" end
	if med.sys < b.highSys and med.dia < b.highDia then return "high" end
	return "crisis"
end

-- "chill" / "normal" / "fever" / "overheat"
function ns.TempStatus()
	local t, c = med.temp, C.temp
	if t < c.chillBelow then return "chill" end
	if t < c.feverFrom then return "normal" end
	if t < c.overheatFrom then return "fever" end
	return "overheat"
end

------------------------------------------------------------------------
-- Инициализация и события
------------------------------------------------------------------------

function sim:Init()
	-- пульс покоя постоянен для персонажа: считаем из GUID
	local guid = P(UnitGUID("player"), "")
	local sum = 0
	for i = 1, #guid do sum = sum + guid:byte(i) end
	med.rest = C.pulse.restMin + sum % (C.pulse.restMax - C.pulse.restMin + 1)
	raw.pulse = med.rest
	med.pulse = med.rest

	UpdateZone()
	ns:Every(C.intervals.sim, Tick)
	ns:Every(C.intervals.slow, SlowScan)
end

local function zoneChanged() pcall(UpdateZone) end
ns:On("ZONE_CHANGED", zoneChanged)
ns:On("ZONE_CHANGED_INDOORS", zoneChanged)
ns:On("ZONE_CHANGED_NEW_AREA", zoneChanged)
ns:On("PLAYER_ENTERING_WORLD", function()
	zoneChanged()
	env.aurasDirty = true
	env.breath = false
end)

ns:On("UNIT_AURA", function(_, unit)
	if unit == "player" then env.aurasDirty = true end
end)

-- Каждый полученный удар добавляет немного стресса (работает и тогда, когда
-- здоровье в бою аддону недоступно).
ns:On("UNIT_COMBAT", function(_, unit, action)
	if issecret(unit) or issecret(action) or unit ~= "player" then return end
	if action == "WOUND" then
		env.impulse = env.impulse + C.stress.hitGain * (C.sensitivity[ns.db.med.sens] or 1)
	end
end)

-- Нехватка дыхания: таймер BREATH
ns:On("MIRROR_TIMER_START", function(_, timer)
	if not issecret(timer) and timer == "BREATH" then env.breath = true end
end)
ns:On("MIRROR_TIMER_STOP", function(_, timer)
	if not issecret(timer) and timer == "BREATH" then env.breath = false end
end)

-- Опьянение: у игры нет функции для степени, но она пишет об этом в системный чат.
ns:On("CHAT_MSG_SYSTEM", function(_, msg)
	if type(msg) ~= "string" or issecret(msg) then return end
	for level = 1, 4 do
		if msg == _G["DRUNK_MESSAGE_SELF" .. level] then
			env.drunk = level - 1
			env.drunkAt = GetTime()
			return
		end
	end
end)

-- Сидение: функции «сидит ли игрок» нет, поэтому запоминаем команду «сесть»
-- (безопасный пост-хук) и сбрасываем при любом движении.
local function hook(tbl, name, fn)
	if type(tbl) == "table" and type(tbl[name]) == "function" then
		pcall(hooksecurefunc, tbl, name, fn)
	end
end
local function toggleSit() env.sitting = not env.sitting end
local function onEmote(token)
	if type(token) ~= "string" then return end
	token = token:upper()
	if token == "SIT" then env.sitting = true elseif token == "STAND" then env.sitting = false end
end
hook(_G, "ToggleSit", toggleSit)
hook(_G, "SitStandOrDescendStart", toggleSit)
hook(_G, "DoEmote", onEmote)
hook(C_ChatInfo, "PerformEmote", onEmote)
