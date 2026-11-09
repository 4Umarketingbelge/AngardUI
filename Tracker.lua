-- AngardUI: счётчик шагов и время на текущем уровне. Данные — на персонажа.
local _, ns = ...
local C = ns.C
local P = ns.Plain
local sqrt = math.sqrt

local tracker = {}
ns.modules[#ns.modules + 1] = tracker

------------------------------------------------------------------------
-- Шаги
------------------------------------------------------------------------

local lastX, lastY, lastInst

-- Позиция в ярдах. В подземельях и на полях боя игра её не отдаёт (nil).
local function Position()
	local ok, y, x, _, inst = pcall(UnitPosition, "player")
	if ok and type(x) == "number" and type(y) == "number" and not ns.issecret(x) and not ns.issecret(y) then
		return x, y, P(inst, 0)
	end
	return nil
end

local function SampleSteps(dt)
	local x, y, inst = Position()
	local speed = P(GetUnitSpeed("player"), 0)

	local onFoot = speed > 0
		and not P(IsMounted(), false)
		and not P(UnitOnTaxi("player"), false)
		and not P(IsFlying(), false)
		and not P(IsSwimming(), false)
		and not P(UnitInVehicle and UnitInVehicle("player"), false)

	if onFoot and dt <= C.steps.maxGap then
		local limit = speed * dt * C.steps.slack
		local d
		if x and lastX and inst == lastInst then
			local dx, dy = x - lastX, y - lastY
			d = sqrt(dx * dx + dy * dy)
			-- больше, чем можно пройти своим ходом: телепорт, транспорт, смена карты
			if d > limit then d = 0 end
		elseif not x then
			d = speed * dt -- позиция недоступна: считаем по скорости
		else
			d = 0 -- первый замер после смены карты
		end
		if d > 0 then
			ns.chardb.steps = ns.chardb.steps + d * C.steps.yard / ns.db.steps.length
		end
	end
	lastX, lastY, lastInst = x, y, inst
end

function ns.GetSteps()
	return ns.chardb.steps
end

function ns:ResetSteps()
	ns.chardb.steps = 0
	if ns.blocks.card.UpdateSteps then ns.blocks.card:UpdateSteps(true) end
end

------------------------------------------------------------------------
-- Время на уровне
------------------------------------------------------------------------

local sessionStart = 0
local silenced -- чат-фреймы, у которых временно отключён вывод /played

function ns.GetLevelTime()
	return ns.chardb.levelSeconds + (GetTime() - sessionStart)
end

local function SaveLevelTime()
	ns.chardb.levelSeconds = ns.GetLevelTime()
	sessionStart = GetTime()
end

local function RestoreChat()
	if not silenced then return end
	for i = 1, #silenced do
		pcall(silenced[i].RegisterEvent, silenced[i], "TIME_PLAYED_MSG")
	end
	silenced = nil
end

-- Один запрос времени у сервера без вывода в чат.
local function RequestSilently()
	if type(RequestTimePlayed) ~= "function" then return end
	silenced = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local cf = _G["ChatFrame" .. i]
		if cf and cf.IsEventRegistered and cf:IsEventRegistered("TIME_PLAYED_MSG") then
			if pcall(cf.UnregisterEvent, cf, "TIME_PLAYED_MSG") then
				silenced[#silenced + 1] = cf
			end
		end
	end
	pcall(RequestTimePlayed)
	C_Timer.After(10, RestoreChat) -- на случай, если ответ не придёт
end

ns:On("TIME_PLAYED_MSG", function(_, total, level)
	if type(level) == "number" and not ns.issecret(level) then
		ns.chardb.levelSeconds = level
		ns.chardb.levelInit = true
		sessionStart = GetTime()
		if ns.blocks.card.UpdateTime then ns.blocks.card:UpdateTime() end
	end
	RestoreChat()
end)

ns:On("PLAYER_LEVEL_UP", function(_, level)
	ns.chardb.levelSeconds = 0
	ns.chardb.levelInit = true
	if type(level) == "number" then ns.chardb.level = level end
	sessionStart = GetTime()
end)

ns:On("PLAYER_LOGOUT", function()
	if ns.chardb then SaveLevelTime() end
end)

ns:On("PLAYER_ENTERING_WORLD", function()
	lastX, lastY, lastInst = nil, nil, nil
end)

------------------------------------------------------------------------

function tracker:Init()
	sessionStart = GetTime()
	local cdb = ns.chardb
	local level = P(UnitLevel("player"), 0)
	-- первый запуск или уровень сменился, пока аддон был выключен
	if not cdb.levelInit or cdb.level ~= level then
		cdb.level = level
		RequestSilently()
	end

	ns:Every(C.intervals.steps, SampleSteps)
	ns:Every(C.intervals.save, SaveLevelTime)
	ns:Every(C.intervals.slow, function()
		local card = ns.blocks.card
		if card:IsVisible() then card:UpdateSteps() end
	end)
	ns:Every(C.intervals.clock, function()
		local card = ns.blocks.card
		if card:IsVisible() then card:UpdateTime() end
	end)
end
