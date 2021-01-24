grapple_pickup = new_type()
grapple_pickup.spr = 20
grapple_pickup.draw = function(self)
	spr(self.spr, self.x, self.y + sin(time()) * 2, 1, 1, not self.right)
end

spike_v = new_type()
spike_v.spr = 36
spike_v.init = function(self)
	if self:check_solid(0, -1) then
		self.flip_y = true
		self.hazard = 3
	else
		self.hit_y = 5
		self.hazard = 2
	end
	self.hit_h = 3
end

spike_h = new_type()
spike_h.spr = 37
spike_h.init = function(self)
	if self:check_solid(-1, 0) then
		self.flip_x = true
		self.hazard = 4
	else
		self.hit_x = 5
		self.hazard = 5
	end
	self.hit_w = 3
end

snowball = new_type()
snowball.spr = 62
snowball.grapple_mode = 3
snowball.holdable = true
snowball.thrown_timer = 0
snowball.update = function(self)
	if not self.held then
		if self.thrown_timer > 0 then
			self.thrown_timer -= 1
		end

		--speed
		if self.speed_x != 0 then
			self.speed_x = approach(self.speed_x, sgn(self.speed_x) * 2, 0.1)
		end

		--gravity
		local on_ground = self:check_solid(0, 1)
		if not on_ground then
			self.speed_y = approach(self.speed_y, 4, 0.4)
		end

		--apply
		self:move_x(self.speed_x, self.on_collide_x)
		self:move_y(self.speed_y, self.on_collide_y)

		if self.y > level.height * 8 + 24 then
			self.destroyed = true
		end
	end
end
snowball.on_collide_x = function(self, moved, total)
	self.speed_x *= -1
	self.remainder_x = 0
	self.freeze = 1
	return true
end
snowball.on_collide_y = function(self, moved, total)
	if self.speed_y >= 4 then
		self.speed_y = -2
	elseif self.speed_y >= 1 then
		self.speed_y = -1
	else
		self.speed_y = 0
	end
	self.remainder_y = 0
	return true
end
snowball.on_release = function(self, thrown)
	if thrown then
		self.thrown_timer = 5
	end
end

springboard = new_type()
springboard.spr = 11
springboard.grapple_mode = 3
springboard.holdable = true
springboard.thrown_timer = 0
springboard.update = function(self)
	if not self.held then
		local on_ground = self:check_solid(0, 1)

		if self.thrown_timer > 0 then
			self.thrown_timer -= 1
		end

		--friction and gravity	
		if on_ground then
			self.speed_x = approach(self.speed_x, 0, 0.6)
		else
			self.speed_y = approach(self.speed_y, 4, 0.4)
		end

		--apply
		self:move_x(self.speed_x, self.on_collide_x)
		self:move_y(self.speed_y, self.on_collide_y)

		if self.y > level.height * 8 + 24 then
			self.destroyed = true
		end
	end
end
springboard.on_collide_x = function(self, moved, total)
	self.speed_x *= -0.2
	self.remainder_x = 0
	self.freeze = 1
	return true
end
springboard.on_collide_y = function(self, moved, total)
	if self.speed_y >= 2 then
		self.speed_y *= -0.5
	else
		self.speed_y = 0
	end
	self.remainder_y = 0
	return true
end
springboard.on_release = function(self, thrown)
	if thrown then
		self.thrown_timer = 5
	end
end

grappler = new_type()
grappler.spr = 46
grappler.grapple_mode = 2
grappler.hit_x = -1
grappler.hit_y = -1
grappler.hit_w = 10
grappler.hit_h = 10

bridge = new_type()
bridge.spr = 63
bridge.falling = false
bridge.update = function(self)
	self.y += 3 * (self.falling and 1 or 0)
end

berry = new_type()
berry.spr = 21
berry.update = function(self)
	if self.collected then
		self.timer += 1
		if self.timer > 5 then
			self.y -= 0.2
		end
		if self.timer > 30 then
			self.destroyed = true
		end
	elseif self.player then
		self.x += (self.player.x - self.x) / 8
		self.y += (self.player.y - 4 - self.y) / 8
		self.flash -= 1

		if self.player:check_solid(0, 1) or self.player.x > level.width * 8 - 16 then
			collected[self.id] = true
			berry_count += 1
			self.collected = true
			self.timer = 0
			self.draw = score
		end
	end
end
berry.collect = function(self, player)
	if not self.player then
		self.player = player
		self.flash = 5
	end
end
berry.draw = function(self)
	if not self.timer or self.timer < 5 then
		grapple_pickup.draw(self)
		if self.flash and self.flash > 0 then
			circ(self.x + 4, self.y + 4, self.flash * 3, 7)
			circfill(self.x + 4, self.y + 4, 5, 7)
		end
	else
		print("1000", self.x - 4, self.y + 1, 8)
		print("1000", self.x - 4, self.y, self.timer % 4 < 2 and 7 or 14)
	end
end

crumble = new_type()
crumble.spr = 19
crumble.geom = g_solid
crumble.grapple_mode = 1
crumble.init = function(self)
	self.time = 0
	self.breaking = false
	self.ox = self.x
	self.oy = self.y
end
crumble.update = function(self)
	if self.breaking then
		self.time += 1
		if self.time > 10 then
			self.x = -32
			self.y = -32
		end
		if self.time > 90 then
			self.x = self.ox
			self.y = self.oy

			local can_respawn = true
			for o in all(objects) do
				if self:overlaps(o) then can_respawn = false break end
			end

			if can_respawn then
				self.breaking = false
				self.time = 0
			else
				self.x = -32
				self.y = -32
			end
		end
	end
end
crumble.draw = function(self)
	spr(self.spr, self.x, self.y)
	if self.time > 2 then
		fillp(0b1010010110100101.1)
		rectfill(self.x, self.y, self.x + 7, self.y + 7, 1)
		fillp()
	end
end
crumble.fall = function(self)
	self.breaking = true
end

checkpoint = new_type()
checkpoint.spr = 13
checkpoint.init = function(self)
	if level_checkpoint == self.id then
		create(player, self.x, self.y)
	end
end
checkpoint.set = function(self)
	level_checkpoint = self.id
end
checkpoint.draw = function(self)
	if level_checkpoint == self.id then
		local tx = 104
		sspr(tx, 0, 1, 8, self.x, self.y)
		pal(2, 11)
		for i=1,7 do
			sspr(tx + i, 0, 1, 8, self.x + i, self.y + sin(-time() * 2 + i * 0.25) * (i - 1) * 0.2)
		end
		pal()
	else
		spr(13, self.x, self.y)
	end
end