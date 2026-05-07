local plr = game:GetService("Players").LocalPlayer
local rf = game:GetService("ReplicatedFirst")
local uis = game:GetService("UserInputService")
local sg = game:GetService("StarterGui")

local ep = require(rf:WaitForChild("providers"):WaitForChild("common"):WaitForChild("emoteProvider"))

local pg = plr:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("EPROBE2")
if old then
	old:Destroy()
end

local g = Instance.new("ScreenGui")
g.Name = "EPROBE2"
g.ResetOnSpawn = false
g.Parent = pg

local f = Instance.new("Frame")
f.Parent = g
f.Size = UDim2.new(0, 520, 0, 260)
f.Position = UDim2.new(1, -540, 0, 100)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
f.BorderSizePixel = 0

local top = Instance.new("TextButton")
top.Parent = f
top.Size = UDim2.new(1, 0, 0, 28)
top.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
top.BorderSizePixel = 0
top.Text = "EMOTE PROBE - DRAG"
top.Font = Enum.Font.Code
top.TextSize = 18
top.TextColor3 = Color3.new(1, 1, 1)
top.AutoButtonColor = false

local txt = Instance.new("TextBox")
txt.Parent = f
txt.Position = UDim2.new(0, 6, 0, 34)
txt.Size = UDim2.new(1, -12, 1, -40)
txt.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
txt.BorderSizePixel = 0
txt.ClearTextOnFocus = false
txt.MultiLine = true
txt.TextEditable = false
txt.TextWrapped = true
txt.Font = Enum.Font.Code
txt.TextSize = 14
txt.TextColor3 = Color3.new(1, 1, 1)
txt.TextXAlignment = Enum.TextXAlignment.Left
txt.TextYAlignment = Enum.TextYAlignment.Top
txt.Text = "booting..."

local dragging = false
local dragStart: Vector3? = nil
local startPos: UDim2? = nil

top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = f.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

uis.InputChanged:Connect(function(input)
	if dragging and dragStart and startPos and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		f.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + d.X,
			startPos.Y.Scale,
			startPos.Y.Offset + d.Y
		)
	end
end)

local cached = {}

pcall(function()
	cached = ep:requestEmotes() or {}
	print("cached emotes", #cached)

	if cached[1] then
		print("example cached emote id", cached[1].Id or cached[1].id)
	end
end)

ep.emotesChanged:Connect(function(list)
	cached = list or {}
	print("emotesChanged", #cached)
end)

local function getHumanoid(): Humanoid?
	local c = plr.Character
	if not c then
		return nil
	end

	return c:FindFirstChildOfClass("Humanoid")
end

local function getAnimator(): Animator?
	local h = getHumanoid()
	if not h then
		return nil
	end

	return h:FindFirstChildOfClass("Animator")
end

local function getModelName(inst: Instance): string
	local model = inst:FindFirstAncestorOfClass("Model")
	if model then
		return model:GetFullName()
	end

	return inst:GetFullName()
end

local function looksLikePartnerClone(inst: Instance): boolean
	local node: Instance? = inst

	while node and node ~= workspace do
		local n = string.lower(node.Name)

		if string.find(n, "partner", 1, true) or string.find(n, "clone", 1, true) then
			return true
		end

		node = node.Parent
	end

	return false
end

local function collectAnimators(): {{ label: string, animator: Animator }}
	local found: {{ label: string, animator: Animator }} = {}
	local seen: {[Animator]: boolean} = {}

	local playerAnimator = getAnimator()
	if playerAnimator then
		seen[playerAnimator] = true
		table.insert(found, {
			label = "PLAYER",
			animator = playerAnimator,
		})
	end

	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Animator") and not seen[inst] and looksLikePartnerClone(inst) then
			seen[inst] = true

			table.insert(found, {
				label = "PARTNER/CLONE " .. getModelName(inst),
				animator = inst,
			})
		end
	end

	return found
end

local function readTracks(animatorInfo: { label: string, animator: Animator }): {string}
	local rows: {string} = {}
	local tracks = animatorInfo.animator:GetPlayingAnimationTracks()

	for _, tr in ipairs(tracks) do
		local anim = tr.Animation
		local animId = anim and anim.AnimationId or ""

		if animId ~= "" then
			local row = string.format(
				"[%s] %s | %s",
				animatorInfo.label,
				animId,
				tr.Name or "track"
			)

			table.insert(rows, row)
			print("emote track", row)
		end
	end

	return rows
end

local function getTrackIds(): string
	local rows: {string} = {}

	for _, animatorInfo in ipairs(collectAnimators()) do
		for _, row in ipairs(readTracks(animatorInfo)) do
			table.insert(rows, row)
		end
	end

	if #rows == 0 then
		return "no playing animation ids found"
	end

	return table.concat(rows, "\n")
end

local currentId = nil

local function refresh()
	txt.Text =
		"GAME EMOTE ID/KEY: " .. tostring(currentId) ..
		"\n\nROBLOX ANIMATION IDS / TRACKS:\n" .. getTrackIds()
end

ep.stateChanged:Connect(function(st)
	currentId = st and st.CurrentEmote
	print("CurrentEmote", currentId)

	task.wait(0.15)
	refresh()

	task.wait(0.5)
	refresh()

	task.wait(1)
	refresh()
end)

plr.CharacterAdded:Connect(function()
	task.wait(2)
	refresh()
end)

txt.Text = "loaded\nclick an emote now"

pcall(function()
	sg:SetCore("SendNotification", {
		Title = "Probe",
		Text = "Click an emote now",
		Duration = 4,
	})
end)

task.spawn(function()
	while g.Parent do
		refresh()
		task.wait(0.75)
	end
end)
