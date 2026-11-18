--!nonstrict
-- Robux monetization configuration for the hot chocolate stand.
--
-- Create these Developer Products in Creator Hub for the Christmas Wonderland
-- experience (Monetization -> Developer Products), then paste each numeric
-- Product ID below. Until an ID is filled in, the matching button tells the
-- player that Robux purchases are not set up yet.

local config = {}

config.DataStoreName = "StreetHoops_CocoaBucks_v1"

config.Products = {
	{ id = 3732962651, robux = 25, bucks = 100, name = "100 Cocoa Bucks" },
	{ id = 3732962691, robux = 60, bucks = 300, name = "300 Cocoa Bucks" },
	{ id = 3732962694, robux = 200, bucks = 1000, name = "1000 Cocoa Bucks" },
}

return config
