-- AngardUI: два сменных квадрата справа (блоки 3 и 5). В каждый можно поставить любой
-- виджет из списка: пульс, температура, давление, часы, погода, координаты и т. д.
-- Виджет — таблица { title, interval, Build(view), Update(view, force) }.
local _, ns = ...
local L, C = ns.L, ns.C
local S = C.layout.square

ns.widgets = {} -- key -> описание
ns.widgetOrder = {} -- порядок в списке настроек

function ns:RegisterWidget(key, def)
	def.key = key
	ns.widgets[key] = def
	ns.widgetOrder[#ns.widgetOrder + 1] = key
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

	function view:SetIcon(key)
		if key ~= self.shownIcon then
			self.shownIcon = key
			self.icon:SetTexture(ns.Icon(key))
		end
	end
end

-- Короткая регистрация виджета типового вида
function ns:RegisterSimpleWidget(key, title, iconKey, interval, update)
	ns:RegisterWidget(key, {
		title = title,
		interval = interval,
		Build = function(view)
			ns.SimpleView(view, title)
			if iconKey then view:SetIcon(iconKey) end
		end,
		Update = update,
	})
end

------------------------------------------------------------------------
-- Слоты
------------------------------------------------------------------------

local slots = {}

local function NewSlot(blockKey, slotKey, height)
	local block = ns:NewBlock(blockKey, S, height)
	block.views = {}

	function block:Refresh()
		local key = ns.db.slots[slotKey]
		if not ns.widgets[key] then key = ns.defaults.slots[slotKey] end
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
