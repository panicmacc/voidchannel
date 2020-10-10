
--
-- A VCA-Digiline Bridge
--

local vca_models = pri_mods.vca.models

local on_digiline_receive = function (pos, node, channel, msg)
	local station_id = minetest.get_meta(pos):get_string("station_id")
	local station = pri_mods['vca']['stations'][station_id]
	if not station then
		station = vca_models.VCAStation:new(pos)
	end
	local fabric_id  = station.fabric_id

	if channel == fabric_id then
		return station:bridge_fwd_vca_digiline(msg)
	else
		return station:bridge_fwd_digiline_vca(channel, msg)
	end	
end

local get_formspec = function(pos, fields)
	local meta = minetest.get_meta(pos)
	local station_id = meta:get_string("station_id")
	local fabric_id = meta:get_string("fabric_id")
	local tx_seq = -1
	local station = pri_mods['vca']['stations'][station_id]
	if station then
		tx_seq = station.tx_seq
	end
	
	local is_refresh = fields and fields.is_refresh == "true"
	print("In get_formspec. Fields contains: " .. dump(fields) .. " and is_refresh is: " .. tostring(is_refresh))

	local formspec = {
		"formspec_version[3]",
		"size[6.5,4.0]",
		"label[0.75,0.5;", minetest.formspec_escape("SID: " .. station_id), "]",
		"label[0.75,1.0;FID: ]",
		"field[1.25,0.85;3,0.3;fabric_id;;", minetest.formspec_escape(fabric_id), "]",
		"label[0.75,1.5;", minetest.formspec_escape("TX Seq: " .. tx_seq), "]",
		"button[0.75,2.0;1.0,0.5;update;Refresh]",
		"checkbox[2.0,2.25;is_refresh;Auto Refresh;" .. tostring( is_refresh ) .. "]"
	}
	return table.concat(formspec, "")
end

minetest.register_node("voidchannel:bridge_digiline", {
	
    drawtype = "nodebox",
    paramtype = "light",
    node_box = {
        type = "regular"
    },
    description = "Connects digiline to VCA-over-digiline",
    tiles = {
        "priutils_testbox_up.png",    -- y+
        "priutils_testbox_down.png",  -- y-
        "priutils_testbox_right.png", -- x+
        "priutils_testbox_left.png",  -- x-
        "priutils_testbox_front.png",  -- z+
        "priutils_testbox_back.png", -- z-
    },
	color = "blue",
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
	
	on_open = function( pos, player, fields)
		local player_name = player:get_player_name( )
		--minetest.update_form( player_name, get_formspec(pos, fields) )
		return get_formspec(pos, fields)
	end,
		
	on_close = function( pos, player, fields )
		local meta = minetest.get_meta(pos)
		local player_name = player:get_player_name( )
		if fields.quit == minetest.FORMSPEC_SIGTIME then
			fields.is_refresh = "true"
			minetest.update_form( player_name, get_formspec(pos, fields) )
		elseif fields.is_refresh then
			local is_refresh = fields.is_refresh == "true"
			minetest.update_form( player_name, get_formspec(pos, fields) )
			if is_refresh == true then
				minetest.get_form_timer( player_name ).start( 1 )
			else
				minetest.get_form_timer( player_name ).stop( )
			end
		elseif fields.update then
			minetest.update_form(player_name, get_formspec(pos))
		end
	end
	
	--[[
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
			pri_mods['vca']['stations'][station_id].fabric_id = fields.fabric_id
		end
	end,
	]]--

	--[[
    on_timer = function(pos)
        local station_id = minetest.get_meta(pos):get_string("station_id")
		local station = pri_mods['vca']['stations'][station_id]
		if station then
			print("Sending hello from station: " .. dump(station))
			station:send_hello()
		end
		
        return true
    end
	]]--
})
