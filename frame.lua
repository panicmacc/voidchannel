
--
-- A Frame that moves through a VCA Fabric
--

local vca_models = pri_mods.vca.models

vca_models.VCAFrame = {
	opcode = "",		-- VCA opcode. FORWARD, REGISTER, HELLO, etc.
	fabric_id = "",		-- VCA fabric_id
	path = {},			-- VCA station_id of each station that's already forwarded the frame	
	seq = 0,			-- Frame sequence number is tracked per src_id, used for loop mitigation
	proto = "",			-- "digiline", "ham", ...
	payload_sha1 = {}	-- sha1 hash of payload to be forwarded
}

function vca_models.VCAFrame:new(frame_tbl)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	
	o.opcode = frame_tbl.opcode
	o.fabric_id = frame_tbl.fabric_id
	o.path = frame_tbl.path
	o.seq = frame_tbl.seq
	o.proto = frame_tbl.proto
	o.payload_sha1 = frame_tbl.payload_sha1

	return vca_models.VCAFrame.validate(o)
end

function vca_models.VCAFrame.validate(frame)
		
	local valid_frame_cases = {
		
		type(frame.fabric_id) == "string" and
		frame.fabric_id ~= "" and
		frame.opcode == "VOIDPATH_TX" and
		type(frame.seq) == "number" and
		type(frame.path) == "table" and
		frame.path ~= {} and
		type(frame.payload_sha1) == "string" and
		frame.payload_sha1 ~= ""
	}
	
	for _, case in ipairs(valid_frame_cases) do
		if case then
			--print("Frame validator is pleased: " .. dump(frame))
			return frame
		end
	end
	print("Frame validator no likey: " .. dump(frame))
	return nil -- If no valid frame cases checked out, give the caller the bad news
end


