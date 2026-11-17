--!nonstrict
-- Robux purchases for the hot chocolate stand.
--
-- Developer Product IDs live in CocoaMonetizationConfig. Purchases are saved
-- with a DataStore (so real money is never lost on a server hop), and the
-- player's live Cocoa Bucks attribute is updated immediately. All saving is
-- wrapped in pcall so the game still runs when API services are off in Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local config = require(ReplicatedStorage:WaitForChild("CocoaMonetizationConfig", 10))
if not config then
	warn("[CocoaMoney] monetization config missing")
	return
end

local remotes = ReplicatedStorage:WaitForChild("CocoaRemotes", 10)
if not remotes then
	warn("[CocoaMoney] CocoaRemotes missing")
	return
end
local BuyBucks = remotes:FindFirstChild("BuyBucks")
if not BuyBucks then
	BuyBucks = Instance.new("RemoteEvent")
	BuyBucks.Name = "BuyBucks"
	BuyBucks.Parent = remotes
end
local Result = remotes:WaitForChild("Result")

local store = DataStoreService:GetDataStore(config.DataStoreName)

local function key(player)
	return "User_" .. player.UserId
end

local function load(player)
	local ok, saved = pcall(function()
		return store:GetAsync(key(player))
	end)
	if ok and type(saved) == "number" then
		player:SetAttribute("CocoaBucks", math.max(0, math.floor(saved)))
	end
end

local function save(player)
	local amount = player:GetAttribute("CocoaBucks")
	if type(amount) ~= "number" then
		return
	end
	pcall(function()
		store:SetAsync(key(player), math.max(0, math.floor(amount)))
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(1) -- let CocoaShop set its starting balance first
		load(player)
	end)
end
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(1)
		load(player)
	end)
end)
Players.PlayerRemoving:Connect(save)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

-- Periodically persist any Cocoa Bucks earned through normal play.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)

local function productFor(id)
	for _, product in ipairs(config.Products) do
		if product.id ~= 0 and product.id == id then
			return product
		end
	end
	return nil
end

BuyBucks.OnServerEvent:Connect(function(player, productId)
	local product = productFor(tonumber(productId))
	if not product then
		Result:FireClient(player, "Robux cocoa isn't set up yet — check back soon!")
		return
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.id)
	end)
	if not ok then
		Result:FireClient(player, "Couldn't open the Robux purchase right now.")
	end
end)

-- Roblox calls this only after a successful payment. Returning PurchaseGranted
-- stops retries; unknown products stay NotProcessedYet so no sale is lost.
MarketplaceService.ProcessReceipt = function(receipt)
	local product = productFor(receipt.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player then
		player:SetAttribute("CocoaBucks", (player:GetAttribute("CocoaBucks") or 0) + product.bucks)
		Result:FireClient(player, "+" .. product.bucks .. " Cocoa Bucks from your Robux purchase!")
	end
	local ok, updated = pcall(function()
		return store:UpdateAsync(key({ UserId = receipt.PlayerId }), function(old)
			return (type(old) == "number" and old or 0) + product.bucks
		end)
	end)
	if not ok or updated == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
