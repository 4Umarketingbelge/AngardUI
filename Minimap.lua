-- AngardUI: кнопка у миникарты. Левая кнопка мыши — настройки, правая — показать или
-- скрыть панель, перетаскивание — передвинуть кнопку по кругу. Без сторонних библиотек.
local _, ns = ...
local L = ns.L
local cos, sin, rad, deg = math.cos, math.sin, math.rad, math.deg
local atan2 = math.atan2 or math.atan

local button

local function Place()
	local angle = rad(ns.db.minimap.angle or 205)
	local radius = (Minimap:GetWidth() or 140) / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", cos(angle) * radius, sin(angle) * radius)
end

-- во время перетаскивания кнопка идёт по кругу за курсором
local function Drag()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not mx or not cx or not scale or scale == 0 then return end
	ns.db.minimap.angle = deg(atan2(cy / scale - my, cx / scale - mx))
	Place()
end

local function Create()
	button = CreateFrame("Button", "AngardUIMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Spell_Holy_Heal")
	icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.db.shown = not ns.db.shown
			ns:ApplyAll()
			if ns.RefreshOptions then ns:RefreshOptions() end
		else
			ns:ToggleOptions()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", Drag)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("AngardUI")
		GameTooltip:AddLine(L.MM_LEFT, 1, 1, 1)
		GameTooltip:AddLine(L.MM_RIGHT, 1, 1, 1)
		GameTooltip:AddLine(L.MM_DRAG, 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
end

function ns:ApplyMinimap()
	if not Minimap then return end
	if not button then
		if not ns.db.minimap.show then return end
		Create()
	end
	button:SetShown(ns.db.minimap.show)
	if ns.db.minimap.show then Place() end
end

-- Запись в меню аддонов у миникарты (если оно есть в клиенте); имя функции указано в .toc
function AngardUI_OnAddonCompartmentClick()
	if ns.db then ns:ToggleOptions() end
end
