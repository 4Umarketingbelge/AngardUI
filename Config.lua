-- AngardUI: единая таблица конфигурации. Все коэффициенты симуляции и размеры — здесь.
local _, ns = ...

ns.C = {
	-- Размеры панели (в единицах интерфейса при масштабе 100%)
	layout = {
		cardWidth = 300, -- ширина карточки и блока гильдии
		square = 124, -- сторона портрета и блока пульса; питомец — половина
		lowerMin = 82, -- минимальная высота блоков здоровья и температуры
		lowerDefault = 98, -- их высота, когда карточка выключена
		gap = 4,
		pad = 8,
		defaultX = 12, -- позиция по умолчанию от левого верхнего угла экрана
		defaultY = -12,
	},

	gold = { 0.86, 0.70, 0.28 },
	yellow = { 1.00, 0.85, 0.10 },

	-- Как часто (сек) выполняются периодические задачи
	intervals = { sim = 0.2, slow = 1.0, steps = 0.25, clock = 15, save = 60, roster = 120 },

	-- Множитель «чувствительности» для всего, что поднимает показатели
	sensitivity = { calm = 0.6, normal = 1.0, dramatic = 1.5 },

	-- ПУЛЬС (уд/мин). Прибавки к пульсу покоя.
	pulse = {
		restMin = 62, restMax = 75, -- пульс покоя (постоянный для персонажа)
		min = 50, max = 190,
		combat = 22, -- сам факт боя
		perAttacker = 9, maxAttackers = 4, -- за каждого атакующего
		lowHealth = 45, -- при 0% здоровья (линейно от потерянного)
		elite = 10, boss = 24, -- элитная / босс-цель
		run = 14, swim = 18, fall = 22, breath = 28,
		sit = -6, eat = -5, rest = -4, -- успокаивают (только вне боя)
		perStress = 14, -- за единицу стресса
		tauUp = 3.5, tauDown = 9, tauDeath = 1.2, -- сек: скорость роста / спада / остановки
		noise = 1.6,
	},

	-- СТРЕСС (0..max) — добавка к пульсу: резкая потеря здоровья, сильная цель, PvP-флаг
	stress = {
		lossGain = 2.2, -- за потерю 100% здоровья
		hitGain = 0.05, -- за каждый полученный удар (если здоровье недоступно аддону)
		decay = 14, -- сек, затухание импульсов
		levelDiff = 3, higherLevel = 0.25, -- цель выше на N уровней
		skull = 0.5, -- цель-«череп»
		pvp = 0.2, -- включён PvP-флаг
		tau = 4,
		max = 1.5,
	},

	-- ДАВЛЕНИЕ (мм рт. ст.) — виджет «Давление»
	bp = {
		sysBase = 114, diaBase = 73,
		sysPerBpm = 0.42, diaPerBpm = 0.22, -- за каждый удар сверх пульса покоя
		sysPerStress = 34, diaPerStress = 20,
		tau = 5, noise = 1.5,
		normalSys = 130, normalDia = 85, -- до этих значений — норма
		highSys = 160, highDia = 100, -- до этих — повышенное, выше — криз
		scaleMin = 90, scaleMax = 200, -- края шкалы
	},

	-- ПОГОДА — виджет «Погода». У игры нет функции погоды, поэтому она выдумана
	-- по климату зоны и времени суток.
	weather = {
		air = { snow = -8, cold = 6, mild = 16, swamp = 22, hot = 28, desert = 36, lava = 48 }, -- °C днём
		night = -6, -- поправка ночью
		rain = { mild = 0.25, cold = 0.35, swamp = 0.40, hot = 0.10 }, -- вероятность осадков
	},

	-- ПИТОМЕЦ: сколько кусочков корма остаётся при настроении 1 / 2 / 3
	pet = { pieces = 7, byHappiness = { 1, 4, 7 } },
	-- виды корма: иконка целого кусочка и иконка съеденного (без неё — бледный след)
	petFood = {
		meat = { icon = "food_meat", eaten = "bone" },
		veggies = { icon = "food_veggies" },
		fish = { icon = "food_fish", eaten = "bone" },
	},

	-- ТЕМПЕРАТУРА (°C)
	temp = {
		base = 36.6, min = 35.0, max = 40.5,
		tau = 30, noise = 0.04,
		swim = -0.5,
		sick = 1.1, -- дебафф «болезнь» или «яд»
		drunkPerLevel = 0.25, -- 3 степени опьянения
		drunkFade = 600, -- сек до снижения степени, если игра не сообщила сама
		combatMax = 0.7, combatRamp = 120, -- долгий бой: +combatMax за combatRamp сек
		run = 0.1,
		indoorsFactor = 0.4, -- в помещении климат зоны влияет слабее
		chillBelow = 36.2, feverFrom = 37.3, overheatFrom = 38.6,
		climate = { snow = -0.9, cold = -0.4, swamp = 0.2, hot = 0.4, desert = 0.8, lava = 1.6 },
	},

	-- Климат зон ванилы. Ключ — AreaID (одинаков во всех клиентах), название зоны
	-- берётся у игры через C_Map.GetAreaInfo, поэтому таблица не зависит от локали.
	zones = {
		[1] = "snow", -- Дун Морог
		[618] = "snow", -- Зимние Ключи
		[36] = "snow", -- Альтеракские горы
		[2597] = "snow", -- Альтеракская долина
		[3456] = "cold", -- Наксрамас
		[85] = "cold", -- Тирисфальские леса
		[130] = "cold", -- Серебряный бор
		[139] = "cold", -- Восточные Чумные земли
		[28] = "cold", -- Западные Чумные земли
		[41] = "cold", -- Перевал Мертвого Ветра
		[8] = "swamp", -- Болото Печали
		[15] = "swamp", -- Пылевые топи
		[11] = "swamp", -- Болотина
		[33] = "hot", -- Тернистая долина
		[490] = "hot", -- Кратер Ун'Горо
		[14] = "hot", -- Дуротар
		[1637] = "hot", -- Оргриммар
		[17] = "hot", -- Степи
		[405] = "hot", -- Пустоши
		[4] = "hot", -- Выжженные земли
		[440] = "desert", -- Танарис
		[1377] = "desert", -- Силитус
		[3] = "desert", -- Бесплодные земли
		[400] = "desert", -- Тысяча Игл
		[51] = "lava", -- Тлеющее ущелье
		[46] = "lava", -- Пылающие степи
		[25] = "lava", -- Черная гора
		[1584] = "lava", -- Глубины Черной горы
		[1583] = "lava", -- Пик Черной горы
		[2717] = "lava", -- Огненные Недра
		[2437] = "lava", -- Огненная пропасть
	},

	-- Названия аур еды/питья (сравнение по имени, вне боя)
	foodAuras = {
		["Food"] = true, ["Drink"] = true, ["Refreshment"] = true, ["Food & Drink"] = true,
		["Еда"] = true, ["Питье"] = true, ["Питьё"] = true, ["Угощение"] = true, ["Еда и питье"] = true,
	},

	-- ШАГИ
	steps = {
		yard = 0.9144, -- метров в ярде
		slack = 1.3, -- во сколько раз смещение может превышать скорость*время (иначе телепорт/транспорт)
		maxGap = 1.0, -- сек: более длинная пауза между замерами не учитывается
	},

	-- КАРДИОГРАММА
	alertGlow = { 1.0, 0.42, 0.30 }, -- подсветка рамки, бьющаяся при здоровье ниже 50%

	ecg = {
		window = 3, -- сколько секунд ленты помещается в окно графика
		fps = 30,
		active = 0.62, -- длина комплекса P-QRS-T в секундах; при частом пульсе он сжимается
		variability = 0.04, -- разброс интервала между ударами (±4%)
		ampRest = 0.8, ampMax = 1.05, -- высота зубцов в покое и на пределе
		ampJitter = 0.06,
		hotFrom = 105, hotTo = 165, -- с какого пульса линия начинает краснеть и где она красная
		hot = { 1.0, 0.22, 0.12 },
		heartKick = 0.28, -- насколько сердечко увеличивается на ударе
		-- форма одного удара: пары (доля периода, высота)
		shape = { 0, 0, 0.10, 0, 0.15, 0.12, 0.20, 0, 0.26, 0, 0.29, -0.15, 0.32, 1, 0.36, -0.30, 0.39, 0,
			0.50, 0, 0.56, 0.18, 0.62, 0.20, 0.68, 0, 1, 0 },
	},

	-- Иконки: список по убыванию предпочтения. Берётся первая, которая есть в клиенте.
	-- Эмблемы фракций Interface\\Timer\\*-Logo — крупные (256 px), их использует сама игра
	-- в отсчёте перед полем боя.
	icons = {
		Horde = { "Interface\\Timer\\Horde-Logo", "Interface\\Icons\\PVPCurrency-Honor-Horde", "Interface\\Icons\\INV_BannerPVP_01" },
		Alliance = { "Interface\\Timer\\Alliance-Logo", "Interface\\Icons\\PVPCurrency-Honor-Alliance", "Interface\\Icons\\INV_BannerPVP_02" },
		Neutral = { "Interface\\Icons\\INV_Misc_QuestionMark", "Interface\\Icons\\INV_Misc_QuestionMark" },
		steps = { "Interface\\Icons\\INV_Boots_05", "Interface\\Icons\\Ability_Rogue_Sprint" },
		rules_pve = { "Interface\\Icons\\INV_Scroll_03", "Interface\\Icons\\INV_Misc_Note_01" },
		rules_pvp = { "Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\INV_Sword_04" },
		rules_hc = { "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", "Interface\\Icons\\Ability_Creature_Cursed_02" },
		rules_rp = { "Interface\\Icons\\INV_Misc_Book_11", "Interface\\Icons\\INV_Misc_Book_09" },
		time = { "Interface\\Icons\\INV_Misc_PocketWatch_01", "Interface\\Icons\\INV_Misc_PocketWatch_02" },
		money = { "Interface\\Icons\\INV_Misc_Coin_02", "Interface\\Icons\\INV_Misc_Coin_01" },
		heart = { "Interface\\Icons\\INV_ValentinesCandy", "Interface\\Icons\\Spell_Holy_Heal" },
		unknown = { "Interface\\Icons\\INV_Misc_QuestionMark", "Interface\\Icons\\INV_Misc_QuestionMark" },
		-- виджеты
		map = { "Interface\\Icons\\INV_Misc_Map_01", "Interface\\Icons\\INV_Misc_Note_01" },
		xp = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Misc_Note_01" },
		gear = { "Interface\\Icons\\INV_Misc_Gear_01", "Interface\\Icons\\Trade_Engineering" },
		bag = { "Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Misc_Bag_10" },
		anvil = { "Interface\\Icons\\Trade_BlackSmithing" },
		wx_snow = { "Interface\\Icons\\Spell_Frost_FrostNova" },
		wx_ash = { "Interface\\Icons\\Spell_Fire_Volcano", "Interface\\Icons\\Spell_Fire_Fire" },
		wx_heat = { "Interface\\Icons\\Spell_Fire_Fire" },
		wx_rain = { "Interface\\Icons\\Spell_Frost_SummonWaterElemental", "Interface\\Icons\\Spell_Frost_FrostBolt02" },
		wx_fog = { "Interface\\Icons\\Spell_Nature_Sleep", "Interface\\Icons\\Spell_Frost_FrostNova" },
		wx_clear = { "Interface\\Icons\\Spell_Holy_HolyBolt", "Interface\\Icons\\Spell_Fire_Fire" },
		wx_night = { "Interface\\Icons\\Spell_Nature_StarFall", "Interface\\Icons\\Spell_Nature_Sleep" },
		ammo = { "Interface\\Icons\\INV_Ammo_Arrow_01", "Interface\\Icons\\INV_Ammo_Bullet_01" },
		hearth = { "Interface\\Icons\\INV_Misc_Rune_01" },
		-- корм питомца
		food_meat = { "Interface\\Icons\\INV_Misc_Food_14", "Interface\\Icons\\INV_Misc_Food_16" },
		food_veggies = { "Interface\\Icons\\INV_Misc_Food_19", "Interface\\Icons\\INV_Misc_Food_08" },
		food_fish = { "Interface\\Icons\\INV_Misc_Fish_02", "Interface\\Icons\\INV_Misc_Fish_01" },
		bone = { "Interface\\Icons\\INV_Misc_Bone_01", "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
	},

	-- Профессии: SkillLineID -> запасная иконка
	professions = {
		[164] = "Interface\\Icons\\Trade_BlackSmithing",
		[165] = "Interface\\Icons\\Trade_LeatherWorking",
		[171] = "Interface\\Icons\\Trade_Alchemy",
		[182] = "Interface\\Icons\\Trade_Herbalism",
		[186] = "Interface\\Icons\\Trade_Mining",
		[197] = "Interface\\Icons\\Trade_Tailoring",
		[202] = "Interface\\Icons\\Trade_Engineering",
		[333] = "Interface\\Icons\\Trade_Engraving",
		[393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
		[755] = "Interface\\Icons\\INV_Misc_Gem_01",
		[773] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
		[129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
		[185] = "Interface\\Icons\\INV_Misc_Food_15",
		[356] = "Interface\\Icons\\Trade_Fishing",
	},
	secondaryProfessions = { [129] = true, [185] = true, [356] = true },
}

-- Настройки по умолчанию (на аккаунт)
ns.defaults = {
	shown = true,
	locked = false,
	scale = 1.0,
	bgAlpha = 0.75,
	hideInCombat = false,
	hidePlayerFrame = true, -- скрывать стандартную рамку игрока (портрет, здоровье, мана)
	minimap = { show = true, angle = 205 }, -- кнопка у миникарты
	pos = false, -- false = позиция по умолчанию
	blocks = { card = true, portrait = true, pulse = true, vitals = true, temp = true, guild = true, pet = true },
	card = { spec = true, rules = true, time = true, money = true, steps = true, profs = true, xp = true },
	ruleset = "auto", -- auto / pve / pvp / hc / rp
	med = { sens = "normal", unit = "C", ecgAnim = true },
	pet = { food = "meat" }, -- meat / veggies / fish
	language = "auto", -- auto / ruRU / enUS
	fx = { levelShine = true, combatBorders = true }, -- блик при новом уровне, красные рамки в бою
	factionBorders = false, -- рамки панели в цвете фракции вместо золотых
	guild = { count = 8, maxRank = 1, onlineOnly = true },
	steps = { length = 0.75 },
}

-- Данные персонажа
ns.charDefaults = {
	steps = 0,
	slots = { top = "pulse", bottom = "temp" }, -- какие виджеты стоят в двух сменных квадратах
	levelSeconds = 0,
	levelInit = false,
	level = 0,
}
