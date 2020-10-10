
--
-- A VCA Switch
--

local vca_models = pri_mods.vca.models

local on_digiline_receive = function (pos, node, channel, msg)
	local station_id = minetest.get_meta(pos):get_string("station_id")
	local station = pri_mods['vca']['stations'][station_id]
	if not station then
		station = vca_models.VCAStation:new(pos)
	end
	local fabric_id  = station.fabric_id

	if channel ~= fabric_id then
		return false
	end
	
	local frame_in = {
		opcode = msg.opcode,
		fabric_id = channel,
		seq = msg.seq,
		path = msg.path,
		proto = msg.proto,
		payload_sha1 = msg.payload_sha1
	}

	--print("[" .. station_id .. "] Got VCA frame: " .. dump(frame_in) .. ". Validating...")
	
	frame_in = vca_models.VCAFrame:new(frame_in)
	
	if not frame_in then
		return false
	end
	
	frame_in = station:check_frame_path(frame_in)
	
	if not frame_in then
		return false
	end
	
	frame_in = station:check_frame_seq(frame_in)
	
	if not frame_in then
		return false
	end
	
    --print("[" .. station_id .. "] Frame passed validations...")

	if frame_in.opcode == "VOIDPATH_TX" then
		station:control_fwd(frame_in)
	end
	
end

minetest.register_node("voidchannel:switch", {
	
    drawtype = "nodebox",
    paramtype = "light",
    node_box = {
        type = "regular"
    },
    description = "Whatever, it's a sweet digilines Node...",
    tiles = {
        "priutils_testbox_up.png",    -- y+
        "priutils_testbox_down.png",  -- y-
        "priutils_testbox_right.png", -- x+
        "priutils_testbox_left.png",  -- x-
        "priutils_testbox_front.png",  -- z+
        "priutils_testbox_back.png", -- z-
    },
	color = "cyan",
    groups = { cracky = 3 },
    is_ground_content = false,
    digiline = {
        receptor = {},
        effector = {
            action = on_digiline_receive
        },
    },
	
	on_construct = function(pos)
		vca_models.VCAStation.handle_node_construct(pos)
	end,
	
    on_destruct = function(pos)
        vca_models.VCAStation.handle_node_construct(pos)
	end,
	
	on_receive_fields = function(pos, _, fields, sender)
		local name = sender:get_player_name()
		if minetest.is_protected(pos, name) and not minetest.check_player_privs(name, {protection_bypass=true}) then
			minetest.record_protection_violation(pos, name)
			return
		end
		if (fields.fabric_id) then
			local meta = minetest.get_meta(pos)
			meta:set_string("fabric_id", fields.fabric_id)
			local station_id = meta:get_string("station_id")
			tacohi['vca']['stations'][station_id].fabric_id = fields.fabric_id
		end
	end,

})