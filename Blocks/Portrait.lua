-- AngardUI: блок 2 — анимированный 3D-портрет персонажа (PlayerModel),
-- запасной вариант — плоский портрет через SetPortraitTexture.
local _, ns = ...
local S = ns.C.layout.square

local block = ns:NewBlock("portrait", S, S)
local portrait = ns.CreatePortrait(block)

function block:Refresh()
	if not self:IsShown() and not ns.db.blocks.portrait then return end
	portrait:SetUnit("player")
end

local function update(_, unit)
	if unit and unit ~= "player" then return end
	if ns.db and block:IsShown() then portrait:SetUnit("player") end
end

-- Правый клик — то же меню, что у стандартной рамки игрока: выйти из группы,
-- способ распределения добычи, метки и т. д. Вызов как в Blizzard PlayerFrame.lua.
function ns.OpenPlayerMenu(owner)
	if type(UnitPopup_OpenMenu) == "function" then
		local ok = pcall(UnitPopup_OpenMenu, "SELF", { unit = "player", ownerFrame = owner, fromPlayerFrame = true })
		if ok then return true end
	end
	if ToggleDropDownMenu and PlayerFrameDropDown then
		return pcall(ToggleDropDownMenu, 1, nil, PlayerFrameDropDown, owner, 0, 0)
	end
	return false
end

block:SetScript("OnMouseUp", function(self, button)
	if button == "RightButton" then ns.OpenPlayerMenu(self) end
end)
ns.Tooltip(block, function(tt)
	tt:AddLine(ns.Plain(UnitName("player"), ""), 1, 1, 1)
	tt:AddLine(ns.L.TT_PORTRAIT_MENU, 0.7, 0.7, 0.7)
end)

ns:On("UNIT_MODEL_CHANGED", update)
ns:On("UNIT_PORTRAIT_UPDATE", update)
