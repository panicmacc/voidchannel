print("Loading voidchannel...")

if not pri_mods then
	pri_mods = { description = "Runtime data for mods Panic Recursive Industries mods." }
end

pri_mods.vca = {
	models = {},
	stations = {},
	fastpath_cache = {}
}

local modpath = minetest.get_modpath("voidchannel")

dofile(modpath .. "/frame.lua")
dofile(modpath .. "/fastpathcache.lua")
dofile(modpath .. "/station.lua")
dofile(modpath .. "/switch.lua")
dofile(modpath .. "/bridge.lua")

print("Voidchannel loading complete.")
