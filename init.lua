local STORAGE = minetest.get_mod_storage()
local kills = tonumber(STORAGE:get_string("kills")) or 0
local MAX_KILLS = 1000
local MAX_ACTIVE = 10
local spawn_timer = 0
local SPEED = 3.5

local modpath = minetest.get_modpath("estado_totalitario")
local tex_path = modpath .. "/textures/estado_char.png"
if io.open(tex_path, "r") then
    minetest.log("action", "[estado_totalitario] Texture loaded: estado_char.png")
else
    minetest.log("error", "[estado_totalitario] ERROR: textures/estado_char.png NOT FOUND!")
end

minetest.register_entity("estado_totalitario:npc", {
	hp_max = 20,
	physical = true,
	collide_with_objects = true,
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
	stepheight = 0.6,
	visual = "mesh",
	mesh = "character.b3d",
	textures = {"estado_char.png"},
	visual_size = {x=1, y=1},
	automatic_rotate = 0,
	makes_footstep_sound = true,
	counted = false,
	attack_cd = 0,
	anim_timer = 0,
	jump_cd = 0,

	on_activate = function(self, staticdata, dtime_s)
		self.object:set_armor_groups({fleshy=100})
		self.object:set_acceleration({x=0, y=-9.8, z=0})
		self.attack_cd = 0
		self.anim_timer = 0
		self.jump_cd = 0
	end,

	update_anim = function(self, hspeed)
		if hspeed > 0.5 then
			self.object:set_animation({x = 168, y = 188}, 30, 0, true)
		else
			self.object:set_animation({x = 0,   y = 79},  30, 0, true)
		end
	end,

	on_step = function(self, dtime)
		if self.counted then return end
		local pos = self.object:get_pos()
		if not pos then return end

		local vel = self.object:get_velocity() or {x=0, y=0, z=0}
		local hp = self.object:get_hp()
		local hspeed = math.sqrt(vel.x*vel.x + vel.z*vel.z)

		-- Animation tick
		self.anim_timer = self.anim_timer + dtime
		if self.anim_timer >= 0.2 then
			self:update_anim(hspeed)
			self.anim_timer = 0
		end

		-- Liquid damage
		local node = minetest.get_node(pos)
		local def = minetest.registered_nodes[node.name]
		if def and def.groups.liquid then
			local dmg = node.name:find("lava") and 4 or 1
			hp = hp - dmg
			self.object:set_hp(math.max(0, hp))
			if self.object:get_hp() <= 0 then
				if not self.counted then
					kills = kills + 1
					STORAGE:set_string("kills", tostring(kills))
					self.counted = true
				end
				self.object:remove()
				return
			end
		end

		-- Find nearest player
		local target = nil
		local min_dist = 80
		for _, plr in ipairs(minetest.get_connected_players()) do
			local ppos = plr:get_pos()
			local d = vector.distance(pos, ppos)
			if d < min_dist then min_dist = d; target = plr end
		end

		if target then
			local tpos = target:get_pos()
			local dx = tpos.x - pos.x
			local dz = tpos.z - pos.z
			local flat_dist = math.sqrt(dx*dx + dz*dz)

			if flat_dist > 0.8 then
				local inv = 1 / flat_dist
				local dirx = dx * inv
				local dirz = dz * inv

				-- Smooth rotation
				local want_yaw = math.atan2(-dirx, dirz)
				local cur_yaw  = self.object:get_yaw() or 0
				local diff = want_yaw - cur_yaw
				if diff >  math.pi then diff = diff - 2 * math.pi end
				if diff < -math.pi then diff = diff + 2 * math.pi end
				self.object:set_yaw(cur_yaw + diff * math.min(dtime * 12, 1))

				-- 🔥 MULTI-POINT LIQUID SCAN (0.4 to 1.0 blocks ahead, 3 heights)
				local liquid_ahead = false
				for dist = 0.4, 1.0, 0.3 do
					for y_off = 0.0, -1.0, -0.5 do
						local c = {x=pos.x+dirx*dist, y=pos.y+y_off, z=pos.z+dirz*dist}
						local n = minetest.get_node(c)
						local d = minetest.registered_nodes[n.name]
						if d and d.groups.liquid then
							liquid_ahead = true
						end
					end
				end

				-- 🧱 SOLID OBSTACLE SCAN
				local solid_ahead = false
				local can_jump_over = false
				for dist = 0.6, 1.0, 0.2 do
					local c = {x=pos.x+dirx*dist, y=pos.y+0.5, z=pos.z+dirz*dist}
					local n = minetest.get_node(c)
					local d = minetest.registered_nodes[n.name]
					if d and d.walkable and not d.groups.liquid then
						solid_ahead = true
						local c_up = {x=c.x, y=c.y+1.2, z=c.z}
						local n_up = minetest.get_node(c_up)
						local d_up = minetest.registered_nodes[n_up.name]
						if not d_up or (not d_up.walkable and not d_up.groups.liquid) then
							can_jump_over = true
						end
					end
				end

				--  GROUND CHECK (Strict)
				local below = {x=pos.x, y=pos.y-0.1, z=pos.z}
				local below_def = minetest.registered_nodes[minetest.get_node(below).name]
				local on_ground = below_def and below_def.walkable and math.abs(vel.y) < 0.1

				--  MOVEMENT DECISION TREE
				if liquid_ahead then
					-- 🛑 STOP immediately near liquids
					self.object:set_velocity({x = 0, y = vel.y, z = 0})
					self.jump_cd = 1.0 -- Lock jump
				elseif solid_ahead and can_jump_over and on_ground and self.jump_cd <= 0 then
					-- ⬆️ JUMP over solid obstacles only
					self.object:set_velocity({x = dirx * SPEED, y = 5.0, z = dirz * SPEED})
					self.jump_cd = 1.5
				elseif not solid_ahead then
					--  NORMAL WALK
					self.object:set_velocity({x = dirx * SPEED, y = vel.y, z = dirz * SPEED})
					if self.jump_cd > 0 then self.jump_cd = self.jump_cd - dtime end
				else
					-- 🧱 BLOCKED (Solid but can't jump)
					-- Gentle nudge to prevent wall-sticking, no jump
					self.object:set_velocity({x = dirx * SPEED * 0.2, y = vel.y, z = dirz * SPEED * 0.2})
					if self.jump_cd > 0 then self.jump_cd = self.jump_cd - dtime end
				end
			else
				-- Close enough: stop horizontally, preserve gravity
				self.object:set_velocity({x = 0, y = vel.y, z = 0})
			end

			-- Contact attack
			self.attack_cd = self.attack_cd - dtime
			if min_dist < 1.5 and self.attack_cd <= 0 then
				target:set_hp(target:get_hp() - 2)
				self.attack_cd = 0.8
			end
		else
			-- Idle friction
			self.object:set_velocity({x = vel.x * 0.85, y = vel.y, z = vel.z * 0.85})
		end
	end,

	on_punch = function(self, puncher, _, tool_caps)
		if self.counted then return end
		local dmg = (tool_caps and tool_caps.damage_groups.fleshy) or 4
		self.object:set_hp(math.max(0, self.object:get_hp() - dmg))
	end,

	on_deactivate = function(self)
		if not self.counted and self.object:get_hp() <= 0 then
			kills = kills + 1
			STORAGE:set_string("kills", tostring(kills))
			self.counted = true
		end
	end
})

minetest.register_globalstep(function(dtime)
	if kills >= MAX_KILLS then return end
	spawn_timer = spawn_timer + dtime
	if spawn_timer < 5 then return end
	spawn_timer = 0

	local active = 0
	for _, obj in pairs(minetest.luaentities) do
		if obj.name == "estado_totalitario:npc" then active = active + 1 end
	end
	if active >= MAX_ACTIVE then return end

	local players = minetest.get_connected_players()
	if #players == 0 then return end

	local plr = players[math.random(#players)]
	local ppos = plr:get_pos()
	local angle = math.random() * math.pi * 2
	local dist = 80 + math.random() * 40
	local sx = ppos.x + math.cos(angle) * dist
	local sz = ppos.z + math.sin(angle) * dist

	local ground_y = nil
	for y = ppos.y + 20, ppos.y - 30, -1 do
		local name = minetest.get_node({x=sx, y=y, z=sz}).name
		if name ~= "ignore" then
			local def = minetest.registered_nodes[name]
			if def and def.walkable then
				ground_y = y
				break
			end
		end
	end
	if not ground_y then return end

	local spawn_pos = {x=sx, y=ground_y + 1.5, z=sz}
	for i = 1, 10 do
		local check = minetest.get_node(spawn_pos)
		local check_def = minetest.registered_nodes[check.name]
		if check_def and check_def.walkable then
			spawn_pos.y = spawn_pos.y + 1
		else
			break
		end
	end

	local eye = {x=ppos.x, y=ppos.y + 1.6, z=ppos.z}
	local chest = {x=spawn_pos.x, y=spawn_pos.y + 0.8, z=spawn_pos.z}

	if not minetest.line_of_sight(eye, chest) then
		local obj = minetest.add_entity(spawn_pos, "estado_totalitario:npc")
		if obj then
			obj:set_rotation({x=0, y=angle + math.pi, z=0})
		end
	end
end)

minetest.register_chatcommand("reset_estado", {
	privs = {server = true},
	func = function()
		kills = 0
		STORAGE:set_string("kills", "0")
		minetest.chat_send_all("[Estado] Kill counter reset.")
	end
})

minetest.register_chatcommand("clear_estado", {
	description = "Removes all active estado_totalitario NPCs",
	privs = {server = true},
	func = function(name)
		local count = 0
		for _, obj in pairs(minetest.luaentities) do
			if obj.name == "estado_totalitario:npc" then
				obj.object:remove()
				count = count + 1
			end
		end
		minetest.chat_send_player(name, "[Estado] Removed " .. count .. " NPCs.")
	end
})
