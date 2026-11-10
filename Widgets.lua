-- AngardUI: два сменных квадрата справа (блоки 3 и 5). В каждый можно поставить любой
-- виджет из списка: пульс, температура, давление, часы, погода, координаты и т. д.
-- Виджет — таблица { titleKey, interval, usesSim, Build(view), Update(view, force), Tooltip(tt) }.
-- Выбор виджетов хранится на персонажа. Правый клик по квадрату открывает список,
-- колёсико мыши листает виджеты по кругу.
local _, ns = ...
local L, C = ns.L, ns.C
local S = C.layout.square

ns.widgets = {} -- key -> описание
ns.widgetOrder = {} -- порядок в списках

function ns:RegisterWidget(key, def)
	def.key = key
	ns.widgets[key] = def
	ns.widgetOrder[#ns.widgetOrder + 1] = key
end

-- Название берётся в момент показа, чтобы смена языка действовала сразу
function ns.WidgetTitle(key)
	local def = ns.widgets[key]
	return def and L[def.titleKey] or tostring(key)
end

------------------------------------------------------------------------
-- Типовой вид: иконка с подписью, крупное значение, строка пояснения, полоска
------------------------------------------------------------------------

local BAR_W = S - 16

function ns.SimpleView(view, title)
	view.icon = view:CreateTexture(nil, "ARTWORK")
	view.icon:SetSize(16, 16)
	view.icon:SetPoint("TOPLEFT", 7, -7)
	view.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	view.label = ns.Font(view, 10, 0.72, 0.72, 0.76)
	view.label:SetPoint("LEFT", view.icon, "RIGHT", 5, 0)
	view.label:SetPoint("RIGHT", view, "RIGHT", -6, 0)
	view.label:SetWordWrap(false)
	view.label:SetText(title)

	view.value = ns.Font(view, 19)
	view.value:SetPoint("LEFT", view, "LEFT", 8, -1)
	view.value:SetPoint("RIGHT", view, "RIGHT", -6, -1)
	view.value:SetWordWrap(false)

	view.sub = ns.Font(view, 11, 0.85, 0.85, 0.88)
	view.sub:SetPoint("TOPLEFT", view.value, "BOTTOMLEFT", 0, -2)
	view.sub:SetPoint("RIGHT", view, "RIGHT", -6, 0)
	view.sub:SetWordWrap(false)

	view.barBg = view:CreateTexture(nil, "ARTWORK", nil, 0)
	view.barBg:SetColorTexture(1, 1, 1, 0.16)
	view.barBg:SetSize(BAR_W, 4)
	view.barBg:SetPoint("BOTTOMLEFT", 8, 7)
	view.barBg:Hide()
	view.bar = view:CreateTexture(nil, "ARTWORK", nil, 1)
	view.bar:SetHeight(4)
	view.bar:SetPoint("LEFT", view.barBg, "LEFT")
	view.bar:Hide()

	-- тексты меняются только при изменении, чтобы не дёргать интерфейс
	function view:Set(value, sub, r, g, b)
		if value ~= self.shownValue then
			self.shownValue = value
			self.value:SetText(value)
		end
		if sub ~= self.shownSub then
			self.shownSub = sub
			self.sub:SetText(sub or "")
		end
		self.value:SetTextColor(r or 1, g or 1, b or 1)
	end

	function view:SetBar(frac, r, g, b)
		if not frac then
			self.barBg:Hide()
			self.bar:Hide()
			return
		end
		if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
		self.barBg:Show()
		self.bar:SetShown(frac > 0)
		self.bar:SetWidth(frac > 0 and frac * BAR_W or 0.001)
		self.bar:SetColorTexture(r or 1, g or 1, b or 1, 1)
	end

	-- key — ключ из C.icons; path — готовый путь или номер файла (иконка предмета)
	function view:SetIcon(key, path)
		local id = path or key
		if id ~= self.shownIcon then
			self.shownIcon = id
			self.icon:SetTexture(path or ns.Icon(key))
		end
	end
end

-- Короткая регистрация виджета типового вида. extra — необязательные поля описания.
function ns:RegisterSimpleWidget(key, titleKey, iconKey, interval, update, extra)
	local def = extra or {}
	def.titleKey = titleKey
	def.interval = interval
	def.Build = function(view)
		ns.SimpleView(view, L[titleKey])
		if iconKey then view:SetIcon(iconKey) end
	end
	def.Update = update
	ns:RegisterWidget(key, def)
end

------------------------------------------------------------------------
-- Слоты
------------------------------------------------------------------------

local slots = {}

local function CurrentKey(slotKey)
	local key = ns.chardb.slots[slotKey]
	if not ns.widgets[key] then key = ns.charDefaults.slots[slotKey] end
	return key
end

local function SetWidget(slotKey, key)
	ns.chardb.slots[slotKey] = key
	for i = 1, #slots do
		if slots[i].slotKey == slotKey then slots[i]:Refresh() end
	end
	if ns.RefreshOptions then ns:RefreshOptions() end
end

local function Cycle(slotKey, step)
	local order = ns.widgetOrder
	local current = CurrentKey(slotKey)
	local index = 1
	for i = 1, #order do
		if order[i] == current then index = i end
	end
	index = (index - 1 + step) % #order + 1
	SetWidget(slotKey, order[index])
end

-- Список виджетов по правому клику. Закрывается выбором, повторным кликом
-- или сам, если увести с него мышь.
local menu, menuItems = nil, {}

local function ToggleMenu(block)
	if not menu then
		menu = CreateFrame("Frame", nil, UIParent)
		menu:SetFrameStrata("TOOLTIP")
		menu:EnableMouse(true)
		menu:SetClampedToScreen(true)
		ns.Skin(menu, 0.96)
		menu:Hide()
		menu:SetScript("OnUpdate", function(self, elapsed)
			if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then
				self.idle = 0
			else
				self.idle = (self.idle or 0) + elapsed
				if self.idle > 1.2 then self:Hide() end
			end
		end)
	end
	if menu:IsShown() and menu.owner == block then
		menu:Hide()
		return
	end
	if GameTooltip then GameTooltip:Hide() end

	local y = C.yellow
	local current = CurrentKey(block.slotKey)
	local order = ns.widgetOrder
	for i = 1, #order do
		local item = menuItems[i]
		if not item then
			item = CreateFrame("Button", nil, menu)
			item:SetHeight(18)
			item.text = ns.Font(item, 12)
			item.text:SetPoint("LEFT", 8, 0)
			item.text:SetPoint("RIGHT", -8, 0)
			item.text:SetWordWrap(false)
			local hl = item:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(1, 1, 1, 0.14)
			item:SetPoint("TOPLEFT", 1, -(i - 1) * 18 - 3)
			item:SetPoint("RIGHT", -1, 0)
			item:SetScript("OnClick", function(self)
				menu:Hide()
				ns.Safe(SetWidget, menu.owner.slotKey, self.key)
			end)
			menuItems[i] = item
		end
		item.key = order[i]
		item.text:SetText(ns.WidgetTitle(order[i]))
		if order[i] == current then item.text:SetTextColor(y[1], y[2], y[3]) else item.text:SetTextColor(1, 1, 1) end
		item:Show()
	end
	for i = #order + 1, #menuItems do menuItems[i]:Hide() end

	menu.owner = block
	menu.idle = 0
	menu:SetScale(ns.root:GetScale())
	menu:SetSize(150, #order * 18 + 6)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", block, "TOPRIGHT", 4, 0)
	menu:Show()
end

local function NewSlot(blockKey, slotKey, height)
	local block = ns:NewBlock(blockKey, S, height)
	block.views = {}
	block.slotKey = slotKey

	function block:Refresh()
		local key = CurrentKey(slotKey)
		local def = ns.widgets[key]
		local view = self.views[key]
		if not view then
			view = CreateFrame("Frame", nil, self)
			view:SetAllPoints()
			view.def = def
			def.Build(view)
			self.views[key] = view
		end
		if self.view ~= view then
			if self.view then self.view:Hide() end
			self.view = view
			view:Show()
		end
		view.acc = 0
		def.Update(view, true)
	end

	-- высота нижнего слота зависит от карточки
	block:SetScript("OnSizeChanged", function(self)
		if ns.db and self.view then ns.Safe(self.view.def.Update, self.view, true) end
	end)

	block:EnableMouseWheel(true)
	block:SetScript("OnMouseWheel", function(_, delta)
		if ns.db then ns.Safe(Cycle, slotKey, delta > 0 and -1 or 1) end
	end)
	block:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and ns.db then ns.Safe(ToggleMenu, self) end
	end)
	ns.Tooltip(block, function(tt, self)
		local def = self.view and self.view.def
		if not def then return end
		tt:AddLine(L[def.titleKey], C.gold[1], C.gold[2], C.gold[3])
		if def.Tooltip then def.Tooltip(tt) end
		tt:AddLine(L.TIP_SLOT, 0.6, 0.6, 0.6)
	end)

	slots[#slots + 1] = block
end

NewSlot("pulse", "top", S)
NewSlot("temp", "bottom", C.layout.lowerDefault)

-- Обновить виджет немедленно (для виджетов, которые слушают события)
function ns:UpdateWidgets(key)
	for i = 1, #slots do
		local view = slots[i].view
		if view and slots[i]:IsShown() and (not key or view.def.key == key) then
			ns.Safe(view.def.Update, view, true)
		end
	end
end

-- Нужна ли сейчас симуляция: показан ли хоть один виджет, который её использует
function ns.SimNeeded()
	for i = 1, #slots do
		local view = slots[i].view
		if view and view.def.usesSim and slots[i]:IsShown() then return true end
	end
	return false
end

-- После смены языка: виды пересоздаются, потому что в них есть постоянные подписи
function ns:RebuildWidgets()
	for i = 1, #slots do
		local block = slots[i]
		for _, view in pairs(block.views) do view:Hide() end
		block.views = {}
		block.view = nil
	end
	if menu then menu:Hide() end
end

local mod = {}
ns.modules[#ns.modules + 1] = mod
function mod:Init()
	ns.state.loginTime = GetTime()
	ns.state.loginMoney = ns.Plain(GetMoney(), 0)
	-- у каждого виджета свой интервал обновления
	ns:Every(C.intervals.sim, function(dt)
		for i = 1, #slots do
			local block = slots[i]
			local view = block.view
			if view and block:IsShown() then
				view.acc = (view.acc or 0) + dt
				if view.acc >= (view.def.interval or 1) then
					view.acc = 0
					ns.Safe(view.def.Update, view)
				end
			end
		end
	end)
end
