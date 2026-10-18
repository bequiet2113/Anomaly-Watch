-- Anomaly Watch — Suite
-- RightShift = menu | J = Anomaly ESP
-- Zrob snapshot na CZYSTEJ mapie (poczatek rundy / Threat: None).
-- Potem zielone podswietlenie = cos do reportu, etykieta = typ z tabletu.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local ENV
pcall(function()
	ENV = getgenv()
end)
if ENV and type(ENV.AnomalySuiteCleanup) == "function" then
	pcall(ENV.AnomalySuiteCleanup)
end

local running = true
local conns = {}
local function track(c)
	table.insert(conns, c)
	return c
end

local char, humanoid, hrp
local function refreshChar()
	char = player.Character
	if not char then
		return false
	end
	humanoid = char:FindFirstChildOfClass("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	Camera = Workspace.CurrentCamera
	return hrp ~= nil
end
refreshChar()

local GREEN = Color3.fromRGB(40, 255, 110)
local GREEN_DIM = Color3.fromRGB(170, 255, 200)

local state = {
	fly = false,
	noclip = false,
	fullbright = false,
	chams = false,
	monster = false,
	fov = false,
	infJump = false,
	noFall = false,
	names = false,
	anomaly = false,
	labels = true,
	speed = 16,
	jump = 50,
}

local originalLighting = {
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows,
	ClockTime = Lighting.ClockTime,
}
local originalFOV = Camera and Camera.FieldOfView or 70

local bv, bg
local input = { fwd = false, back = false, left = false, right = false, up = false, down = false }
local playerHighlights = {}
local nameTags = {}
local monsterHighlights = {}
local uiRefresh = {}

-- ========== ANOMALY ESP STATE ==========
local tracked = {}
local extras = {}
local knownHumanoids = {}
local intruderWatch = {}
local snapped = false
local snapCount = 0
local snapClock = 0
local marks = {}
local lastListSig = ""
local lastThreat = ""
local anomalyItems = {}
local statusOverride
local statusOverrideUntil = 0

local ignoreWords = {
	"case", "screen", "ui", "prompt", "tablet", "gui", "button", "frame",
	"label", "text", "image", "light", "floor", "wall", "ceiling", "roof",
	"terrain", "spawn", "baseplate", "camera", "barrier", "hitbox", "bound",
}

local priorityWords = {
	"carpet", "pool", "ball", "television", "tv", "shoe", "chair", "alarm", "clock",
	"paper", "tire", "soap", "painting", "picture", "mirror", "whiteboard", "list",
	"note", "computer", "tap", "cabinet", "container", "cup", "coke", "cola", "pot",
	"mug", "apple", "mannequin", "duck", "crib", "curtain", "bucket", "washing",
	"machine", "fence", "projector", "monitor", "pillow", "telephone", "phone",
	"poster", "pizza", "urinal", "microwave", "drawer", "door", "fridge", "bed",
	"lamp", "plant", "book", "window", "toilet", "shower", "pan", "sofa", "couch",
	"table", "frame", "photo", "doll", "toy", "vase", "plate", "bottle", "remote",
}

local monsterWords = {
	"intruder", "monster", "entity", "naked", "tall", "figure", "doppel",
	"alternate", "creature", "enemy",
}

local RANK = {
	["Intruder"] = 8,
	["Missing Object"] = 7,
	["Extra Object"] = 6,
	["Distorted Object"] = 5,
	["Moved Object"] = 4,
	["Strange Imagery"] = 3,
	["Strange Light"] = 2,
	["Other"] = 1,
}

local function isOurStuff(obj)
	if not obj then
		return false
	end
	local n = obj.Name
	if n == "AW_Marker" or n == "AW_Anomaly" or n == "AW_Tag" or n == "AW_FlyAtt" then
		return true
	end
	local p = obj.Parent
	while p and p ~= Workspace do
		if p.Name == "AW_Marker" then
			return true
		end
		p = p.Parent
	end
	return false
end

local function playerModelOf(obj)
	local cur = obj
	while cur and cur ~= Workspace do
		if cur:IsA("Model") then
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl.Character == cur then
					return cur
				end
			end
		end
		cur = cur.Parent
	end
	return nil
end

local function humanoidModelOf(obj)
	local cur = obj
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function isPlayerRelated(obj)
	return playerModelOf(obj) ~= nil
end

local function nameHas(name, list)
	for _, w in ipairs(list) do
		if string.find(name, w, 1, true) then
			return true
		end
	end
	return false
end

local function isTrackable(obj)
	if isOurStuff(obj) or isPlayerRelated(obj) then
		return false
	end
	if not obj:IsA("BasePart") then
		return false
	end
	local name = string.lower(obj.Name)
	if nameHas(name, ignoreWords) then
		return false
	end
	local mag = obj.Size.Magnitude
	if mag > 55 or mag < 0.08 then
		return false
	end
	if obj.Anchored == false and mag < 0.4 then
		return false
	end
	return true
end

local function isPriority(name)
	return nameHas(string.lower(name), priorityWords)
end

local function decalSig(obj)
	local t = {}
	for _, c in ipairs(obj:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then
			table.insert(t, c.ClassName .. c.Name .. tostring(c.Texture) .. tostring(c.Color3) .. tostring(c.Transparency))
		elseif c:IsA("SurfaceGui") then
			local texts = { "sg", c.Name, tostring(c.Enabled) }
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					table.insert(texts, d.Text)
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
					table.insert(texts, tostring(d.Image))
				end
			end
			table.insert(t, table.concat(texts, ","))
		end
	end
	table.sort(t)
	return table.concat(t, "|")
end

local function particleSig(obj)
	local t = {}
	for _, c in ipairs(obj:GetChildren()) do
		if c:IsA("ParticleEmitter") or c:IsA("Beam") or c:IsA("Trail") or c:IsA("Fire") or c:IsA("Smoke") or c:IsA("Sparkles") then
			local rate = c:IsA("ParticleEmitter") and c.Rate or 0
			table.insert(t, c.ClassName .. c.Name .. tostring(c.Enabled) .. tostring(math.floor(rate)))
		end
	end
	table.sort(t)
	return table.concat(t, "|")
end

local function colorDistance(a, b)
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
end

local function rotationDelta(cf1, cf2)
	local rx, ry, rz = (cf1:Inverse() * cf2):ToEulerAnglesXYZ()
	return math.abs(rx) + math.abs(ry) + math.abs(rz)
end

local function adornTarget(inst)
	if not inst then
		return inst
	end
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	if model and model ~= Workspace and not isPlayerRelated(model) then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and not isPlayerRelated(model) then
			return model
		end
		local n = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				if n > 35 then
					break
				end
			end
		end
		if n > 0 and n <= 35 then
			return model
		end
	end
	if inst:IsA("Light") then
		local p = inst.Parent
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return inst
end

local function instancePos(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	end
	if inst:IsA("Model") then
		local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		return p and p.Position or nil
	end
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	if inst:IsA("Light") and inst.Parent and inst.Parent:IsA("BasePart") then
		return inst.Parent.Position
	end
	return nil
end

local function better(a, b)
	return (RANK[a] or 0) > (RANK[b] or 0)
end

local function clearMark(key)
	local m = marks[key]
	if not m then
		return
	end
	pcall(function()
		if m.hl then
			m.hl:Destroy()
		end
	end)
	pcall(function()
		if m.gui then
			m.gui:Destroy()
		end
	end)
	pcall(function()
		if m.marker then
			m.marker:Destroy()
		end
	end)
	marks[key] = nil
end

local function clearAllMarks()
	for k in pairs(marks) do
		clearMark(k)
	end
end

local function want(desired, adornee, reason, objectName, pos)
	if not adornee then
		return
	end
	local key = adornee
	local prev = desired[key]
	if prev and not better(reason, prev.reason) then
		return
	end
	desired[key] = {
		adornee = adornee,
		reason = reason,
		name = objectName or adornee.Name,
		pos = pos or instancePos(adornee),
	}
end

local function applyDesired(desired)
	for key, d in pairs(desired) do
		if d.keep then
			continue
		end
		if not d.adornee or not d.adornee.Parent then
			continue
		end
		local existing = marks[key]
		if existing and existing.reason == d.reason and existing.name == d.name and existing.hl and existing.hl.Parent then
			if existing.label then
				existing.label.Text = d.reason .. "\n" .. d.name
			end
			continue
		end
		clearMark(key)
		local hl = Instance.new("Highlight")
		hl.Name = "AW_Anomaly"
		hl.Adornee = d.adornee
		hl.FillColor = GREEN
		hl.OutlineColor = GREEN_DIM
		hl.FillTransparency = 0.38
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = d.adornee

		local gui, label
		if state.labels then
			local host = d.adornee:IsA("BasePart") and d.adornee or d.adornee:FindFirstChildWhichIsA("BasePart", true)
			if host then
				gui = Instance.new("BillboardGui")
				gui.Name = "AW_Tag"
				gui.Adornee = host
				gui.Size = UDim2.fromOffset(180, 46)
				gui.StudsOffset = Vector3.new(0, 3.2, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 500
				gui.Parent = host
				label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundColor3 = Color3.fromRGB(6, 18, 10)
				label.BackgroundTransparency = 0.25
				label.Text = d.reason .. "\n" .. d.name
				label.TextColor3 = GREEN
				label.TextStrokeTransparency = 0.4
				label.Font = Enum.Font.GothamBold
				label.TextSize = 13
				label.Parent = gui
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 6)
				c.Parent = label
			end
		end
		marks[key] = { hl = hl, gui = gui, label = label, reason = d.reason, name = d.name }
	end
end

local function makeMarker(cf, text)
	local mark = Instance.new("Part")
	mark.Name = "AW_Marker"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.Size = Vector3.new(0.7, 0.7, 0.7)
	mark.Material = Enum.Material.Neon
	mark.Color = GREEN
	mark.CFrame = cf
	mark.Parent = Workspace
	local hl = Instance.new("Highlight")
	hl.Name = "AW_Anomaly"
	hl.Adornee = mark
	hl.FillColor = GREEN
	hl.OutlineColor = GREEN_DIM
	hl.FillTransparency = 0.15
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = mark
	local gui = Instance.new("BillboardGui")
	gui.Name = "AW_Tag"
	gui.Adornee = mark
	gui.Size = UDim2.fromOffset(180, 46)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = mark
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(6, 18, 10)
	label.BackgroundTransparency = 0.25
	label.Text = text
	label.TextColor3 = GREEN
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = label
	return mark, hl, gui, label
end

local statusLabel
local rowsFrame

local function refreshAnomalyList()
	if not rowsFrame then
		return
	end
	local sigParts = {}
	for i, it in ipairs(anomalyItems) do
		sigParts[i] = it.reason .. it.name .. tostring(math.floor(it.dist or 0))
	end
	local sig = tostring(snapCount) .. "#" .. table.concat(sigParts, "|")
	if statusLabel then
		if statusOverride and os.clock() < statusOverrideUntil then
			statusLabel.Text = statusOverride
		elseif not snapped then
			statusLabel.Text = "Brak snapshotu — kliknij na czystej mapie"
		else
			statusLabel.Text = string.format("%d do reportu   |   %d obiektow w bazie", #anomalyItems, snapCount)
		end
	end
	if sig == lastListSig then
		return
	end
	lastListSig = sig
	for _, ch in ipairs(rowsFrame:GetChildren()) do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
	if #anomalyItems == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -8, 0, 32)
		empty.BackgroundTransparency = 1
		empty.Text = snapped and "Czysto. Nic do reportu." or "Wlacz ESP i zrob snapshot."
		empty.TextColor3 = Color3.fromRGB(140, 150, 160)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = rowsFrame
		return
	end
	for _, it in ipairs(anomalyItems) do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 28)
		row.BackgroundColor3 = Color3.fromRGB(16, 32, 22)
		row.BackgroundTransparency = 0.15
		row.Text = string.format("  %dm   %s   %s", math.floor(it.dist or 0), it.reason, it.name)
		row.TextColor3 = GREEN
		row.Font = Enum.Font.Gotham
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Parent = rowsFrame
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = row
	end
end

local function takeSnapshot()
	clearAllMarks()
	tracked = {}
	extras = {}
	knownHumanoids = {}
	intruderWatch = {}
	anomalyItems = {}
	lastListSig = ""
	statusOverride = nil
	local n = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if isOurStuff(obj) or isPlayerRelated(obj) then
			continue
		end
		if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
			local pos = instancePos(obj)
			knownHumanoids[obj] = pos or Vector3.zero
			if nameHas(string.lower(obj.Name), monsterWords) then
				intruderWatch[obj] = true
			end
		end
		if obj:IsA("BasePart") and isTrackable(obj) then
			tracked[obj] = {
				cf = obj.CFrame,
				size = obj.Size,
				color = obj.Color,
				transparency = obj.Transparency,
				material = obj.Material,
				decal = decalSig(obj),
				particles = particleSig(obj),
				parent = obj.Parent,
				name = obj.Name,
				priority = isPriority(obj.Name),
			}
			n += 1
		elseif obj:IsA("Light") and not isPlayerRelated(obj) then
			local ln = string.lower(obj.Name)
			if not nameHas(ln, { "gui", "ui" }) then
				tracked[obj] = {
					light = true,
					color = obj.Color,
					brightness = obj.Brightness,
					enabled = obj.Enabled,
					range = obj.Range,
					parent = obj.Parent,
					name = (obj.Parent and obj.Parent.Name or obj.Name),
				}
				n += 1
			end
		end
	end
	snapped = true
	snapCount = n
	snapClock = os.clock()
	refreshAnomalyList()
	return n
end

local function scanAnomalies()
	if not state.anomaly or not snapped then
		if not state.anomaly then
			clearAllMarks()
			anomalyItems = {}
			refreshAnomalyList()
		end
		return
	end

	local desired = {}
	local missingGroups = {}

	for obj, data in pairs(tracked) do
		if data.light then
			if not obj.Parent then
				local host = data.parent
				if host and host.Parent then
					want(desired, adornTarget(host), "Strange Light", data.name, instancePos(host))
				end
			else
				local changed = false
				if colorDistance(obj.Color, data.color) > 0.08 then
					changed = true
				end
				if math.abs(obj.Brightness - data.brightness) > 0.35 then
					changed = true
				end
				if obj.Enabled ~= data.enabled then
					changed = true
				end
				if data.range and math.abs(obj.Range - data.range) > 2 then
					changed = true
				end
				if changed then
					local host = obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent or obj
					want(desired, adornTarget(host), "Strange Light", data.name, instancePos(host))
				end
			end
			continue
		end

		if not obj.Parent then
			local host = data.parent
			if host and host.Parent and not isOurStuff(host) then
				want(desired, adornTarget(host), "Missing Object", data.name, data.cf.Position)
			else
				local gid = data.name .. tostring(math.floor(data.cf.Position.X)) .. ":" .. tostring(math.floor(data.cf.Position.Z))
				missingGroups[gid] = data
			end
			continue
		end

		local reason
		local pri = data.priority
		local posD = (obj.Position - data.cf.Position).Magnitude
		local rotD = rotationDelta(data.cf, obj.CFrame)
		local sizeD = (obj.Size - data.size).Magnitude
		local pThresh = pri and 0.08 or 0.28
		local rThresh = pri and 0.12 or 0.35

		if sizeD > (pri and 0.1 or 0.32) then
			reason = "Distorted Object"
		elseif data.transparency < 0.45 and obj.Transparency >= 0.9 then
			reason = "Missing Object"
		elseif data.transparency >= 0.9 and obj.Transparency < 0.45 then
			reason = "Extra Object"
		elseif posD > pThresh or rotD > rThresh then
			reason = "Moved Object"
		elseif decalSig(obj) ~= data.decal then
			reason = "Strange Imagery"
		elseif colorDistance(obj.Color, data.color) > (pri and 0.05 or 0.12) then
			reason = "Strange Imagery"
		elseif obj.Material ~= data.material then
			reason = "Strange Imagery"
		elseif particleSig(obj) ~= data.particles then
			reason = "Other"
		elseif math.abs(obj.Transparency - data.transparency) > 0.2 then
			reason = "Other"
		end

		if reason then
			local target = adornTarget(obj)
			local hum = humanoidModelOf(obj)
			if hum and not playerModelOf(hum) then
				want(desired, hum, "Intruder", hum.Name, instancePos(hum))
			else
				want(desired, target, reason, target.Name, instancePos(target) or obj.Position)
			end
		end

		if obj:GetAttribute("Anomaly") == true or obj:GetAttribute("Reportable") == true then
			local target = adornTarget(obj)
			want(desired, target, "Other", target.Name, instancePos(target))
		end
	end

	local extraAlive = 0
	for obj in pairs(extras) do
		if obj.Parent and not tracked[obj] and not isOurStuff(obj) and not isPlayerRelated(obj) then
			extraAlive += 1
		else
			extras[obj] = nil
		end
	end
	local suppressExtras = extraAlive > 80
	if suppressExtras then
		extras = {}
		statusOverride = "Mapa sie przebudowala — zrob snapshot jeszcze raz"
		statusOverrideUntil = os.clock() + 6
	end

	if not suppressExtras then
		for obj in pairs(extras) do
			if not obj.Parent then
				extras[obj] = nil
				continue
			end
			local hum = humanoidModelOf(obj)
			if hum and not playerModelOf(hum) then
				intruderWatch[hum] = true
				continue
			end
			if tracked[obj] then
				continue
			end
			local target = adornTarget(obj)
			if target and not isPlayerRelated(target) then
				want(desired, target, "Extra Object", target.Name, instancePos(target) or instancePos(obj))
			end
		end
	end

	for model in pairs(intruderWatch) do
		if not model.Parent or playerModelOf(model) or isOurStuff(model) then
			intruderWatch[model] = nil
			continue
		end
		if Camera and model:IsDescendantOf(Camera) then
			intruderWatch[model] = nil
			continue
		end
		want(desired, model, "Intruder", model.Name, instancePos(model))
	end

	for model, origin in pairs(knownHumanoids) do
		if model.Parent and not playerModelOf(model) and not intruderWatch[model] then
			local pos = instancePos(model)
			if pos and origin and (pos - origin).Magnitude > 6 then
				want(desired, model, "Intruder", model.Name, pos)
			end
		elseif not model.Parent then
			knownHumanoids[model] = nil
		end
	end

	for gid, data in pairs(missingGroups) do
		local key = "missing:" .. gid
		local text = "Missing Object\n" .. data.name
		local existing = marks[key]
		if not (existing and existing.marker and existing.marker.Parent) then
			clearMark(key)
			local marker, hl, gui, label = makeMarker(data.cf, text)
			marks[key] = { hl = hl, gui = gui, label = label, marker = marker, reason = "Missing Object", name = data.name }
		end
		desired[key] = {
			adornee = marks[key].marker,
			reason = "Missing Object",
			name = data.name,
			pos = data.cf.Position,
			keep = true,
		}
	end

	local visualDesired = {}
	for key, d in pairs(desired) do
		if not d.keep then
			visualDesired[key] = d
		end
	end
	applyDesired(visualDesired)

	for key in pairs(marks) do
		local d = desired[key]
		local gone = d and not d.keep and d.adornee and not d.adornee.Parent
		if not d or gone then
			clearMark(key)
		end
	end

	local items = {}
	local seen = {}
	for _, d in pairs(desired) do
		local id = d.reason .. "|" .. d.name .. "|" .. tostring(d.adornee)
		if not seen[id] then
			seen[id] = true
			local pos = d.pos
			local dist = 0
			if hrp and pos then
				dist = (hrp.Position - pos).Magnitude
			end
			table.insert(items, { reason = d.reason, name = d.name, dist = dist })
		end
	end
	table.sort(items, function(a, b)
		return (a.dist or 0) < (b.dist or 0)
	end)
	if #items > 40 then
		local cut = {}
		for i = 1, 40 do
			cut[i] = items[i]
		end
		items = cut
	end
	anomalyItems = items
	refreshAnomalyList()
end

local function setAnomaly(on)
	state.anomaly = on
	if on then
		scanAnomalies()
	else
		clearAllMarks()
		anomalyItems = {}
		refreshAnomalyList()
	end
	if uiRefresh.anomaly then
		uiRefresh.anomaly()
	end
end

local function readThreat()
	local found
	for _, gui in ipairs(playerGui:GetDescendants()) do
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			local text = gui.Text
			if text and string.find(string.lower(text), "threat", 1, true) then
				found = string.match(text, "[Tt]hreat%s*[Ll]evel:?%s*(%a+)") or string.match(text, "(%a+)%s*$")
				if found then
					break
				end
			end
		end
	end
	return found
end

-- ========== MOVEMENT ==========
local function setNoclip(on)
	if not char then
		return
	end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = not on
		end
	end
end

local function setNoclipState(on)
	state.noclip = on
	setNoclip(on)
	if uiRefresh.noclip then
		uiRefresh.noclip()
	end
end

local function destroyFly()
	if bv then
		pcall(function()
			bv:Destroy()
		end)
		bv = nil
	end
	if bg then
		pcall(function()
			bg:Destroy()
		end)
		bg = nil
	end
	if hrp then
		local att = hrp:FindFirstChild("AW_FlyAtt")
		if att then
			att:Destroy()
		end
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
		end)
	end
end

local function createFly()
	if not refreshChar() then
		return
	end
	destroyFly()
	bv = Instance.new("BodyVelocity")
	bv.Name = "AW_FlyVel"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.P = 2500
	bv.Velocity = Vector3.zero
	bv.Parent = hrp
	bg = Instance.new("BodyGyro")
	bg.Name = "AW_FlyGyro"
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bg.P = 4000
	bg.Parent = hrp
end

local function getMove()
	local mv = Vector3.zero
	Camera = Workspace.CurrentCamera
	if not Camera then
		return mv
	end
	local look, right = Camera.CFrame.LookVector, Camera.CFrame.RightVector
	if input.fwd then
		mv += Vector3.new(look.X, 0, look.Z)
	end
	if input.back then
		mv -= Vector3.new(look.X, 0, look.Z)
	end
	if input.right then
		mv += Vector3.new(right.X, 0, right.Z)
	end
	if input.left then
		mv -= Vector3.new(right.X, 0, right.Z)
	end
	return mv.Magnitude > 0 and mv.Unit or mv
end

local function setFlyState(on)
	state.fly = on
	if on then
		if not refreshChar() then
			state.fly = false
			return
		end
		if humanoid then
			humanoid.PlatformStand = true
		end
		createFly()
	else
		destroyFly()
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
	if uiRefresh.fly then
		uiRefresh.fly()
	end
end

local function setFullbright(on)
	state.fullbright = on
	if on then
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.FogEnd = 1e5
		Lighting.GlobalShadows = false
		Lighting.ClockTime = 14
	else
		Lighting.Brightness = originalLighting.Brightness
		Lighting.Ambient = originalLighting.Ambient
		Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
		Lighting.FogEnd = originalLighting.FogEnd
		Lighting.GlobalShadows = originalLighting.GlobalShadows
		Lighting.ClockTime = originalLighting.ClockTime
	end
	if uiRefresh.fullbright then
		uiRefresh.fullbright()
	end
end

local function setFOV(on)
	state.fov = on
	Camera = Workspace.CurrentCamera
	if Camera then
		Camera.FieldOfView = on and 120 or originalFOV
	end
	if uiRefresh.fov then
		uiRefresh.fov()
	end
end

local function applySpeedJump()
	if not humanoid or not humanoid.Parent then
		return
	end
	humanoid.WalkSpeed = state.speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = state.jump
end

-- ========== PLAYER ESP ==========
local function createChams(plr)
	if plr == player then
		return
	end
	local c = plr.Character
	if not c then
		return
	end
	if playerHighlights[plr] then
		playerHighlights[plr]:Destroy()
	end
	local hl = Instance.new("Highlight")
	hl.Name = "Chams"
	hl.Adornee = c
	hl.FillColor = Color3.fromRGB(0, 170, 255)
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = c
	playerHighlights[plr] = hl
end

local function clearChams()
	for _, hl in pairs(playerHighlights) do
		if hl then
			hl:Destroy()
		end
	end
	playerHighlights = {}
end

local function setChams(on)
	state.chams = on
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			createChams(p)
		end
	else
		clearChams()
	end
	if uiRefresh.chams then
		uiRefresh.chams()
	end
end

local function createName(plr)
	if plr == player then
		return
	end
	local c = plr.Character
	if not c then
		return
	end
	local head = c:FindFirstChild("Head")
	if not head then
		return
	end
	if nameTags[plr] then
		nameTags[plr]:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameESP"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(140, 28)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = plr.DisplayName ~= "" and plr.DisplayName or plr.Name
	lbl.TextColor3 = Color3.fromRGB(0, 255, 180)
	lbl.TextStrokeTransparency = 0.35
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.Parent = bb
	nameTags[plr] = bb
end

local function clearNames()
	for _, t in pairs(nameTags) do
		if t then
			t:Destroy()
		end
	end
	nameTags = {}
end

local function setNames(on)
	state.names = on
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			createName(p)
		end
	else
		clearNames()
	end
	if uiRefresh.names then
		uiRefresh.names()
	end
end

local function isMonster(model)
	if not model:IsA("Model") or isOurStuff(model) or playerModelOf(model) then
		return false
	end
	local n = string.lower(model.Name)
	if nameHas(n, monsterWords) then
		return true
	end
	if model:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(model) then
		return true
	end
	return false
end

local function clearMonsters()
	for _, hl in pairs(monsterHighlights) do
		if hl then
			hl:Destroy()
		end
	end
	monsterHighlights = {}
end

local function scanMonsters()
	local alive = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and isMonster(obj) then
			alive[obj] = true
			if not monsterHighlights[obj] or not monsterHighlights[obj].Parent then
				local hl = Instance.new("Highlight")
				hl.Name = "MonsterESP"
				hl.Adornee = obj
				hl.FillColor = Color3.fromRGB(255, 40, 40)
				hl.OutlineColor = Color3.fromRGB(255, 200, 0)
				hl.FillTransparency = 0.4
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = obj
				monsterHighlights[obj] = hl
			end
		end
	end
	for m, hl in pairs(monsterHighlights) do
		if not alive[m] then
			if hl then
				hl:Destroy()
			end
			monsterHighlights[m] = nil
		end
	end
end

local function setMonster(on)
	state.monster = on
	if on then
		scanMonsters()
	else
		clearMonsters()
	end
	if uiRefresh.monster then
		uiRefresh.monster()
	end
end

local function hookPlayer(plr)
	if plr == player then
		return
	end
	track(plr.CharacterAdded:Connect(function()
		task.wait(0.35)
		if not running then
			return
		end
		if state.chams then
			createChams(plr)
		end
		if state.names then
			createName(plr)
		end
	end))
end

for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
track(Players.PlayerAdded:Connect(hookPlayer))
track(Players.PlayerRemoving:Connect(function(plr)
	if playerHighlights[plr] then
		playerHighlights[plr]:Destroy()
		playerHighlights[plr] = nil
	end
	if nameTags[plr] then
		nameTags[plr]:Destroy()
		nameTags[plr] = nil
	end
end))

-- ========== CLEAN OLD ESP ==========
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("Highlight") and (d.Name == "Chams" or d.Name == "MonsterESP" or d.Name == "AW_Anomaly") then
		d:Destroy()
	elseif d.Name == "NameESP" or d.Name == "AW_Tag" or d.Name == "AW_Marker" or d.Name == "AW_FlyVel" or d.Name == "AW_FlyGyro" then
		d:Destroy()
	end
end
local oldGui = playerGui:FindFirstChild("AnomalySuite")
if oldGui then
	oldGui:Destroy()
end

-- ========== GUI ==========
local screen = Instance.new("ScreenGui")
screen.Name = "AnomalySuite"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(340, 480)
main.Position = UDim2.new(0, 24, 0.5, -240)
main.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screen
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(46, 62, 54)
mainStroke.Thickness = 1.4
mainStroke.Parent = main

local title = Instance.new("Frame")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 54)
title.BackgroundColor3 = Color3.fromRGB(18, 28, 24)
title.BorderSizePixel = 0
title.Active = true
title.Parent = main
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 16)
titleFill.Position = UDim2.new(0, 0, 1, -16)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 28, 24)
titleFill.BorderSizePixel = 0
titleFill.Parent = title

local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 3, 0, 28)
accent.Position = UDim2.fromOffset(12, 13)
accent.BackgroundColor3 = GREEN
accent.BorderSizePixel = 0
accent.Parent = title
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.fromOffset(24, 6)
titleText.Size = UDim2.new(1, -90, 0, 22)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 15
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextColor3 = Color3.fromRGB(236, 255, 244)
titleText.Text = "ANOMALY SUITE"
titleText.Parent = title

local subText = Instance.new("TextLabel")
subText.BackgroundTransparency = 1
subText.Position = UDim2.fromOffset(24, 28)
subText.Size = UDim2.new(1, -90, 0, 16)
subText.Font = Enum.Font.Gotham
subText.TextSize = 11
subText.TextXAlignment = Enum.TextXAlignment.Left
subText.TextColor3 = Color3.fromRGB(120, 160, 140)
subText.Text = "RightShift menu   ·   J anomaly ESP"
subText.Parent = title

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -36, 0, 14)
closeBtn.BackgroundColor3 = Color3.fromRGB(36, 24, 24)
closeBtn.Text = "x"
closeBtn.TextColor3 = Color3.fromRGB(230, 140, 140)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = false
closeBtn.Parent = title
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
	main.Visible = false
end)

local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = inp.Position
		startPos = main.Position
	end
end)
title.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 30)
tabBar.Position = UDim2.fromOffset(8, 62)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local pages = {}
local tabButtons = {}
local activeTab = "Move"

local function showTab(name)
	activeTab = name
	for id, page in pairs(pages) do
		page.Visible = id == name
	end
	for id, btn in pairs(tabButtons) do
		local on = id == name
		btn.BackgroundColor3 = on and Color3.fromRGB(28, 64, 44) or Color3.fromRGB(24, 26, 32)
		btn.TextColor3 = on and GREEN or Color3.fromRGB(170, 176, 186)
	end
end

local function makeTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / 3, -4, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(170, 176, 186)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.Parent = tabBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = btn
	btn.MouseButton1Click:Connect(function()
		showTab(name)
	end)
	tabButtons[name] = btn

	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.new(1, -16, 1, -108)
	page.Position = UDim2.fromOffset(8, 98)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = GREEN
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.Visible = false
	page.Parent = main
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 6)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = page
	lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.fromOffset(0, lay.AbsoluteContentSize.Y + 12)
	end)
	pages[name] = page
	return page
end

local pageMove = makeTab("Move")
local pageVis = makeTab("Visual")
local pageAnom = makeTab("Anomaly")
showTab("Anomaly")

local function makeToggle(parent, name, id, getter, setter)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(226, 230, 236)
	lbl.Text = name
	lbl.Parent = btn

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(42, 20)
	pill.Position = UDim2.new(1, -52, 0.5, -10)
	pill.BackgroundColor3 = Color3.fromRGB(48, 32, 34)
	pill.BorderSizePixel = 0
	pill.Parent = btn
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(1, 0)
	pc.Parent = pill
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.fromRGB(210, 210, 214)
	knob.BorderSizePixel = 0
	knob.Parent = pill
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(1, 0)
	kc.Parent = knob

	local function refresh()
		local on = getter()
		pill.BackgroundColor3 = on and Color3.fromRGB(28, 110, 62) or Color3.fromRGB(48, 32, 34)
		knob.Position = on and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)
		knob.BackgroundColor3 = on and GREEN or Color3.fromRGB(180, 180, 186)
		btn.BackgroundColor3 = on and Color3.fromRGB(20, 36, 28) or Color3.fromRGB(24, 26, 32)
	end
	btn.MouseButton1Click:Connect(function()
		setter(not getter())
		refresh()
	end)
	uiRefresh[id] = refresh
	refresh()
end

local function makeSlider(parent, name, minV, maxV, getter, setter)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 52)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(12, 6)
	lbl.Size = UDim2.new(1, -20, 0, 16)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(220, 224, 230)
	lbl.Text = name .. "   " .. tostring(getter())
	lbl.Parent = frame

	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.Position = UDim2.fromOffset(12, 32)
	bar.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((getter() - minV) / (maxV - minV), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 190, 150)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill

	local drag = false
	local function setFromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local val = math.floor(minV + rel * (maxV - minV) + 0.5)
		setter(val)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		lbl.Text = name .. "   " .. tostring(val)
		applySpeedJump()
	end
	bar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = true
			setFromX(inp.Position.X)
		end
	end)
	track(UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = false
		end
	end))
	track(UserInputService.InputChanged:Connect(function(inp)
		if not drag then
			return
		end
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			setFromX(inp.Position.X)
		end
	end))
end

local function makeButton(parent, text, color, fn)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(232, 255, 240)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.AutoButtonColor = true
	btn.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn
	btn.MouseButton1Click:Connect(fn)
	return btn
end

local function makeHint(parent, text, tall)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, tall or 44)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(130, 145, 140)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Parent = parent
	return lbl
end

makeToggle(pageMove, "Fly   [F]", "fly", function()
	return state.fly
end, setFlyState)
makeToggle(pageMove, "Noclip   [N]", "noclip", function()
	return state.noclip
end, setNoclipState)
makeToggle(pageMove, "Infinite Jump", "infJump", function()
	return state.infJump
end, function(v)
	state.infJump = v
end)
makeToggle(pageMove, "No Fall", "noFall", function()
	return state.noFall
end, function(v)
	state.noFall = v
end)
makeSlider(pageMove, "WalkSpeed", 16, 120, function()
	return state.speed
end, function(v)
	state.speed = v
end)
makeSlider(pageMove, "JumpPower", 50, 220, function()
	return state.jump
end, function(v)
	state.jump = v
end)
makeHint(pageMove, "Fly: WASD, Space gora, LeftCtrl dol. Menu nie blokuje sterowania.", 32)

makeToggle(pageVis, "Fullbright   [G]", "fullbright", function()
	return state.fullbright
end, setFullbright)
makeToggle(pageVis, "FOV 120   [V]", "fov", function()
	return state.fov
end, setFOV)
makeToggle(pageVis, "Player Chams   [B]", "chams", function()
	return state.chams
end, setChams)
makeToggle(pageVis, "Name ESP", "names", function()
	return state.names
end, setNames)
makeToggle(pageVis, "Monster ESP   [M]", "monster", function()
	return state.monster
end, setMonster)
makeHint(pageVis, "Monster ESP jest czerwony (intruder / humanoid). Anomaly ESP na zakladce obok jest zielony i mowi co wpisac w tablet.", 48)

makeToggle(pageAnom, "Anomaly ESP   [J]", "anomaly", function()
	return state.anomaly
end, setAnomaly)
makeToggle(pageAnom, "Etykiety typu", "labels", function()
	return state.labels
end, function(v)
	state.labels = v
	if state.anomaly then
		clearAllMarks()
		scanAnomalies()
	end
end)

makeButton(pageAnom, "Snapshot czystej mapy", Color3.fromRGB(24, 92, 58), function()
	local n = takeSnapshot()
	if statusLabel then
		statusLabel.Text = string.format("Snapshot: %d obiektow. Czekam na zmiany.", n)
	end
end)

makeHint(pageAnom, "Zielone = do reportu. Etykieta to typ z tabletu: Moved Object, Extra Object, Missing Object, Strange Imagery, Strange Light, Distorted Object, Other, Intruder. Snapshot rob na poczatku rundy, zanim anomalie wejda. Przy Threat: None baseline robi sie sam.", 78)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Brak snapshotu — kliknij na czystej mapie"
statusLabel.TextColor3 = GREEN
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = pageAnom

rowsFrame = Instance.new("Frame")
rowsFrame.Name = "Rows"
rowsFrame.Size = UDim2.new(1, 0, 0, 0)
rowsFrame.AutomaticSize = Enum.AutomaticSize.Y
rowsFrame.BackgroundTransparency = 1
rowsFrame.Parent = pageAnom
local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 4)
rowsLayout.Parent = rowsFrame

refreshAnomalyList()

-- ========== INPUT ==========
track(UserInputService.InputChanged:Connect(function(inp)
	if not dragging then
		return
	end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = inp.Position - dragStart
	main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end))

track(UserInputService.InputBegan:Connect(function(io, gp)
	local k = io.KeyCode
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	if not gp and not typing then
		if k == Enum.KeyCode.RightShift then
			main.Visible = not main.Visible
		elseif k == Enum.KeyCode.F then
			setFlyState(not state.fly)
		elseif k == Enum.KeyCode.N then
			setNoclipState(not state.noclip)
		elseif k == Enum.KeyCode.G then
			setFullbright(not state.fullbright)
		elseif k == Enum.KeyCode.B then
			setChams(not state.chams)
		elseif k == Enum.KeyCode.M then
			setMonster(not state.monster)
		elseif k == Enum.KeyCode.V then
			setFOV(not state.fov)
		elseif k == Enum.KeyCode.J then
			setAnomaly(not state.anomaly)
		end
	end
	if typing then
		return
	end
	if k == Enum.KeyCode.W then
		input.fwd = true
	elseif k == Enum.KeyCode.S then
		input.back = true
	elseif k == Enum.KeyCode.A then
		input.left = true
	elseif k == Enum.KeyCode.D then
		input.right = true
	elseif k == Enum.KeyCode.Space then
		input.up = true
	elseif k == Enum.KeyCode.LeftControl then
		input.down = true
	end
end))

track(UserInputService.InputEnded:Connect(function(io)
	local k = io.KeyCode
	if k == Enum.KeyCode.W then
		input.fwd = false
	elseif k == Enum.KeyCode.S then
		input.back = false
	elseif k == Enum.KeyCode.A then
		input.left = false
	elseif k == Enum.KeyCode.D then
		input.right = false
	elseif k == Enum.KeyCode.Space then
		input.up = false
	elseif k == Enum.KeyCode.LeftControl then
		input.down = false
	end
end))

track(UserInputService.JumpRequest:Connect(function()
	if state.infJump and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

track(RunService.Stepped:Connect(function()
	if state.noclip and char then
		setNoclip(true)
	end
end))

track(RunService.Heartbeat:Connect(function()
	if not running then
		return
	end
	Camera = Workspace.CurrentCamera
	refreshChar()
	if state.fly and hrp and bv and bg then
		local flat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
		if flat.Magnitude > 0.05 then
			bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
		end
		local m = getMove() * 80
		local vy = 0
		if input.up then
			vy = 60
		end
		if input.down then
			vy = -60
		end
		bv.Velocity = Vector3.new(m.X, vy, m.Z)
	end
	if humanoid then
		if humanoid.WalkSpeed ~= state.speed then
			humanoid.WalkSpeed = state.speed
		end
		if humanoid.JumpPower ~= state.jump then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = state.jump
		end
		if state.noFall then
			local st = humanoid:GetState()
			if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end
	end
	if state.fullbright then
		if Lighting.ClockTime ~= 14 or Lighting.GlobalShadows ~= false then
			Lighting.Brightness = 2
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.FogEnd = 1e5
			Lighting.GlobalShadows = false
			Lighting.ClockTime = 14
		end
	end
	if state.fov and Camera and Camera.FieldOfView ~= 120 then
		Camera.FieldOfView = 120
	end
end))

track(Workspace.DescendantAdded:Connect(function(obj)
	if not running or not state.anomaly or not snapped then
		return
	end
	task.defer(function()
		if not running or not obj.Parent then
			return
		end
		if isOurStuff(obj) or isPlayerRelated(obj) then
			return
		end
		if obj:IsA("Humanoid") then
			local model = obj.Parent
			if model and model:IsA("Model") and not playerModelOf(model) and not knownHumanoids[model] then
				if not (Camera and model:IsDescendantOf(Camera)) then
					intruderWatch[model] = true
				end
			end
			return
		end
		if obj:IsA("BasePart") and isTrackable(obj) and not tracked[obj] then
			local hum = humanoidModelOf(obj)
			if hum and not playerModelOf(hum) and not knownHumanoids[hum] then
				intruderWatch[hum] = true
				return
			end
			extras[obj] = obj.Parent
		elseif obj:IsA("Model") then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			if hum and not playerModelOf(obj) and not knownHumanoids[obj] then
				intruderWatch[obj] = true
				return
			end
			for _, d in ipairs(obj:GetDescendants()) do
				if d:IsA("BasePart") and isTrackable(d) and not tracked[d] then
					extras[d] = obj
				end
			end
		elseif obj:IsA("Light") and not tracked[obj] then
			extras[obj] = obj.Parent
		elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("ParticleEmitter") or obj:IsA("SurfaceGui") then
			local host = obj.Parent
			if host and host:IsA("BasePart") and not isPlayerRelated(host) and not tracked[host] then
				extras[host] = host.Parent
			end
		end
	end)
end))

track(player.CharacterAdded:Connect(function(c)
	char = c
	task.wait(0.35)
	if not running then
		return
	end
	refreshChar()
	applySpeedJump()
	if state.fly then
		setFlyState(true)
	end
	if state.noclip then
		setNoclip(true)
	end
	if state.chams then
		for _, p in ipairs(Players:GetPlayers()) do
			createChams(p)
		end
	end
	if state.names then
		for _, p in ipairs(Players:GetPlayers()) do
			createName(p)
		end
	end
end))

track(player.CharacterRemoving:Connect(function()
	destroyFly()
end))

task.spawn(function()
	local monsterAcc = 0
	while running do
		if state.anomaly then
			scanAnomalies()
		end
		monsterAcc += 0.65
		if monsterAcc >= 2 then
			monsterAcc = 0
			if state.monster then
				scanMonsters()
			end
			local threat = readThreat()
			if threat and string.lower(threat) == "none" and lastThreat ~= "" and string.lower(lastThreat) ~= "none" then
				if os.clock() - snapClock > 8 then
					takeSnapshot()
				end
			end
			if threat then
				lastThreat = threat
			end
		end
		task.wait(0.65)
	end
end)

local function cleanup()
	running = false
	state.fly = false
	state.noclip = false
	state.anomaly = false
	destroyFly()
	setNoclip(false)
	clearAllMarks()
	clearChams()
	clearNames()
	clearMonsters()
	setFullbright(false)
	if Camera then
		Camera.FieldOfView = originalFOV
	end
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	if screen then
		screen:Destroy()
	end
end

if ENV then
	ENV.AnomalySuiteCleanup = cleanup
end

print("[Anomaly Suite] Menu: RightShift | Anomaly ESP: J | Snapshot na czystej mapie")