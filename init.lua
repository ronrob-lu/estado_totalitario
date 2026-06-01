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

	update_anim = function(self)
		local vel = self.object:get_velocity() or {x=0,y=0,z=0}
		local hspeed = math.sqrt(vel.x*vel.x + vel.z*vel.z)
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

		self.anim_timer = self.anim_timer + dtime
		if self.anim_timer >= 0.15 then
			self:update_anim()
			self.anim_timer = 0
		end

		self.jump_cd = self.jump_cd - dtime

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

				-- Rotation
				local want_yaw = math.atan2(-dirx, dirz)
				local cur_yaw  = self.object:get_yaw() or 0
				local diff = want_yaw - cur_yaw
				if diff >  math.pi then diff = diff - 2 * math.pi end
				if diff < -math.pi then diff = diff + 2 * math.pi end
				self.object:set_yaw(cur_yaw + diff * math.min(dtime * 12, 1))

				--  LIQUID AVOIDANCE (Strict)
				local liquid_ahead = false
				local check_fwd = {x = pos.x + dirx * 0.6, y = pos.y, z = pos.z + dirz * 0.6}
				local check_fwd_below = {x = pos.x + dirx * 0.6, y = pos.y - 1, z = pos.z + dirz * 0.6}
				
				local n1 = minetest.registered_nodes[minetest.get_node(check_fwd).name]
				local n2 = minetest.registered_nodes[minetest.get_node(check_fwd_below).name]
				if (n1 and n1.groups.liquid) or (n2 and n2.groups.liquid) then
					liquid_ahead = true
				end

				if liquid_ahead then
					-- COMPLETE STOP near liquids
					self.object:set_velocity({x = 0, y = 0, z = 0})
				else
					-- ✅ SAFE TO MOVE
					local vy = vel.y
					self.object:set_velocity({x = dirx * SPEED, y = vy, z = dirz * SPEED})

					--  ROBUST JUMP & ANTI-STUCK LOGIC
					local ground_node = minetest.get_node({x=pos.x, y=pos.y - 0.1, z=pos.z})
					local ground_def = minetest.registered_nodes[ground_node.name]
					local is_grounded = ground_def and ground_def.walkable and vel.y > -1.5 and vel.y < 0.8

					if is_grounded and self.jump_cd <= 0 then
						local obstacle_found = false
						-- Scan multiple points ahead (0.5 to 1.2 blocks)
						for i = 0.5, 1.2, 0.3 do
							local obs_pos = {x = pos.x + dirx * i, y = pos.y + 0.3, z = pos.z + dirz * i}
							local obs_def = minetest.registered_nodes[minetest.get_node(obs_pos).name]
							if obs_def and obs_def.walkable and not obs_def.groups.liquid then
								local above_pos = {x = obs_pos.x, y = pos.y + 1.7, z = obs_pos.z}
								local above_def = minetest.registered_nodes[minetest.get_node(above_pos).name]
								if not above_def or (not above_def.walkable and not above_def.groups.liquid) then
									obstacle_found = true
									break
								end
							end
						end

						-- Stuck detection: grounded, facing player, but barely moving
						local hspeed = math.sqrt(vel.x*vel.x + vel.z*vel.z)
						local is_stuck = hspeed < 0.6 and flat_dist > 3.0

						if obstacle_found or is_stuck then
							self.object:set_velocity({x = dirx * SPEED, y = 4.8 + math.random()*0.4, z = dirz * SPEED})
							self.jump_cd = 0.7
						end
					end
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
