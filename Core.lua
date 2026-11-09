-- AngardUI: ядро — безопасные обёртки API, события, таймеры, сохранённые данные,
-- корневой фрейм панели, раскладка блоков и слэш-команда.
local ADDON, ns = ...
local L, C = ns.L, ns.C

ns.blocks = {} -- key -> frame
ns.modules = {} -- модули с методом Init (вызывается на PLAYER_LOGIN)
ns.state = { hasGuild = false, hasPet = false, inCombat = false }

local floor, max = math.floor, math.max

------------------------------------------------------------------------
-- Безопасная работа с API
------------------------------------------------------------------------

-- В Forever действуют «secret values» (как в Midnight): часть боевых значений в бою
-- нельзя сравнивать и использовать в арифметике. Все такие чтения идут через Plain().
local issecret = issecretvalue or function() return false end
ns.issecret = issecret

-- Возвращает значение, если с ним можно работать; иначе default.
function ns.Plain(v, default)
	if v == nil or issecret(v) then return default end
	return v
end

-- Вызов функции, которой может не быть в этом клиенте. Ошибка или отсутствие -> nil.
function ns.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g, h end
	return nil
end

-- Ошибки в обработчиках не роняют аддон: первые три уходят в стандартный обработчик,
-- последняя хранится для /angard debug.
local errCount = 0
function ns.Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		errCount = errCount + 1
		ns.lastError = tostring(err)
		if errCount <= 3 then
			local handler = geterrorhandler and geterrorhandler()
			if handler then pcall(handler, err) end
		end
	end
end

-- Иконка с запасным вариантом, если основного файла нет в клиенте.
function ns.Icon(key)
	local pair = C.icons[key] or C.icons.unknown
	if type(GetFileIDFromPath) == "function" then
		local id = ns.Call(GetFileIDFromPath, pair[1])
		if not id or id == 0 then return pair[2] end
	end
	return pair[1]
end

function ns:Print(msg)
	print("|cffdcb246AngardUI|r: " .. msg)
end

------------------------------------------------------------------------
-- События и периодические задачи
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		ns.Safe(list[i], event, ...)
	end
end)

-- Подписка. Неизвестное клиенту событие просто игнорируется (возвращает false).
-- События UNIT_* регистрируются только для игрока и питомца.
function ns:On(event, fn)
	if not handlers[event] then
		local ok
		if event:sub(1, 5) == "UNIT_" then
			ok = pcall(eventFrame.RegisterUnitEvent, eventFrame, event, "player", "pet")
		else
			ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
		end
		if not ok then return false end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

-- Один общий OnUpdate с троттлингом для всех периодических задач.
local tickers = {}
function ns:Every(interval, fn)
	tickers[#tickers + 1] = { interval = interval, acc = 0, fn = fn }
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
	if not ns.db then return end
	for i = 1, #tickers do
		local t = tickers[i]
		t.acc = t.acc + elapsed
		if t.acc >= t.interval then
			local dt = t.acc
			t.acc = 0
			ns.Safe(t.fn, dt)
		end
	end
end)

------------------------------------------------------------------------
-- Форматирование
------------------------------------------------------------------------

-- 25165 -> "25 165"
function ns.Group(n)
	local s = tostring(floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

function ns.FormatDuration(sec)
	local m = floor(sec / 60)
	local h = floor(m / 60)
	local d = floor(h / 24)
	if d > 0 then return L.T_D:format(d, h % 24) end
	if h > 0 then return L.T_H:format(h, m % 60) end
	return L.T_M:format(m)
end

-- Десятичная дробь с разделителем локали: 37.2 -> "37,2"
function ns.Decimal(v, digits)
	local s = string.format("%." .. (digits or 1) .. "f", v)
	if L.DEC ~= "." then s = s:gsub("%.", L.DEC) end
	return s
end

-- Верхний регистр с поддержкой кириллицы (string.upper её не трогает)
function ns.Upper(s)
	s = s:gsub("\209\145", "\208\129")
	s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
	s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
	return s:upper()
end

function ns.ClassColor(classFile)
	local c
	if classFile then
		if C_ClassColor and C_ClassColor.GetClassColor then c = ns.Call(C_ClassColor.GetClassColor, classFile) end
		if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[classFile] end
	end
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

------------------------------------------------------------------------
-- Оформление
------------------------------------------------------------------------

local skinned = {} -- фоны блоков панели (для ползунка прозрачности)

function ns.Font(parent, size, r, g, b, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetTextColor(r or 1, g or 1, b or 1)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- Чёрный фон и тонкая золотая рамка. fixedAlpha — для окон вне панели.
function ns.Skin(f, fixedAlpha)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 1)
	bg:SetAlpha(fixedAlpha or 0.75)
	f.bg = bg
	if not fixedAlpha then skinned[#skinned + 1] = bg end

	local g = C.gold
	local function edge(p1, p2, vertical)
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(g[1], g[2], g[3], 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if vertical then t:SetWidth(1) else t:SetHeight(1) end
	end
	edge("TOPLEFT", "TOPRIGHT")
	edge("BOTTOMLEFT", "BOTTOMRIGHT")
	edge("TOPLEFT", "BOTTOMLEFT", true)
	edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

-- Сердечко: встроенный атлас, если он есть в клиенте, иначе иконка.
function ns.Heart(parent, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	local atlas = C_Texture and C_Texture.GetAtlasInfo and ns.Call(C_Texture.GetAtlasInfo, "GarrisonTroops-Health")
	if atlas and t.SetAtlas then
		t:SetAtlas("GarrisonTroops-Health")
	else
		t:SetTexture(ns.Icon("heart"))
		t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	t:SetDesaturated(true) -- красим сами через SetVertexColor
	return t
end

-- Модель с запасным 2D-портретом. Возвращает объект с методами SetUnit/SetDead.
function ns.CreatePortrait(parent)
	local p = {}
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, parent)
	if ok and model then
		model:SetPoint("TOPLEFT", 2, -2)
		model:SetPoint("BOTTOMRIGHT", -2, 2)
		p.model = model
	end
	local tex = parent:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 2, -2)
	tex:SetPoint("BOTTOMRIGHT", -2, 2)
	tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	tex:Hide()
	p.tex = tex
	local shade = (model or parent):CreateTexture(nil, "OVERLAY")
	shade:SetPoint("TOPLEFT", parent, 2, -2)
	shade:SetPoint("BOTTOMRIGHT", parent, -2, 2)
	shade:SetColorTexture(0.25, 0.25, 0.25, 0.55)
	shade:Hide()
	p.shade = shade

	function p:SetUnit(unit)
		self.unit = unit
		local m = self.model
		local shown = false
		if m then
			shown = pcall(function()
				m:ClearModel()
				m:SetUnit(unit)
				if m.SetPortraitZoom then m:SetPortraitZoom(1) end
				if m.SetCamDistanceScale then m:SetCamDistanceScale(1) end
			end)
			m:SetShown(shown)
		end
		if shown then
			self.tex:Hide()
		else
			pcall(SetPortraitTexture, self.tex, unit)
			self.tex:Show()
		end
	end

	function p:SetDead(dead)
		local m = self.model
		local done = false
		if m and m:IsShown() and m.SetDesaturation then
			done = pcall(m.SetDesaturation, m, dead and 1 or 0)
		end
		self.tex:SetDesaturated(dead and true or false)
		-- если модель обесцветить нельзя — затемняем серой накладкой
		self.shade:SetShown(dead and not done and not self.tex:IsShown())
	end

	if model then
		-- модель сбрасывается при скрытии, поэтому при показе задаём её заново
		model:SetScript("OnShow", function()
			if p.unit then ns.Safe(p.SetUnit, p, p.unit) end
		end)
	end
	return p
end

------------------------------------------------------------------------
-- Корневой фрейм и блоки
------------------------------------------------------------------------

local root = CreateFrame("Frame", "AngardUIPanel", UIParent)
root:SetSize(10, 10)
root:SetFrameStrata("LOW")
root:SetMovable(true)
root:SetClampedToScreen(true)
root:Hide()
ns.root = root

-- Положение хранится в единицах UIParent, чтобы масштаб не сдвигал левый верхний угол.
function ns:ApplyPosition()
	local p = ns.db.pos
	local s = root:GetScale()
	root:ClearAllPoints()
	root:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
		(p and p.x or C.layout.defaultX) / s, (p and p.y or C.layout.defaultY) / s)
end

function ns:SavePosition()
	local s = root:GetScale()
	local left, top = root:GetLeft(), root:GetTop()
	if not left or not top then return end
	ns.db.pos = { x = left * s, y = top * s - UIParent:GetHeight() }
	ns:ApplyPosition()
end

-- Обычный незащищённый фрейм: его можно показывать, скрывать и двигать в бою.
function ns:NewBlock(key, w, h)
	local f = CreateFrame("Frame", "AngardUIBlock_" .. key, root)
	f:SetSize(w, h)
	ns.Skin(f)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function()
		if not ns.db.locked then root:StartMoving() end
	end)
	f:SetScript("OnDragStop", function()
		root:StopMovingOrSizing()
		ns:SavePosition()
	end)
	ns.blocks[key] = f
	return f
end

-- Три колонки; выключенные блоки и пустые колонки не оставляют дыр.
local COLUMNS = {
	{ "card", "guild" },
	{ "portrait", "vitals", "pet" },
	{ "pulse", "temp" },
}

function ns:Layout()
	local db, B, lay = ns.db, ns.blocks, C.layout
	local S, gap = lay.square, lay.gap

	local vis = {}
	for key in pairs(B) do vis[key] = db.blocks[key] and true or false end
	vis.guild = vis.guild and ns.state.hasGuild
	vis.pet = vis.pet and ns.state.hasPet

	-- карточка высотой в два ряда правых блоков
	local cardH = max(B.card.contentHeight or 0, S + gap + lay.lowerMin)
	local lowerH = vis.card and (cardH - S - gap) or lay.lowerDefault
	B.card:SetSize(lay.cardWidth, cardH)
	B.guild:SetWidth(lay.cardWidth)
	B.portrait:SetSize(S, S)
	B.pulse:SetSize(S, S)
	B.vitals:SetSize(S, lowerH)
	B.temp:SetSize(S, lowerH)
	B.pet:SetSize(S / 2, S / 2)

	local x, maxY = 0, 0
	for _, column in ipairs(COLUMNS) do
		local y, colW = 0, 0
		for _, key in ipairs(column) do
			local f = B[key]
			if vis[key] then
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
				f:Show()
				y = y + f:GetHeight() + gap
				colW = max(colW, f:GetWidth())
			else
				f:Hide()
			end
		end
		if colW > 0 then
			x = x + colW + gap
			maxY = max(maxY, y)
		end
	end
	root:SetSize(max(x - gap, 1), max(maxY - gap, 1))
end

function ns:UpdateVisibility()
	local db = ns.db
	root:SetShown(db.shown and not (db.hideInCombat and ns.state.inCombat))
end

function ns:RefreshAll()
	for _, f in pairs(ns.blocks) do
		if f.Refresh then ns.Safe(f.Refresh, f) end
	end
	ns:Layout()
end

-- Применяет все настройки сразу, без перезагрузки интерфейса.
function ns:ApplyAll()
	local db = ns.db
	root:SetScale(db.scale)
	ns:ApplyPosition()
	for i = 1, #skinned do skinned[i]:SetAlpha(db.bgAlpha) end
	for _, f in pairs(ns.blocks) do f:EnableMouse(not db.locked) end
	ns:RefreshAll()
	ns:UpdateVisibility()
	ns:ApplyPlayerFrame()
	if ns.ApplyMinimap then ns:ApplyMinimap() end
end

-- Стандартная рамка игрока (портрет, здоровье, мана) дублирует панель. Она защищённая,
-- поэтому скрывается штатным драйвером состояния и только вне боя; если настройку
-- поменяли в бою — применится сразу после него.
local playerFrameHidden = false
local function restorePlayerFrame(pf)
	UnregisterStateDriver(pf, "visibility")
	pf:Show()
end
function ns:ApplyPlayerFrame()
	local want = ns.db.hidePlayerFrame and true or false
	if want == playerFrameHidden then return end
	local pf = _G.PlayerFrame
	if not pf or type(RegisterStateDriver) ~= "function" then return end
	if InCombatLockdown() then
		ns.state.playerFramePending = true
		return
	end
	ns.state.playerFramePending = false
	local ok
	if want then
		ok = pcall(RegisterStateDriver, pf, "visibility", "hide")
	else
		ok = pcall(restorePlayerFrame, pf)
	end
	if ok then playerFrameHidden = want end
end

------------------------------------------------------------------------
-- Сохранённые данные
------------------------------------------------------------------------

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function ns:ResetAll()
	wipe(ns.db)
	copyDefaults(ns.defaults, ns.db)
	ns:ApplyAll()
end

ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	AngardUIDB = copyDefaults(ns.defaults, type(AngardUIDB) == "table" and AngardUIDB or {})
	AngardUICharDB = copyDefaults(ns.charDefaults, type(AngardUICharDB) == "table" and AngardUICharDB or {})
	ns.db, ns.chardb = AngardUIDB, AngardUICharDB
	-- 1.0 -> 1.1: блок давления заменён блоком здоровья и маны
	if ns.db.blocks.pressure ~= nil then
		ns.db.blocks.vitals = ns.db.blocks.pressure
		ns.db.blocks.pressure = nil
	end
end)

ns:On("PLAYER_LOGIN", function()
	if not ns.db then return end
	ns.state.inCombat = InCombatLockdown() and true or false
	for _, m in ipairs(ns.modules) do
		if m.Init then ns.Safe(m.Init, m) end
	end
	ns:ApplyAll()
end)

ns:On("PLAYER_ENTERING_WORLD", function()
	if ns.db then ns:RefreshAll() end
end)

ns:On("PLAYER_REGEN_DISABLED", function()
	ns.state.inCombat = true
	ns:UpdateVisibility()
end)

ns:On("PLAYER_REGEN_ENABLED", function()
	ns.state.inCombat = false
	ns:UpdateVisibility()
	if ns.state.playerFramePending then ns:ApplyPlayerFrame() end
end)

-- при смене масштаба интерфейса или разрешения держим панель на месте
ns:On("UI_SCALE_CHANGED", function()
	if ns.db then ns:ApplyPosition() end
end)

------------------------------------------------------------------------
-- Слэш-команда
------------------------------------------------------------------------

SLASH_ANGARDUI1 = "/angard"
SLASH_ANGARDUI2 = "/angardui"
SlashCmdList["ANGARDUI"] = function(msg)
	if not ns.db then return end
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	local db = ns.db
	if cmd == "" then
		if ns.ToggleOptions then ns:ToggleOptions() end
		return
	elseif cmd == "show" then
		db.shown = true
		ns:Print(L.MSG_SHOWN)
	elseif cmd == "hide" then
		db.shown = false
		ns:Print(L.MSG_HIDDEN)
	elseif cmd == "lock" then
		db.locked = not db.locked
		ns:Print(db.locked and L.MSG_LOCKED or L.MSG_UNLOCKED)
	elseif cmd == "unlock" then
		db.locked = false
		ns:Print(L.MSG_UNLOCKED)
	elseif cmd == "reset" then
		db.pos = false
		ns:Print(L.MSG_RESET)
	elseif cmd == "debug" then
		ns:Print(ns.lastError or L.MSG_NOERR)
		return
	else
		ns:Print(L.MSG_HELP)
		return
	end
	ns:ApplyAll()
	if ns.RefreshOptions then ns:RefreshOptions() end
end
