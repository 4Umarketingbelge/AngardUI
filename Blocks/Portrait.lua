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

ns:On("UNIT_MODEL_CHANGED", update)
ns:On("UNIT_PORTRAIT_UPDATE", update)
