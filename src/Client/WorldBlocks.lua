--[[
	WorldBlocks: syncs the track list to Part instances in workspace.
	Each track gets a block with track name and optional cover art (asset thumbnail).
]]

local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local BLOCK_SPACING = 10
local BLOCK_SIZE = Vector3.new(6, 8, 1) -- wide x tall x deep
local CONTAINER_NAME = "RoAudioBlocks"
local BLOCK_PREFIX = "Track_"

local WorldBlocks = {}

local _container = nil
local _trackNames = {} -- assetId -> name (cached)

local function getContainer(): Instance
	if _container and _container.Parent then
		return _container
	end
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing then
		_container = existing
		return _container
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = Workspace
	_container = folder
	return _container
end

local function fetchTrackName(assetId: string): string
	if _trackNames[assetId] then
		return _trackNames[assetId]
	end
	local id = tonumber(assetId)
	if not id then return "ID: " .. string.sub(assetId, 1, 12) end
	local ok, result = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
	end)
	if ok and type(result) == "table" and type(result.Name) == "string" and #result.Name > 0 then
		_trackNames[assetId] = result.Name
		return result.Name
	end
	_trackNames[assetId] = "ID: " .. string.sub(assetId, 1, 12)
	return _trackNames[assetId]
end

-- Thumbnail: try rbxthumb format for asset (may work for audio/catalog assets)
local function getThumbnailImage(assetId: string): string?
	local id = tonumber(assetId)
	if not id then return nil end
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

local function buildBlock(assetId: string, index: number): Instance
	local name = fetchTrackName(assetId)
	local container = getContainer()
	local part = Instance.new("Part")
	part.Name = BLOCK_PREFIX .. assetId
	part.Size = BLOCK_SIZE
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(45, 45, 55)
	part.Position = Vector3.new((index - 1) * BLOCK_SPACING, 3, -20)
	part.Parent = container

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "TrackGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = part

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "Cover"
	imageLabel.Size = UDim2.new(1, 0, 0.65, 0)
	imageLabel.Position = UDim2.new(0, 0, 0, 0)
	imageLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	imageLabel.BorderSizePixel = 0
	imageLabel.ScaleType = Enum.ScaleType.Fit
	local thumb = getThumbnailImage(assetId)
	if thumb then
		imageLabel.Image = thumb
	else
		imageLabel.Image = ""
	end
	imageLabel.Parent = surfaceGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Title"
	textLabel.Size = UDim2.new(1, -8, 0.35, -4)
	textLabel.Position = UDim2.new(0, 4, 0.65, 2)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = name
	textLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	textLabel.TextSize = 14
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = surfaceGui

	return part
end

function WorldBlocks.sync(trackAssetIds: { string })
	local container = getContainer()
	local existing = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #BLOCK_PREFIX) == BLOCK_PREFIX then
			local aid = string.sub(child.Name, #BLOCK_PREFIX + 1, -1)
			existing[aid] = child
		end
	end

	for aid, part in pairs(existing) do
		local found = false
		for _, id in ipairs(trackAssetIds) do
			if id == aid then found = true break end
		end
		if not found then
			part:Destroy()
		end
	end

	for i, assetId in ipairs(trackAssetIds) do
		local part = existing[assetId]
		if part and part.Parent then
			part.Position = Vector3.new((i - 1) * BLOCK_SPACING, 3, -20)
			local gui = part:FindFirstChild("TrackGui")
			if gui then
				local title = gui:FindFirstChild("Title")
				if title and title:IsA("TextLabel") then
					title.Text = fetchTrackName(assetId)
				end
			end
		else
			buildBlock(assetId, i)
		end
	end
end

function WorldBlocks.clear()
	if _container and _container.Parent then
		_container:Destroy()
		_container = nil
	end
end

return WorldBlocks
