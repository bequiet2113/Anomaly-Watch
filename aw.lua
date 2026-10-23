local api = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

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
function api.track(c)
	table.insert(conns, c)
	return c
end

local char, humanoid, hrp
function api.refreshChar()
	char = player.Character
	if not char then
		return false
	end
	humanoid = char:FindFirstChildOfClass("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	Camera = Workspace.CurrentCamera
	return hrp ~= nil
end
api.refreshChar()

local GREEN = Color3.fromRGB(40, 255, 110)
local GREEN_DIM = Color3.fromRGB(170, 255, 200)
local PINK = Color3.fromRGB(255, 70, 150)

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
	autoSnap = true,
	autoReport = false,
	reportGlance = true,
	autoFix = true,
	stalk = false,
	deleteClick = false,
	pairFix = true,
	pairRadius = 22,
	moveScale = 100,
	labelDist = 500,
	fillTrans = 38,
	onlyPriority = false,
	customIgnore = "",
	repMoved = true,
	repExtra = true,
	repMissing = true,
	repImagery = true,
	repLight = true,
	repDistorted = true,
	repOther = true,
	repIntruder = true,
	speed = 16,
	jump = 50,
	flySpeed = 80,
	flyUp = 60,
	hardVis = false,
	tracers = true,
	boxes = true,
	skeletons = true,
	rainbow = true,
	hardPlayers = true,
	hardAnoms = true,
	hardMonsters = true,
	tracerWidth = 8,
	boxThick = 5,
	rainbowSpeed = 45,
	ignoreAnomaly = false,
	circleBait = false,
	steerAnomaly = false,
	anomalySpeed = 18,
	circleRadius = 16,
	orbitSpeed = 14,
	fleeDist = 30,
	stopDist = 3,
	spread = 7,
	waypointLoop = true,
	reportHold = 24,
	reportTries = 4,
	reportStand = 6,
	reportFov = 40,
	reportCamDist = 22,
	reportTabletWait = 32,
	reportWarm = 8,
	reportReturn = 25,
	reportPrompt = true,
	reportVim = true,
	reportSignals = true,
	reportNoclip = true,
	posThresh = 28,
	rotThresh = 35,
	colorThresh = 12,
	sizeThresh = 32,
	stretchThresh = 145,
	transThresh = 20,
	lightBright = 35,
	lightRange = 20,
	confirmNeed = 2,
	maxList = 40,
	priPos = 8,
	priRot = 12,
	priColor = 5,
	priSize = 10,
	missingTrans = 90,
	reflThresh = 28,
	doorNear = 16,
	intruderMove = 6,
	extraFlood = 80,
	autoReportWait = 24,
	threatRefresh = 8,
}

local binds = {
	menu = Enum.KeyCode.RightShift,
	fly = Enum.KeyCode.F,
	noclip = Enum.KeyCode.N,
	fullbright = Enum.KeyCode.G,
	chams = Enum.KeyCode.B,
	monster = Enum.KeyCode.M,
	fov = Enum.KeyCode.V,
	esp = Enum.KeyCode.J,
	snap = Enum.KeyCode.K,
	report = Enum.KeyCode.T,
	tablet = Enum.KeyCode.R,
	del = Enum.KeyCode.One,
	hard = Enum.KeyCode.H,
	point = Enum.KeyCode.Two,
	circle = Enum.KeyCode.Three,
	ignore = Enum.KeyCode.Four,
	steer = Enum.KeyCode.Five,
	way = Enum.KeyCode.Six,
	clearWay = Enum.KeyCode.Zero,
}

local savedBodyCf
local savedCamType, savedCamCf, savedCamSub, savedCamFov
local snapUntil = 0
local snapItem
local snapStand
local snapLook
local reportedIds = {}
local scanning = false
local controlPoint
local controlAngle = 0
local monsterHolds = {}
local waypoints = {}
local waypointIndex = 1
local visBeams = {}
local skelBeams = {}
local tracerOrigin
local originAtt
local pointMarker
local pointLabel
local captureBind
local logLines = {}
local logLabel
local statusLabel
local rowsFrame
local wayFrame
local reportAnomaly
local hookTablet
local confirmIds = {}
local scanGen = 0
local reportBusy = false
local pinnedItem
local hookedBtns = {}
local uiRefresh = {}

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

local tracked = {}
local extras = {}
local knownHumanoids = {}
local intruderWatch = {}
local snapped = false
local snapCount = 0
local snapClock = 0
local marks = {}
local lastListSig = ""
local lastThreatNorm = ""
local currentThreat = ""
local baselineLocked = false
local customIgnoreList = {}
local anomalyItems = {}
local statusOverride
local statusOverrideUntil = 0
local stalkModels = {}
local nextStalkScan = 0
local hardMonsters = {}
local nextHardScan = 0

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
	"alternate", "creature", "enemy", "anomaly", "skinwalker", "mimic",
}

local ourNames = {
	AW_Marker = true,
	AW_Anomaly = true,
	AW_Tag = true,
	AW_FlyAtt = true,
	AW_ControlPoint = true,
	AW_TraceOrigin = true,
	AW_Tracer = true,
	AW_Box = true,
	AW_Hard = true,
	AW_VisAtt = true,
	AW_Skel = true,
	AW_Way = true,
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

local TYPE_NAMES = {
	"distorted object",
	"strange imagery",
	"strange light",
	"missing object",
	"extra object",
	"moved object",
	"intruder",
	"other",
}

local KEY_NAMES = {
	[Enum.KeyCode.RightShift] = "RShift",
	[Enum.KeyCode.LeftShift] = "LShift",
	[Enum.KeyCode.LeftControl] = "LCtrl",
	[Enum.KeyCode.RightControl] = "RCtrl",
	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5",
	[Enum.KeyCode.Six] = "6",
	[Enum.KeyCode.Zero] = "0",
}

function api.keyName(code)
	if typeof(code) ~= "EnumItem" then
		return "?"
	end
	return KEY_NAMES[code] or code.Name
end

function api.logStatus(msg, seconds)
	statusOverride = msg
	statusOverrideUntil = os.clock() + (seconds or 3.2)
	table.insert(logLines, 1, msg)
	while #logLines > 12 do
		table.remove(logLines)
	end
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
	end
	if statusLabel then
		statusLabel.Text = msg
	end
end

function api.isOurStuff(obj)
	if not obj then
		return false
	end
	local n = obj.Name
	if ourNames[n] then
		return true
	end
	local p = obj.Parent
	while p and p ~= Workspace do
		if ourNames[p.Name] then
			return true
		end
		p = p.Parent
	end
	return false
end

function api.playerModelOf(obj)
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

function api.humanoidModelOf(obj)
	local cur = obj
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

function api.isPlayerRelated(obj)
	return api.playerModelOf(obj) ~= nil
end

function api.nameHas(name, list)
	for _, w in ipairs(list) do
		if string.find(name, w, 1, true) then
			return true
		end
	end
	return false
end

function api.isTrackable(obj)
	if api.isOurStuff(obj) or api.isPlayerRelated(obj) then
		return false
	end
	if not obj:IsA("BasePart") then
		return false
	end
	local name = string.lower(obj.Name)
	if api.nameHas(name, ignoreWords) or api.nameHas(name, customIgnoreList) then
		return false
	end
	local parentName = obj.Parent and string.lower(obj.Parent.Name) or ""
	if parentName ~= "" and api.nameHas(parentName, customIgnoreList) then
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

function api.isPriority(name)
	return api.nameHas(string.lower(name), priorityWords)
end

function api.decalSig(obj)
	local t = {}
	if obj:IsA("MeshPart") then
		t[#t + 1] = "mesh:" .. tostring(obj.MeshId) .. ":" .. tostring(obj.TextureID)
	end
	for _, c in ipairs(obj:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then
			local extra = ""
			if c:IsA("Texture") then
				extra = string.format(":%.1f:%.1f", c.OffsetStudsU or 0, c.OffsetStudsV or 0)
			end
			t[#t + 1] = c.ClassName .. c.Name .. tostring(c.Face) .. tostring(c.Texture) .. tostring(c.Color3) .. string.format("%.2f", c.Transparency) .. extra
		elseif c:IsA("SurfaceAppearance") then
			t[#t + 1] = "sa:" .. tostring(c.ColorMap) .. ":" .. tostring(c.NormalMap) .. ":" .. tostring(c.Color)
		elseif c:IsA("SpecialMesh") then
			t[#t + 1] = "sm:" .. tostring(c.MeshId) .. ":" .. tostring(c.TextureId)
		elseif c:IsA("SurfaceGui") then
			local texts = { "sg", c.Name, tostring(c.Enabled) }
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
					texts[#texts + 1] = (d.Text or "") .. tostring(d.TextColor3)
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
					texts[#texts + 1] = tostring(d.Image) .. tostring(d.ImageColor3)
				end
			end
			t[#t + 1] = table.concat(texts, ",")
		end
	end
	table.sort(t)
	return table.concat(t, "|")
end

function api.particleSig(obj)
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

function api.colorDistance(a, b)
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
end

function api.rotationDelta(cf1, cf2)
	local rx, ry, rz = (cf1:Inverse() * cf2):ToEulerAnglesXYZ()
	return math.abs(rx) + math.abs(ry) + math.abs(rz)
end

function api.adornTarget(inst)
	if not inst then
		return inst
	end
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	if model and model ~= Workspace and not api.isPlayerRelated(model) then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and not api.isPlayerRelated(model) then
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

function api.instancePos(inst)
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

function api.better(a, b)
	return (RANK[a] or 0) > (RANK[b] or 0)
end

function api.clearMark(key)
	local m = marks[key]
	if not m then
		return
	end
	pcall(function()
		if m.hl then m.hl:Destroy() end
	end)
	pcall(function()
		if m.gui then m.gui:Destroy() end
	end)
	pcall(function()
		if m.marker then m.marker:Destroy() end
	end)
	marks[key] = nil
end

function api.clearAllMarks()
	for k in pairs(marks) do
		api.clearMark(k)
	end
end

local REASON_ON = {
	["Moved Object"] = "repMoved",
	["Extra Object"] = "repExtra",
	["Missing Object"] = "repMissing",
	["Strange Imagery"] = "repImagery",
	["Strange Light"] = "repLight",
	["Distorted Object"] = "repDistorted",
	["Other"] = "repOther",
	["Intruder"] = "repIntruder",
}

function api.want(desired, adornee, reason, objectName, pos)
	if not adornee or not reason then
		return
	end
	local flag = REASON_ON[reason]
	if flag and state[flag] == false then
		return
	end
	if state.onlyPriority and reason ~= "Intruder" then
		local n = objectName or adornee.Name or ""
		if not api.isPriority(n) then
			return
		end
	end
	local key = adornee
	local prev = desired[key]
	if prev and not api.better(reason, prev.reason) then
		return
	end
	desired[key] = {
		adornee = adornee,
		reason = reason,
		name = objectName or adornee.Name,
		pos = pos or api.instancePos(adornee),
	}
end

function api.applyDesired(desired)
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
		api.clearMark(key)
		local hl = Instance.new("Highlight")
		hl.Name = "AW_Anomaly"
		hl.Adornee = d.adornee
		hl.FillColor = GREEN
		hl.OutlineColor = GREEN_DIM
		hl.FillTransparency = math.clamp((state.fillTrans or 38) / 100, 0.05, 0.9)
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
				gui.MaxDistance = state.labelDist or 500
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

function api.makeMarker(cf, text)
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

function api.refreshAnomalyList()
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
			statusLabel.Text = "Brak snapshotu - K na czystej mapie"
		else
			statusLabel.Text = string.format("%d do reportu   |   %d w bazie", #anomalyItems, snapCount)
		end
	end
	if sig == lastListSig then
		return
	end
	lastListSig = sig
	for _, ch in ipairs(rowsFrame:GetChildren()) do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") then
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
	local shown = math.min(#anomalyItems, state.maxList or 40)
	for i = 1, shown do
		local it = anomalyItems[i]
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 28)
		row.BackgroundColor3 = Color3.fromRGB(16, 32, 22)
		row.BackgroundTransparency = 0.15
		row.Text = string.format("  %dm   %s   %s", math.floor(it.dist or 0), it.reason, it.name)
		row.TextColor3 = GREEN
		row.Font = Enum.Font.Gotham
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.AutoButtonColor = true
		row.Parent = rowsFrame
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = row
		row.MouseButton1Click:Connect(function()
			if reportAnomaly then
				reportAnomaly(it)
			end
		end)
	end
end

function api.motionFlags(name, parent)
	local blob = string.lower((name or "") .. " " .. (parent and parent.Name or ""))
	local function has(w)
		return string.find(blob, w, 1, true) ~= nil
	end
	local ambient = has("wiatrak") or has("windmill") or has("ventilat") or has("propeller") or has("turbine") or has("clock") or has("zegar") or has("rotor") or has("spinner") or has("pendulum") or has("fanblade") or has("ceilingfan")
	if not ambient then
		ambient = has("fan") and not has("fancy")
	end
	local doorish = has("door") or has("drzwi") or has("drawer") or has("szuflada") or has("fridge") or has("lodowka") or has("cabinet") or has("szafa") or has("closet")
	local clockish = has("clock") or has("zegar") or has("timer") or has("stopwatch")
	return ambient, doorish, clockish
end

function api.axisStretch(a, b)
	local function ratio(x, y)
		local lo = math.max(math.min(x, y), 0.05)
		return math.max(x, y) / lo
	end
	return math.max(ratio(a.X, b.X), ratio(a.Y, b.Y), ratio(a.Z, b.Z))
end

function api.takeSnapshot()
	api.clearAllMarks()
	tracked = {}
	extras = {}
	knownHumanoids = {}
	intruderWatch = {}
	anomalyItems = {}
	lastListSig = ""
	confirmIds = {}
	reportedIds = {}
	statusOverride = nil
	local n = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if api.isOurStuff(obj) or api.isPlayerRelated(obj) then
			continue
		end
		if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
			local pos = api.instancePos(obj)
			knownHumanoids[obj] = pos or Vector3.zero
			if api.nameHas(string.lower(obj.Name), monsterWords) then
				intruderWatch[obj] = true
			end
		end
		if obj:IsA("BasePart") and api.isTrackable(obj) then
			tracked[obj] = {
				cf = obj.CFrame,
				size = obj.Size,
				color = obj.Color,
				transparency = obj.Transparency,
				material = obj.Material,
				decal = api.decalSig(obj),
				particles = api.particleSig(obj),
				parent = obj.Parent,
				name = obj.Name,
				priority = api.isPriority(obj.Name),
				mesh = obj:IsA("MeshPart") and obj.MeshId or "",
				tex = obj:IsA("MeshPart") and obj.TextureID or "",
				refl = obj.Reflectance or 0,
				childN = #obj:GetChildren(),
				hasFx = false,
				forceImg = false,
				slice = n % 4,
				swingCap = math.max(16, obj.Size.Magnitude * 1.5),
			}
			local amb, door, clock = api.motionFlags(obj.Name, obj.Parent)
			tracked[obj].ambient = amb
			tracked[obj].doorish = door
			tracked[obj].clockish = clock
			tracked[obj].hasFx = tracked[obj].particles ~= ""
			local look = table.concat({
				tostring(obj.Color),
				tostring(obj.Material),
				string.format("%.2f", obj.Transparency),
				tracked[obj].mesh,
				tracked[obj].tex,
				string.format("%.2f", tracked[obj].refl),
				tracked[obj].decal,
			}, "~")
			if clock then
				look = string.gsub(look, "%d", "#")
			end
			tracked[obj].look = look
			n += 1
		elseif obj:IsA("Light") and not api.isPlayerRelated(obj) then
			local ln = string.lower(obj.Name)
			if not api.nameHas(ln, { "gui", "ui" }) then
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
	api.refreshAnomalyList()
	return n
end

function api.propKey(name, parent)
	local n = string.lower(name or "")
	if (n == "part" or n == "meshpart" or n == "union" or n == "handle") and parent then
		return string.lower(parent.Name)
	end
	return n
end

function api.buildPropSets()
	local baseline, live = {}, {}
	for obj, data in pairs(tracked) do
		if data.light or not data.cf or not data.size or not data.name then
			continue
		end
		local kn = api.propKey(data.name, data.parent)
		baseline[#baseline + 1] = { name = kn, size = data.size, pos = data.cf.Position }
		if obj.Parent and obj:IsA("BasePart") then
			live[#live + 1] = { name = api.propKey(obj.Name, obj.Parent), size = obj.Size, pos = obj.Position }
		end
	end
	for obj in pairs(extras) do
		if typeof(obj) == "Instance" and obj.Parent and obj:IsA("BasePart") and not tracked[obj] and not api.isOurStuff(obj) and not api.isPlayerRelated(obj) then
			live[#live + 1] = { name = api.propKey(obj.Name, obj.Parent), size = obj.Size, pos = obj.Position }
		end
	end
	return baseline, live
end

function api.bucketize(list)
	local map = {}
	for _, it in ipairs(list) do
		local b = map[it.name]
		if not b then
			b = {}
			map[it.name] = b
		end
		b[#b + 1] = it
	end
	return map
end

function api.countBucket(map, name, size, pos, radius)
	local bucket = map[name]
	if not bucket then
		return 0
	end
	local n = 0
	for _, it in ipairs(bucket) do
		if (size - it.size).Magnitude <= math.max(0.35, size.Magnitude * 0.22) and (it.pos - pos).Magnitude <= radius then
			n += 1
		end
	end
	return n
end

function api.sameShape(a, b)
	return (a - b).Magnitude <= math.max(0.35, a.Magnitude * 0.22)
end

function api.liveLook(obj)
	return table.concat({
		tostring(obj.Color),
		tostring(obj.Material),
		string.format("%.2f", obj.Transparency),
		obj:IsA("MeshPart") and (obj.MeshId or "") or "",
		obj:IsA("MeshPart") and (obj.TextureID or "") or "",
		string.format("%.2f", obj.Reflectance or 0),
		api.decalSig(obj),
	}, "~")
end

function api.looksDifferent(data, obj)
	if not data or not data.look or not obj or not obj:IsA("BasePart") then
		return false
	end
	local now = api.liveLook(obj)
	if data.clockish then
		now = string.gsub(now, "%d", "#")
	end
	return now ~= data.look
end

function api.nearestBaseline(obj, radius)
	if not obj:IsA("BasePart") then
		return nil
	end
	local kn = api.propKey(obj.Name, obj.Parent)
	local best, bestD
	for _, data in pairs(tracked) do
		if data.look and data.cf and data.size and not data.light then
			if api.propKey(data.name, data.parent) == kn and api.sameShape(obj.Size, data.size) then
				local d = (obj.Position - data.cf.Position).Magnitude
				if d <= radius and (not bestD or d < bestD) then
					best, bestD = data, d
				end
			end
		end
	end
	return best
end

function api.nearestLiveTwin(kn, size, pos, radius)
	local best, bestD
	local function take(obj)
		if typeof(obj) ~= "Instance" or not obj.Parent or not obj:IsA("BasePart") then
			return
		end
		if api.isOurStuff(obj) or api.isPlayerRelated(obj) then
			return
		end
		if api.propKey(obj.Name, obj.Parent) ~= kn or not api.sameShape(obj.Size, size) then
			return
		end
		local d = (obj.Position - pos).Magnitude
		if d <= radius and (not bestD or d < bestD) then
			best, bestD = obj, d
		end
	end
	for obj, data in pairs(tracked) do
		if not data.light then
			take(obj)
		end
	end
	for obj in pairs(extras) do
		take(obj)
	end
	return best
end

function api.adornExtra(inst)
	if not inst then
		return inst
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and model ~= Workspace then
		for _, d in ipairs(model:GetDescendants()) do
			if tracked[d] then
				return inst
			end
		end
	end
	return api.adornTarget(inst)
end

function api.scanAnomalies()
	if scanning then
		return
	end
	if not state.anomaly or not snapped then
		if not state.anomaly then
			api.clearAllMarks()
			anomalyItems = {}
			api.refreshAnomalyList()
		end
		return
	end
	scanning = true
	local desired = {}
	local missingGroups = {}
	local propBase, propLive = api.buildPropSets()
	local baseMap, liveMap = api.bucketize(propBase), api.bucketize(propLive)
	local pairR = state.pairRadius or 22
	scanGen += 1
	local budget = 0
	local posBase = (state.posThresh or 28) / 100
	local rotBase = (state.rotThresh or 35) / 100
	local colBase = (state.colorThresh or 12) / 100
	local sizeBase = (state.sizeThresh or 32) / 100
	local stretchNeed = (state.stretchThresh or 145) / 100
	local transNeed = (state.transThresh or 20) / 100
	local priPos = (state.priPos or 8) / 100
	local priRot = (state.priRot or 12) / 100
	local priCol = (state.priColor or 5) / 100
	local priSize = (state.priSize or 10) / 100
	local missT = (state.missingTrans or 90) / 100
	local reflNeed = (state.reflThresh or 28) / 100
	for obj, data in pairs(tracked) do
		budget += 1
		if budget % 400 == 0 then
			task.wait()
		end
		if data.light then
			if not obj.Parent then
				local host = data.parent
				if host and host.Parent then
					api.want(desired, api.adornTarget(host), "Strange Light", data.name, api.instancePos(host))
				end
			else
				local colorChanged = api.colorDistance(obj.Color, data.color) > 0.08
				local brightChanged = math.abs(obj.Brightness - data.brightness) > ((state.lightBright or 35) / 100)
				local rangeChanged = data.range and math.abs(obj.Range - data.range) > ((state.lightRange or 20) / 10)
				local enabledChanged = obj.Enabled ~= data.enabled
				if enabledChanged and not colorChanged and not brightChanged then
					data.lightStreak = (data.lightStreak or 0) + 1
				else
					data.lightStreak = 0
				end
				local changed = colorChanged or brightChanged or rangeChanged or (enabledChanged and (data.lightStreak or 0) >= 2)
				if changed then
					local host = obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent or obj
					api.want(desired, api.adornTarget(host), "Strange Light", data.name, api.instancePos(host))
				end
			end
			continue
		end
		if not obj.Parent then
			local kn = api.propKey(data.name, data.parent)
			local filled = false
			if state.pairFix and data.size and data.cf then
				local b = api.countBucket(baseMap, kn, data.size, data.cf.Position, pairR)
				local l = api.countBucket(liveMap, kn, data.size, data.cf.Position, pairR)
				filled = b > 0 and l >= b
			end
			if filled then
				local twin = api.nearestLiveTwin(kn, data.size, data.cf.Position, pairR)
				if twin and api.looksDifferent(data, twin) then
					local target = api.adornTarget(twin)
					api.want(desired, target, "Strange Imagery", target.Name, api.instancePos(target) or twin.Position)
				end
			else
				local gid = kn .. tostring(math.floor(data.cf.Position.X)) .. ":" .. tostring(math.floor(data.cf.Position.Z))
				missingGroups[gid] = data
			end
			continue
		end
		local reason
		local pri = data.priority
		local posD = (obj.Position - data.cf.Position).Magnitude
		local rotD = api.rotationDelta(data.cf, obj.CFrame)
		local sizeD = (obj.Size - data.size).Magnitude
		local scale = (state.moveScale or 100) / 100
		local pThresh = (pri and priPos or posBase) * scale
		local rThresh = (pri and priRot or rotBase) * scale
		local ambient = data.ambient
		local doorish = data.doorish
		local swingCap = data.swingCap or math.max(16, data.size.Magnitude * 1.5)
		local deviant = posD > pThresh or rotD > rThresh
		if doorish and deviant and not data.sawMove and hrp and sizeD < 0.25 and posD < swingCap then
			local nearNow = (obj.Position - hrp.Position).Magnitude < (state.doorNear or 16)
			local nearOld = (data.cf.Position - hrp.Position).Magnitude < (state.doorNear or 16)
			if nearNow or nearOld then
				data.playerDoor = true
			end
		end
		if deviant then
			data.sawMove = true
		else
			data.sawMove = false
			data.playerDoor = false
		end
		local suppressMove = sizeD < 0.25 and posD < swingCap and (ambient or data.playerDoor)
		local stretch = api.axisStretch(obj.Size, data.size)
		local kids = #obj:GetChildren()
		local img = false
		if obj:IsA("MeshPart") and ((obj.MeshId or "") ~= (data.mesh or "") or (obj.TextureID or "") ~= (data.tex or "")) then
			img = true
		elseif math.abs((obj.Reflectance or 0) - (data.refl or 0)) > reflNeed then
			img = true
		end
		local oldKids = data.childN or -1
		local due = data.forceImg or kids ~= oldKids or (scanGen % 4 == (data.slice or 0))
		if not img and due then
			local sig = api.decalSig(obj)
			local baseSig = data.decal or ""
			if data.clockish then
				sig = string.gsub(sig, "%d", "#")
				baseSig = string.gsub(baseSig, "%d", "#")
			end
			if sig ~= baseSig then
				img = true
			end
			data.childN = kids
			data.forceImg = false
		end
		local fxChanged = false
		if data.hasFx or kids ~= oldKids then
			local ps = api.particleSig(obj)
			if ps ~= (data.particles or "") then
				fxChanged = true
				data.hasFx = ps ~= ""
			end
		end
		if sizeD > (pri and priSize or sizeBase) or stretch >= stretchNeed then
			reason = "Distorted Object"
		elseif data.transparency < 0.45 and obj.Transparency >= missT then
			reason = "Missing Object"
		elseif data.transparency >= missT and obj.Transparency < 0.45 then
			reason = "Extra Object"
		elseif deviant and not suppressMove then
			reason = "Moved Object"
		elseif img then
			reason = "Strange Imagery"
		elseif api.colorDistance(obj.Color, data.color) > (pri and priCol or colBase) then
			reason = "Strange Imagery"
		elseif obj.Material ~= data.material then
			reason = "Strange Imagery"
		elseif fxChanged and not suppressMove then
			reason = "Other"
		elseif math.abs(obj.Transparency - data.transparency) > transNeed and not (suppressMove and ambient) then
			reason = "Other"
		end
		if reason then
			local target = api.adornTarget(obj)
			local hum = api.humanoidModelOf(obj)
			if hum and not api.playerModelOf(hum) then
				api.want(desired, hum, "Intruder", hum.Name, api.instancePos(hum))
			else
				api.want(desired, target, reason, target.Name, api.instancePos(target) or obj.Position)
			end
		end
		if obj:GetAttribute("Anomaly") == true or obj:GetAttribute("Reportable") == true then
			local target = api.adornTarget(obj)
			api.want(desired, target, "Other", target.Name, api.instancePos(target))
		end
	end
	local extraAlive = 0
	for obj in pairs(extras) do
		if obj.Parent and not tracked[obj] and not api.isOurStuff(obj) and not api.isPlayerRelated(obj) then
			extraAlive += 1
		else
			extras[obj] = nil
		end
	end
	local suppressExtras = extraAlive > (state.extraFlood or 80)
	if suppressExtras then
		extras = {}
		api.logStatus("Mapa sie przebudowala - zrob snapshot jeszcze raz", 6)
	end
	if not suppressExtras then
		for obj in pairs(extras) do
			if not obj.Parent then
				extras[obj] = nil
				continue
			end
			local hum = api.humanoidModelOf(obj)
			if hum and not api.playerModelOf(hum) then
				intruderWatch[hum] = true
				continue
			end
			if tracked[obj] then
				continue
			end
			local skipTwin = false
			if obj:IsA("BasePart") and state.pairFix then
				local kn = api.propKey(obj.Name, obj.Parent)
				local b = api.countBucket(baseMap, kn, obj.Size, obj.Position, pairR)
				local l = api.countBucket(liveMap, kn, obj.Size, obj.Position, pairR)
				skipTwin = l <= b
			end
			if skipTwin and obj:IsA("BasePart") then
				local baseData = api.nearestBaseline(obj, pairR)
				if baseData and api.looksDifferent(baseData, obj) then
					local target = api.adornExtra(obj)
					if target and not api.isPlayerRelated(target) then
						api.want(desired, target, "Strange Imagery", target.Name, api.instancePos(target) or obj.Position)
					end
				end
			elseif not skipTwin then
				local target = api.adornExtra(obj)
				if target and not api.isPlayerRelated(target) then
					api.want(desired, target, "Extra Object", target.Name, api.instancePos(target) or api.instancePos(obj))
				end
			end
		end
	end
	for model in pairs(intruderWatch) do
		if not model.Parent or api.playerModelOf(model) or api.isOurStuff(model) then
			intruderWatch[model] = nil
			continue
		end
		if Camera and model:IsDescendantOf(Camera) then
			intruderWatch[model] = nil
			continue
		end
		api.want(desired, model, "Intruder", model.Name, api.instancePos(model))
	end
	for model, origin in pairs(knownHumanoids) do
		if model.Parent and not api.playerModelOf(model) and not intruderWatch[model] then
			local pos = api.instancePos(model)
			if pos and origin and (pos - origin).Magnitude > (state.intruderMove or 6) then
				api.want(desired, model, "Intruder", model.Name, pos)
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
			api.clearMark(key)
			local marker, hl, gui, label = api.makeMarker(data.cf, text)
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
	api.applyDesired(visualDesired)
	for key in pairs(marks) do
		local d = desired[key]
		local gone = d and not d.keep and d.adornee and not d.adornee.Parent
		if not d or gone then
			api.clearMark(key)
		end
	end
	local items = {}
	local seen = {}
	local nextConfirm = {}
	local need = math.max(1, state.confirmNeed or 2)
	for _, d in pairs(desired) do
		local pos = d.pos
		local id = d.reason .. "|" .. (d.name or "") .. "|" .. tostring(d.adornee)
		if not seen[id] then
			seen[id] = true
			local streak = (confirmIds[id] or 0) + 1
			nextConfirm[id] = streak
			local stable = streak >= need or d.reason == "Intruder"
			if stable then
				local dist = 0
				if hrp and pos then
					dist = (hrp.Position - pos).Magnitude
				end
				table.insert(items, {
					reason = d.reason,
					name = d.name,
					dist = dist,
					pos = pos,
					adornee = d.adornee,
				})
			end
		end
	end
	confirmIds = nextConfirm
	table.sort(items, function(a, b)
		return (a.dist or 0) < (b.dist or 0)
	end)
	local cap = state.maxList or 40
	if #items > cap then
		local cut = {}
		for i = 1, cap do
			cut[i] = items[i]
		end
		items = cut
	end
	anomalyItems = items
	api.refreshAnomalyList()
	scanning = false
end

function api.setAnomaly(on)
	state.anomaly = on
	if on then
		api.scanAnomalies()
	else
		api.clearAllMarks()
		anomalyItems = {}
		api.refreshAnomalyList()
	end
	if uiRefresh.anomaly then
		uiRefresh.anomaly()
	end
end

function api.isCleanThreat(norm)
	return norm == "none" or norm == "safe" or norm == "clear" or norm == "brak" or norm == "peaceful" or norm == "calm"
end

function api.readThreat()
	local found
	for _, gui in ipairs(playerGui:GetDescendants()) do
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			if gui:FindFirstAncestor("AnomalySuite") then
				continue
			end
			local text = gui.Text
			if text then
				local low = string.lower(text)
				if string.find(low, "threat", 1, true) then
					found = string.match(low, "threat%s*level%s*:%s*(%a+)")
						or string.match(low, "threat%s*:%s*(%a+)")
						or string.match(low, "threat%s*level%s+(%a+)")
					if found and #found >= 3 then
						break
					end
					found = nil
				end
			end
		end
	end
	return found
end

function api.prettyLevel(s)
	if not s or s == "" then
		return s
	end
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

function api.handleThreat(level)
	local norm = string.lower(level)
	if norm == lastThreatNorm then
		return
	end
	local prevNorm = lastThreatNorm
	local prevPretty = currentThreat
	lastThreatNorm = norm
	currentThreat = api.prettyLevel(norm)
	if not state.autoSnap then
		api.refreshAnomalyList()
		return
	end
	if api.isCleanThreat(norm) then
		baselineLocked = false
		local n = api.takeSnapshot()
		api.logStatus(string.format("Auto snapshot (%s) - %d obiektow", currentThreat, n), 4)
		return
	end
	if prevNorm == "" or api.isCleanThreat(prevNorm) then
		baselineLocked = true
		if not snapped then
			local n = api.takeSnapshot()
			baselineLocked = true
			api.logStatus(string.format("Threat: %s - snapshot %d moze miec anomalie", currentThreat, n), 5)
		else
			api.logStatus("Threat: " .. currentThreat .. " - baseline zamrozony", 5)
		end
		return
	end
	api.logStatus("Threat: " .. (prevPretty ~= "" and prevPretty or prevNorm) .. " -> " .. currentThreat, 4)
end

function api.setNoclip(on)
	if not char then
		return
	end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = not on
		end
	end
end

function api.setNoclipState(on)
	state.noclip = on
	api.setNoclip(on)
	if uiRefresh.noclip then
		uiRefresh.noclip()
	end
end

function api.destroyFly()
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
		pcall(function()
			hrp.Anchored = false
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	if humanoid and humanoid.Parent and not snapItem then
		pcall(function()
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end)
	end
end

function api.createFly()
	if not api.refreshChar() then
		return
	end
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
	end
	pcall(function()
		hrp.Anchored = true
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end

function api.getMove()
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

function api.setFlyState(on)
	state.fly = on
	if on then
		api.createFly()
	else
		api.destroyFly()
	end
	if uiRefresh.fly then
		uiRefresh.fly()
	end
end

function api.setFullbright(on)
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

function api.setFOV(on)
	state.fov = on
	Camera = Workspace.CurrentCamera
	if Camera then
		Camera.FieldOfView = on and 120 or originalFOV
	end
	if uiRefresh.fov then
		uiRefresh.fov()
	end
end

function api.applySpeedJump()
	if not humanoid or not humanoid.Parent then
		return
	end
	humanoid.WalkSpeed = state.speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = state.jump
end

function api.createChams(plr)
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

function api.clearChams()
	for _, hl in pairs(playerHighlights) do
		if hl then
			hl:Destroy()
		end
	end
	playerHighlights = {}
end

function api.setChams(on)
	state.chams = on
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			api.createChams(p)
		end
	else
		api.clearChams()
	end
	if uiRefresh.chams then
		uiRefresh.chams()
	end
end

function api.createName(plr)
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

function api.clearNames()
	for _, t in pairs(nameTags) do
		if t then
			t:Destroy()
		end
	end
	nameTags = {}
end

function api.setNames(on)
	state.names = on
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			api.createName(p)
		end
	else
		api.clearNames()
	end
	if uiRefresh.names then
		uiRefresh.names()
	end
end

function api.isMonster(model)
	if not model:IsA("Model") or api.isOurStuff(model) or api.playerModelOf(model) then
		return false
	end
	local n = string.lower(model.Name)
	if api.nameHas(n, monsterWords) then
		return true
	end
	if model:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(model) then
		return true
	end
	return false
end

function api.clearMonsters()
	for _, hl in pairs(monsterHighlights) do
		if hl then
			hl:Destroy()
		end
	end
	monsterHighlights = {}
end

function api.scanMonsters()
	local alive = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and api.isMonster(obj) then
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

function api.setMonster(on)
	state.monster = on
	if on then
		api.scanMonsters()
	else
		api.clearMonsters()
	end
	if uiRefresh.monster then
		uiRefresh.monster()
	end
end

function api.hookPlayer(plr)
	if plr == player then
		return
	end
	api.track(plr.CharacterAdded:Connect(function()
		task.wait(0.35)
		if not running then
			return
		end
		if state.chams then
			api.createChams(plr)
		end
		if state.names then
			api.createName(plr)
		end
	end))
end

for _, p in ipairs(Players:GetPlayers()) do
	api.hookPlayer(p)
end
api.track(Players.PlayerAdded:Connect(api.hookPlayer))
api.track(Players.PlayerRemoving:Connect(function(plr)
	if playerHighlights[plr] then
		playerHighlights[plr]:Destroy()
		playerHighlights[plr] = nil
	end
	if nameTags[plr] then
		nameTags[plr]:Destroy()
		nameTags[plr] = nil
	end
end))

function api.hardColor(shift)
	if not state.rainbow then
		return GREEN
	end
	local hue = ((os.clock() * ((state.rainbowSpeed or 45) / 100)) + (shift or 0)) % 1
	return Color3.fromHSV(hue, 1, 1)
end

function api.ensureTracerRig()
	if tracerOrigin and tracerOrigin.Parent then
		return
	end
	tracerOrigin = Instance.new("Part")
	tracerOrigin.Name = "AW_TraceOrigin"
	tracerOrigin.Anchored = true
	tracerOrigin.CanCollide = false
	tracerOrigin.CanQuery = false
	tracerOrigin.CanTouch = false
	tracerOrigin.Transparency = 1
	tracerOrigin.Size = Vector3.new(0.2, 0.2, 0.2)
	tracerOrigin.Parent = Workspace
	originAtt = Instance.new("Attachment")
	originAtt.Name = "AW_OriginAtt"
	originAtt.Parent = tracerOrigin
end

function api.dropVis(inst)
	local rec = visBeams[inst]
	if not rec then
		return
	end
	pcall(function()
		if rec.beam then
			rec.beam:Destroy()
		end
	end)
	pcall(function()
		if rec.att then
			rec.att:Destroy()
		end
	end)
	pcall(function()
		if rec.box then
			rec.box:Destroy()
		end
	end)
	pcall(function()
		if rec.hl then
			rec.hl:Destroy()
		end
	end)
	visBeams[inst] = nil
end

function api.clearSkel(model)
	local list = skelBeams[model]
	if not list then
		return
	end
	for _, b in ipairs(list) do
		pcall(function()
			b:Destroy()
		end)
	end
	skelBeams[model] = nil
end

function api.clearHardVis()
	for inst in pairs(visBeams) do
		api.dropVis(inst)
	end
	for model in pairs(skelBeams) do
		api.clearSkel(model)
	end
	if tracerOrigin then
		pcall(function()
			tracerOrigin:Destroy()
		end)
		tracerOrigin = nil
		originAtt = nil
	end
end

function api.paintVis(inst, color)
	if not inst or not inst.Parent then
		return
	end
	local host = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end
	local adornee = inst:IsA("Model") and inst or host
	local rec = visBeams[inst]
	if not rec or not rec.beam or not rec.beam.Parent or not originAtt then
		api.ensureTracerRig()
		local att = Instance.new("Attachment")
		att.Name = "AW_VisAtt"
		att.Parent = host
		local beam = Instance.new("Beam")
		beam.Name = "AW_Tracer"
		beam.Attachment0 = originAtt
		beam.Attachment1 = att
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Brightness = 3
		beam.Segments = 1
		beam.Parent = tracerOrigin
		local box = Instance.new("SelectionBox")
		box.Name = "AW_Box"
		box.Adornee = adornee
		box.SurfaceTransparency = 0.78
		box.Parent = tracerOrigin
		local hl = Instance.new("Highlight")
		hl.Name = "AW_Hard"
		hl.Adornee = adornee
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0
		hl.Parent = tracerOrigin
		rec = { beam = beam, att = att, box = box, hl = hl, host = host }
		visBeams[inst] = rec
	end
	local w = (state.tracerWidth or 8) / 100
	rec.beam.Width0 = w
	rec.beam.Width1 = w * 0.35
	rec.beam.Enabled = state.tracers ~= false
	rec.beam.Color = ColorSequence.new(color)
	rec.box.Color3 = color
	rec.box.SurfaceColor3 = color
	rec.box.LineThickness = (state.boxThick or 5) / 100
	rec.box.Visible = state.boxes ~= false
	rec.hl.FillColor = color
	rec.hl.OutlineColor = Color3.new(1, 1, 1)
	rec.hl.Enabled = true
end

local SKEL_LINKS = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
}

function api.paintSkeleton(model, color)
	if not state.skeletons or not model or not model.Parent then
		api.clearSkel(model)
		return
	end
	if skelBeams[model] then
		for _, b in ipairs(skelBeams[model]) do
			if b and b.Parent then
				b.Color = ColorSequence.new(color)
			end
		end
		return
	end
	local made = {}
	for _, link in ipairs(SKEL_LINKS) do
		local a = model:FindFirstChild(link[1])
		local bpart = model:FindFirstChild(link[2])
		if a and bpart and a:IsA("BasePart") and bpart:IsA("BasePart") then
			local att0 = Instance.new("Attachment")
			att0.Name = "AW_Skel"
			att0.Parent = a
			local att1 = Instance.new("Attachment")
			att1.Name = "AW_Skel"
			att1.Parent = bpart
			local beam = Instance.new("Beam")
			beam.Name = "AW_Skel"
			beam.Attachment0 = att0
			beam.Attachment1 = att1
			beam.FaceCamera = true
			beam.Width0 = 0.05
			beam.Width1 = 0.05
			beam.LightEmission = 1
			beam.Color = ColorSequence.new(color)
			beam.Parent = a
			made[#made + 1] = beam
			made[#made + 1] = att0
			made[#made + 1] = att1
		end
	end
	if #made > 0 then
		skelBeams[model] = made
	end
end

function api.updateHardVis()
	if not state.hardVis then
		if next(visBeams) or next(skelBeams) or tracerOrigin then
			api.clearHardVis()
		end
		return
	end
	api.ensureTracerRig()
	Camera = Workspace.CurrentCamera
	if Camera and tracerOrigin then
		tracerOrigin.CFrame = Camera.CFrame
	end
	if os.clock() >= nextHardScan then
		nextHardScan = os.clock() + 0.5
		local list = {}
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("Model") and api.isMonster(obj) then
				list[#list + 1] = obj
			end
		end
		hardMonsters = list
	end
	local seen = {}
	local function add(inst, shift, skel)
		if not inst or seen[inst] or not inst.Parent then
			return
		end
		seen[inst] = true
		local col = api.hardColor(shift)
		api.paintVis(inst, col)
		if skel and inst:IsA("Model") then
			api.paintSkeleton(inst, col)
		end
	end
	if state.hardAnoms then
		for i, it in ipairs(anomalyItems) do
			add(it.adornee, i * 0.07, false)
		end
	end
	if state.hardPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				add(plr.Character, 0.33, true)
			end
		end
	end
	if state.hardMonsters then
		for i, obj in ipairs(hardMonsters) do
			add(obj, 0.66 + i * 0.04, true)
		end
	end
	for inst in pairs(visBeams) do
		if not seen[inst] then
			api.dropVis(inst)
		end
	end
	for model in pairs(skelBeams) do
		if not seen[model] then
			api.clearSkel(model)
		end
	end
end
function api.claimSims()
	pcall(function()
		if sethiddenproperty then
			sethiddenproperty(player, "SimulationRadius", 1e4)
			sethiddenproperty(player, "MaxSimulationRadius", 1e4)
		end
	end)
	pcall(function()
		if setsimulationradius then
			setsimulationradius(1e4, 1e4)
		end
	end)
end

function api.showPoint(pos, text)
	if not pointMarker or not pointMarker.Parent then
		pointMarker = Instance.new("Part")
		pointMarker.Name = "AW_ControlPoint"
		pointMarker.Anchored = true
		pointMarker.CanCollide = false
		pointMarker.CanQuery = false
		pointMarker.CanTouch = false
		pointMarker.Material = Enum.Material.Neon
		pointMarker.Shape = Enum.PartType.Ball
		pointMarker.Size = Vector3.new(1.6, 1.6, 1.6)
		pointMarker.Color = PINK
		pointMarker.Parent = Workspace
		local hl = Instance.new("Highlight")
		hl.Name = "AW_Hard"
		hl.Adornee = pointMarker
		hl.FillColor = PINK
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.3
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = pointMarker
		local gui = Instance.new("BillboardGui")
		gui.Name = "AW_Tag"
		gui.Size = UDim2.fromOffset(180, 36)
		gui.StudsOffset = Vector3.new(0, 2.4, 0)
		gui.AlwaysOnTop = true
		gui.Parent = pointMarker
		pointLabel = Instance.new("TextLabel")
		pointLabel.Size = UDim2.fromScale(1, 1)
		pointLabel.BackgroundTransparency = 0.25
		pointLabel.BackgroundColor3 = Color3.fromRGB(30, 8, 18)
		pointLabel.Text = "PUNKT"
		pointLabel.TextColor3 = PINK
		pointLabel.Font = Enum.Font.GothamBold
		pointLabel.TextSize = 14
		pointLabel.Parent = gui
	end
	pointMarker.Position = pos + Vector3.new(0, 1.5, 0)
	if pointLabel then
		pointLabel.Text = text or "PUNKT"
	end
end

function api.clearWayMarkers()
	for _, d in ipairs(Workspace:GetChildren()) do
		if d.Name == "AW_Way" then
			d:Destroy()
		end
	end
end

function api.drawWaypoints()
	api.clearWayMarkers()
	for i, pos in ipairs(waypoints) do
		local p = Instance.new("Part")
		p.Name = "AW_Way"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(0.8, 0.8, 0.8)
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 180, 40)
		p.Position = pos + Vector3.new(0, 1.2, 0)
		p.Parent = Workspace
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(40, 20)
		gui.StudsOffset = Vector3.new(1.4, 0, 0)
		gui.AlwaysOnTop = true
		gui.Parent = p
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = tostring(i)
		lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 14
		lbl.Parent = gui
	end
end

function api.refreshWayList()
	if not wayFrame then
		return
	end
	for _, ch in ipairs(wayFrame:GetChildren()) do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
	if #waypoints == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -8, 0, 22)
		empty.BackgroundTransparency = 1
		empty.Text = "Brak trasy. 6 dodaje punkt pod myszka."
		empty.TextColor3 = Color3.fromRGB(140, 150, 160)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = wayFrame
		return
	end
	for i, pos in ipairs(waypoints) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 24)
		row.BackgroundColor3 = Color3.fromRGB(36, 22, 28)
		row.Text = string.format("  %d   %.0f, %.0f, %.0f", i, pos.X, pos.Y, pos.Z)
		row.TextColor3 = PINK
		row.Font = Enum.Font.Gotham
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = wayFrame
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = row
		row.MouseButton1Click:Connect(function()
			table.remove(waypoints, i)
			if waypointIndex > #waypoints then
				waypointIndex = 1
			end
			api.drawWaypoints()
			api.refreshWayList()
		end)
	end
end

function api.mouseWorld()
	local mouse = player:GetMouse()
	if mouse and mouse.Hit then
		return mouse.Hit.Position
	end
	return nil
end

function api.placeControlPoint()
	local pos = api.mouseWorld()
	if not pos then
		api.logStatus("Brak punktu pod myszka", 2)
		return
	end
	controlPoint = pos
	monsterHolds = {}
	api.showPoint(pos, "CEL")
	api.logStatus(string.format("Cel: %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z), 2.5)
end

function api.addWaypoint()
	local pos = api.mouseWorld()
	if not pos then
		api.logStatus("Brak punktu pod myszka", 2)
		return
	end
	waypoints[#waypoints + 1] = pos
	controlPoint = pos
	api.showPoint(pos, "TRASA " .. tostring(#waypoints))
	api.drawWaypoints()
	api.refreshWayList()
	api.logStatus("Waypoint " .. tostring(#waypoints), 2)
end

function api.clearWaypoints()
	waypoints = {}
	waypointIndex = 1
	api.clearWayMarkers()
	api.refreshWayList()
	api.logStatus("Trasa wyczyszczona", 2)
end

function api.refreshMonsterCache()
	if os.clock() < nextStalkScan then
		return
	end
	nextStalkScan = os.clock() + 0.4
	local list = {}
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and api.isMonster(obj) then
			list[#list + 1] = obj
		end
	end
	stalkModels = list
end

function api.disarmMonster(model, root)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.CanTouch then
			p.CanTouch = false
		end
	end
	if root.Anchored then
		pcall(function()
			root.Anchored = false
		end)
	end
end

function api.pushMonster(model, goal, speed)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
		return
	end
	api.disarmMonster(model, root)
	local flatGoal = Vector3.new(goal.X, root.Position.Y, goal.Z)
	local delta = Vector3.new(flatGoal.X - root.Position.X, 0, flatGoal.Z - root.Position.Z)
	local dist = delta.Magnitude
	pcall(function()
		hum:MoveTo(flatGoal)
	end)
	local stop = state.stopDist or 3
	if dist > stop then
		pcall(function()
			local dir = delta.Unit
			local spd = speed or state.anomalySpeed or 18
			root.AssemblyLinearVelocity = Vector3.new(dir.X * spd, root.AssemblyLinearVelocity.Y, dir.Z * spd)
		end)
	else
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end)
	end
	return dist
end

function api.controlActive()
	return state.ignoreAnomaly or state.circleBait or state.steerAnomaly
end

function api.driveAnomalies(dt)
	if not api.controlActive() then
		return false
	end
	if not hrp or snapItem then
		return true
	end
	api.claimSims()
	if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
	api.refreshMonsterCache()
	controlAngle += (dt or 0.016) * ((state.orbitSpeed or 14) / 10)
	local radius = state.circleRadius or 16
	local spd = state.anomalySpeed or 18
	for i, model in ipairs(stalkModels) do
		if model.Parent and not api.playerModelOf(model) then
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if root and root:IsA("BasePart") then
				local goal
				local spread = ((i - 1) * (state.spread or 7)) * 0.15
				if state.circleBait then
					local center = controlPoint or hrp.Position
					local ang = controlAngle + (i - 1) * (0.9 + spread)
					goal = center + Vector3.new(math.cos(ang) * radius, 0, math.sin(ang) * radius)
				elseif state.steerAnomaly and #waypoints > 0 then
					local idx = ((waypointIndex - 1) % #waypoints) + 1
					goal = waypoints[idx]
					local dist = api.pushMonster(model, goal, spd)
					if i == 1 and dist and dist <= (state.stopDist or 3) + 1 and state.waypointLoop then
						waypointIndex = idx % #waypoints + 1
					end
					continue
				elseif state.steerAnomaly and controlPoint then
					goal = controlPoint
				else
					local hold = monsterHolds[model]
					local away = root.Position - hrp.Position
					local flat = Vector3.new(away.X, 0, away.Z)
					local flee = state.fleeDist or 30
					if not hold or (root.Position - hrp.Position).Magnitude < flee * 0.55 then
						if flat.Magnitude < 1 then
							flat = Vector3.new(1, 0, 0)
						end
						local side = Vector3.new(-flat.Z, 0, flat.X).Unit * ((i % 2 == 0) and 6 or -6)
						hold = hrp.Position + flat.Unit * flee + side
						monsterHolds[model] = hold
					end
					goal = hold
				end
				if goal then
					api.pushMonster(model, goal, spd)
				end
			end
		end
	end
	return true
end

function api.applyStalk()
	if not state.stalk or not hrp or api.controlActive() then
		return
	end
	api.claimSims()
	if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
	api.refreshMonsterCache()
	for _, model in ipairs(stalkModels) do
		if model.Parent and not api.playerModelOf(model) then
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if root and root:IsA("BasePart") then
				local delta = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z)
				local dist = delta.Magnitude
				local goal = hrp.Position
				if dist < 8 and dist > 0.05 then
					goal = hrp.Position - delta.Unit * 8
				end
				api.pushMonster(model, goal, state.anomalySpeed or 16)
			end
		end
	end
end

function api.parentGui(gui)
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		elseif protectgui then
			protectgui(gui)
		end
	end)
	local hosts = {}
	pcall(function()
		if typeof(gethui) == "function" then
			local h = gethui()
			if typeof(h) == "Instance" then
				hosts[#hosts + 1] = h
			end
		end
	end)
	pcall(function()
		hosts[#hosts + 1] = game:GetService("CoreGui")
	end)
	hosts[#hosts + 1] = playerGui
	for _, host in ipairs(hosts) do
		if typeof(host) == "Instance" then
			local ok = pcall(function()
				gui.Parent = host
			end)
			if ok and gui.Parent ~= nil then
				return
			end
		end
	end
end

function api.killOldGui()
	local bags = { playerGui }
	pcall(function()
		if typeof(gethui) == "function" then
			local h = gethui()
			if typeof(h) == "Instance" then
				bags[#bags + 1] = h
			end
		end
	end)
	pcall(function()
		bags[#bags + 1] = game:GetService("CoreGui")
	end)
	for _, bag in ipairs(bags) do
		if typeof(bag) == "Instance" then
			local old = bag:FindFirstChild("AnomalySuite")
			if old then
				pcall(function()
					old:Destroy()
				end)
			end
		end
	end
end

pcall(function()
	for _, d in ipairs(Workspace:GetDescendants()) do
		pcall(function()
			if d:IsA("Highlight") and (d.Name == "Chams" or d.Name == "MonsterESP" or d.Name == "AW_Anomaly" or d.Name == "AW_Hard") then
				d:Destroy()
			elseif d.Name == "NameESP" or d.Name == "AW_Tag" or d.Name == "AW_Marker" or d.Name == "AW_FlyVel" or d.Name == "AW_FlyGyro" or d.Name == "AW_TraceOrigin" or d.Name == "AW_ControlPoint" or d.Name == "AW_Way" then
				d:Destroy()
			end
		end)
	end
end)
api.killOldGui()

local screen = Instance.new("ScreenGui")
screen.Name = "AnomalySuite"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 2147483647
screen.Enabled = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
api.parentGui(screen)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(540, 660)
main.Position = UDim2.new(0, 18, 0.5, -330)
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
titleText.Text = "ANOMALY SUITE  v6"
titleText.Parent = title
local subText = Instance.new("TextLabel")
subText.BackgroundTransparency = 1
subText.Position = UDim2.fromOffset(24, 28)
subText.Size = UDim2.new(1, -90, 0, 16)
subText.Font = Enum.Font.Gotham
subText.TextSize = 11
subText.TextXAlignment = Enum.TextXAlignment.Left
subText.TextColor3 = Color3.fromRGB(120, 160, 140)
subText.Text = "J ESP  T raport  H wizual  2 cel  3 kolo  4 ignoruj"
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
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local pages = {}
local tabButtons = {}
local TAB_COUNT = 6

function api.showTab(name)
	for id, page in pairs(pages) do
		page.Visible = id == name
	end
	for id, btn in pairs(tabButtons) do
		local on = id == name
		btn.BackgroundColor3 = on and Color3.fromRGB(28, 64, 44) or Color3.fromRGB(24, 26, 32)
		btn.TextColor3 = on and GREEN or Color3.fromRGB(170, 176, 186)
	end
end

function api.makeTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / TAB_COUNT, -4, 1, 0)
	btn.TextSize = 10
	btn.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(170, 176, 186)
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.Parent = tabBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = btn
	btn.MouseButton1Click:Connect(function()
		api.showTab(name)
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

local pageMove = api.makeTab("Move")
local pageVis = api.makeTab("Visual")
local pageAnom = api.makeTab("Anom")
local pageSteer = api.makeTab("Steruj")
local pageRep = api.makeTab("Raport")
local pageSet = api.makeTab("Filtr")
api.showTab("Anom")
function api.makeToggle(parent, name, id, getter, setter)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
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

function api.makeSlider(parent, name, minV, maxV, getter, setter)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 48)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(12, 4)
	lbl.Size = UDim2.new(1, -20, 0, 16)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(220, 224, 230)
	lbl.Text = name .. "   " .. tostring(getter())
	lbl.Parent = frame
	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.Position = UDim2.fromOffset(12, 28)
	bar.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((getter() - minV) / math.max(maxV - minV, 1), 0, 1), 0, 1, 0)
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
	end
	bar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = true
			setFromX(inp.Position.X)
		end
	end)
	api.track(UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			drag = false
		end
	end))
	api.track(UserInputService.InputChanged:Connect(function(inp)
		if not drag then
			return
		end
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			setFromX(inp.Position.X)
		end
	end))
end

function api.makeButton(parent, text, color, fn)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
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

function api.makeHint(parent, text, tall)
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

function api.makeSection(parent, text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = GREEN
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

api.makeToggle(pageMove, "Fly", "fly", function()
	return state.fly
end, api.setFlyState)
api.makeToggle(pageMove, "Noclip", "noclip", function()
	return state.noclip
end, api.setNoclipState)
api.makeToggle(pageMove, "Infinite Jump", "infJump", function()
	return state.infJump
end, function(v)
	state.infJump = v
end)
api.makeToggle(pageMove, "No Fall", "noFall", function()
	return state.noFall
end, function(v)
	state.noFall = v
end)
api.makeSlider(pageMove, "WalkSpeed", 16, 120, function()
	return state.speed
end, function(v)
	state.speed = v
	api.applySpeedJump()
end)
api.makeSlider(pageMove, "JumpPower", 50, 220, function()
	return state.jump
end, function(v)
	state.jump = v
	api.applySpeedJump()
end)
api.makeSlider(pageMove, "Fly speed", 20, 180, function()
	return state.flySpeed
end, function(v)
	state.flySpeed = v
end)
api.makeSlider(pageMove, "Fly gora/dol", 20, 140, function()
	return state.flyUp
end, function(v)
	state.flyUp = v
end)
api.makeHint(pageMove, "Fly: WASD, Space gora, LeftCtrl dol. Klawisze zmienisz na dole zakladki Filtr.", 32)

api.makeSection(pageVis, "PODSTAWA")
api.makeToggle(pageVis, "Fullbright", "fullbright", function()
	return state.fullbright
end, api.setFullbright)
api.makeToggle(pageVis, "FOV 120", "fov", function()
	return state.fov
end, api.setFOV)
api.makeToggle(pageVis, "Player Chams", "chams", function()
	return state.chams
end, api.setChams)
api.makeToggle(pageVis, "Name ESP", "names", function()
	return state.names
end, api.setNames)
api.makeToggle(pageVis, "Monster ESP (czerwony)", "monster", function()
	return state.monster
end, api.setMonster)
api.makeToggle(pageVis, "Intrudery gonia, nie bija", "stalk", function()
	return state.stalk
end, function(v)
	state.stalk = v
end)
api.makeSection(pageVis, "HARD ESP")
api.makeToggle(pageVis, "Hard ESP", "hardVis", function()
	return state.hardVis
end, function(v)
	state.hardVis = v
	if not v then
		api.clearHardVis()
	end
end)
api.makeToggle(pageVis, "Tracery", "tracers", function()
	return state.tracers
end, function(v)
	state.tracers = v
end)
api.makeToggle(pageVis, "Boxy", "boxes", function()
	return state.boxes
end, function(v)
	state.boxes = v
end)
api.makeToggle(pageVis, "Szkielety", "skeletons", function()
	return state.skeletons
end, function(v)
	state.skeletons = v
	if not v then
		for model in pairs(skelBeams) do
			api.clearSkel(model)
		end
	end
end)
api.makeToggle(pageVis, "Tecza", "rainbow", function()
	return state.rainbow
end, function(v)
	state.rainbow = v
end)
api.makeToggle(pageVis, "Hard: anomalie", "hardAnoms", function()
	return state.hardAnoms
end, function(v)
	state.hardAnoms = v
end)
api.makeToggle(pageVis, "Hard: gracze", "hardPlayers", function()
	return state.hardPlayers
end, function(v)
	state.hardPlayers = v
end)
api.makeToggle(pageVis, "Hard: intruderzy", "hardMonsters", function()
	return state.hardMonsters
end, function(v)
	state.hardMonsters = v
end)
api.makeSlider(pageVis, "Grubosc tracera", 2, 30, function()
	return state.tracerWidth
end, function(v)
	state.tracerWidth = v
end)
api.makeSlider(pageVis, "Grubosc boxa", 1, 20, function()
	return state.boxThick
end, function(v)
	state.boxThick = v
end)
api.makeSlider(pageVis, "Predkosc teczy", 10, 120, function()
	return state.rainbowSpeed
end, function(v)
	state.rainbowSpeed = v
end)
api.makeHint(pageVis, "Hard ESP rysuje tecze, linie do celu i obwodke. Szkielet na graczach i intruderach. Wlacz H.", 40)

api.makeToggle(pageAnom, "Anomaly ESP", "anomaly", function()
	return state.anomaly
end, api.setAnomaly)
api.makeToggle(pageAnom, "Etykiety typu", "labels", function()
	return state.labels
end, function(v)
	state.labels = v
	if state.anomaly then
		api.clearAllMarks()
		api.scanAnomalies()
	end
end)
api.makeToggle(pageAnom, "Auto snapshot (Threat)", "autoSnap", function()
	return state.autoSnap
end, function(v)
	state.autoSnap = v
end)
api.makeButton(pageAnom, "Snapshot czystej mapy", Color3.fromRGB(24, 92, 58), function()
	local n = api.takeSnapshot()
	api.logStatus(string.format("Snapshot: %d obiektow. Czekam na zmiany.", n), 3)
end)
api.makeToggle(pageAnom, "Auto raport", "autoReport", function()
	return state.autoReport
end, function(v)
	state.autoReport = v
end)
api.makeToggle(pageAnom, "Usuwanie kliknieciem", "deleteClick", function()
	return state.deleteClick
end, function(v)
	state.deleteClick = v
	api.logStatus(v and "Usuwanie: kliknij obiekt" or "Usuwanie wylaczone", 2)
end)
api.makeHint(pageAnom, "Klik wiersza albo T. Skrypt stawia cie przed obiektem, patrzy w obraz i klika typ. Log jest w zakladce Raport.", 48)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Brak snapshotu - K na czystej mapie"
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
api.refreshAnomalyList()

api.makeSection(pageSteer, "TRYB")
api.makeToggle(pageSteer, "Ignoruj gracza", "ignoreAnomaly", function()
	return state.ignoreAnomaly
end, function(v)
	state.ignoreAnomaly = v
	monsterHolds = {}
	api.logStatus(v and "Anomalia ucieka od ciebie" or "Ignorowanie wylaczone", 2)
end)
api.makeToggle(pageSteer, "Rage bait - kolo", "circleBait", function()
	return state.circleBait
end, function(v)
	state.circleBait = v
	if v and not controlPoint and hrp then
		controlPoint = hrp.Position
		api.showPoint(controlPoint, "KOLO")
	end
	api.logStatus(v and "Chodzi w kolko wokol punktu" or "Kolo wylaczone", 2)
end)
api.makeToggle(pageSteer, "Idz do punktu / trasy", "steerAnomaly", function()
	return state.steerAnomaly
end, function(v)
	state.steerAnomaly = v
	api.logStatus(v and "Idzie tam gdzie wskazesz" or "Sterowanie wylaczone", 2)
end)
api.makeToggle(pageSteer, "Petla trasy", "waypointLoop", function()
	return state.waypointLoop
end, function(v)
	state.waypointLoop = v
end)
api.makeSection(pageSteer, "LICZBY")
api.makeSlider(pageSteer, "Predkosc anomalii", 6, 40, function()
	return state.anomalySpeed
end, function(v)
	state.anomalySpeed = v
end)
api.makeSlider(pageSteer, "Promien kola", 4, 60, function()
	return state.circleRadius
end, function(v)
	state.circleRadius = v
end)
api.makeSlider(pageSteer, "Predkosc kola", 4, 40, function()
	return state.orbitSpeed
end, function(v)
	state.orbitSpeed = v
end)
api.makeSlider(pageSteer, "Dystans ucieczki", 10, 80, function()
	return state.fleeDist
end, function(v)
	state.fleeDist = v
	monsterHolds = {}
end)
api.makeSlider(pageSteer, "Dystans stop", 1, 12, function()
	return state.stopDist
end, function(v)
	state.stopDist = v
end)
api.makeSlider(pageSteer, "Rozstrzal stada", 0, 20, function()
	return state.spread
end, function(v)
	state.spread = v
end)
api.makeButton(pageSteer, "Postaw cel pod myszka", Color3.fromRGB(120, 40, 70), api.placeControlPoint)
api.makeButton(pageSteer, "Dodaj waypoint", Color3.fromRGB(90, 60, 20), api.addWaypoint)
api.makeButton(pageSteer, "Wyczysc trase", Color3.fromRGB(50, 40, 40), api.clearWaypoints)
api.makeHint(pageSteer, "2 = cel. 3 = kolo. 4 = ignoruj (ucieka). 5 = idz na cel albo po trasie. 6 = waypoint. 0 = czysc. Klik wiersza trasy kasuje ten punkt. Kolo bije sterowanie.", 64)
wayFrame = Instance.new("Frame")
wayFrame.Size = UDim2.new(1, 0, 0, 0)
wayFrame.AutomaticSize = Enum.AutomaticSize.Y
wayFrame.BackgroundTransparency = 1
wayFrame.Parent = pageSteer
local wayLay = Instance.new("UIListLayout")
wayLay.Padding = UDim.new(0, 4)
wayLay.Parent = wayFrame
api.refreshWayList()

api.makeSection(pageRep, "JAK KLIKA")
api.makeToggle(pageRep, "Auto naprawa (idz + klik)", "autoFix", function()
	return state.autoFix
end, function(v)
	state.autoFix = v
end)
api.makeToggle(pageRep, "Teleport przed obiekt", "reportGlance", function()
	return state.reportGlance
end, function(v)
	state.reportGlance = v
end)
api.makeToggle(pageRep, "Noclip na czas raportu", "reportNoclip", function()
	return state.reportNoclip
end, function(v)
	state.reportNoclip = v
end)
api.makeToggle(pageRep, "Klik sygnalow (hook)", "reportSignals", function()
	return state.reportSignals
end, function(v)
	state.reportSignals = v
end)
api.makeToggle(pageRep, "Klik myszka VIM", "reportVim", function()
	return state.reportVim
end, function(v)
	state.reportVim = v
end)
api.makeToggle(pageRep, "ProximityPrompt", "reportPrompt", function()
	return state.reportPrompt
end, function(v)
	state.reportPrompt = v
end)
api.makeSection(pageRep, "CZASY")
api.makeSlider(pageRep, "Czas patrzenia x0.1s", 8, 50, function()
	return state.reportHold
end, function(v)
	state.reportHold = v
end)
api.makeSlider(pageRep, "Proby klikniecia", 1, 8, function()
	return state.reportTries
end, function(v)
	state.reportTries = v
end)
api.makeSlider(pageRep, "Odleglosc stania", 3, 14, function()
	return state.reportStand
end, function(v)
	state.reportStand = v
end)
api.makeSlider(pageRep, "FOV raportu", 20, 70, function()
	return state.reportFov
end, function(v)
	state.reportFov = v
end)
api.makeSlider(pageRep, "Dystans kamery x0.1", 8, 40, function()
	return state.reportCamDist
end, function(v)
	state.reportCamDist = v
end)
api.makeSlider(pageRep, "Czekanie na tablet x0.01s", 10, 80, function()
	return state.reportTabletWait
end, function(v)
	state.reportTabletWait = v
end)
api.makeSlider(pageRep, "Klatki przed klikiem", 2, 20, function()
	return state.reportWarm
end, function(v)
	state.reportWarm = v
end)
api.makeSlider(pageRep, "Powrot x0.01s", 5, 60, function()
	return state.reportReturn
end, function(v)
	state.reportReturn = v
end)
api.makeSlider(pageRep, "Auto raport co x0.1s", 10, 60, function()
	return state.autoReportWait
end, function(v)
	state.autoReportWait = v
end)
api.makeHint(pageRep, "Log nizej mowi czy znalazl przycisk i jaki ma tekst. Jak jest '0 przyciskow' - tablet nie byl otwarty. Skrypt sam wciska R i szuka jeszcze raz.", 52)
logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, 0, 0, 150)
logLabel.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
logLabel.Text = "Log raportu pojawi sie tutaj."
logLabel.TextColor3 = Color3.fromRGB(170, 230, 190)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Parent = pageRep
local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logLabel
local logPad = Instance.new("UIPadding")
logPad.PaddingLeft = UDim.new(0, 6)
logPad.PaddingTop = UDim.new(0, 4)
logPad.Parent = logLabel

function api.setIgnoreText(v)
	state.customIgnore = v or ""
	table.clear(customIgnoreList)
	for word in string.gmatch(string.lower(state.customIgnore), "[^,%s]+") do
		if #word >= 2 then
			table.insert(customIgnoreList, word)
		end
	end
	api.clearAllMarks()
end

function api.makeBox(parent, name, placeholder)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 56)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(12, 4)
	lbl.Size = UDim2.new(1, -20, 0, 16)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(220, 224, 230)
	lbl.Text = name
	lbl.Parent = frame
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -24, 0, 24)
	box.Position = UDim2.fromOffset(12, 26)
	box.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	box.Text = state.customIgnore
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(120, 130, 140)
	box.TextColor3 = GREEN
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = box
	box.FocusLost:Connect(function()
		api.setIgnoreText(box.Text)
	end)
end

api.makeSection(pageSet, "WYKRYWANIE")
api.makeToggle(pageSet, "Licz dubli (talerze)", "pairFix", function()
	return state.pairFix
end, function(v)
	state.pairFix = v
	api.clearAllMarks()
end)
api.makeSlider(pageSet, "Promien dubli", 8, 80, function()
	return state.pairRadius
end, function(v)
	state.pairRadius = v
end)
api.makeSlider(pageSet, "Czulosc ruchu %", 40, 220, function()
	return state.moveScale
end, function(v)
	state.moveScale = v
end)
api.makeSlider(pageSet, "Prog ruchu x0.01", 5, 80, function()
	return state.posThresh
end, function(v)
	state.posThresh = v
end)
api.makeSlider(pageSet, "Prog obrotu x0.01", 5, 90, function()
	return state.rotThresh
end, function(v)
	state.rotThresh = v
end)
api.makeSlider(pageSet, "Prog koloru x0.01", 2, 40, function()
	return state.colorThresh
end, function(v)
	state.colorThresh = v
end)
api.makeSlider(pageSet, "Prog rozmiaru x0.01", 5, 80, function()
	return state.sizeThresh
end, function(v)
	state.sizeThresh = v
end)
api.makeSlider(pageSet, "Prog rozciagniecia %", 110, 250, function()
	return state.stretchThresh
end, function(v)
	state.stretchThresh = v
end)
api.makeSlider(pageSet, "Prog przezroczystosci", 5, 60, function()
	return state.transThresh
end, function(v)
	state.transThresh = v
end)
api.makeSlider(pageSet, "Priorytet ruch", 2, 30, function()
	return state.priPos
end, function(v)
	state.priPos = v
end)
api.makeSlider(pageSet, "Priorytet obrot", 2, 40, function()
	return state.priRot
end, function(v)
	state.priRot = v
end)
api.makeSlider(pageSet, "Priorytet kolor", 1, 20, function()
	return state.priColor
end, function(v)
	state.priColor = v
end)
api.makeSlider(pageSet, "Priorytet rozmiar", 2, 40, function()
	return state.priSize
end, function(v)
	state.priSize = v
end)
api.makeSlider(pageSet, "Swiatlo jasnosc", 10, 80, function()
	return state.lightBright
end, function(v)
	state.lightBright = v
end)
api.makeSlider(pageSet, "Swiatlo zasieg", 5, 40, function()
	return state.lightRange
end, function(v)
	state.lightRange = v
end)
api.makeSlider(pageSet, "Potwierdzenia skanu", 1, 5, function()
	return state.confirmNeed
end, function(v)
	state.confirmNeed = v
end)
api.makeSlider(pageSet, "Max na liscie", 8, 60, function()
	return state.maxList
end, function(v)
	state.maxList = v
end)
api.makeSlider(pageSet, "Zasieg etykiet", 60, 900, function()
	return state.labelDist
end, function(v)
	state.labelDist = v
	api.clearAllMarks()
end)
api.makeSlider(pageSet, "Przezroczystosc ESP %", 10, 85, function()
	return state.fillTrans
end, function(v)
	state.fillTrans = v
	api.clearAllMarks()
end)
api.makeSlider(pageSet, "Ruch intrudera", 2, 20, function()
	return state.intruderMove
end, function(v)
	state.intruderMove = v
end)
api.makeSlider(pageSet, "Drzwi blisko gracza", 6, 30, function()
	return state.doorNear
end, function(v)
	state.doorNear = v
end)
api.makeSlider(pageSet, "Flood extra", 20, 200, function()
	return state.extraFlood
end, function(v)
	state.extraFlood = v
end)
api.makeToggle(pageSet, "Tylko obiekty z listy", "onlyPriority", function()
	return state.onlyPriority
end, function(v)
	state.onlyPriority = v
	api.clearAllMarks()
end)
api.makeBox(pageSet, "Ignoruj nazwy (po przecinku)", "plate, cup, door")
api.makeHint(pageSet, "Typy na tablecie. Wylaczone nie wchodza na liste ani na podswietlenie.", 28)

function api.typeToggle(label, key)
	api.makeToggle(pageSet, label, key, function()
		return state[key]
	end, function(v)
		state[key] = v
		api.clearAllMarks()
	end)
end
api.typeToggle("Moved Object", "repMoved")
api.typeToggle("Extra Object", "repExtra")
api.typeToggle("Missing Object", "repMissing")
api.typeToggle("Strange Imagery", "repImagery")
api.typeToggle("Strange Light", "repLight")
api.typeToggle("Distorted Object", "repDistorted")
api.typeToggle("Other", "repOther")
api.typeToggle("Intruder", "repIntruder")

api.makeSection(pageSet, "KLAWISZE - kliknij i wcisnij nowy")
local bindOrder = {
	{ "menu", "Menu" },
	{ "esp", "Anomaly ESP" },
	{ "snap", "Snapshot" },
	{ "report", "Raport" },
	{ "hard", "Hard ESP" },
	{ "del", "Usuwanie" },
	{ "point", "Cel" },
	{ "circle", "Kolo" },
	{ "ignore", "Ignoruj" },
	{ "steer", "Steruj" },
	{ "way", "Waypoint" },
	{ "clearWay", "Czysc trase" },
	{ "fly", "Fly" },
	{ "noclip", "Noclip" },
	{ "fullbright", "Fullbright" },
	{ "fov", "FOV" },
	{ "chams", "Chams" },
	{ "monster", "Monster ESP" },
	{ "tablet", "Tablet (R)" },
}
for _, pair in ipairs(bindOrder) do
	local id, label = pair[1], pair[2]
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 28)
	btn.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(220, 230, 224)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.Parent = pageSet
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	local function paint()
		local mark = captureBind == id and "  ...wcisnij klawisz" or ("  " .. api.keyName(binds[id]))
		btn.Text = "  " .. label .. mark
		btn.BackgroundColor3 = captureBind == id and Color3.fromRGB(40, 60, 40) or Color3.fromRGB(24, 26, 32)
	end
	paint()
	uiRefresh["bind_" .. id] = paint
	btn.MouseButton1Click:Connect(function()
		captureBind = id
		for bid in pairs(binds) do
			if uiRefresh["bind_" .. bid] then
				uiRefresh["bind_" .. bid]()
			end
		end
	end)
end

api.track(UserInputService.InputChanged:Connect(function(inp)
	if not dragging then
		return
	end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = inp.Position - dragStart
	main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end))

function api.sameKey(a, b)
	return a == b
end

function api.toggleBind(id)
	if id == "menu" then
		main.Visible = not main.Visible
	elseif id == "fly" then
		api.setFlyState(not state.fly)
	elseif id == "noclip" then
		api.setNoclipState(not state.noclip)
	elseif id == "fullbright" then
		api.setFullbright(not state.fullbright)
	elseif id == "chams" then
		api.setChams(not state.chams)
	elseif id == "monster" then
		api.setMonster(not state.monster)
	elseif id == "fov" then
		api.setFOV(not state.fov)
	elseif id == "esp" then
		api.setAnomaly(not state.anomaly)
	elseif id == "snap" then
		local n = api.takeSnapshot()
		api.logStatus(string.format("Snapshot: %d obiektow", n), 3)
	elseif id == "report" then
		if reportAnomaly then
			local pick = anomalyItems[1]
			for _, it in ipairs(anomalyItems) do
				if it.reason == "Intruder" then
					pick = it
					break
				end
			end
			if pick then
				reportAnomaly(pick)
			else
				api.logStatus("Brak anomalii do raportu", 2)
			end
		end
	elseif id == "tablet" then
		if hookTablet then
			hookTablet()
		end
	elseif id == "del" then
		state.deleteClick = not state.deleteClick
		if uiRefresh.deleteClick then
			uiRefresh.deleteClick()
		end
		api.logStatus(state.deleteClick and "Usuwanie: kliknij obiekt" or "Usuwanie wylaczone", 2)
	elseif id == "hard" then
		state.hardVis = not state.hardVis
		if not state.hardVis then
			api.clearHardVis()
		end
		if uiRefresh.hardVis then
			uiRefresh.hardVis()
		end
	elseif id == "point" then
		api.placeControlPoint()
	elseif id == "circle" then
		state.circleBait = not state.circleBait
		if state.circleBait and not controlPoint and hrp then
			controlPoint = hrp.Position
			api.showPoint(controlPoint, "KOLO")
		end
		if uiRefresh.circleBait then
			uiRefresh.circleBait()
		end
		api.logStatus(state.circleBait and "Kolo wlaczone" or "Kolo wylaczone", 2)
	elseif id == "ignore" then
		state.ignoreAnomaly = not state.ignoreAnomaly
		monsterHolds = {}
		if uiRefresh.ignoreAnomaly then
			uiRefresh.ignoreAnomaly()
		end
		api.logStatus(state.ignoreAnomaly and "Ignoruje gracza" or "Ignorowanie off", 2)
	elseif id == "steer" then
		state.steerAnomaly = not state.steerAnomaly
		if uiRefresh.steerAnomaly then
			uiRefresh.steerAnomaly()
		end
		api.logStatus(state.steerAnomaly and "Sterowanie on" or "Sterowanie off", 2)
	elseif id == "way" then
		api.addWaypoint()
	elseif id == "clearWay" then
		api.clearWaypoints()
	end
end
api.track(UserInputService.InputBegan:Connect(function(io, gp)
	local k = io.KeyCode
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	if typing then
		return
	end
	if captureBind and k ~= Enum.KeyCode.Unknown then
		binds[captureBind] = k
		local done = captureBind
		captureBind = nil
		for bid in pairs(binds) do
			if uiRefresh["bind_" .. bid] then
				uiRefresh["bind_" .. bid]()
			end
		end
		api.logStatus("Klawisz " .. done .. " = " .. api.keyName(k), 2)
		return
	end
	if k == binds.tablet and hookTablet then
		hookTablet()
	end
	for id, code in pairs(binds) do
		if api.sameKey(code, k) and id ~= "tablet" then
			api.toggleBind(id)
			break
		end
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

api.track(UserInputService.InputEnded:Connect(function(io)
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

api.track(UserInputService.JumpRequest:Connect(function()
	if state.infJump and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

pcall(function()
	RunService:UnbindFromRenderStep("AWFly")
end)
RunService:BindToRenderStep("AWFly", Enum.RenderPriority.Camera.Value + 5, function(dt)
	if not running or not state.fly or snapItem then
		return
	end
	if not api.refreshChar() or not hrp then
		return
	end
	pcall(function()
		if humanoid then
			humanoid.PlatformStand = true
			humanoid.AutoRotate = false
		end
		hrp.Anchored = true
		local cam = Workspace.CurrentCamera
		local dir = Vector3.zero
		if cam then
			local look = cam.CFrame.LookVector
			local right = cam.CFrame.RightVector
			if input.fwd then
				dir += look
			end
			if input.back then
				dir -= look
			end
			if input.right then
				dir += right
			end
			if input.left then
				dir -= right
			end
		end
		if input.up then
			dir += Vector3.yAxis
		end
		if input.down then
			dir -= Vector3.yAxis
		end
		local step = Vector3.zero
		if dir.Magnitude > 0.001 then
			step = dir.Unit * (state.flySpeed or 80) * (dt or 0.016)
		end
		local pos = hrp.Position + step
		local lookv = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		local flat = Vector3.new(lookv.X, 0, lookv.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
		hrp.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end)

api.track(RunService.Stepped:Connect(function()
	if state.noclip and char then
		api.setNoclip(true)
	end
end))

api.track(RunService.Heartbeat:Connect(function(dt)
	if not running then
		return
	end
	Camera = Workspace.CurrentCamera
	api.refreshChar()
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
	if state.fov and not snapItem and Camera and Camera.FieldOfView ~= 120 then
		Camera.FieldOfView = 120
	end
	if state.hardVis then
		api.updateHardVis()
	end
	if not api.driveAnomalies(dt) and state.stalk then
		api.applyStalk()
	end
end))

local extraQueue = {}
local extraQueued = false
function api.flushExtras()
	extraQueued = false
	if not running or not snapped then
		table.clear(extraQueue)
		return
	end
	local batch = extraQueue
	extraQueue = {}
	local n = 0
	for _, obj in ipairs(batch) do
		n += 1
		if n % 250 == 0 then
			task.wait()
		end
		if not obj.Parent or api.isOurStuff(obj) or api.isPlayerRelated(obj) then
			continue
		end
		if obj:IsA("Humanoid") then
			local model = obj.Parent
			if model and model:IsA("Model") and not api.playerModelOf(model) and not knownHumanoids[model] then
				if not (Camera and model:IsDescendantOf(Camera)) then
					intruderWatch[model] = true
				end
			end
			continue
		end
		if obj:IsA("BasePart") and api.isTrackable(obj) and not tracked[obj] then
			local hum = api.humanoidModelOf(obj)
			if hum and not api.playerModelOf(hum) and not knownHumanoids[hum] then
				intruderWatch[hum] = true
				continue
			end
			extras[obj] = obj.Parent
		elseif obj:IsA("Model") then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			if hum and not api.playerModelOf(obj) and not knownHumanoids[obj] then
				intruderWatch[obj] = true
				continue
			end
			local added = 0
			for _, d in ipairs(obj:GetDescendants()) do
				if added > 40 then
					break
				end
				if d:IsA("BasePart") and api.isTrackable(d) and not tracked[d] then
					extras[d] = obj
					added += 1
				end
			end
		elseif obj:IsA("Light") and not tracked[obj] then
			extras[obj] = obj.Parent
		elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("ParticleEmitter") or obj:IsA("SurfaceGui") or obj:IsA("SurfaceAppearance") then
			local host = obj.Parent
			if host and host:IsA("BasePart") and not api.isPlayerRelated(host) then
				local data = tracked[host]
				if data then
					data.forceImg = true
					if obj:IsA("ParticleEmitter") then
						data.hasFx = true
					end
				else
					extras[host] = host.Parent
				end
			end
		end
	end
end

api.track(Workspace.DescendantAdded:Connect(function(obj)
	if not running or not state.anomaly or not snapped then
		return
	end
	extraQueue[#extraQueue + 1] = obj
	if extraQueued then
		return
	end
	extraQueued = true
	task.defer(api.flushExtras)
end))

api.track(player.CharacterAdded:Connect(function(c)
	char = c
	task.wait(0.35)
	if not running then
		return
	end
	api.refreshChar()
	api.applySpeedJump()
	if screen and screen.Parent == nil then
		api.parentGui(screen)
	end
	if main then
		main.Visible = true
	end
	if state.fly then
		api.setFlyState(true)
	end
	if state.noclip then
		api.setNoclip(true)
	end
	if state.chams then
		for _, p in ipairs(Players:GetPlayers()) do
			api.createChams(p)
		end
	end
	if state.names then
		for _, p in ipairs(Players:GetPlayers()) do
			api.createName(p)
		end
	end
end))

api.track(player.CharacterRemoving:Connect(function()
	api.destroyFly()
end))

function api.guiText(g)
	if g:IsA("TextButton") or g:IsA("TextLabel") or g:IsA("TextBox") then
		return string.lower(g.Text or "")
	end
	return ""
end

function api.guiBlob(g)
	local parts = { string.lower(g.Name or ""), api.guiText(g) }
	local ok, desc = pcall(function()
		return g:GetDescendants()
	end)
	if ok and desc then
		local n = 0
		for _, d in ipairs(desc) do
			n += 1
			if n > 24 then
				break
			end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				parts[#parts + 1] = string.lower(d.Text or "")
			end
		end
	end
	if g.Parent then
		parts[#parts + 1] = string.lower(g.Parent.Name or "")
		parts[#parts + 1] = api.guiText(g.Parent)
	end
	return table.concat(parts, " ")
end

function api.prettyWords(low)
	local parts = {}
	for w in string.gmatch(low, "%a+") do
		parts[#parts + 1] = string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)
	end
	return table.concat(parts, " ")
end

function api.reasonFromBlob(blob)
	blob = string.lower(blob or "")
	local best, bestLen
	for _, name in ipairs(TYPE_NAMES) do
		if string.find(blob, name, 1, true) and (not bestLen or #name > bestLen) then
			best = name
			bestLen = #name
		end
	end
	if not best then
		return nil
	end
	return api.prettyWords(best)
end

function api.guiRoots()
	local roots = { playerGui }
	Camera = Workspace.CurrentCamera
	if Camera then
		roots[#roots + 1] = Camera
	end
	if char then
		roots[#roots + 1] = char
	end
	local names = { "Tablet", "Phone", "Device", "AnomalyTablet", "Report", "Clipboard" }
	for _, name in ipairs(names) do
		local f = Workspace:FindFirstChild(name, true)
		if f and not api.isOurStuff(f) then
			roots[#roots + 1] = f
		end
	end
	return roots
end

function api.eachButton(fn)
	for _, root in ipairs(api.guiRoots()) do
		local ok, list = pcall(function()
			return root:GetDescendants()
		end)
		if ok and list then
			for _, g in ipairs(list) do
				if not g:FindFirstAncestor("AnomalySuite") and (g:IsA("TextButton") or g:IsA("ImageButton")) then
					local stop = fn(g)
					if stop then
						return
					end
				end
			end
		end
	end
end

function api.pickItem(reason)
	if pinnedItem and pinnedItem.pos and (not reason or pinnedItem.reason == reason) then
		return pinnedItem
	end
	local best
	for _, it in ipairs(anomalyItems) do
		if it.pos and (not reason or it.reason == reason) then
			if not best or (it.dist or 1e9) < (best.dist or 1e9) then
				best = it
			end
		end
	end
	return best
end

function api.faceCFrame(stand, look)
	local face = Vector3.new(look.X, stand.Y, look.Z)
	if (face - stand).Magnitude < 0.25 then
		face = stand + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(stand, face)
end

function api.standAndLook(item)
	local pos = item.pos
	local host = item.adornee
	if host and host:IsA("Model") then
		local p = host.PrimaryPart or host:FindFirstChildWhichIsA("BasePart", true)
		if p then
			host = p
			pos = pos or p.Position
		end
	elseif host and host:IsA("BasePart") then
		pos = pos or host.Position
	end
	if host and host:IsA("BasePart") and host.Name == "AW_Marker" then
		pos = host.Position
	end
	if not pos then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {}
	if char then
		filter[#filter + 1] = char
	end
	if host and typeof(host) == "Instance" then
		local m = host:IsA("Model") and host or host:FindFirstAncestorOfClass("Model")
		if m and m ~= Workspace then
			filter[#filter + 1] = m
		else
			filter[#filter + 1] = host
		end
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local pad = state.reportStand or 6
	local candidates = {}
	if host and host:IsA("BasePart") and host.Name ~= "AW_Marker" then
		local cf, size = host.CFrame, host.Size
		local pads = {
			Vector3.new(0, 0, -(math.max(size.Z, 1) * 0.5 + pad)),
			Vector3.new(0, 0, math.max(size.Z, 1) * 0.5 + pad),
			Vector3.new(-(math.max(size.X, 1) * 0.5 + pad), 0, 0),
			Vector3.new(math.max(size.X, 1) * 0.5 + pad, 0, 0),
			Vector3.new(0, math.max(size.Y, 1) * 0.5 + 2.2, pad * 0.4),
			Vector3.new(0, 1.6, -(math.max(size.Z, 1) * 0.5 + pad + 2)),
		}
		for _, localOff in ipairs(pads) do
			candidates[#candidates + 1] = (cf * CFrame.new(localOff)).Position
		end
	end
	local flat = Vector3.new(0, 0, 1)
	if hrp then
		local d = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
		if d.Magnitude > 0.4 then
			flat = d.Unit
		end
	end
	candidates[#candidates + 1] = pos + flat * pad + Vector3.new(0, 2.2, 0)
	candidates[#candidates + 1] = pos - flat * pad + Vector3.new(0, 2.2, 0)
	candidates[#candidates + 1] = pos + Vector3.new(flat.Z, 2.2, -flat.X) * pad
	candidates[#candidates + 1] = pos + Vector3.new(0, 3.6, 0)
	local function sees(from)
		local origin = from + Vector3.new(0, 1.55, 0)
		local dir = pos - origin
		if dir.Magnitude < 0.25 then
			return true
		end
		local hit = Workspace:Raycast(origin, dir, params)
		if not hit then
			return true
		end
		if host and typeof(host) == "Instance" then
			if hit.Instance == host or hit.Instance:IsDescendantOf(host) then
				return true
			end
			local parent = host.Parent
			if parent and hit.Instance:IsDescendantOf(parent) then
				return true
			end
		end
		return false
	end
	local best
	local bestDist = 1e9
	for _, cpos in ipairs(candidates) do
		if sees(cpos) then
			local d = hrp and (cpos - hrp.Position).Magnitude or 0
			if d < bestDist then
				bestDist = d
				best = cpos
			end
		end
	end
	if not best then
		best = pos + flat * pad + Vector3.new(0, 2.5, 0)
	end
	return best, pos
end

function api.aimCamera(lookAt)
	local cam = Workspace.CurrentCamera
	if not cam or not lookAt then
		return
	end
	if not savedCamCf then
		savedCamType = cam.CameraType
		savedCamCf = cam.CFrame
		savedCamSub = cam.CameraSubject
		savedCamFov = cam.FieldOfView
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = state.reportFov or 40
	local origin = (hrp and (hrp.Position + Vector3.new(0, 1.6, 0))) or (lookAt + Vector3.new(0, 1.4, 4))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = char and { char } or {}
	params.IgnoreWater = true
	local dir = lookAt - origin
	local surface = lookAt
	if dir.Magnitude > 0.2 then
		local hit = Workspace:Raycast(origin, dir.Unit * (dir.Magnitude + 4), params)
		if hit then
			surface = hit.Position
		end
		local away = origin - surface
		local n = away.Magnitude > 0.05 and away.Unit or Vector3.new(0, 0.15, 1).Unit
		origin = surface + n * ((state.reportCamDist or 22) / 10)
	end
	if (surface - origin).Magnitude < 0.2 then
		origin = origin + Vector3.new(0, 0.4, 2)
	end
	cam.CFrame = CFrame.lookAt(origin, surface)
end

function api.holdPose()
	if not hrp or not snapStand or not snapLook then
		return
	end
	hrp.CFrame = api.faceCFrame(snapStand, snapLook)
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
	if bv then
		bv.Velocity = Vector3.zero
	end
	api.aimCamera(snapLook)
end

function api.restoreBody()
	api.refreshChar()
	if hrp and savedBodyCf then
		hrp.CFrame = savedBodyCf
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	savedBodyCf = nil
	snapItem = nil
	snapStand = nil
	snapLook = nil
	snapUntil = 0
	if not state.noclip then
		api.setNoclip(false)
	end
	if humanoid and not state.fly then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end
	if hrp and not state.fly then
		pcall(function()
			hrp.Anchored = false
		end)
	end
	local cam = Workspace.CurrentCamera
	if cam and savedCamCf then
		pcall(function()
			cam.CameraSubject = savedCamSub
			cam.CameraType = savedCamType or Enum.CameraType.Custom
			cam.CFrame = savedCamCf
			if state.fov then
				cam.FieldOfView = 120
			elseif savedCamFov then
				cam.FieldOfView = savedCamFov
			end
		end)
	end
	savedCamCf = nil
	savedCamFov = nil
end

function api.snapBodyTo(item, hold)
	api.refreshChar()
	if not hrp or not item or not item.pos then
		return false
	end
	if state.reportGlance == false and state.autoFix == false then
		return false
	end
	local stand, look = api.standAndLook(item)
	if not stand or not look then
		return false
	end
	if not savedBodyCf then
		savedBodyCf = hrp.CFrame
	end
	if state.reportNoclip ~= false then
		api.setNoclip(true)
	end
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end
	snapItem = item
	snapStand = stand
	snapLook = look
	snapUntil = os.clock() + (hold or ((state.reportHold or 24) / 10))
	api.holdPose()
	return true
end

function api.hookClick(btn, reason)
	if hookedBtns[btn] then
		return
	end
	hookedBtns[btn] = true
	local function before()
		local item = api.pickItem(reason)
		if item then
			api.snapBodyTo(item, (state.reportHold or 24) / 10)
			api.logStatus("Patrze na: " .. item.reason, 2)
		end
	end
	local wrapped = false
	pcall(function()
		if getconnections and hookfunction then
			for _, sigName in ipairs({ "MouseButton1Click", "MouseButton1Down", "Activated" }) do
				local sig = btn[sigName]
				if typeof(sig) == "RBXScriptSignal" then
					for _, c in ipairs(getconnections(sig)) do
						if c.Function then
							local original
							original = hookfunction(c.Function, function(...)
								before()
								return original(...)
							end)
							wrapped = true
						end
					end
				end
			end
		end
	end)
	btn.MouseButton1Down:Connect(function()
		if not wrapped then
			before()
		end
	end)
end

hookTablet = function()
	task.delay(0.12, function()
		local n = 0
		api.eachButton(function(g)
			local reason = api.reasonFromBlob(api.guiBlob(g))
			if reason then
				n += 1
				api.hookClick(g, reason)
			end
		end)
		api.logStatus("Tablet: " .. tostring(n) .. " przyciskow typu", 2)
	end)
end

function api.buttonUnderMouse()
	local pos = UserInputService:GetMouseLocation()
	local list = playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, g in ipairs(list) do
		if not g:FindFirstAncestor("AnomalySuite") then
			local reason = api.reasonFromBlob(api.guiBlob(g))
			if reason then
				return reason
			end
		end
	end
	return nil
end

function api.overOurGui()
	local pos = UserInputService:GetMouseLocation()
	local list = playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, g in ipairs(list) do
		if g:FindFirstAncestor("AnomalySuite") then
			return true
		end
	end
	return false
end

function api.deleteClicked(target)
	if not target or not target:IsA("BasePart") then
		return false
	end
	if target:IsA("Terrain") or api.isOurStuff(target) or api.isPlayerRelated(target) then
		return false
	end
	local victim = target
	local model = target:FindFirstAncestorOfClass("Model")
	if model and model ~= Workspace and not api.isPlayerRelated(model) and not model:FindFirstChildOfClass("Humanoid") then
		local n = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				if n > 40 then
					break
				end
			end
		end
		if n > 0 and n <= 40 then
			victim = model
		end
	end
	local name = victim.Name
	local ok = pcall(function()
		victim:Destroy()
	end)
	api.logStatus(ok and ("Usunieto: " .. name) or ("Nie usunieto: " .. name), 2)
	return true
end

function api.findTypeButton(reason)
	local low = string.lower(reason or "")
	if low == "" then
		return nil, 0
	end
	local best, bestScore, count = nil, nil, 0
	api.eachButton(function(g)
		local own = api.guiText(g)
		local blob = api.guiBlob(g)
		local score = 0
		if string.find(blob, low, 1, true) or string.find(own, low, 1, true) then
			count += 1
		end
		if string.find(own, low, 1, true) then
			score = 100 + #low
		elseif string.find(blob, low, 1, true) then
			score = 60 + #low
		end
		if score > 0 and g.Visible == false then
			score -= 30
		end
		if score > 0 and (not bestScore or score > bestScore) then
			best, bestScore = g, score
		end
	end)
	return best, count
end

function api.buttonCenter(btn)
	local pos = btn.AbsolutePosition
	local size = btn.AbsoluteSize
	local inset = GuiService:GetGuiInset()
	return pos.X + size.X * 0.5, pos.Y + size.Y * 0.5 + inset.Y
end

function api.pressButton(btn)
	if not btn then
		return false, "brak"
	end
	local how = {}
	if state.reportSignals ~= false then
		pcall(function()
			if getconnections then
				for _, sigName in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up" }) do
					local okSig, sig = pcall(function()
						return btn[sigName]
					end)
					if okSig and typeof(sig) == "RBXScriptSignal" then
						for _, c in ipairs(getconnections(sig)) do
							if c.Function then
								how[#how + 1] = "signal"
								task.spawn(c.Function)
							end
						end
					end
				end
			end
		end)
		pcall(function()
			if firesignal then
				firesignal(btn.MouseButton1Click)
				how[#how + 1] = "firesignal"
			end
		end)
	end
	if state.reportVim ~= false then
		local x, y = api.buttonCenter(btn)
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseMoveEvent(x, y, game)
			task.wait(0.02)
			vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.03)
			vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
			how[#how + 1] = "vim"
		end)
		pcall(function()
			if mouse1click then
				mouse1click()
				how[#how + 1] = "m1"
			end
		end)
	end
	if #how == 0 then
		return false, "zero metod"
	end
	return true, table.concat(how, "+")
end

function api.tapKey(key)
	local ok = pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, key, false, game)
		task.wait(0.05)
		vim:SendKeyEvent(false, key, false, game)
	end)
	return ok
end

function api.countTypeButtons()
	local n = 0
	api.eachButton(function(g)
		if api.reasonFromBlob(api.guiBlob(g)) then
			n += 1
		end
	end)
	return n
end

function api.firePromptNear(pos)
	if not state.reportPrompt or not fireproximityprompt or not pos then
		return false
	end
	local best, bestD
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Enabled then
			local part = p.Parent
			local ppos
			if part and part:IsA("BasePart") then
				ppos = part.Position
			elseif part and part:IsA("Attachment") then
				ppos = part.WorldPosition
			end
			if ppos then
				local d = (ppos - pos).Magnitude
				local maxd = (p.MaxActivationDistance or 12) + 10
				if d <= maxd and (not bestD or d < bestD) then
					best, bestD = p, d
				end
			end
		end
	end
	if not best then
		return false
	end
	local ok = pcall(function()
		fireproximityprompt(best, (best.HoldDuration or 0) + 0.05)
	end)
	return ok
end

function api.itemKey(it)
	local p = it.pos or Vector3.zero
	return (it.reason or "") .. "|" .. (it.name or "") .. "|" .. tostring(math.floor(p.X + 0.5)) .. "|" .. tostring(math.floor(p.Z + 0.5))
end

function api.shortBtn(btn)
	if not btn then
		return "-"
	end
	local t = api.guiText(btn)
	if t == "" then
		t = string.lower(btn.Name)
	end
	if #t > 42 then
		t = string.sub(t, 1, 42)
	end
	return t
end

reportAnomaly = function(item)
	if not item or reportBusy then
		return
	end
	reportBusy = true
	pinnedItem = item
	task.spawn(function()
		local okRun, err = pcall(function()
			api.logStatus("1/4 ide do: " .. item.reason .. " / " .. (item.name or "?"), 3)
			local okSnap = api.snapBodyTo(item, (state.reportHold or 24) / 10)
			local warm = state.reportWarm or 8
			for _ = 1, warm do
				api.holdPose()
				task.wait(0.03)
			end
			if not okSnap then
				api.logStatus("2/4 nie ma pozycji obiektu", 3)
			else
				api.logStatus("2/4 stoje przed obiektem, otwieram tablet", 3)
			end
			local pressed, how, foundText = false, "", ""
			if state.autoFix ~= false then
				local tries = state.reportTries or 4
				for attempt = 1, tries do
					api.holdPose()
					local btn, count = api.findTypeButton(item.reason)
					api.logStatus(string.format("3/4 proba %d  przyciskow typu w UI: %d", attempt, api.countTypeButtons()), 2)
					if not btn then
						api.tapKey(binds.tablet or Enum.KeyCode.R)
						task.wait((state.reportTabletWait or 32) / 100)
						hookTablet()
						api.holdPose()
						btn, count = api.findTypeButton(item.reason)
						api.logStatus(string.format("3/4 po R: %d trafien '%s'", count or 0, item.reason), 2)
					end
					if btn then
						foundText = api.shortBtn(btn)
						api.holdPose()
						local did, via = api.pressButton(btn)
						pressed = did
						how = via
						api.logStatus("4/4 klik [" .. via .. "] tekst: " .. foundText, 3)
						if did then
							break
						end
					else
						api.logStatus("3/4 NIE WIDZE przycisku '" .. item.reason .. "' - otworz tablet", 3)
					end
					task.wait(0.15)
				end
				if state.reportPrompt and item.pos then
					local prompted = api.firePromptNear(item.pos)
					if prompted then
						api.logStatus("Dodatkowo: ProximityPrompt", 2)
					end
				end
			end
			if pressed then
				reportedIds[api.itemKey(item)] = true
				api.logStatus("ZGLOSZONO " .. item.reason .. " przez " .. how .. " | " .. foundText, 4)
			elseif okSnap then
				api.logStatus("WIDZE obiekt. Kliknij '" .. item.reason .. "' sam - przycisk nie lapie sie", 4)
			else
				api.logStatus("Brak pozycji - nie ma czego zglosic", 3)
			end
			local back = (state.reportReturn or 25) / 100
			while running and snapItem and os.clock() < snapUntil do
				task.wait(0.05)
			end
			task.wait(back)
		end)
		if not okRun then
			api.logStatus("Raport error: " .. tostring(err), 4)
		end
		reportBusy = false
	end)
end

task.spawn(function()
	while running do
		if snapItem and os.clock() < snapUntil and hrp then
			api.holdPose()
		elseif savedBodyCf and os.clock() >= snapUntil then
			api.restoreBody()
		end
		task.wait(0.03)
	end
end)

api.track(UserInputService.InputBegan:Connect(function(inp)
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if state.deleteClick and not api.overOurGui() and not api.buttonUnderMouse() then
		local target = player:GetMouse().Target
		if target and api.deleteClicked(target) then
			return
		end
	end
	local reason = api.buttonUnderMouse()
	if not reason then
		return
	end
	local item = api.pickItem(reason)
	if item then
		api.snapBodyTo(item, (state.reportHold or 24) / 10)
		api.logStatus("Klik typu: " .. reason, 2)
	end
end))

task.spawn(function()
	local monsterAcc = 0
	local noneRefresh = 0
	local reportAcc = 0
	while running do
		local threat = api.readThreat()
		if threat then
			api.handleThreat(threat)
		end
		if state.autoSnap and snapped and not baselineLocked and api.isCleanThreat(string.lower(currentThreat or "")) then
			noneRefresh += 0.55
			if noneRefresh >= (state.threatRefresh or 8) and os.clock() - snapClock >= (state.threatRefresh or 8) then
				noneRefresh = 0
				api.takeSnapshot()
			end
		else
			noneRefresh = 0
		end
		if state.anomaly then
			if not pcall(api.scanAnomalies) then
				scanning = false
			end
		end
		if state.autoReport and not reportBusy and #anomalyItems > 0 then
			reportAcc += 0.28
			if reportAcc >= ((state.autoReportWait or 24) / 10) then
				reportAcc = 0
				local pick
				for _, it in ipairs(anomalyItems) do
					if it.reason == "Intruder" and not reportedIds[api.itemKey(it)] then
						pick = it
						break
					end
				end
				if not pick then
					for _, it in ipairs(anomalyItems) do
						if not reportedIds[api.itemKey(it)] then
							pick = it
							break
						end
					end
				end
				if pick and reportAnomaly then
					reportAnomaly(pick)
				end
			end
		else
			reportAcc = 0
		end
		monsterAcc += 0.28
		if monsterAcc >= 5 then
			monsterAcc = 0
			if state.monster then
				api.scanMonsters()
			end
		end
		task.wait(0.28)
	end
end)

function api.cleanup()
	running = false
	state.fly = false
	state.noclip = false
	state.anomaly = false
	state.stalk = false
	state.deleteClick = false
	state.hardVis = false
	state.ignoreAnomaly = false
	state.circleBait = false
	state.steerAnomaly = false
	pcall(function()
		RunService:UnbindFromRenderStep("AWFly")
	end)
	pcall(api.restoreBody)
	pcall(api.clearHardVis)
	pcall(api.clearWaypoints)
	if pointMarker then
		pcall(function()
			pointMarker:Destroy()
		end)
	end
	api.destroyFly()
	api.setNoclip(false)
	api.clearAllMarks()
	api.clearChams()
	api.clearNames()
	api.clearMonsters()
	api.setFullbright(false)
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
	ENV.AnomalySuiteCleanup = api.cleanup
end
print("zaladowalo sie to kurestwo")
