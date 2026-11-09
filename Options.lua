-- AngardUI: окно настроек в стиле панели (чёрный фон, золотая рамка).
-- Все элементы управления свои — без шаблонов Blizzard и выпадающих меню UIDropDownMenu,
-- чтобы не вносить taint. Любое изменение применяется сразу.
local _, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor
local G = C.gold

local WIN_W, WIN_H, NAV_W = 600, 460, 140
local CONTENT_W = WIN_W - NAV_W - 36

local win = CreateFrame("Frame", "AngardUIOptionsFrame", UIParent)
win:SetSize(WIN_W, WIN_H)
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
ns.Skin(win, 0.94)
tinsert(UISpecialFrames, "AngardUIOptionsFrame") -- закрытие по Esc

local titleText = ns.Font(win, 15, G[1], G[2], G[3])
titleText:SetPoint("TOPLEFT", 12, -10)
titleText:SetText(L.OPT_TITLE)

local titleLine = win:CreateTexture(nil, "ARTWORK")
titleLine:SetColorTexture(G[1], G[2], G[3], 0.8)
titleLine:SetHeight(1)
titleLine:SetPoint("TOPLEFT", 1, -34)
titleLine:SetPoint("TOPRIGHT", -1, -34)

local refreshers = {} -- виджеты с методом Refresh (синхронизация с сохранёнными данными)

local function apply()
	ns:ApplyAll()
end

------------------------------------------------------------------------
-- Элементы управления
------------------------------------------------------------------------

local function Button(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 24)
	ns.Skin(b, 0.6)
	b.label = ns.Font(b, 12, G[1], G[2], G[3], "CENTER")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(G[1], G[2], G[3], 0.18)
	b:SetScript("OnClick", function(self) ns.Safe(onClick, self) end)
	return b
end

local function Check(parent, text, get, set)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(CONTENT_W, 22)
	local box = CreateFrame("Frame", nil, b)
	box:SetSize(16, 16)
	box:SetPoint("LEFT")
	ns.Skin(box, 0.6)
	local mark = box:CreateTexture(nil, "OVERLAY")
	mark:SetSize(10, 10)
	mark:SetPoint("CENTER")
	mark:SetColorTexture(G[1], G[2], G[3], 1)
	local label = ns.Font(b, 13)
	label:SetPoint("LEFT", box, "RIGHT", 8, 0)
	label:SetText(text)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	function b.Refresh() mark:SetShown(get() and true or false) end
	b:SetScript("OnClick", function()
		set(not get())
		b.Refresh()
		ns.Safe(apply)
	end)
	b.height = 24
	refreshers[#refreshers + 1] = b
	return b
end

local function Slider(parent, text, minV, maxV, step, get, set, fmt)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(CONTENT_W, 40)
	local label = ns.Font(holder, 13)
	label:SetPoint("TOPLEFT")
	label:SetText(text)
	local valueText = ns.Font(holder, 13, G[1], G[2], G[3], "RIGHT")
	valueText:SetPoint("TOPRIGHT", -40, 0)

	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(CONTENT_W - 40, 16)
	s:SetPoint("BOTTOMLEFT", 0, 2)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:EnableMouse(true)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(1, 1, 1, 0.2)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
	local thumb = s:GetThumbTexture()
	thumb:SetSize(8, 16)
	thumb:SetVertexColor(G[1], G[2], G[3])

	local syncing = false
	s:SetScript("OnValueChanged", function(_, v)
		if syncing then return end
		v = floor(v / step + 0.5) * step
		if v < minV then v = minV elseif v > maxV then v = maxV end
		valueText:SetText(fmt(v))
		if v ~= get() then
			set(v)
			ns.Safe(apply)
		end
	end)
	function holder.Refresh()
		syncing = true
		s:SetValue(get())
		syncing = false
		valueText:SetText(fmt(get()))
	end
	holder.height = 46
	refreshers[#refreshers + 1] = holder
	return holder
end

-- Одно общее выпадающее меню
local menu = CreateFrame("Frame", nil, win)
menu:SetFrameStrata("TOOLTIP")
menu:EnableMouse(true)
menu:Hide()
ns.Skin(menu, 0.97)
local menuItems = {}

local function OpenMenu(anchor, items, current, onPick)
	if menu:IsShown() and menu.anchor == anchor then
		menu:Hide()
		return
	end
	menu.anchor = anchor
	for i, item in ipairs(items) do
		local b = menuItems[i]
		if not b then
			b = CreateFrame("Button", nil, menu)
			b:SetHeight(20)
			b.text = ns.Font(b, 12)
			b.text:SetPoint("LEFT", 8, 0)
			b.text:SetPoint("RIGHT", -8, 0)
			b.text:SetWordWrap(false)
			local hl = b:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(G[1], G[2], G[3], 0.22)
			menuItems[i] = b
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 1, -(i - 1) * 20 - 2)
		b:SetPoint("RIGHT", -1, 0)
		b.text:SetText(item.text)
		if item.value == current then b.text:SetTextColor(G[1], G[2], G[3]) else b.text:SetTextColor(1, 1, 1) end
		b:SetScript("OnClick", function()
			menu:Hide()
			ns.Safe(onPick, item.value)
		end)
		b:Show()
	end
	for i = #items + 1, #menuItems do menuItems[i]:Hide() end
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:SetSize(anchor:GetWidth(), #items * 20 + 4)
	menu:Show()
end

-- itemsFn() -> { { value = ..., text = ... }, ... }
local function Dropdown(parent, text, itemsFn, get, set)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(CONTENT_W, 46)
	local label = ns.Font(holder, 13)
	label:SetPoint("TOPLEFT")
	label:SetText(text)

	local b = CreateFrame("Button", nil, holder)
	b:SetSize(240, 22)
	b:SetPoint("BOTTOMLEFT", 0, 2)
	ns.Skin(b, 0.6)
	b.text = ns.Font(b, 12)
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -22, 0)
	b.text:SetWordWrap(false)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	arrow:SetSize(12, 12)
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetRotation(-math.pi / 2)
	arrow:SetVertexColor(G[1], G[2], G[3])
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(G[1], G[2], G[3], 0.12)

	function holder.Refresh()
		local current = get()
		local shown = tostring(current)
		for _, item in ipairs(itemsFn()) do
			if item.value == current then shown = item.text end
		end
		b.text:SetText(shown)
	end
	b:SetScript("OnClick", function()
		OpenMenu(b, itemsFn(), get(), function(value)
			set(value)
			holder.Refresh()
			apply()
		end)
	end)
	holder.height = 52
	refreshers[#refreshers + 1] = holder
	return holder
end

-- Подтверждение (своё окно, без StaticPopup)
local confirm = CreateFrame("Frame", nil, win)
confirm:SetSize(340, 110)
confirm:SetPoint("CENTER")
confirm:SetFrameStrata("TOOLTIP")
confirm:EnableMouse(true)
confirm:Hide()
ns.Skin(confirm, 0.98)
confirm.text = ns.Font(confirm, 13, 1, 1, 1, "CENTER")
confirm.text:SetPoint("TOPLEFT", 14, -16)
confirm.text:SetPoint("TOPRIGHT", -14, -16)
local yes = Button(confirm, L.YES, 110, function()
	confirm:Hide()
	if confirm.onAccept then confirm.onAccept() end
end)
yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 12)
local no = Button(confirm, L.NO, 110, function() confirm:Hide() end)
no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 12)

local function Confirm(text, onAccept)
	menu:Hide()
	confirm.text:SetText(text)
	confirm.onAccept = onAccept
	confirm:Show()
end

------------------------------------------------------------------------
-- Разделы
------------------------------------------------------------------------

local pages, navButtons, current = {}, {}, nil

local function ShowPage(key)
	current = key
	menu:Hide()
	for k, page in pairs(pages) do page:SetShown(k == key) end
	for k, b in pairs(navButtons) do
		if k == key then b.label:SetTextColor(G[1], G[2], G[3]) else b.label:SetTextColor(1, 1, 1) end
		b.sel:SetShown(k == key)
	end
end

local navCount = 0
local function Page(key, title)
	local page = CreateFrame("Frame", nil, win)
	page:SetPoint("TOPLEFT", NAV_W + 18, -46)
	page:SetPoint("BOTTOMRIGHT", -18, 50)
	page:Hide()
	page.y = 0
	function page:Add(widget, indent)
		widget:SetPoint("TOPLEFT", self, "TOPLEFT", indent or 0, -self.y)
		self.y = self.y + (widget.height or (widget:GetHeight() + 8))
		return widget
	end
	pages[key] = page

	local b = CreateFrame("Button", nil, win)
	b:SetSize(NAV_W, 26)
	b:SetPoint("TOPLEFT", 8, -44 - navCount * 28)
	navCount = navCount + 1
	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(G[1], G[2], G[3], 0.16)
	b.label = ns.Font(b, 13)
	b.label:SetPoint("LEFT", 10, 0)
	b.label:SetText(title)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.07)
	b:SetScript("OnClick", function() ShowPage(key) end)
	navButtons[key] = b
	return page
end

local navLine = win:CreateTexture(nil, "ARTWORK")
navLine:SetColorTexture(G[1], G[2], G[3], 0.5)
navLine:SetWidth(1)
navLine:SetPoint("TOPLEFT", NAV_W + 12, -35)
navLine:SetPoint("BOTTOMLEFT", NAV_W + 12, 44)

-- доступ к вложенной настройке: field(ns.db-подтаблица, ключ)
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

-- 1. Общее
do
	local p = Page("general", L.TAB_GENERAL)
	p:Add(Check(p, L.O_SHOW, flag(nil, "shown")))
	p:Add(Check(p, L.O_LOCK, flag(nil, "locked")))
	p:Add(Check(p, L.O_HIDE_COMBAT, flag(nil, "hideInCombat")))
	p.y = p.y + 8
	local getS, setS = flag(nil, "scale")
	p:Add(Slider(p, L.O_SCALE, 0.6, 1.6, 0.05, getS, setS, percent))
	local getA, setA = flag(nil, "bgAlpha")
	p:Add(Slider(p, L.O_ALPHA, 0, 1, 0.05, getA, setA, percent))
	p.y = p.y + 6
	p:Add(Button(p, L.O_RESET_POS, 200, function()
		ns.db.pos = false
		apply()
	end))
end

-- 2. Блоки
do
	local p = Page("blocks", L.TAB_BLOCKS)
	local order = { "card", "portrait", "pulse", "pressure", "temp", "guild", "pet" }
	for _, key in ipairs(order) do
		p:Add(Check(p, L["B_" .. key:upper()], flag("blocks", key)))
	end
end

-- 3. Карточка
do
	local p = Page("card", L.TAB_CARD)
	local order = { "spec", "rules", "time", "money", "steps", "profs" }
	for _, key in ipairs(order) do
		p:Add(Check(p, L["C_" .. key:upper()], flag("card", key)))
	end
	p.y = p.y + 8
	local items = {
		{ value = "auto", text = L.RULE_AUTO },
		{ value = "pve", text = L.RULE_PVE },
		{ value = "pvp", text = L.RULE_PVP },
		{ value = "hc", text = L.RULE_HC },
		{ value = "rp", text = L.RULE_RP },
	}
	local get, set = flag(nil, "ruleset")
	p:Add(Dropdown(p, L.C_RULESET, function() return items end, get, set))
end

-- 4. Медицина
do
	local p = Page("med", L.TAB_MED)
	local sens = {
		{ value = "calm", text = L.M_CALM },
		{ value = "normal", text = L.M_NORMAL },
		{ value = "dramatic", text = L.M_DRAMATIC },
	}
	local getS, setS = flag("med", "sens")
	p:Add(Dropdown(p, L.M_SENS, function() return sens end, getS, setS))
	local units = { { value = "C", text = "°C" }, { value = "F", text = "°F" } }
	local getU, setU = flag("med", "unit")
	p:Add(Dropdown(p, L.M_UNIT, function() return units end, getU, setU))
	p:Add(Check(p, L.M_ECG, flag("med", "ecgAnim")))
end

-- 5. Гильдия
do
	local p = Page("guild", L.TAB_GUILD)
	local getC, setC = flag("guild", "count")
	p:Add(Slider(p, L.G_COUNT, 2, 12, 1, getC, setC, function(v) return tostring(floor(v + 0.5)) end))

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
	p:Add(Dropdown(p, L.G_RANK, ranks, getR, setR))
	p:Add(Check(p, L.G_ONLINE, flag("guild", "onlineOnly")))
end

-- 6. Шаги
do
	local p = Page("steps", L.TAB_STEPS)
	local getL, setL = flag("steps", "length")
	p:Add(Slider(p, L.S_LENGTH, 0.5, 1.0, 0.01, getL, setL, function(v)
		return L.S_LENGTH_FMT:format(ns.Decimal(v, 2))
	end))
	p.y = p.y + 6

	local counter = CreateFrame("Frame", nil, p)
	counter:SetSize(CONTENT_W, 18)
	counter.text = ns.Font(counter, 13)
	counter.text:SetPoint("LEFT")
	function counter.Refresh()
		counter.text:SetText(L.S_COUNT:format(ns.Group(ns.GetSteps())))
	end
	counter.height = 28
	refreshers[#refreshers + 1] = counter
	p:Add(counter)

	p:Add(Button(p, L.S_RESET, 200, function()
		Confirm(L.S_RESET_Q, function()
			ns:ResetSteps()
			counter.Refresh()
		end)
	end))
end

------------------------------------------------------------------------
-- Нижние кнопки, крестик
------------------------------------------------------------------------

local closeX = CreateFrame("Button", nil, win)
closeX:SetSize(22, 22)
closeX:SetPoint("TOPRIGHT", -6, -6)
closeX.label = ns.Font(closeX, 16, G[1], G[2], G[3], "CENTER")
closeX.label:SetPoint("CENTER")
closeX.label:SetText("X")
local closeHl = closeX:CreateTexture(nil, "HIGHLIGHT")
closeHl:SetAllPoints()
closeHl:SetColorTexture(1, 0.2, 0.2, 0.3)
closeX:SetScript("OnClick", function() win:Hide() end)

local bottomLine = win:CreateTexture(nil, "ARTWORK")
bottomLine:SetColorTexture(G[1], G[2], G[3], 0.5)
bottomLine:SetHeight(1)
bottomLine:SetPoint("BOTTOMLEFT", 1, 44)
bottomLine:SetPoint("BOTTOMRIGHT", -1, 44)

local resetAll = Button(win, L.RESET_ALL, 250, function()
	Confirm(L.RESET_ALL_Q, function()
		ns:ResetAll()
		ns:RefreshOptions()
	end)
end)
resetAll:SetPoint("BOTTOMLEFT", 12, 10)

local closeBtn = Button(win, L.CLOSE, 120, function() win:Hide() end)
closeBtn:SetPoint("BOTTOMRIGHT", -12, 10)

------------------------------------------------------------------------
-- Открытие и регистрация в меню игры
------------------------------------------------------------------------

function ns:RefreshOptions()
	if not win:IsShown() then return end
	for i = 1, #refreshers do ns.Safe(refreshers[i].Refresh) end
end

win:SetScript("OnShow", function()
	ShowPage(current or "general")
	ns:RefreshOptions()
end)
win:SetScript("OnHide", function()
	menu:Hide()
	confirm:Hide()
end)

function ns:ToggleOptions(forceShow)
	if not ns.db then return end
	if win:IsShown() and not forceShow then win:Hide() else win:Show() end
end

-- «Настройки → Модификации»: страница с кнопкой, открывающей это окно.
local function RegisterInGameMenu()
	local panel = CreateFrame("Frame")
	panel.name = "AngardUI"
	local title = ns.Font(panel, 18, G[1], G[2], G[3])
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("AngardUI")
	local desc = ns.Font(panel, 13)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	desc:SetWidth(520)
	desc:SetText(L.OPT_DESC)
	local open = Button(panel, L.OPT_OPEN, 260, function() ns:ToggleOptions(true) end)
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
