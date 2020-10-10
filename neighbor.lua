
--
-- A VCA Neighbor is a reference kept by one Station to another Station that is currently reachable
--

local vca_models = tacohi.vca.models

vca_models.VCANeighbor = {
	station = {},				-- unique id of the Station on the fabric; assigned to Station by a Switch during registration
	last_seen = "",
}

function vca_models.VCANeighbor:new(neighbor_id)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.station = tacohi['vca']['stations'][neighbor_id]
	o.last_seen = minetest.get_gametime()
	return o
end

function vca_models.VCANeighbor:update()
	self.last_seen = minetest.get_gametime()
end