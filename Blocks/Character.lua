-- AngardUI: блок 1 — карточка персонажа.
local _, ns = ...
local L, C = ns.L, ns.C
local P = ns.Plain
local floor, min = math.floor, math.min

local W, PAD = C.layout.cardWidth, C.layout.pad
local INNER = W - PAD * 2
local HEADER_H, ROW_H, CELL_H = 54, 21, 25
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local card = ns:NewBlock("card", W, 210)

------------------------------------------------------------------------
-- Заголовок: эмблема фракции, имя, уровень, шаги
------------------------------------------------------------------------

local function circle(tex)
	local mask = card:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
end

-- место под эмблему; в нём либо крупный герб фракции, либо круглая иконка с золотым кольцом
local slot = CreateFrame("Frame", nil, card)
slot:SetSize(HEADER_H, HEADER_H)
slot:SetPoint("TOPLEFT", PAD - 2, -(PAD - 2))

local crest = slot:CreateTexture(nil, "ARTWORK", nil, 1)
crest:SetSize(HEADER_H + 6, HEADER_H + 6)
crest:SetPoint("CENTER")

local ring = slot:CreateTexture(nil, "ARTWORK", nil, 0)
ring:SetSize(HEADER_H - 2, HEADER_H - 2)
ring:SetPoint("CENTER")
ring:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
circle(ring)

local emblem = slot:CreateTexture(nil, "ARTWORK", nil, 1)
emblem:SetSize(HEADER_H - 6, HEADER_H - 6)
emblem:SetPoint("CENTER")
emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
circle(emblem)

local nameText = ns.Font(card, 17)
nameText:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, -6)
nameText:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
nameText:SetWordWrap(false)

local levelText = ns.Font(card, 14)
levelText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -3)

local stepsText = ns.Font(card, 13, 1, 1, 1, "RIGHT")
stepsText:SetPoint("RIGHT", card, "TOPRIGHT", -PAD, -(PAD + 39))
local stepsIcon = card:CreateTexture(nil, "ARTWORK")
stepsIcon:SetSize(14, 14)
stepsIcon:SetPoint("RIGHT", stepsText, "LEFT", -4, 0)
stepsIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local separator = card:CreateTexture(nil, "ARTWORK")
separator:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.8)
separator:SetHeight(1)
separator:SetPoint("TOPLEFT", PAD, -(PAD + HEADER_H + 2))
separator:SetPoint("TOPRIGHT", -PAD, -(PAD + HEADER_H + 2))

-- полоска опыта поверх разделителя: заполненная часть — доля до следующего уровня
local xpFill = card:CreateTexture(nil, "OVERLAY")
xpFill:SetColorTexture(0.62, 0.35, 0.95, 1)
xpFill:SetHeight(2)
xpFill:SetPoint("LEFT", separator, "LEFT")
xpFill:Hide()

------------------------------------------------------------------------
-- Строки и ячейки профессий
------------------------------------------------------------------------

local ROW_ORDER = { "spec", "rules", "time", "money" }
local rows = {}
for _, key in ipairs(ROW_ORDER) do
	local r = CreateFrame("Frame", nil, card)
	r:SetSize(INNER, ROW_H - 2)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(17, 17)
	r.icon:SetPoint("LEFT")
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.text = ns.Font(r, 13)
	r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.text:SetPoint("RIGHT")
	r.text:SetWordWrap(false)
	rows[key] = r
end

local CELL_W = floor(INNER / 3)
local BAR_W = 52
local cells = {}
local function Cell(i)
	local c = cells[i]
	if c then return c end
	c = CreateFrame("Frame", nil, card)
	c:SetSize(CELL_W, CELL_H - 2)
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(19, 19)
	c.icon:SetPoint("LEFT")
	c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.text = ns.Font(c, 13)
	c.text:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 5, 1)
	c.barBg = c:CreateTexture(nil, "ARTWORK", nil, 0)
	c.barBg:SetColorTexture(1, 1, 1, 0.18)
	c.barBg:SetSize(BAR_W, 2)
	c.barBg:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 5, 0)
	c.bar = c:CreateTexture(nil, "ARTWORK", nil, 1)
	c.bar:SetColorTexture(1, 1, 1, 0.95)
	c.bar:SetHeight(2)
	c.bar:SetPoint("LEFT", c.barBg, "LEFT")
	ns.Tooltip(c, function(tt, self)
		if self.profName then
			tt:AddLine(self.profName, C.gold[1], C.gold[2], C.gold[3])
			tt:AddLine(self.profValue, 1, 1, 1)
		end
	end, true)
	cells[i] = c
	return c
end

------------------------------------------------------------------------
-- Данные
------------------------------------------------------------------------

-- В Forever специализацию не выбирают отдельно: это ветка талантов, в которую вложено
-- больше всего очков. Так же считает само окно талантов игры (группы черт дерева талантов).
local function TraitTreeSpec()
	local SI, T = C_SpecializationInfo, C_Traits
	if not (T and T.GetConfigInfo and T.GetGroupDisplayInfoByTreeID and T.GetGroupCurrencyInfo) then return nil end
	local configID
	if SI and SI.GetCombatConfigIDForSpecGroup then
		configID = SI.GetCombatConfigIDForSpecGroup(SI.GetActiveSpecGroup and SI.GetActiveSpecGroup() or 1)
	end
	if not configID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		configID = C_ClassTalents.GetActiveConfigID()
	end
	if not configID then return nil end
	local config = T.GetConfigInfo(configID)
	local treeID = config and config.treeIDs and config.treeIDs[1]
	if not treeID then return nil end

	local displays = T.GetGroupDisplayInfoByTreeID(treeID)
	local ids = {}
	for i, d in ipairs(displays) do ids[i] = d.groupID end
	local infos = T.GetGroupCurrencyInfo(configID, ids)

	local bestName, bestIcon, bestSpent = nil, nil, 0
	for _, d in ipairs(displays) do
		for _, g in ipairs(infos) do
			if g.traitNodeGroupID == d.groupID then
				local currency = g.currencyInfos and g.currencyInfos[1]
				local spent = currency and currency.spent or 0
				if spent > bestSpent then
					bestName, bestIcon, bestSpent = d.displayName, d.icon, spent
				end
			end
		end
	end
	return bestName, bestIcon
end

-- Специализация: ветка талантов Forever, затем API специализаций, затем старые вкладки талантов.
local function GetSpec()
	local ok, treeName, treeIcon = pcall(TraitTreeSpec)
	if ok and type(treeName) == "string" and treeName ~= "" then return treeName, treeIcon end
	local SI = C_SpecializationInfo
	local idx = ns.Call(SI and SI.GetSpecialization) or ns.Call(GetSpecialization)
	if type(idx) == "number" and idx > 0 then
		local _, name, _, icon = ns.Call(SI and SI.GetSpecializationInfo, idx)
		if type(name) ~= "string" then _, name, _, icon = ns.Call(GetSpecializationInfo, idx) end
		if type(name) == "string" and name ~= "" then return name, icon end
	end
	if type(GetNumTalentTabs) == "function" and type(GetTalentTabInfo) == "function" then
		local bestName, bestIcon, bestPts = nil, nil, 0
		for i = 1, (ns.Call(GetNumTalentTabs) or 0) do
			local a, b, c, d, e = ns.Call(GetTalentTabInfo, i)
			local name, icon, pts
			if type(a) == "string" then name, icon, pts = a, b, c else name, icon, pts = b, d, e end
			if type(pts) == "number" and pts > bestPts and type(name) == "string" then
				bestName, bestIcon, bestPts = name, icon, pts
			end
		end
		if bestName then return bestName, bestIcon end
	end
	return nil
end

-- Свод правил: "pve" / "pvp" / "hc" / "rp". Настройка может переопределить.
function ns.GetRuleset()
	local override = ns.db.ruleset
	if override ~= "auto" then return override end
	local GR, E = C_GameRules, Enum and Enum.GameRule
	if GR and GR.IsGameRuleActive and E then
		if E.HardcoreRuleset and ns.Call(GR.IsGameRuleActive, E.HardcoreRuleset) == true then return "hc" end
		if E.RPRuleset and ns.Call(GR.IsGameRuleActive, E.RPRuleset) == true then return "rp" end
		if E.PvPRuleset and ns.Call(GR.IsGameRuleActive, E.PvPRuleset) == true then return "pvp" end
	elseif GR and ns.Call(GR.IsHardcoreActive) == true then
		return "hc"
	end
	return "pve"
end

-- Профессии: GetProfessions + список навыков (C_SkillInfo), без дублей.
local profList, profPool = {}, {}
local function addProf(n, id, name, icon, cur, maxv, primary)
	local e = profPool[n]
	if not e then e = {}; profPool[n] = e end
	e.id, e.name, e.icon, e.cur, e.max, e.primary = id, name, icon, cur, maxv, primary
	profList[n] = e
end

local function sortProfs(a, b)
	if a.primary ~= b.primary then return a.primary end
	return (a.id or 0) < (b.id or 0)
end

function ns.GetProfessions()
	local n = 0
	local seenID, seenName = {}, {}
	if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
		local p1, p2, arch, fish, cook, extra = ns.Call(GetProfessions)
		local idx = { p1, p2, arch, fish, cook, extra }
		for i = 1, 6 do
			if idx[i] then
				local name, icon, cur, maxv, _, _, skillLine = ns.Call(GetProfessionInfo, idx[i])
				if type(name) == "string" and type(cur) == "number" then
					n = n + 1
					addProf(n, skillLine, name, icon or (skillLine and C.professions[skillLine]), cur, maxv or 0, i <= 2)
					if skillLine then seenID[skillLine] = true end
					seenName[name] = true
				end
			end
		end
	end
	local SK = C_SkillInfo
	if SK and SK.GetNumSkillLines and SK.GetSkillLineInfo then
		for i = 1, (ns.Call(SK.GetNumSkillLines) or 0) do
			local info = ns.Call(SK.GetSkillLineInfo, i)
			if type(info) == "table" and not info.isHeader then
				local id = info.skillID
				if id and C.professions[id] and not seenID[id] and not seenName[info.name] then
					n = n + 1
					local icon = C_TradeSkillUI and ns.Call(C_TradeSkillUI.GetTradeSkillTexture, id)
					addProf(n, id, info.name, icon or C.professions[id], info.rank or 0, info.maxRank or 0,
						not C.secondaryProfessions[id])
					seenID[id] = true
				end
			end
		end
	end
	for i = n + 1, #profList do profList[i] = nil end
	table.sort(profList, sortProfs)
	return profList
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:1:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:1:0|t"

------------------------------------------------------------------------
-- Обновление
------------------------------------------------------------------------

function card:UpdateTime()
	rows.time.text:SetText(L.ON_LEVEL:format(ns.FormatDuration(ns.GetLevelTime())))
end

local shownSteps = -1
function card:UpdateSteps(force)
	local n = floor(ns.GetSteps())
	if n ~= shownSteps or force then
		shownSteps = n
		stepsText:SetText(ns.Group(n))
	end
end

function card:UpdateXP()
	local cur, maxv = P(UnitXP("player"), 0), P(UnitXPMax("player"), 0)
	if not ns.db.card.xp or maxv <= 0 or cur <= 0 then
		xpFill:Hide()
		return
	end
	xpFill:SetWidth(math.max(min(cur / maxv, 1) * INNER, 0.001))
	xpFill:Show()
end

function card:UpdateMoney()
	local money = P(GetMoney(), 0)
	local g, s, c = floor(money / 10000), floor(money / 100) % 100, money % 100
	rows.money.text:SetText(("%s %s%s %d%s %d%s"):format(L.MONEY, ns.Group(g), GOLD_ICON, s, SILVER_ICON, c, COPPER_ICON))
end

function card:UpdateProfessions()
	local list = ns.db.card.profs and ns.GetProfessions() or nil
	local n = list and min(#list, 6) or 0
	for i = 1, n do
		local p, c = list[i], Cell(i)
		c.icon:SetTexture(p.icon or ns.Icon("unknown"))
		c.text:SetText(p.cur .. "/" .. p.max)
		c.profName, c.profValue = p.name, p.cur .. " / " .. p.max
		local frac = (p.max > 0) and min(p.cur / p.max, 1) or 0
		c.bar:SetWidth(frac > 0 and (BAR_W * frac) or 0.001)
		c.bar:SetShown(frac > 0)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + ((i - 1) % 3) * CELL_W, card.profTop - floor((i - 1) / 3) * CELL_H)
		c:Show()
	end
	for i = n + 1, #cells do cells[i]:Hide() end
	return n
end

function card:Refresh()
	local db = ns.db.card

	local _, classFile = UnitClass("player")
	classFile = P(classFile)
	local className = P(UnitClass("player"), "")
	-- в Forever UnitName возвращает имя и фамилию двумя значениями
	local first, surname = UnitName("player")
	first, surname = P(first, ""), P(surname)
	local fullName = first
	if type(surname) == "string" and surname ~= "" then
		local consts = Constants and Constants.CharacterNameSeparatorConsts
		fullName = first .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
	end
	nameText:SetText(fullName)
	nameText:SetTextColor(ns.ClassColor(classFile))
	levelText:SetText(L.LEVEL:format(P(UnitLevel("player"), 0)))

	local faction = P(UnitFactionGroup("player"), "Neutral")
	local factionIcon = ns.Icon(C.icons[faction] and faction or "Neutral")
	local isCrest = factionIcon:find("Timer", 1, true) ~= nil
	crest:SetShown(isCrest)
	ring:SetShown(not isCrest)
	emblem:SetShown(not isCrest)
	if isCrest then crest:SetTexture(factionIcon) else emblem:SetTexture(factionIcon) end

	stepsIcon:SetTexture(ns.Icon("steps"))
	stepsIcon:SetShown(db.steps)
	stepsText:SetShown(db.steps)
	self:UpdateSteps(true)
	self:UpdateXP()

	-- строки
	local specName, specIcon = GetSpec()
	rows.spec.icon:SetTexture(specIcon or (classFile and ("Interface\\Icons\\ClassIcon_" .. classFile)) or ns.Icon("unknown"))
	-- до выбора специализации игра отдаёт вместо неё название класса — не дублируем
	if specName == className then specName = nil end
	rows.spec.text:SetText(specName and L.CLASS_SPEC:format(className, specName) or className)

	local rule = ns.GetRuleset()
	rows.rules.icon:SetTexture(ns.Icon("rules_" .. rule))
	rows.rules.text:SetText(L.RULES:format(L["RULE_" .. rule:upper()] or L.RULE_PVE))

	rows.time.icon:SetTexture(ns.Icon("time"))
	self:UpdateTime()
	rows.money.icon:SetTexture(ns.Icon("money"))
	self:UpdateMoney()

	local y = -(PAD + HEADER_H + 8)
	for _, key in ipairs(ROW_ORDER) do
		local r = rows[key]
		if db[key] then
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, y)
			r:Show()
			y = y - ROW_H
		else
			r:Hide()
		end
	end

	-- профессии: первая строка до 3, вторая — остальные
	self.profTop = y - 2
	local n = self:UpdateProfessions()
	if n > 0 then
		y = self.profTop - (floor((n - 1) / 3) + 1) * CELL_H
	end
	self.contentHeight = -y + PAD
end

------------------------------------------------------------------------
-- События
------------------------------------------------------------------------

local function full()
	if not ns.db then return end
	card:Refresh()
	ns:Layout()
end

ns:On("PLAYER_LEVEL_UP", function(_, level)
	if not ns.db then return end
	if type(level) == "number" then levelText:SetText(L.LEVEL:format(level)) end
	card:UpdateTime()
end)
ns:On("PLAYER_MONEY", function() if ns.db then card:UpdateMoney() end end)
ns:On("UNIT_NAME_UPDATE", function(_, unit) if unit == "player" then full() end end)
ns:On("SKILL_LINES_CHANGED", full)
ns:On("TRADE_SKILL_LIST_UPDATE", full)
ns:On("PLAYER_SPECIALIZATION_CHANGED", full)
ns:On("ACTIVE_TALENT_GROUP_CHANGED", full)
ns:On("PLAYER_TALENT_UPDATE", full)
ns:On("GAME_RULES_CHANGED", full)
ns:On("PLAYER_XP_UPDATE", function() if ns.db then card:UpdateXP() end end)
ns:On("TRAIT_CONFIG_UPDATED", full)
ns:On("TRAIT_TREE_CURRENCY_INFO_UPDATED", full)
ns:On("ACTIVE_COMBAT_CONFIG_CHANGED", full)
