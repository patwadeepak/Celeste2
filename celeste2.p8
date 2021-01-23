pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

-- globals
room = 0
objects = {}
snow = {}
clouds = {}

function _init()

	for i=0,25 do
		snow[i] = { x = rnd(132), y = rnd(132) }
	end
	for i=0,25 do
		clouds[i] = { x = rnd(132), y = rnd(132), s = 16 + rnd(32) }
	end

	room_load(0)
end
-->8

freeze_time = 0

input_x = 0
input_y = 0
input_x_turned = false
input_y_turned = false
input_jump = false
input_jump_pressed = 0
input_grapple = false
input_grapple_pressed = 0

function consume_jump_press()
	local val = input_jump_pressed > 0
	input_jump_pressed = 0
	return val
end

function consume_grapple_press()
	local val = input_grapple_pressed > 0
	input_grapple_pressed = 0
	return val
end

function _update()

	-- input_x
	local prev_x = input_x
	if (btn(0)) then
		if (btn(1)) then
			if (input_x_turned) then
				input_x = prev_x
			else
				input_x = -prev_x
				input_x_turned = true
			end
		else
			input_x = -1
			input_x_turned = false
		end
	elseif (btn(1)) then
		input_x = 1
		input_x_turned = false
	else
		input_x = 0
		input_x_turned = false
	end

	-- input_y
	local prev_y = input_y
	if (btn(2)) then
		if (btn(3)) then
			if (input_y_turned) then
				input_y = prev_y
			else
				input_y = -prev_y
				input_y_turned = true
			end
		else
			input_y = -1
			input_y_turned = false
		end
	elseif (btn(3)) then
		input_y = 1
		input_y_turned = false
	else
		input_y = 0
		input_y_turned = false
	end

	-- input_jump
	local jump = btn(4)
	if (jump and not input_jump) then		
		input_jump_pressed = 4
	elseif (jump) then
		input_jump_pressed = max(0, input_jump_pressed - 1)
	else
		input_jump_pressed = 0
	end
	input_jump = jump

	-- input_grapple
	local grapple = btn(5)
	if (grapple and not input_grapple) then
		input_grapple_pressed = 4
	elseif (grapple) then
		input_grapple_pressed = max(0, input_grapple_pressed - 1)
	else
		input_grapple_pressed = 0
	end
	input_grapple = grapple

	--freeze
	if (freeze_time > 0) then
		freeze_time -= 1
	else
		--objects
		for o in all(objects) do
			o:update()
			if (o.destroyed) then
				del(objects, o)
			end
		end
	end
end
-->8
function _draw()

	local camera_x = peek2(0x5f28)
	local camera_y = peek2(0x5f2a)

	-- clear screen
	cls(0)

	-- draw clouds
	local cc = 13
	for i=0,#clouds do
		local c = clouds[i]
		local x = camera_x + (c.x - camera_x * 0.9) % (128 + c.s) - c.s / 2
		local y = camera_y + (c.y - camera_y * 0.9) % (128 + c.s / 2)
		clip(x - c.s / 2 - camera_x, y - c.s / 2 - camera_y, c.s, c.s / 2)
		circfill(x, y, c.s / 3, cc)
		if (i % 2 == 0) then
			circfill(x - c.s / 3, y, c.s / 5, cc)
		end
		if (i % 2 == 0) then
			circfill(x + c.s / 3, y, c.s / 6, cc)
		end
		c.x += (4 - i % 4) * 0.25
	end
	clip(0,0,128,128)

	-- draw tileset
	map((room % 4) * 16, (room / 4) * 16, 0, 0, 32, 16, 1)

	-- draw objects
	local p = nil
	for o in all(objects) do
		if (o.base == player) then p = o else o:draw() end
	end
	if (p) then p:draw() end

	-- draw snow
	for i=1,#snow do
		circfill(camera_x + (snow[i].x - camera_x * 0.5) % 132 - 2, camera_y + (snow[i].y - camera_y * 0.5) % 132, i % 2, 7)
		snow[i].x += (4 - i % 4)
		snow[i].y += sin(time() * 0.25 + i * 0.1)
	end


	-- debug
	if (false) do
		for i=1,#objects do
			local o = objects[i]
			rect(o.x + o.hit_x, o.y + o .hit_y, o.x + o.hit_x + o.hit_w - 1, o.y + o.hit_y + o.hit_h - 1, 8)
		end

		camera(0, 0)
		print("cpu: " .. flr(stat(1) * 100) .. "/100", 9, 9, 8)
		print("mem: " .. flr(stat(0)) .. "/2048", 9, 15, 8)
		camera(camera_x, camera_y)
	end
end

-->8

-- Objects:
#include object.lua
#include player.lua
#include objects.lua

-->8

-- gets the tile at the given location in the CURRENT room
function room_tile_at(x, y)
	return mget((room % 4) * 16 + x, (room / 4) * 16 + y)
end

-- loads the given room
function room_load(index)
	room = index
	objects = {}

	for i = 0,15 do
		for j = 0,15 do
			for n=1,#types do
				if (room_tile_at(i, j) == types[n].tile) then
					create(types[n], i * 8, j * 8)
				end
			end
		end
	end
end

function approach(x, target, max_delta)
	if (x < target) then
		return min(x + max_delta, target)
	else
		return max(x - max_delta, target)
	end
end

function draw_sine_h(x0, x1, y, col, amplitude, time_freq, x_freq, fade_x_dist)
	pset(x0, y, col)
	pset(x1, y, col)

	local x_sign = sgn(x1 - x0)
	local x_max = abs(x1 - x0) - 1
	local last_y = y
	local this_y = 0
	local ax = 0
	local ay = 0
	local fade = 1

	for i = 1, x_max do
		
		if (i <= fade_x_dist) then
			fade = i / (fade_x_dist + 1)
		elseif (i > x_max - fade_x_dist + 1) then
			fade = (x_max + 1 - i) / (fade_x_dist + 1)
		else
			fade = 1
		end

		ax = x0 + i * x_sign
		ay = y + sin(time() * time_freq + i * x_freq) * amplitude * fade
		pset(ax, ay, col)

		this_y = ay
		while (abs(ay - last_y) > 1) do
			ay -= sgn(this_y - last_y)
			pset(ax - x_sign, ay, col)
		end
		last_y = this_y
	end
end

__gfx__
00000000777777770011110001111110011111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000700000070111111011144411111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700722222071114441111474471144441100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000722222071147447101444440174474100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000722222070144444000aaaa00044444100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007007222220700aaaa000022220000aaaa700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000722222070022220007000070002222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777770070070000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777777777777777777777599999999000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777791111119006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777791411419000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777771177777711777777791441119000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777712217777122177777791144119004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
71777122221111222217771791414419009990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
72111222222222222221112791111119004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
72222222222222222222222799999999009990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
72222222222222222222222757777775000000000000066622222222222222225555555555555555555555555777777777777777777777750000000000000000
77222222222222222222227777777777000000000007777722222221122222225555555555555550055555557771111177711111777111170000000000000000
77222222222222222222227777777777000000000000066622222211112222225555555555555500005555557777111117771111177711170000000000000000
77722222222222222222277777177177007000700000000022222111111222225555555555555000000555557177711111777111117771170000000000000000
777222222222222222222777772112770070007000000666222211111111222255555555555500000000555571c777ccccc777ccccc777170000000000000000
772222222222222222222277772222770676067600077777222111111111122255555555555000000000055571cc777ccccc777ccccc77770000000000000000
77222222222222222222227777722777067606760000066622111111111111225555555555000000000000557111177711111777111117770000000000000000
72222222222222222222222757777775067606760000000021111111111111125555555550000000000000055777777777777777777777750000000000000000
722222222222222222222227577777777777777777777775211111111111111211111111500000000000000557777775777ccc17777ccc170000000000000000
7222222222222222222222277777777777777777777777772211111111111122111111115500000000000055777711177777cc177777cc170000000000000000
72222722222222222222222777777777777777777777777722211111111112221111111155500000000005557177711771777c1771777c170000000000000000
72222222222222222222222777777771177777711777777722221111111122221111111155550000000055557117771771c7771771c777170000000000000000
772222222222222222272277777777122177771221777777222221111112222211111111555550000005555571cc777771cc777771cc77770000000000000000
777222222277772222222777717771222211112222177717222222111122222211111111555555000055555571ccc77771ccc77771ccc7770000000000000000
777772222777777222277777721112222222222222211127222222211222222211111111555555500555555571cccc7771cccc77711111770000000000000000
577777777777777777777775577777777777777777777775222222222222222211111111555555555555555571cccc1771cccc17577777750000000000000000
__gff__
0003000000000000000000000000000003030300000000000000000000000000030303030800030301010107070700000303030303030303010101070707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3837212131313131313131313131313131313131313131313131313131313136000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
38272122283900002a2828282828282828282900000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3838272228280000000000000028282828280000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3736372228290000000000000028282828280000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
213131320000000014000000002a282828280000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2223283900000000000000000000282828280000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b282829000000333435250000002a2828290000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3c2828000000003334352500000000003b000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3c2829000000000000000000000000003c000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3d2800000000000000000000000000003c000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
213435000000000200000000000000003c000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222424000000000000000000000000003c000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22282839000000000013003a391324243d000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2111111200003334343528281011111111111111111111111111111111111126000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2726272213003a2828002a282021213838383827212121212638383838383838000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3838382711111111111111112627263838383838382721263838383838383838000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01030306245342452024510245102451024510245002450030500305002b5002b5002950029500245002450030500305002b5002b5002950029500245002450030500305002b5002b50029500295002450024500
0104020317770187711877018770154001540015400164001740018400194001a4001b4001d4001e4001f4001f4001f4001c40018400164000000000000000000000000000000000000000000000000000000000
010b05080017000160001500014000132001220012200122000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010b000030820308152b8102b8152981029815248102481530820308152b8102b8152981029815248102481530820308152b8102b8152981029815248102481530820308152b8102b81529810298152481024815
010b0000080200801513025130151a0251a0151f0251f015080200801513025130151a0251a0151f0251f015080200801513025130151a0251a0151f0251f015080200801513025130151a0251a0151f0251f015
010b00000c0200c01513025130151a0251a0151f0251f0150c0200c01513025130151a0251a0151f0251f0150c0200c01513025130151a0251a0151f0251f0150c0200c01513025130151a0251a0151f0251f015
010b00000a0200a01513025130151a0251a0151f0251f0150a0200a01513025130151a0251a0151f0251f0150a0200a01513025130151a0251a0151f0251f0150a0200a01513025130151a0251a0151f0251f015
010b0000060200601513025130151a0251a0151f0251f015060200601513025130151a0251a0151f0251f015070200701513025130151a0251a0151f0251f015070200701513025130151a0251a0151f0251f015
010b00002480024800248002480024800248002480024800248002480024800248002480024800248002480000000000000000000000000000000000000000000000000000000000000000000000001f7501f745
010b0000247502474500000000002b7502b74500000000002b7502b74500000000002b7502b74500000240002b9502b7402b7322b7222c750007002e7502e7402e7302e72530760000002e7502e7452c7502c745
010b00002b9502b7402b7402b7322b7222b7122c7502b750297502974029740297302972029712297120000027750277402774027730277222771229750277502675026740267302672226712267120000000000
010b00002482024820248202482024812248122481224812248122481224812248122481224812248122481500000000000000000000000000000000000000000000000000000000000000000000000000000000
010b0000247502474024732247252b7502b74500000000002b7502b74500000000002b7502b74500000000002b7502b7402b7322b7252c750000002e9502e7402e7522e74530750307452e7502e7452c7502c745
010b0000090200901513020130151a0201a0151f0201f0150802008015120201201519020190151e0201e0150702007015110201101518020180151d0201d0150602006015140201401518020180151d0201d015
010b00002b9502b7402b7402b7322b7222b7122c7502b7402975029740297402973229722297122b7502974027750277402774027732277222771229750277402675026740267402673226722267122671026710
010b000014a4014a1014a1014a4014a1014a1014a4014a1014a4014a1014a1014a4014a1014a1020a4020a1014a4014a1014a1014a4014a1014a1014a4014a1014a4014a1014a1014a4014a1014a1016a4016a10
010b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024a2018a11
010b000018a4018a1018a1018a4018a1018a1018a4018a1018a4018a1018a1018a4018a1018a1024a4024a1018a4018a1018a1018a4018a1018a1018a4018a1018a4018a1018a1018a4018a1018a101aa4018a30
010b000016a4016a1016a1016a4016a1016a1016a4016a1016a4016a1016a1016a4016a1016a1022a4022a1016a4016a1016a1016a4016a1016a1016a4016a1016a4016a1016a1016a4016a1016a1018a4016a30
010b000012a4012a1012a1012a4012a1012a1012a4012a1012a4012a1012a1012a4012a1012a101ea401ea1007a40000000000000000000000000007a20000000000000000000000000007a200000024a2018a11
__music__
01 09424344
00 09424316
00 090a4315
00 090b4317
00 090c4318
00 090d0e19
00 110a0f15
00 410b1017
00 410c1218
02 41131444

