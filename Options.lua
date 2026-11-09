-- AngardUI: окно настроек в стиле «бенто» — сетка плиток со скруглёнными рамками.
-- Цвет рамок и акцентов зависит от фракции: синий у Альянса, красный у Орды.
-- Все элементы управления свои — без шаблонов кнопок Blizzard и UIDropDownMenu,
-- чтобы не вносить taint. Любое изменение применяется сразу.
local ADDON, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor

local WIN_PAD, GAP, COL_W, TILE_PAD = 14, 10, 264, 12
local INNER = COL_W - TILE_PAD * 2
local HERO_H, FOOT_H = 60, 28
local WIN_W = WIN_PAD * 2 + COL_W * 3 + GAP * 2
local ROUND_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local win -- создаётся при первом открытии, когда фракция уже известна
local refreshers = {} -- виджеты с методом Refresh
local menu, confirm

------------------------------------------------------------------------
-- Цвет фракции
------------------------------------------------------------------------

local FACTION_COLORS = {
	Alliance = { 0.24, 0.56, 1.00 },
	Horde = { 0.92, 0.18, 0.15 },
	Neutral = C.gold,
}

local accent
local function A()
	if not accent then
		local faction = ns.Plain(UnitFactionGroup("player"), "Neutral")
		accent = FACTION_COLORS[faction] or FACTION_COLORS.Neutral
	end
	return accent[1], accent[2], accent[3]
end

------------------------------------------------------------------------
-- Оформление
------------------------------------------------------------------------

local function NewFrame(kind, name, parent)
	local ok, f = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
	if ok and f then return f end
	return CreateFrame(kind, name, parent)
end

-- Скруглённая плитка: тёмная заливка и рамка цвета фракции.
local function Rounded(f, fill, borderAlpha, edgeSize)
	local r, g, b = A()
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = WHITE, edgeFile = ROUND_EDGE, edgeSize = edgeSize or 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		f:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
		f:SetBackdropBorderColor(r, g, b, borderAlpha or 1)
	else
		ns.Skin(f, fill[4]) -- клиент без Backdrop: прямые рамки
	end
end

-- Прямоугольник с тонкой рамкой (для мелких элементов, где скругление не читается)
local function Box(f, fillAlpha, borderAlpha)
	local r, g, b = A()
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, fillAlpha or 0.5)
	f.fill = bg
	local function edge(p1, p2, vertical)
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(r, g, b, borderAlpha or 0.7)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if vertical then t:SetWidth(1) else t:SetHeight(1) end
	end
	edge("TOPLEFT", "TOPRIGHT")
	edge("BOTTOMLEFT", "BOTTOMRIGHT")
	edge("TOPLEFT", "BOTTOMLEFT", true)
	edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

local FILL_WINDOW = { 0.02, 0.02, 0.03, 0.96 }
local FILL_TILE = { 0.07, 0.07, 0.09, 0.95 }
local FILL_POPUP = { 0.05, 0.05, 0.07, 0.99 }

local function apply()
	ns:ApplyAll()
end

------------------------------------------------------------------------
-- Элементы управления
------------------------------------------------------------------------

-- filled = true: залитая акцентная кнопка (главное действие)
local function Button(parent, text, w, onClick, filled)
	local r, g, b = A()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(w, 24)
	Box(btn, 0.5, filled and 1 or 0.6)
	if filled then btn.fill:SetColorTexture(r * 0.45, g * 0.45, b * 0.45, 0.95) end
	btn.label = ns.Font(btn, 12, 1, 1, 1, "CENTER")
	btn.label:SetPoint("CENTER")
	btn.label:SetText(text)
	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(r, g, b, 0.25)
	btn:SetScript("OnClick", function(self) ns.Safe(onClick, self) end)
	btn.height = 30
	return btn
end

local function Check(parent, text, get, set)
	local r, g, b = A()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(INNER, 22)
	local box = CreateFrame("Frame", nil, btn)
	box:SetSize(14, 14)
	box:SetPoint("LEFT")
	Box(box, 0.6, 0.8)
	local mark = box:CreateTexture(nil, "OVERLAY")
	mark:SetPoint("TOPLEFT", 3, -3)
	mark:SetPoint("BOTTOMRIGHT", -3, 3)
	mark:SetColorTexture(r, g, b, 1)
	local label = ns.Font(btn, 12)
	label:SetPoint("LEFT", box, "RIGHT", 8, 0)
	label:SetPoint("RIGHT")
	label:SetWordWrap(false)
	label:SetText(text)
	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", -4, 0)
	hl:SetPoint("BOTTOMRIGHT", 4, 0)
	hl:SetColorTexture(1, 1, 1, 0.06)
	function btn.Refresh()
		local on = get() and true or false
		mark:SetShown(on)
		if on then label:SetTextColor(1, 1, 1) else label:SetTextColor(0.62, 0.62, 0.66) end
	end
	btn:SetScript("OnClick", function()
		set(not get())
		btn.Refresh()
		ns.Safe(apply)
	end)
	btn.height = 24
	refreshers[#refreshers + 1] = btn
	return btn
end

local function Slider(parent, text, minV, maxV, step, get, set, fmt)
	local r, g, b = A()
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(INNER, 36)
	local label = ns.Font(holder, 12)
	label:SetPoint("TOPLEFT")
	label:SetText(text)
	local valueText = ns.Font(holder, 12, r, g, b, "RIGHT")
	valueText:SetPoint("TOPRIGHT")

	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(INNER, 14)
	s:SetPoint("BOTTOMLEFT", 0, 0)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:EnableMouse(true)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(1, 1, 1, 0.14)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local fill = s:CreateTexture(nil, "BORDER")
	fill:SetColorTexture(r, g, b, 0.9)
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	s:SetThumbTexture(WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(8, 14)
	thumb:SetVertexColor(1, 1, 1)

	local function show(v)
		valueText:SetText(fmt(v))
		local frac = (maxV > minV) and (v - minV) / (maxV - minV) or 0
		fill:SetWidth(frac > 0 and frac * INNER or 0.001)
		fill:SetShown(frac > 0)
	end

	local syncing = false
	s:SetScript("OnValueChanged", function(_, v)
		if syncing then return end
		v = floor(v / step + 0.5) * step
		if v < minV then v = minV elseif v > maxV then v = maxV end
		show(v)
		if v ~= get() then
			set(v)
			ns.Safe(apply)
		end
	end)
	function holder.Refresh()
		syncing = true
		s:SetValue(get())
		syncing = false
		show(get())
	end
	holder.height = 42
	refreshers[#refreshers + 1] = holder
	return holder
end

-- Одно общее выпадающее меню
local menuItems = {}
local function OpenMenu(anchor, items, current, onPick)
	if menu:IsShown() and menu.anchor == anchor then
		menu:Hide()
		return
	end
	local r, g, b = A()
	menu.anchor = anchor
	for i, item in ipairs(items) do
		local btn = menuItems[i]
		if not btn then
			btn = CreateFrame("Button", nil, menu)
			btn:SetHeight(20)
			btn.text = ns.Font(btn, 12)
			btn.text:SetPoint("LEFT", 8, 0)
			btn.text:SetPoint("RIGHT", -8, 0)
			btn.text:SetWordWrap(false)
			local hl = btn:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(r, g, b, 0.28)
			menuItems[i] = btn
		end
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", 1, -(i - 1) * 20 - 2)
		btn:SetPoint("RIGHT", -1, 0)
		btn.text:SetText(item.text)
		if item.value == current then btn.text:SetTextColor(r, g, b) else btn.text:SetTextColor(1, 1, 1) end
		btn:SetScript("OnClick", function()
			menu:Hide()
			ns.Safe(onPick, item.value)
		end)
		btn:Show()
	end
	for i = #items + 1, #menuItems do menuItems[i]:Hide() end
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:SetSize(anchor:GetWidth(), #items * 20 + 4)
	menu:Show()
end

-- itemsFn() -> { { value = ..., text = ... }, ... }
local function Dropdown(parent, text, itemsFn, get, set)
	local r, g, b = A()
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(INNER, 42)
	local label = ns.Font(holder, 12)
	label:SetPoint("TOPLEFT")
	label:SetText(text)

	local btn = CreateFrame("Button", nil, holder)
	btn:SetSize(INNER, 22)
	btn:SetPoint("BOTTOMLEFT", 0, 0)
	Box(btn, 0.55, 0.6)
	btn.text = ns.Font(btn, 12)
	btn.text:SetPoint("LEFT", 8, 0)
	btn.text:SetPoint("RIGHT", -22, 0)
	btn.text:SetWordWrap(false)
	local arrow = btn:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	arrow:SetSize(12, 12)
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetRotation(-math.pi / 2)
	arrow:SetVertexColor(r, g, b)
	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(r, g, b, 0.15)

	function holder.Refresh()
		local current = get()
		local shown = tostring(current)
		for _, item in ipairs(itemsFn()) do
			if item.value == current then shown = item.text end
		end
		btn.text:SetText(shown)
	end
	btn:SetScript("OnClick", function()
		OpenMenu(btn, itemsFn(), get(), function(value)
			set(value)
			holder.Refresh()
			apply()
		end)
	end)
	holder.height = 48
	refreshers[#refreshers + 1] = holder
	return holder
end

local function Confirm(text, onAccept)
	menu:Hide()
	confirm.text:SetText(text)
	confirm.onAccept = onAccept
	confirm:Show()
end

-- доступ к настройке: flag("blocks", "card") или flag(nil, "shown")
local function flag(tableKey, key)
	return function()
		local t = tableKey and ns.db[tableKey] or ns.db
		return t[key]
	end, function(v)
		local t = tableKey and ns.db[tableKey] or ns.db
		t[key] = v
	end
end

local function percent(v) return floor(v * 100 + 0.5) .. "%" end

------------------------------------------------------------------------
-- Сборка окна
------------------------------------------------------------------------

local function Build()
	local r, g, b = A()

	win = NewFrame("Frame", "AngardUIOptionsFrame", UIParent)
	win:SetPoint("CENTER")
	win:SetFrameStrata("FULLSCREEN_DIALOG")
	win:SetToplevel(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:Hide()
	Rounded(win, FILL_WINDOW, 0.9, 16)
	tinsert(UISpecialFrames, "AngardUIOptionsFrame") -- закрытие по Esc

	menu = NewFrame("Frame", nil, win)
	menu:SetFrameStrata("TOOLTIP")
	menu:EnableMouse(true)
	menu:Hide()
	Box(menu, 0.97, 0.9)

	-- плитки: три колонки, плитки в колонке идут сверху вниз
	local columns = { {}, {}, {} }
	local function Tile(col, title)
		local tile = NewFrame("Frame", nil, win)
		Rounded(tile, FILL_TILE, 0.75)
		local pill = tile:CreateTexture(nil, "ARTWORK")
		pill:SetColorTexture(r, g, b, 1)
		pill:SetSize(3, 14)
		pill:SetPoint("TOPLEFT", TILE_PAD, -TILE_PAD)
		local head = ns.Font(tile, 13, r, g, b)
		head:SetPoint("LEFT", pill, "RIGHT", 7, 0)
		head:SetText(ns.Upper(title))
		tile.y = TILE_PAD + 22
		function tile:Add(widget, space)
			widget:SetPoint("TOPLEFT", self, "TOPLEFT", TILE_PAD, -self.y)
			self.y = self.y + (widget.height or (widget:GetHeight() + 6)) + (space or 0)
			return widget
		end
		table.insert(columns[col], tile)
		return tile
	end

	-- шапка: эмблема фракции, название, версия, крестик
	local hero = NewFrame("Frame", nil, win)
	hero:SetPoint("TOPLEFT", WIN_PAD, -WIN_PAD)
	hero:SetPoint("TOPRIGHT", -WIN_PAD, -WIN_PAD)
	hero:SetHeight(HERO_H)
	Rounded(hero, { r * 0.16, g * 0.16, b * 0.16, 0.95 }, 1)
	local crest = hero:CreateTexture(nil, "ARTWORK")
	crest:SetSize(46, 46)
	crest:SetPoint("LEFT", 12, 0)
	local faction = ns.Plain(UnitFactionGroup("player"), "Neutral")
	crest:SetTexture(ns.Icon(C.icons[faction] and faction or "Neutral"))
	local title = ns.Font(hero, 20)
	title:SetPoint("TOPLEFT", crest, "TOPRIGHT", 10, -3)
	title:SetText("AngardUI")
	local sub = ns.Font(hero, 12, 0.72, 0.72, 0.76)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	local version = C_AddOns and ns.Call(C_AddOns.GetAddOnMetadata, ADDON, "Version")
	sub:SetText(L.OPT_SUB:format(type(version) == "string" and version or "?"))

	local closeX = CreateFrame("Button", nil, hero)
	closeX:SetSize(26, 26)
	closeX:SetPoint("RIGHT", -12, 0)
	Box(closeX, 0.4, 0.6)
	closeX.label = ns.Font(closeX, 14, 1, 1, 1, "CENTER")
	closeX.label:SetPoint("CENTER", 0, 0)
	closeX.label:SetText("X")
	local closeHl = closeX:CreateTexture(nil, "HIGHLIGHT")
	closeHl:SetAllPoints()
	closeHl:SetColorTexture(1, 0.25, 0.25, 0.35)
	closeX:SetScript("OnClick", function() win:Hide() end)

	-- 1. Общее
	do
		local t = Tile(1, L.TAB_GENERAL)
		t:Add(Check(t, L.O_SHOW, flag(nil, "shown")))
		t:Add(Check(t, L.O_LOCK, flag(nil, "locked")))
		t:Add(Check(t, L.O_HIDE_COMBAT, flag(nil, "hideInCombat")))
		t:Add(Check(t, L.O_HIDE_PLAYER, flag(nil, "hidePlayerFrame")))
		t:Add(Check(t, L.O_MINIMAP, flag("minimap", "show")), 6)
		local getS, setS = flag(nil, "scale")
		t:Add(Slider(t, L.O_SCALE, 0.6, 1.6, 0.05, getS, setS, percent))
		local getA, setA = flag(nil, "bgAlpha")
		t:Add(Slider(t, L.O_ALPHA, 0, 1, 0.05, getA, setA, percent), 4)
		t:Add(Button(t, L.O_RESET_POS, INNER, function()
			ns.db.pos = false
			apply()
		end))
	end

	-- 6. Шаги
	do
		local t = Tile(1, L.TAB_STEPS)
		local getL, setL = flag("steps", "length")
		t:Add(Slider(t, L.S_LENGTH, 0.5, 1.0, 0.01, getL, setL, function(v)
			return L.S_LENGTH_FMT:format(ns.Decimal(v, 2))
		end))
		local counter = CreateFrame("Frame", nil, t)
		counter:SetSize(INNER, 18)
		counter.text = ns.Font(counter, 12, 0.72, 0.72, 0.76)
		counter.text:SetPoint("LEFT")
		function counter.Refresh()
			counter.text:SetText(L.S_COUNT:format(ns.Group(ns.GetSteps())))
		end
		counter.height = 24
		refreshers[#refreshers + 1] = counter
		t:Add(counter)
		t:Add(Button(t, L.S_RESET, INNER, function()
			Confirm(L.S_RESET_Q, function()
				ns:ResetSteps()
				counter.Refresh()
			end)
		end))
	end

	-- 2. Блоки
	do
		local t = Tile(2, L.TAB_BLOCKS)
		for _, key in ipairs({ "card", "portrait", "pulse", "vitals", "temp", "guild", "pet" }) do
			t:Add(Check(t, L["B_" .. key:upper()], flag("blocks", key)))
		end
	end

	-- 4. Медицина
	do
		local t = Tile(2, L.TAB_MED)
		local sens = {
			{ value = "calm", text = L.M_CALM },
			{ value = "normal", text = L.M_NORMAL },
			{ value = "dramatic", text = L.M_DRAMATIC },
		}
		local getS, setS = flag("med", "sens")
		t:Add(Dropdown(t, L.M_SENS, function() return sens end, getS, setS))
		local units = { { value = "C", text = "°C" }, { value = "F", text = "°F" } }
		local getU, setU = flag("med", "unit")
		t:Add(Dropdown(t, L.M_UNIT, function() return units end, getU, setU))
		t:Add(Check(t, L.M_ECG, flag("med", "ecgAnim")))
	end

	-- 3. Карточка
	do
		local t = Tile(3, L.TAB_CARD)
		for _, key in ipairs({ "spec", "rules", "time", "money", "steps", "profs" }) do
			t:Add(Check(t, L["C_" .. key:upper()], flag("card", key)))
		end
		t.y = t.y + 4
		local items = {
			{ value = "auto", text = L.RULE_AUTO },
			{ value = "pve", text = L.RULE_PVE },
			{ value = "pvp", text = L.RULE_PVP },
			{ value = "hc", text = L.RULE_HC },
			{ value = "rp", text = L.RULE_RP },
		}
		local get, set = flag(nil, "ruleset")
		t:Add(Dropdown(t, L.C_RULESET, function() return items end, get, set))
	end

	-- 5. Гильдия
	do
		local t = Tile(3, L.TAB_GUILD)
		local getC, setC = flag("guild", "count")
		t:Add(Slider(t, L.G_COUNT, 2, 12, 1, getC, setC, function(v) return tostring(floor(v + 0.5)) end))
		-- ранги гильдии: значение — индекс ранга с нуля (0 = глава)
		local function ranks()
			local items = {}
			local n = IsInGuild() and ns.Call(GuildControlGetNumRanks) or 0
			if type(n) == "number" and n > 0 then
				for i = 1, n do
					local name = ns.Call(GuildControlGetRankName, i)
					items[i] = { value = i - 1, text = (type(name) == "string" and name ~= "") and name or L.RANK_N:format(i) }
				end
			else
				items[1] = { value = 0, text = L.RANK_GM }
				for i = 2, 6 do items[i] = { value = i - 1, text = L.RANK_N:format(i) } end
			end
			return items
		end
		local getR, setR = flag("guild", "maxRank")
		t:Add(Dropdown(t, L.G_RANK, ranks, getR, setR))
		t:Add(Check(t, L.G_ONLINE, flag("guild", "onlineOnly")))
	end

	-- раскладка плиток: колонки выравниваются по самой высокой, растягивая нижнюю плитку
	local gridTop = WIN_PAD + HERO_H + GAP
	local tallest = 0
	for _, column in ipairs(columns) do
		local h = -GAP
		for _, tile in ipairs(column) do
			tile.h = tile.y + TILE_PAD - 4
			h = h + tile.h + GAP
		end
		column.h = h
		if h > tallest then tallest = h end
	end
	for c, column in ipairs(columns) do
		local y = gridTop
		for i, tile in ipairs(column) do
			local h = tile.h
			if i == #column then h = h + (tallest - column.h) end
			tile:SetSize(COL_W, h)
			tile:SetPoint("TOPLEFT", win, "TOPLEFT", WIN_PAD + (c - 1) * (COL_W + GAP), -y)
			y = y + h + GAP
		end
	end
	win:SetSize(WIN_W, gridTop + tallest + GAP + FOOT_H + WIN_PAD)

	-- нижние кнопки
	local resetAll = Button(win, L.RESET_ALL, 250, function()
		Confirm(L.RESET_ALL_Q, function()
			ns:ResetAll()
			ns:RefreshOptions()
		end)
	end)
	resetAll:SetPoint("BOTTOMLEFT", WIN_PAD, WIN_PAD)
	local closeBtn = Button(win, L.CLOSE, 140, function() win:Hide() end, true)
	closeBtn:SetPoint("BOTTOMRIGHT", -WIN_PAD, WIN_PAD)

	-- подтверждение (своё окно, без StaticPopup)
	confirm = NewFrame("Frame", nil, win)
	confirm:SetSize(360, 116)
	confirm:SetPoint("CENTER")
	confirm:SetFrameStrata("TOOLTIP")
	confirm:EnableMouse(true)
	confirm:Hide()
	Rounded(confirm, FILL_POPUP, 1, 16)
	confirm.text = ns.Font(confirm, 13, 1, 1, 1, "CENTER")
	confirm.text:SetPoint("TOPLEFT", 16, -20)
	confirm.text:SetPoint("TOPRIGHT", -16, -20)
	local yes = Button(confirm, L.YES, 120, function()
		confirm:Hide()
		if confirm.onAccept then confirm.onAccept() end
	end, true)
	yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 16)
	local no = Button(confirm, L.NO, 120, function() confirm:Hide() end)
	no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 16)

	win:SetScript("OnShow", function() ns:RefreshOptions() end)
	win:SetScript("OnHide", function()
		menu:Hide()
		confirm:Hide()
	end)
end

------------------------------------------------------------------------
-- Открытие и регистрация в меню игры
------------------------------------------------------------------------

function ns:RefreshOptions()
	if not win or not win:IsShown() then return end
	for i = 1, #refreshers do ns.Safe(refreshers[i].Refresh) end
end

function ns:ToggleOptions(forceShow)
	if not ns.db then return end
	if not win then Build() end
	if win:IsShown() and not forceShow then win:Hide() else win:Show() end
end

-- «Настройки → Модификации»: страница с кнопкой, открывающей это окно.
local function RegisterInGameMenu()
	local panel = CreateFrame("Frame")
	panel.name = "AngardUI"
	local title = ns.Font(panel, 18, A())
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("AngardUI")
	local desc = ns.Font(panel, 13)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	desc:SetWidth(520)
	desc:SetText(L.OPT_DESC)
	local open = Button(panel, L.OPT_OPEN, 260, function() ns:ToggleOptions(true) end, true)
	open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "AngardUI")
		Settings.RegisterAddOnCategory(category)
		ns.settingsCategory = category
	elseif type(InterfaceOptions_AddCategory) == "function" then
		InterfaceOptions_AddCategory(panel)
	end
end

local mod = {}
ns.modules[#ns.modules + 1] = mod
function mod:Init()
	local ok, err = pcall(RegisterInGameMenu)
	if not ok then ns.lastError = tostring(err) end
end
