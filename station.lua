
--
-- A VCA Station; could be a Client, Switch, Router, Bridge, Firewall, etc..
--

local vca_models = pri_mods.vca.models

vca_models.VCAStation = {
	fabric_id = "",					-- id of the Fabric this Station is participating in
	station_id = "",				-- unique id of the Station on the fabric; assigned to Station by a Switch during registration
	tx_seq = 0,						-- increment this for each Frame I originate in the fabric
	tx_counters = {},				-- a place to track which frames we've already seen from each remote station
}

function vca_models.VCAStation.generate_station_id()
	return string.format("%04x-%04x-%04x", math.random(0x0, 0xffff), math.random(0x0, 0xffff), math.random(0x0, 0xffff))
end

function vca_models.VCAStation.handle_node_construct(pos)
	local meta = minetest.get_meta(pos)

	local fabric_id = 'fabric_1'

	meta:set_string("fabric_id", fabric_id)
	meta:set_string("station_id", vca_models.VCAStation.generate_station_id())

	local station = vca_models.VCAStation:new(pos)
	local station_id = station.station_id

	meta:set_string("infotext", "Station ID: " .. station.station_id .. "\nFabric ID: " .. station.fabric_id)

	--[[local formspec = {
		"formspec_version[3]",
		"size[6.5,4.0]",
		"label[0.75,0.5;", minetest.formspec_escape("SID: " .. station.station_id), "]",
		"field[0.75,1.5;5.25,0.3;fabric_id;Fabric ID;${fabric_id}]"
	}
	meta:set_string("formspec", table.concat(formspec, ""))
	]]--
end

function vca_models.VCAStation.handle_node_destruct(pos)
	return
end

function vca_models.VCAStation:new(station_pos)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	local meta = minetest.get_meta(station_pos)
	
	o.fabric_id = meta:get_string("fabric_id")
	o.station_id = meta:get_string("station_id")
	o.tx_seq = 0
	o.tx_counters = {}
	o.station_pos = station_pos
	
	pri_mods['vca']['stations'][o.station_id] = o
	
	return o
end

function vca_models.VCAStation:get_formspec()
	local formspec = {
		"formspec_version[3]",
		"size[6.5,4.0]",
		"label[0.75,0.5;", minetest.formspec_escape("SID: " .. station.station_id), "]",
		"field[0.75,1.5;5.25,0.3;fabric_id;Fabric ID;${fabric_id}]"
	}
	return formspec
end

function vca_models.VCAStation:check_frame_seq(frame)
	-- FIXME: Add a window to allow out-of-order frames

	local src_station_id = frame.path[1]
	local last_frame_seen = self.tx_counters[src_station_id]
	
	if frame.seq == 0 then
		--print("Frame has seq = 0. Resetting TX seq for Station: " .. src_station_id .. " and allowing...")
		self.tx_counters[src_station_id] = frame.seq
		return frame
	end

	if not last_frame_seen then
		--print("No existing TX seq for Station: " .. src_station_id .. ". Starting TX seq at: " .. frame.seq .. " and allowing...")
		self.tx_counters[src_station_id] = frame.seq
		return frame
	end
	
	if frame.seq > last_frame_seen then
		--print("Frame passed seq check. TX counter was: " .. dump(last_frame_seen) .. ". Setting TX counter to: " .. frame.seq .. "...")
		self.tx_counters[src_station_id] = frame.seq
		return frame
    end
	
	print("Frame failed seq check. Frame seq: " .. frame.seq .. " TX counter: " .. last_frame_seen .. ". Dropping...")
	return nil
end

function vca_models.VCAStation:check_frame_path(frame)
	for _, station_id in ipairs(frame.path) do
		if station_id == self.station_id then
			--print("Frame failed path check. Frame: " .. dump(frame) .. " My Station ID: " .. dump(self.station_id) .. ". Dropping.")
			return nil
		end
	end
	--print("Frame passed path check. Frame: " .. dump(frame) .. " My Station ID: " .. dump(self.station_id) .. ".")
	return frame
end

function vca_models.VCAStation:control_tx(opcode, path, payload_sha1)
		
	if path then
		path[ #path + 1 ] = self.station_id
	else
		path = { self.station_id }
	end
	
	local out_frame = {
		opcode = opcode,
		fabric_id = self.fabric_id,
		path = path,
		seq = self.tx_seq,
		proto = 'digiline',
		payload_sha1 = payload_sha1
	}
	out_frame = vca_models.VCAFrame:new(out_frame)
	--print("Station " .. self.station_id .. " sending frame: \n" .. dump(out_frame))
	self.tx_seq = self.tx_seq + 1
	digilines.receptor_send(self.station_pos, digilines.rules.default, self.fabric_id, out_frame)

end

function vca_models.VCAStation:control_fwd(frame)
	
	if frame.path then
		frame.path[ #frame.path + 1 ] = self.station_id
	else
		frame.path = { self.station_id }
	end
	
	frame = vca_models.VCAFrame:new(frame)
	--print("Station " .. self.station_id .. " forwarding frame: \n" .. dump(out_frame))
	digilines.receptor_send(self.station_pos, digilines.rules.default, self.fabric_id, frame)
end

function vca_models.VCAStation:digiline_tx(channel, msg)
	digilines.receptor_send(self.station_pos, digilines.rules.default, channel, msg)
end

function vca_models.VCAStation:bridge_fwd_vca_digiline(msg)
	local frame_in = {
		opcode = msg.opcode,
		fabric_id = self.fabric_id,
		seq = msg.seq,
		path = msg.path,
		proto = msg.proto,
		payload_sha1 = msg.payload_sha1
	}

	--print("[Bridge " .. self.station_id .. "] Got VCA frame: \n" .. dump(frame_in) .. "\nValidating...")
	
	frame_in = vca_models.VCAFrame:new(frame_in)
	
	if not frame_in then
		return false
	end
	
	frame_in = self:check_frame_path(frame_in)
	
	if not frame_in then
		return false
	end
	
	frame_in = self:check_frame_seq(frame_in)
	
	if not frame_in then
		return false
	end
	
    --print("[Bridge " .. self.station_id .. "] Frame passed validations...")

	if frame_in.opcode == "VOIDPATH_TX" then
		--print("[Bridge " .. self.station_id .. "] Got good VOIDPATH_TX control frame. Fetching data frame from cache...")
	end
	
	local payload_sha1 = frame_in.payload_sha1
	local cache_entry = pri_mods.vca.fastpath_cache[payload_sha1]
	
	if not cache_entry or not cache_entry.payload then
		print("[Bridge " .. self.station_id .. "] Failed to get entry from cache or entry had no payload for sha1 " .. payload_sha1 .. ". Something's not right. Giving up..")
		return false
	end
	
	print("[Bridge " .. self.station_id .. "] Successfully fetched payload from VCA cache.\nChannel: " .. cache_entry.payload.channel .. "\nSHA1: " .. payload_sha1 .. " from cache.\nForwarding...")
	pri_mods.vca.fastpath_cache[payload_sha1].counters.rx_frames = pri_mods.vca.fastpath_cache[payload_sha1].counters.rx_frames + 1
	self:digiline_tx(cache_entry.payload.channel, cache_entry.payload.msg)
	
	return true
end

function vca_models.VCAStation:bridge_fwd_digiline_vca(channel, msg)
	-- Prepare payload and payload sha1 for push to VCA cache
	local payload = {
		channel = channel,
		msg = msg
	}
	local payload_sha1 = minetest.sha1(minetest.serialize(payload))
	print("[Bridge " .. self.station_id .. "] got digiline frame to encapsulate. \nChannel: " .. channel .. "\nSHA1: " .. payload_sha1 .. "\nMessage:\n" .. dump(msg) )
	
	local vca_cache_entry = pri_mods.vca.fastpath_cache[payload_sha1]
	
	if not vca_cache_entry then
		vca_cache_entry = {
			payload = payload,
			counters = {
				rx_frames = 0,
				tx_frames = 0
			}
		}
		pri_mods.vca.fastpath_cache[payload_sha1] = vca_cache_entry
	end

	pri_mods.vca.fastpath_cache[payload_sha1].counters.tx_frames = pri_mods.vca.fastpath_cache[payload_sha1].counters.tx_frames + 1
	self:control_tx('VOIDPATH_TX', nil, payload_sha1)
	
	return true
end