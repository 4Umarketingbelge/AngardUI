-- AngardUI: виджет «Пульс» — число ударов в минуту и бегущая кардиограмма.
-- График строится из линий по опорным точкам формы удара; частота пиков равна пульсу.
local _, ns = ...
local L, C = ns.L, ns.C
local floor = math.floor
local Y = C.yellow
local SHAPE = C.ecg.shape
local FRAME = 1 / C.ecg.fps

local function Build(view)
	local heart = ns.Heart(view, 18)
	heart:SetPoint("TOPLEFT", 7, -7)
	heart:SetVertexColor(Y[1], Y[2], Y[3])

	local number = ns.Font(view, 21, Y[1], Y[2], Y[3], "RIGHT")
	number:SetPoint("TOPRIGHT", -8, -6)

	local unitText = ns.Font(view, 10, Y[1], Y[2], Y[3], "RIGHT")
	unitText:SetPoint("BOTTOMRIGHT", -7, 6)
	unitText:SetText(L.BPM)

	local graph = CreateFrame("Frame", nil, view)
	graph:SetPoint("TOPLEFT", 6, -32)
	graph:SetPoint("BOTTOMRIGHT", -6, 20)

	local lines, used, lastUsed = {}, 0, 0
	local phase = 0 -- сколько ударов «прошло»; дробная часть — положение внутри удара
	local shownBpm = -1

	local function Segment(xa, ya, xb, yb)
		used = used + 1
		local l = lines[used]
		if not l then
			l = graph:CreateLine(nil, "ARTWORK")
			l:SetThickness(1.6)
			l:SetColorTexture(Y[1], Y[2], Y[3], 1)
			lines[used] = l
		end
		l:SetStartPoint("BOTTOMLEFT", graph, xa, ya)
		l:SetEndPoint("BOTTOMLEFT", graph, xb, yb)
		l:Show()
	end

	local function Draw()
		local w, h = graph:GetWidth(), graph:GetHeight()
		if not w or w <= 0 or h <= 0 then return end
		local bpm = ns.med.pulse
		local base, amp = h * 0.24, h * 0.70
		used = 0

		if bpm < 1 then
			Segment(0, base, w, base) -- смерть: прямая линия
		else
			local beats = C.ecg.window * bpm / 60 -- ударов в окне
			local ppb = w / beats -- пикселей на удар
			for k = floor(phase - beats), floor(phase) do
				local x0 = w - (phase - k) * ppb
				for j = 1, #SHAPE - 3, 2 do
					local xa, ya = x0 + SHAPE[j] * ppb, base + SHAPE[j + 1] * amp
					local xb, yb = x0 + SHAPE[j + 2] * ppb, base + SHAPE[j + 3] * amp
					if xb > 0 and xa < w and xb > xa then
						-- обрезка по краям окна
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
				end
			end
		end

		for i = used + 1, lastUsed do lines[i]:Hide() end
		lastUsed = used
	end

	function view:UpdatePulse(force)
		local bpm = floor(ns.med.pulse + 0.5)
		if bpm ~= shownBpm or force then
			shownBpm = bpm
			number:SetText(bpm)
			if force or not ns.db.med.ecgAnim then Draw() end
		end
	end

	-- Анимация: фаза растёт каждый кадр, перерисовка — не чаще ecg.fps.
	local acc = 0
	view:SetScript("OnUpdate", function(_, elapsed)
		if not ns.db or not ns.db.med.ecgAnim then return end
		phase = phase + elapsed * ns.med.pulse / 60
		if phase > 4096 then phase = phase - 4096 end
		acc = acc + elapsed
		if acc < FRAME then return end
		acc = 0
		Draw()
	end)
end

ns:RegisterWidget("pulse", {
	title = L.W_PULSE,
	interval = C.intervals.sim,
	Build = Build,
	Update = function(view, force) view:UpdatePulse(force) end,
})
