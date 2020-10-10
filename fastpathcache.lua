--
-- An entry in the global fastpath cache table, where fastpath-forwarded frame payloads are stored
-- Indexed by the sha1 of the payload so the cache entry can be easily recalled
--

local vca_models = pri_mods.vca.models

vca_models.VCAFastpathCacheEntry = {
	timestamp = 0,
	payload = nil,
	payload_sha1 = ""
}

function vca_models.VCAFastpathCacheEntry:new(payload)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.payload = payload
	o.payload_sha1 = minetest.sha1(payload)
	return o
end

function vca_models.VCAFastpathCacheEntry:forward(egress_id)
	egress_station = pri_mods['vca']['stations'][egress_id]
	if egress_station then
		self.timestamp = minetest.get_worldtime()
		egress_station.fastpath_receive(self.payload_sha1)
	end
end
