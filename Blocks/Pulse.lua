-- AngardUI: виджет «Пульс» — число ударов в минуту и бегущая кардиограмма.
-- Как на мониторе: лента идёт с постоянной скоростью, а удары появляются с частотой пульса,
-- так что при 60 уд/мин зубцы редкие, при 160 — частые. У каждого удара свой интервал
-- (небольшая естественная неровность) и своя высота; сердечко вздрагивает на каждом ударе,
-- а линия при высоком пульсе желтеет к оранжевому и красному.
local _, ns = ...
local L, C = ns.L, ns.C
local floor, min, max, exp, random = math.floor, math.min, math.max, math.exp, math.random
local Y = C.yellow
local E = C.ecg
local SHAPE = E.shape
local FRAME = 1 / E.fps

local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- цвет по пульсу: жёлтый в покое, оранжевый при нагрузке, красный на пределе
local function PulseColor(bpm)
	local k = clamp01((bpm - E.hotFrom) / (E.hotTo - E.hotFrom))
	local hot = E.hot
	return Y[1] + (hot[1] - Y[1]) * k, Y[2] + (hot[2] - Y[2]) * k, Y[3] + (hot[3] - Y[3]) * k
end

local function Build(view)
	local HEART = 18
	local heart = ns.Heart(view, HEART)
	heart:SetPoint("CENTER", view, "TOPLEFT", 7 + HEART / 2, -7 - HEART / 2)

	local number = ns.Font(view, 21, Y[1], Y[2], Y[3], "RIGHT")
	number:SetPoint("TOPRIGHT", -8, -6)

	local unitText = ns.Font(view, 10, Y[1], Y[2], Y[3], "RIGHT")
	unitText:SetPoint("BOTTOMRIGHT", -7, 6)
	unitText:SetText(L.BPM)

	local graph = CreateFrame("Frame", nil, view)
	graph:SetPoint("TOPLEFT", 6, -32)
	graph:SetPoint("BOTTOMRIGHT", -6, 20)

	local lines, used, lastUsed = {}, 0, 0
	local cr, cg, cb = Y[1], Y[2], Y[3]
	local shownBpm = -1

	-- лента: удары {t = начало, dur = длина интервала, amp = высота}
	local now = 0
	local beats = {}
	local nextBeat = 0
	local lastBeatAt = -10

	local function Segment(xa, ya, xb, yb)
		used = used + 1
		local l = lines[used]
		if not l then
			l = graph:CreateLine(nil, "ARTWORK")
			l:SetThickness(1.6)
			l:SetColorTexture(cr, cg, cb, 1)
			lines[used] = l
		end
		l:SetStartPoint("BOTTOMLEFT", graph, xa, ya)
		l:SetEndPoint("BOTTOMLEFT", graph, xb, yb)
		l:Show()
	end

	-- отрезок с обрезкой по краям окна
	local function Clipped(xa, ya, xb, yb, w)
		if xb <= 0 or xa >= w or xb <= xa then return end
		if xa < 0 then
			ya = ya + (yb - ya) * (-xa) / (xb - xa)
			xa = 0
		end
		if xb > w then
			yb = ya + (yb - ya) * (w - xa) / (xb - xa)
			xb = w
		end
		Segment(xa, ya, xb, yb)
	end

	local function SetColor(r, g, b)
		if r == cr and g == cg and b == cb then return end
		cr, cg, cb = r, g, b
		for i = 1, #lines do lines[i]:SetColorTexture(r, g, b, 1) end
		number:SetTextColor(r, g, b)
		unitText:SetTextColor(r, g, b)
	end

	-- новый удар: интервал по текущему пульсу с небольшим разбросом, высота растёт с пульсом
	local function AddBeat(t, bpm)
		local dur = 60 / bpm * (1 + (random() * 2 - 1) * E.variability)
		local amp = E.ampRest + (E.ampMax - E.ampRest) * clamp01((bpm - 60) / 110)
		amp = amp * (1 + (random() * 2 - 1) * E.ampJitter)
		beats[#beats + 1] = { t = t, dur = dur, amp = amp }
		return dur
	end

	-- без анимации: ровная лента ударов по текущему пульсу, заканчивается «сейчас»
	local function FillStatic(bpm)
		wipe(beats)
		if bpm < 1 then return end
		local dur = 60 / bpm
		local t = now - dur * floor(E.window / dur + 2)
		while t < now do
			AddBeat(t, bpm)
			t = t + beats[#beats].dur
		end
		nextBeat = t
	end

	local function Draw()
		local w, h = graph:GetWidth(), graph:GetHeight()
		if not w or w <= 0 or h <= 0 then return end
		local base, fullAmp = h * 0.24, h * 0.70
		local pps = w / E.window -- пикселей в секунду
		used = 0

		local covered = 0 -- до какого x лента уже нарисована
		for i = 1, #beats do
			local b = beats[i]
			local x0 = w - (now - b.t) * pps
			if x0 > covered then
				Clipped(covered, base, x0, base, w) -- пауза между ударами (например, после смерти)
			end
			-- комплекс P-QRS-T занимает не больше E.active секунд, остальное — ровная линия
			local active = min(b.dur, E.active)
			local amp = fullAmp * b.amp
			for j = 1, #SHAPE - 3, 2 do
				local ta = SHAPE[j] * active
				local tb = (j + 3 == #SHAPE) and b.dur or SHAPE[j + 2] * active
				Clipped(x0 + ta * pps, base + SHAPE[j + 1] * amp, x0 + tb * pps, base + SHAPE[j + 3] * amp, w)
			end
			covered = max(covered, x0 + b.dur * pps)
		end
		if covered < w then
			Clipped(max(covered, 0), base, w, base, w) -- сердце стоит: прямая линия
		end

		for i = used + 1, lastUsed do lines[i]:Hide() end
		lastUsed = used
	end

	function view:UpdatePulse(force)
		local pulse = ns.med.pulse
		local bpm = floor(pulse + 0.5)
		SetColor(PulseColor(pulse))
		if bpm ~= shownBpm or force then
			shownBpm = bpm
			number:SetText(bpm)
			if force or not ns.db.med.ecgAnim then
				if not ns.db.med.ecgAnim then FillStatic(pulse) end
				Draw()
			end
		end
	end

	-- Анимация: лента сдвигается каждый кадр, перерисовка — не чаще E.fps.
	local acc = 0
	view:SetScript("OnUpdate", function(_, elapsed)
		if not ns.db or not ns.db.med.ecgAnim then return end
		now = now + elapsed
		local pulse = ns.med.pulse

		-- новые удары; после остановки сердца их нет, и лента выпрямляется
		if pulse >= 1 then
			if nextBeat < now - E.window then nextBeat = now end -- после долгой паузы
			while nextBeat <= now do
				lastBeatAt = nextBeat
				nextBeat = nextBeat + AddBeat(nextBeat, pulse)
			end
		end
		-- ушедшие за левый край
		while beats[1] and now - beats[1].t - beats[1].dur > E.window do
			table.remove(beats, 1)
		end

		-- сердечко вздрагивает в момент зубца R
		local age = now - lastBeatAt - E.active * 0.32
		local k = (age >= 0) and (1 + E.heartKick * exp(-age * 14)) or 1
		heart:SetSize(HEART * k, HEART * k)

		acc = acc + elapsed
		if acc < FRAME then return end
		acc = 0
		Draw()
	end)
end

ns:RegisterWidget("pulse", {
	titleKey = "W_PULSE",
	interval = C.intervals.sim,
	usesSim = true,
	Build = Build,
	Update = function(view, force) view:UpdatePulse(force) end,
	Tooltip = function(tt) ns.PulseTooltip(tt) end,
})
