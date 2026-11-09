-- AngardUI: блок 6 — гильдия и её офицеры. Клик по имени только открывает поле
-- шёпота этому игроку; аддон сам ничего не отправляет.
local _, ns = ...
local L, C = ns.L, ns.C
local P = ns.Plain
local ceil, min = math.ceil, math.min

local W, PAD = C.layout.cardWidth, C.layout.pad
local ROW_H, TOP = 17, 52
local COL_W = (W - PAD * 2) / 2
local MAX_BUTTONS = 12

local block = ns:NewBlock("guild", W, 120)

local title = ns.Font(block, 15, C.gold[1], C.gold[2], C.gold[3])
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetPoint("RIGHT", -PAD, 0)
title:SetWordWrap(false)

local line = block:CreateTexture(nil, "ARTWORK")
line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.8)
line:SetHeight(1)
line:SetPoint("TOPLEFT", PAD, -29)
line:SetPoint("TOPRIGHT", -PAD, -29)

local hint = ns.Font(block, 12)
hint:SetPoint("TOPLEFT", PAD, -34)

local more = ns.Font(block, 12)

------------------------------------------------------------------------
-- Шёпот
------------------------------------------------------------------------

-- Только открывает строку ввода с адресатом. Вызывается из клика мышью.
local function OpenWhisper(name)
	if not name or name == "" then return end
	if ChatFrameUtil and ChatFrameUtil.SendTell then
		ChatFrameUtil.SendTell(name)
	elseif type(ChatFrame_SendTell) == "function" then
		ChatFrame_SendTell(name)
	elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
		ChatFrameUtil.OpenChat("/w " .. name .. " ")
	elseif type(ChatFrame_OpenChat) == "function" then
		ChatFrame_OpenChat("/w " .. name .. " ")
	end
end

local buttons = {}
for i = 1, MAX_BUTTONS do
	local b = CreateFrame("Button", nil, block)
	b:SetSize(COL_W - 6, ROW_H)
	b.text = ns.Font(b, 13)
	b.text:SetAllPoints()
	b.text:SetWordWrap(false)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.12)
	b:SetScript("OnClick", function(self) ns.Safe(OpenWhisper, self.fullName) end)
	b:Hide()
	buttons[i] = b
end

------------------------------------------------------------------------
-- Состав
------------------------------------------------------------------------

local list, pool = {}, {}
local total = 0

local function byRank(a, b)
	if a.online ~= b.online then return a.online end
	if a.rank ~= b.rank then return a.rank < b.rank end
	return a.name < b.name
end

-- Убирает название своего игрового мира из имени для показа.
local function ShortName(full)
	if type(Ambiguate) == "function" then
		local ok, short = pcall(Ambiguate, full, "guild")
		if ok and type(short) == "string" and short ~= "" then return short end
	end
	return full
end

local function Collect()
	local n = 0
	local gdb = ns.db.guild
	local myGUID = P(UnitGUID("player"))
	local count = P(ns.Call(GetNumGuildMembers), 0)
	for i = 1, count do
		local name, _, rankIndex, _, _, _, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
		if type(name) == "string" and type(rankIndex) == "number" and rankIndex <= gdb.maxRank
			and (online or not gdb.onlineOnly) and (not guid or guid ~= myGUID) then
			n = n + 1
			local e = pool[n]
			if not e then e = {}; pool[n] = e end
			e.full, e.name, e.rank, e.class, e.online = name, ShortName(name), rankIndex, class, online and true or false
			list[n] = e
		end
	end
	for i = n + 1, #list do list[i] = nil end
	table.sort(list, byRank)
	total = n
end

function block:Refresh()
	local guildName = IsInGuild() and P(GetGuildInfo("player")) or nil
	local had = ns.state.hasGuild
	ns.state.hasGuild = guildName ~= nil
	if not guildName then return had end

	title:SetText(ns.Upper(guildName))
	Collect()

	local shown = min(total, ns.db.guild.count, MAX_BUTTONS)
	for i = 1, MAX_BUTTONS do
		local b = buttons[i]
		if i <= shown then
			local e = list[i]
			b.fullName = e.full
			b.text:SetText(e.name)
			local r, g, bl = ns.ClassColor(e.class)
			if not e.online then r, g, bl = r * 0.55, g * 0.55, bl * 0.55 end
			b.text:SetTextColor(r, g, bl)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", block, "TOPLEFT", PAD + ((i - 1) % 2) * COL_W, -TOP - math.floor((i - 1) / 2) * ROW_H)
			b:Show()
		else
			b:Hide()
		end
	end

	local rowsUsed = ceil(shown / 2)
	local y = TOP + rowsUsed * ROW_H
	hint:SetText(shown > 0 and L.GUILD_HINT or L.GUILD_NONE)
	if total > shown then
		more:SetText(L.GUILD_MORE:format(total - shown))
		more:ClearAllPoints()
		more:SetPoint("TOPLEFT", block, "TOPLEFT", PAD, -y - 1)
		more:Show()
		y = y + ROW_H
	else
		more:Hide()
	end
	self:SetHeight(y + PAD)
	return had
end

------------------------------------------------------------------------
-- События
------------------------------------------------------------------------

local function RequestRoster()
	if not IsInGuild() then return end
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		ns.Call(C_GuildInfo.GuildRoster)
	else
		ns.Call(GuildRoster)
	end
end

local pending = false
local function update()
	pending = false
	if not ns.db then return end
	block:Refresh()
	ns:Layout()
end

-- обновления состава приходят пачками — обрабатываем не чаще раза в секунду
local function schedule()
	if pending then return end
	pending = true
	C_Timer.After(1, function() ns.Safe(update) end)
end

ns:On("GUILD_ROSTER_UPDATE", schedule)
ns:On("PLAYER_GUILD_UPDATE", schedule)
ns:On("GUILD_RANKS_UPDATE", schedule)

local mod = {}
ns.modules[#ns.modules + 1] = mod
function mod:Init()
	RequestRoster()
	ns:Every(C.intervals.roster, function()
		if block:IsVisible() then RequestRoster() end
	end)
end
