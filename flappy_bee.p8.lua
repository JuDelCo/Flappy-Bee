pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--flappy bee
--@judelco

-- todo: eliminar métodos sin usar
-- todo: fix input p8lib
-- todo: lpad & num p8lib

-- todo: titulo y caratula del cartucho
-- todo: crear material de publicación (gif animado from pico8, screenshots, texto twitter, texto bbs, página itch.io)
--		 https://www.lexaloffle.com/bbs/?tid=29008
--		 @gruber_music
--		 pico-8 tunes volume 1
--			#2 "pastoral" - main menu & gameplay night
--			#5 "ice" - gameplay day
-- todo: publicar

--[[
	sfx_play(12) intro - sonido al aparecer la abeja dormida
	sfx_play(13) intro - plic de la mano en la abeja

	sfx_play(14) title - flsssh al caer el titulo
	sfx_play(15) title - bloogh! al terminar de caer el titulo cuando vibra todo
	sfx_play(16) title - plinc al poner el menu principal
	sfx_play(17) title - plic al cambiar entre opciones del menu
	sfx_play(18) title - pipipipipipi al pulsar una opción del menu

	sfx_play(19) settings - plic al cambiar entre opciones
	sfx_play(20) settings - ploc al togglear una opción
	sfx_play(21) settings - pic al pulsar un boton

	sfx_play(22) game - flap al aletear
	sfx_play(23) game - ploc al golpearse
	sfx_play(24) game - poff al caer al suelo (si estaba alto)
	sfx_play(25) game - plic al cambiar entre opciones (botones)
	sfx_play(26) game - pic al pulsar un boton
	sfx_play(27) game - titirin al obtener highscore
	sfx_play(28) game - plinc al conseguir un punto (obstaculo)
]]--

-- ---------------------------

-- [polish] sfx al morir (pantalla de resultados)
-- [polish] particulas !!! aletear ! chocar ! más sitios ! (texto !, menú !, acciones !, .... everywhere !)
-- [polish] florituras con el texto (cambio de colores, movimiento, ...)
-- [gameplay] experiencia + niveles
-- [gameplay] logros:
--[[
	"early bee" - 1 partida
	"at least you tried" - 0 puntos run
	"you keep trying" - > 0 puntos despues del logro anterior
	2,5,10,25,50,100 - partidas
	1,5,10,25,50,100,200,500 - puntos (one run)
	1,10,50,100,200,500,1000 - puntos (accumulated)
	1,2,5,10,15,20,25,30,35,40,45,50 - niveles (experiencia)
]]--
-- [gameplay] tienda de puntos/monedas:
--[[
	permitir activar/desactivar cada modificador
	modificadores
		miel arriba y abajo del mapa ? (recolectar especiales / +5 puntos)
		agua ? (shader effect)
		gravedad invertida
		cambiar color amarillo abeja (skins / hats)
		dejar efectos / estelas (particulas)
			al saltar (especiales cuando cerca de la tierra)
			permanentes
		salto sea mas controlado (salte menos en realidad)
		escudo que te cubre un toque
	consumibles
		invulnerable, crezcas de tamaño y destruyas todas las tuberias que toques
	habilidades ?
]]--

--[[ dependencies:
	game loop
	util functions (only a few)
	metatables
	objects
	fsm
	game state
	input
	animation
	physics_object (from physics)
]]--

--------------------------------
-- game loop
--------------------------------

_ = {}

function _init()
	_.input = input()
	_.state = flappy_bee_game()
end

function _update60()
	_.input:update()
	_.state:update()
end

-- todo: debug
function _draw()
	_.state:draw()
	--_draw_debug()
end

function _draw_debug()
	print_outline("cpu: " .. cpu_usage() .. "%", 1, 1, 1, 6)
	print_outline("mem: " .. memory_usage() .. "%", 1, 7, 1, 6)

	-- print("") print("") info() -- 30fps
end

--------------------------------
-- util functions
--------------------------------

function cpu_usage()
	return flr(stat(1) * 100)
end

function memory_usage()
	return flr((stat(0) / 1024) * 100)
end

function contains(str, needle)
	local limit = #str - #needle + 1
	local found = false
	
	for i = 0, limit, 1 do
		found = true

		for j = 0, #needle, 1 do
			if sub(str, i+j, 1) != sub(needle, j, 1) then
				found = false
			end
		end
		
		if found then
			return true
		end
	end

	return false
end

function overlaps(x1, y1, w1, h1, x2, y2, w2, h2)
	local x_distance = x1 - x2
	local x_size = (w1 + w2) * 0.5

	if abs(x_distance) >= x_size then
		return false
	end

	local y_distance = y1 - y2
	local y_size = (h1 + h2) * 0.5

	if abs(y_distance) >= y_size then
		return false
	end

	return true
end

function between(value, x, y)
	return (value >= x) and (value <= y)
end

function clamp(value, x, y)
	return max(min(value, y), x)
end

function print_outline(text, x, y, c1, c2)
	print(text, x + 1, y - 1, c1)
	print(text, x + 1, y, c1)
	print(text, x + 1, y + 1, c1)
	print(text, x, y + 1, c1)
	print(text, x - 1, y + 1, c1)
	print(text, x - 1, y, c1)
	print(text, x - 1, y - 1, c1)
	print(text, x, y - 1, c1)
	print(text, x, y, c2)
end

function print_shadow(text, x, y, c1, c2)
	print(text, x, y + 1, c1)
	print(text, x, y, c2)
end

function num(value)
	return value and 1 or 0
end

function lpad(str, len, char)
	if char == nil then
		char = " "
	end

	str = str .. ""
	local padding = ""

	for i = 1, (len - #str) do
		padding = padding .. char
	end
	
	return padding .. str
end

function music_play(n)
	if _.music_active != n then
		music_stop()
		
		if _.settings.music == 1 then
			music(n)
			_.music_active = n
		end
	end
end

function music_stop()
	music(-1, 100)
	_.music_active = -1
end

function sfx_play(n)
	if _.settings.sfx == 1 then
		sfx(n)
	end
end

--------------------------------
-- metatables
--------------------------------

__setmetatable = setmetatable
__metatables = {}

function setmetatable(object, mt)
  __metatables[object] = mt
  return __setmetatable(object, mt)
end

function getmetatable(object)
  return __metatables[object]
end

--------------------------------
-- objects
--------------------------------

object = {}
object.__index = object

function object:new()
	-- prototype
end

function object:extend()
	local new_class = {}

	for k, v in pairs(self) do
		if contains(k, "__") then
			new_class[k] = v
		end
	end

	new_class.__index = new_class
	new_class.super = self
	setmetatable(new_class, self)

	return new_class
end

function object:implement(...)
	for _, class in pairs({...}) do
		for k, v in pairs(class) do
			if self[k] == nil and type(v) == "function" then
				self[k] = v
			end
		end
	end
end

function object:is(t)
	local mt = getmetatable(self)

	while mt do
		if mt == t then
			return true
		end

		mt = getmetatable(mt)
	end

	return false
end

function object:__tostring()
	return "object"
end

function object:__call(...)
	local obj = setmetatable({}, self)
	obj:new(...)

	return obj
end

--------------------------------
-- fsm
--------------------------------

fsm = object:extend()

function fsm:new()
	self.state_current = ""
	self.state_next = ""
	self.state_timer = 0
	self.state_list = {}
	self.state_stack = {}
end

function fsm:add(name, script)
	self.state_list[name] = script
end

function fsm:init(name)
	self.state_current = name
	self.state_next = name
	self.state_stack[0] = name
end

function fsm:switch(name, push)
	self.state_next = name

	if push == true then
		self.state_stack[count(self.state_stack)] = self.state_next
	end
end

function fsm:switch_previous()
	del(self.state_stack, count(self.state_stack) - 1)
	self:switch(self.state_stack[count(self.state_stack) - 1], false)
end

function fsm:update()
	self.state_list[self.state_current](self.state_timer)

	if self.state_next != self.state_current then
		self.state_current = self.state_next
		self.state_timer = 0
	else
		self.state_timer += 1
	end
end

function fsm:is(name)
	return self.state_current == name
end

--------------------------------
-- game state
--------------------------------

game_state = fsm:extend()

function game_state:new()
	self.super:new()
	self.state_list_draw = {}
end

function game_state:add(name, update_script, draw_script)
	self.super:add(name, update_script)
	self.state_list_draw[name] = draw_script
end

function game_state:update()
	self.state_list[self.state_current](self.state_timer)
end

function game_state:draw()
	self.state_list_draw[self.state_current](self.state_timer)
	
	if self.state_next != self.state_current then
		self.state_current = self.state_next
		self.state_timer = 0
	else
		self.state_timer += 1
	end
end

--------------------------------
-- input
--------------------------------

input = object:extend()

function input:new()
	self.pad_left_counter = 0
	self.pad_right_counter = 0
	self.pad_up_counter = 0
	self.pad_down_counter = 0
	self.pad_z_counter = 0
	self.pad_x_counter = 0
	
	poke(0x5f2d, 1)
	
	self.mouse_left_counter = 0
	self.mouse_middle_counter = 0
	self.mouse_right_counter = 0
	self.mouse_last_x_pos = stat(32)
	self.mouse_last_y_pos = stat(33)
	self.mouse_rest_counter = 0
end

function input:update()
	if btn(0) then self.pad_left_counter += 1
	elseif self.pad_left_counter > 0 then self.pad_left_counter = -1
	else self.pad_left_counter = 0 end
	
	if btn(1) then self.pad_right_counter += 1
	elseif self.pad_right_counter > 0 then self.pad_right_counter = -1
	else self.pad_right_counter = 0 end
	
	if btn(2) then self.pad_up_counter += 1
	elseif self.pad_up_counter > 0 then self.pad_up_counter = -1
	else self.pad_up_counter = 0 end
	
	if btn(3) then self.pad_down_counter += 1
	elseif self.pad_down_counter > 0 then self.pad_down_counter = -1
	else self.pad_down_counter = 0 end

	if btn(4) then self.pad_z_counter += 1
	elseif self.pad_z_counter > 0 then self.pad_z_counter = -1
	else self.pad_z_counter = 0 end
	
	if btn(5) then self.pad_x_counter += 1
	elseif self.pad_x_counter > 0 then self.pad_x_counter = -1
	else self.pad_x_counter = 0 end

	if band(shr(stat(34), 0), 1) == 1 then self.mouse_left_counter += 1
	elseif self.mouse_left_counter > 0 then self.mouse_left_counter = -1
	else self.mouse_left_counter = 0 end
	
	if band(shr(stat(34), 2), 1) == 1 then self.mouse_middle_counter += 1
	elseif self.mouse_middle_counter > 0 then self.mouse_middle_counter = -1
	else self.mouse_middle_counter = 0 end
	
	if band(shr(stat(34), 1), 1) == 1 then self.mouse_right_counter += 1
	elseif self.mouse_right_counter > 0 then self.mouse_right_counter = -1
	else self.mouse_right_counter = 0 end
	
	if self.mouse_last_x_pos != stat(32) or self.mouse_last_y_pos != stat(33) or
		self:mouse_left() > 0 or self:mouse_middle() > 0 or self:mouse_right() > 0 then
		self.mouse_rest_counter = 0
	else
		self.mouse_rest_counter += 1
	end
	
	self.mouse_last_x_pos = stat(32)
	self.mouse_last_y_pos = stat(33)
end

function input:pad_left()
	return self.pad_left_counter
end

function input:pad_right()
	return self.pad_right_counter
end

function input:pad_up()
	return self.pad_up_counter
end

function input:pad_down()
	return self.pad_down_counter
end

function input:pad_z()
	return self.pad_z_counter
end

function input:pad_x()
	return self.pad_x_counter
end

function input:mouse_x()
	return stat(32)
end

function input:mouse_y()
	return stat(33)
end

function input:mouse_left()
	return self.mouse_left_counter
end

function input:mouse_middle()
	return self.mouse_middle_counter
end

function input:mouse_right()
	return self.mouse_right_counter
end

function input:mouse_is_resting()
	return self.mouse_rest_counter
end

--------------------------------
-- animation
--------------------------------

animation = object:extend()

function animation:new()
	self.animations = {}
	self.anim_current = ""
	self.anim_current_index = 1
	self.anim_timer = 0
	self.current_frame = 0
end

function animation:add(name, frames, speed, loop)
	self.animations[name] = {}
	self.animations[name].frames = frames
	self.animations[name].speed = speed
	self.animations[name].loop = loop
end

function animation:play(name)
	assert(self.animations[name] != nil, "animation name doesn't exist")

	self.anim_current = name
	self.anim_timer = 0
	self.anim_current_index = 1
	self.current_frame = self.animations[name].frames[1]
end

function animation:update()
	if self.animations == "" then
		return
	end

	self.anim_timer += 1

	if not self.animations[self.anim_current].loop and self.anim_current_index == #self.animations[self.anim_current].frames then
		return
	end

	if self.anim_timer > self.animations[self.anim_current].speed then
		self.anim_current_index += 1
		self.anim_timer = 0
		
		if self.anim_current_index > #self.animations[self.anim_current].frames then
			self.anim_current_index = 1
		end

		self.current_frame = self.animations[self.anim_current].frames[self.anim_current_index]
	end
end

function animation:current()
	return self.current_frame
end

--------------------------------
-- physics
--------------------------------

physics_object = object:extend()

function physics_object:new()
	self.x = 0
	self.y = 0
	self.x_remainder = 0
	self.y_remainder = 0

	self.w = 2
	self.h = 2
	self.half_w = 1
	self.half_h = 1
end

function physics_object:left()
	return self.x - flr(self.half_w)
end

function physics_object:right()
	return self.x + flr(self.half_w) - ((self.w + 1) % 2)
end

function physics_object:top()
	return self.y - flr(self.half_h)
end

function physics_object:bottom()
	return self.y + flr(self.half_h) - ((self.h + 1) % 2)
end

function physics_object:draw(color)
	rectfill(self:left(), self:top(), self:right(), self:bottom(), color)
end

--------------------------------
-- flappy bee game
--------------------------------

flappy_bee_game = game_state:extend()

function flappy_bee_game:new()
	self.super:new()

	self:add("load", function(tick) self:load_update(tick) end, function(tick) self:load_draw(tick) end)
	self:add("intro", function(tick) self:intro_update(tick) end, function(tick) self:intro_draw(tick) end)
	self:add("title", function(tick) self:title_update(tick) end, function(tick) self:title_draw(tick) end)
	self:add("game", function(tick) self:game_update(tick) end, function(tick) self:game_draw(tick) end)
	self:add("settings", function(tick) self:settings_update(tick) end, function(tick) self:settings_draw(tick) end)

	self:init("load")
end

function flappy_bee_game:load_update(tick)
	if(tick > 50) then
		self:switch("intro")
	end
end

function flappy_bee_game:load_draw(tick)
	cls()
	pal()
end

function flappy_bee_game:intro_update(tick)
	if tick == 0 then
		_.settings = settings()

		self.intro_idle_animation = animation()
		self.intro_idle_animation:add("idle_flap", { 1, 3, 5, 7 }, 8, true)
		self.intro_idle_animation:play("idle_flap")
		self.title_movement = false
	end

	self.intro_idle_animation:update()
	
	if(tick > 310) then
		self:switch("title")
	end
end

function flappy_bee_game:intro_draw(tick)
	cls()

	if between(tick, 1, 35) then
		if tick == 1 then
			sfx_play(12)
		end

		local cx = 55
		local cy = 45
		local logofr = 9
		local frx = logofr % 16 * 8
		local fry = flr(logofr / 16) * 8

		for s = 0, (tick + 1) do
			for y = 0, 15 do
				camera(rnd(30 / tick), rnd(30 / tick))

				for x = 0, 15 do
					if(y == s) then
						pset(cx + x, cy + y, 7)
					elseif(y == (s - 1)) then
						pset(cx + x, cy + y, 6)
					elseif(y < (s - 1)) then
						pset(cx + x, cy + y, sget(frx + x, fry + y))
					end
				end
			end
		end
	elseif between(tick, 36, 78) then
		spr(9, 55, 45, 2, 2)
		spr(11, 59, 135 - (tick - 35) * 1.8, 2, 2)
	elseif between(tick, 79, 110) then
		spr(9, 55, 45, 2, 2)
		spr(11, 59, 55, 2, 2)
	elseif between(tick, 111, 118) then
		if tick == 111 then
			sfx_play(13)
		end

		camera(rnd(2)-1, rnd(2)-1)
		spr(9, 55, 45, 2, 2)
		camera()
		spr(13, 59, 55, 2, 2)
	elseif between(tick, 119, 125) then
		spr(self.intro_idle_animation:current(), 55, 45, 2, 2)
		spr(11, 59, 55, 2, 2)
	elseif between(tick, 126, 240) then
		spr(self.intro_idle_animation:current(), 55, 45, 2, 2)
	elseif between(tick, 241, 255) then
		spr(self.intro_idle_animation:current(), 55, 45, 2, 2)

		local fade_1_colors = { [0] = 0, 1, 0, 0, 0, 0, 0, 6, 0, 0, 13, 0, 0, 0, 0, 0 }

		for i = 0, 15 do
			pal(i, fade_1_colors[i], 1)
		end
	elseif tick > 255 and tick <= 270 then
		spr(self.intro_idle_animation:current(), 55, 45, 2, 2)

		local fade_2_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 1, 0, 0, 0, 0, 0 }

		for i = 0, 15 do
			pal(i, fade_2_colors[i], 1)
		end
	elseif tick > 270 and tick <= 285 then
		spr(self.intro_idle_animation:current(), 55, 45, 2, 2)

		local fade_3_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 }

		for i = 0, 15 do
			pal(i, fade_3_colors[i], 1)
		end
	elseif tick > 285 and tick <= 310 then
		pal()
	end

	if between(tick, 160, 285) then
		print_outline("jUdELcO", 49, 65, 1, 10)
		print_outline("PRESENTS", 47, 72, 1, 10)
	end
end

function flappy_bee_game:title_update(tick)
	if tick == 0 then
		_.settings = settings()
		if _.world == nil then
			_.player = player(30, 40, 10, 10)
			_.world = world()
		end
		_.world.night = false
		_.world.city = true
		_.score = score()

		self.title_show_menu = false
		self.title_selected_menu = 0
		self.title_starting = false
	end
	
	local previous_selected_menu = self.title_selected_menu

	if self.title_show_menu and not self.title_starting then
		if _.input:mouse_is_resting() == 0 then
			if between(_.input:mouse_x(), 35, 83) and between(_.input:mouse_y(), 67, 75) then
				self.title_selected_menu = 0
			elseif between(_.input:mouse_x(), 35, 83) and between(_.input:mouse_y(), 76, 84) then
				self.title_selected_menu = 1
			end
		end
		
		if _.input:pad_up() == 1 then
			self.title_selected_menu -= 1
		elseif _.input:pad_down() == 1 then
			self.title_selected_menu += 1
		end

		self.title_selected_menu = clamp(self.title_selected_menu, 0, 1)

		if (between(_.input:mouse_x(), 35, 83) and between(_.input:mouse_y(), 67, 84) and _.input:mouse_left() == 1) or
			(_.input:pad_x() == 1 or _.input:pad_z() == 1) then
			sfx_play(18)
			self.title_starting = 0
		end
	end
	
	if abs(tick) > 45 or self.title_movement then
		_.world:update()
		self.title_movement = true
		
		if player.check_input() and not self.title_show_menu then
			sfx_play(16)
			self.title_show_menu = true
		end
	end

	if self.title_starting then
		self.title_starting += 1
		
		if self.title_starting == 30 and self.title_selected_menu == 0 then
			music_stop()
		end
		
		if self.title_starting > 75 then
			if self.title_selected_menu == 0 then
				self:switch("game")
			elseif self.title_selected_menu == 1 then
				self:switch("settings")
			end
		end
	end
	
	if previous_selected_menu != self.title_selected_menu then
		sfx_play(17)
	end
	
	if tick >= 3600 then
		music_stop()
		self:switch("load")
	end
end

function flappy_bee_game:title_draw(tick)
	if tick == 0 then
		pal()
	end
	
	_.world:draw()
	_.world:draw_terrain()

	if between(abs(tick), 0, 35) then
		if tick == 1 then
			sfx_play(14)
		elseif tick == 30 then
			sfx_play(15)
		end

		map(82, 1, 35, -50 + 10 + (tick * 1.5), 7, 2)
		map(82, 3, 35, -50 + 27 + (tick * 1.5), 7, 2)
	elseif between(abs(tick), 36, 45) then
		map(82, 1, 35, 10, 7, 2)
		map(82, 3, 35, 27, 7, 2)
		
		camera(rnd(2), rnd(2))
	else
		if tick == 60 then
			music_play(0)
		end
		
		camera()

		if not self.title_show_menu and (tick + 20) % 90 < 60 then
			spr(13, 20, 72, 2, 2)
			print_outline("tap OR press z/x", 37, 77, 1, 7)
		elseif self.title_show_menu then
			print_outline("\x85", 41, 73 + (8 * self.title_selected_menu), 1, 11)
			
			if not self.title_starting then
				if self.title_selected_menu == 0 then
					print_outline("play", 52, 73, 1, 7)
					print_outline("settings", 52, 81, 1, 6)
				elseif self.title_selected_menu == 1 then
					print_outline("play", 52, 73, 1, 6)
					print_outline("settings", 52, 81, 1, 7)
				end
			else
				if self.title_selected_menu == 0 then
					if self.title_starting % 10 < 5 then
						print_outline("play", 52, 73, 1, 7)
					end
					print_outline("settings", 52, 81, 1, 6)
				elseif self.title_selected_menu == 1 then
					print_outline("play", 52, 73, 1, 6)
					if self.title_starting % 10 < 5 then
						print_outline("settings", 52, 81, 1, 7)
					end
				end
			end
		end

		if _.input:mouse_is_resting() < 40 then
			if between(_.input:mouse_left(), 1, 10) then
				spr(13, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
			else
				spr(11, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
			end
		end

		local offset_y = sin(tick / 80) * 1.5
		
		map(82, 1, 35, 10 + offset_y, 7, 2) -- flappy
		
		if tick % 100 < 15 then
			map(82, 3, 35 + rnd(2) - 1, 27 + rnd(2) - 1 + offset_y, 7, 2)
		else
			map(82, 3, 35, 27 + offset_y, 7, 2) -- bee
		end
	end
	
	if not self.title_movement then
		if abs(tick) <= 2 then
			cls(1)
		elseif abs(tick) <= 5 then
			cls(6)
		elseif abs(tick) <= 8 then
			cls(7)
		end
	end
	
	if self.title_starting and self.title_selected_menu == 0 then
		if between(self.title_starting, 50, 58) then
			local fade_1_colors = { [0] = 0, 1, 0, 0, 0, 0, 0, 6, 0, 0, 13, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_1_colors[i], 1)
			end
		elseif between(self.title_starting, 59, 66) then
			local fade_2_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 1, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_2_colors[i], 1)
			end
		elseif between(self.title_starting, 67, 100) then
			local fade_3_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_3_colors[i], 1)
			end
		end
	end
end

function flappy_bee_game.game_reset()
	_.player = player(30, 40, 10, 10)
	_.settings = settings()
	_.world = world()
	_.obstacles = {}
	_.score = score()
	_.game_started = false
	_.state.state_timer = 0
end

function flappy_bee_game:game_update(tick)
	if tick == 0 then
		self.game_reset()
	end
	
	if tick == 10 then
		if not _.world.night then
			music_play(0)
		else
			music_play(8)
		end
	end

	if _.game_started and tick % 110 == 0 then
		obstacle.instantiate()
	end

	_.world:update()
	foreach(_.obstacles, obstacle.update)
	_.player:update()
end

function flappy_bee_game:game_draw(tick)
	if tick == 0 then
		pal()
	end

	_.world:draw()
	foreach(_.obstacles, obstacle.draw)
	_.world:draw_terrain()
	_.score:draw()
	_.player:draw()

	if abs(tick) <= 2 then
		cls(1)
	elseif abs(tick) <= 5 then
		cls(6)
	elseif abs(tick) <= 8 then
		cls(7)
	end
end

function flappy_bee_game:settings_update(tick)
	if tick == 0 then
		self.settings_selected_item = 0
		self.settings_loading = false
		self.settings_erase_warning = false
	end

	_.world:update()

	local previous_selected_item = self.settings_selected_item

	if abs(tick) > 78 and not self.settings_loading then
		if _.input:mouse_is_resting() == 0 then
			if between(_.input:mouse_x(), 17, 40) and between(_.input:mouse_y(), 21, 26) then
				self.settings_selected_item = 0
			elseif between(_.input:mouse_x(), 47, 65) and between(_.input:mouse_y(), 21, 26) then
				self.settings_selected_item = 1
			elseif between(_.input:mouse_x(), 73, 99) and between(_.input:mouse_y(), 21, 26) then
				self.settings_selected_item = 2
			elseif between(_.input:mouse_x(), 17, 40) and between(_.input:mouse_y(), 42, 47) then
				self.settings_selected_item = 3
			elseif between(_.input:mouse_x(), 43, 65) and between(_.input:mouse_y(), 42, 47) then
				self.settings_selected_item = 4
			elseif between(_.input:mouse_x(), 70, 99) and between(_.input:mouse_y(), 42, 47) then
				self.settings_selected_item = 5
			elseif between(_.input:mouse_x(), 17, 44) and between(_.input:mouse_y(), 63, 68) then
				self.settings_selected_item = 6
			elseif between(_.input:mouse_x(), 50, 68) and between(_.input:mouse_y(), 63, 68) then
				self.settings_selected_item = 7
			elseif between(_.input:mouse_x(), 17, 96) and between(_.input:mouse_y(), 73, 89) then
				self.settings_selected_item = 8
			elseif between(_.input:mouse_x(), 17, 50) and between(_.input:mouse_y(), 91, 107) then
				self.settings_selected_item = 9
			end
		end
		
		if _.input:pad_up() == 1 or _.input:pad_left() == 1 then
			self.settings_selected_item -= 1
		elseif _.input:pad_down() == 1 or _.input:pad_right() == 1 then
			self.settings_selected_item += 1
		end

		self.settings_selected_item = clamp(self.settings_selected_item, 0, 9)

		if _.input:mouse_left() == 1 then
			if between(_.input:mouse_x(), 17, 40) and between(_.input:mouse_y(), 21, 26) then
				_.settings:set_day(1)
				_.settings:set_night(1)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 47, 65) and between(_.input:mouse_y(), 21, 26) then
				_.settings:set_day(1)
				_.settings:set_night(0)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 73, 99) and between(_.input:mouse_y(), 21, 26) then
				_.settings:set_day(0)
				_.settings:set_night(1)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 17, 40) and between(_.input:mouse_y(), 42, 47) then
				_.settings:set_city(1)
				_.settings:set_mountain(1)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 43, 65) and between(_.input:mouse_y(), 42, 47) then
				_.settings:set_city(1)
				_.settings:set_mountain(0)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 70, 99) and between(_.input:mouse_y(), 42, 47) then
				_.settings:set_city(0)
				_.settings:set_mountain(1)
				sfx_play(20)
			elseif between(_.input:mouse_x(), 17, 44) and between(_.input:mouse_y(), 63, 68) then
				_.settings:set_music(abs(_.settings.music - 1))
				
				if _.settings.music == 1 then
					music_play(0)
				else
					music_stop()
				end
				
				sfx_play(20)
			elseif between(_.input:mouse_x(), 50, 68) and between(_.input:mouse_y(), 63, 68) then
				_.settings:set_sfx(abs(_.settings.sfx - 1))
				sfx_play(20)
			elseif between(_.input:mouse_x(), 17, 96) and between(_.input:mouse_y(), 73, 89) then
				if not self.settings_erase_warning then
					self.settings_erase_warning = true
				else
					self.settings_loading = 0
				end
				sfx_play(21)
			elseif between(_.input:mouse_x(), 17, 50) and between(_.input:mouse_y(), 91, 107) then
				self.settings_loading = 0
				sfx_play(21)
			end
		elseif _.input:pad_x() == 1 or _.input:pad_z() == 1 then
			if self.settings_selected_item == 0 then
				_.settings:set_day(1)
				_.settings:set_night(1)
				sfx_play(20)
			elseif self.settings_selected_item == 1 then
				_.settings:set_day(1)
				_.settings:set_night(0)
				sfx_play(20)
			elseif self.settings_selected_item == 2 then
				_.settings:set_day(0)
				_.settings:set_night(1)
				sfx_play(20)
			elseif self.settings_selected_item == 3 then
				_.settings:set_city(1)
				_.settings:set_mountain(1)
				sfx_play(20)
			elseif self.settings_selected_item == 4 then
				_.settings:set_city(1)
				_.settings:set_mountain(0)
				sfx_play(20)
			elseif self.settings_selected_item == 5 then
				_.settings:set_city(0)
				_.settings:set_mountain(1)
				sfx_play(20)
			elseif self.settings_selected_item == 6 then
				_.settings:set_music(abs(_.settings.music - 1))
				
				if _.settings.music == 1 then
					music_play(0)
				else
					music_stop()
				end
				
				sfx_play(20)
			elseif self.settings_selected_item == 7 then
				_.settings:set_sfx(abs(_.settings.sfx - 1))
				sfx_play(20)
			elseif self.settings_selected_item == 8 then
				if not self.settings_erase_warning then
					self.settings_erase_warning = true
				else
					self.settings_loading = 0
				end
				sfx_play(21)
			elseif self.settings_selected_item == 9 then
				self.settings_loading = 0
				sfx_play(21)
			end
		end
	end
	
	if previous_selected_item != self.settings_selected_item then
		sfx_play(19)
	end

	if self.settings_loading then
		self.settings_loading += 1

		if self.settings_loading > 78 then
			if self.settings_selected_item == 8 then
				_.settings:reset()
				_.score:reset()
				
				music_stop()

				self:switch("load")
			elseif self.settings_selected_item == 9 then
				self:switch("title")
			end
		end
	end
end

function flappy_bee_game:settings_draw(tick)
	if tick == 0 then
		pal()
	end
	
	_.world:draw()
	_.world:draw_terrain()

	local dn_both = (_.settings.day == 1 and _.settings.night == 1)
	local dn_day = (_.settings.day == 1 and _.settings.night == 0)
	local dn_night = (_.settings.day == 0 and _.settings.night == 1)
	local cm_both = (_.settings.city == 1 and _.settings.mountain == 1)
	local cm_city = (_.settings.city == 1 and _.settings.mountain == 0)
	local cm_mountain = (_.settings.city == 0 and _.settings.mountain == 1)
	local s_music = (_.settings.music == 1)
	local s_sfx  = (_.settings.sfx == 1)

	local offset_y = 0
	
	if between(abs(tick), 0, 78) then
		offset_y = (128 + 108) - (tick * 3)
	end
	
	if self.settings_loading then
		offset_y = (self.settings_loading * 3)
	end

	draw_ui_square(37, 0 + offset_y, 47, 7)
	print_outline("- settings -", 41, 4 + offset_y, 2, 7)

	draw_ui_square(14, 10 + offset_y, 93, 103)

	print_shadow("dAY/nIGHT cONFIG", 23, 18 + 0 + offset_y, 6, 2)
	draw_ui_checkbox(22, 18 + 8 + offset_y, dn_both, (self.settings_selected_item == 0), tick)
	print("bOTH", 30, 18 + 8 + offset_y, 14 - (num(dn_both) * 11))
	draw_ui_checkbox(52, 18 + 8 + offset_y, dn_day, (self.settings_selected_item == 1), tick)
	print("dAY", 60, 18 + 8 + offset_y, 14 - (num(dn_day) * 11))
	draw_ui_checkbox(78, 18 + 8 + offset_y, dn_night, (self.settings_selected_item == 2), tick)
	print("nIGHT", 86, 18 + 8 + offset_y, 14 - (num(dn_night) * 11))

	print_shadow("cITY/mOUNTAIN cONFIG", 23, 18 + 21 + offset_y, 6, 2)
	draw_ui_checkbox(22, 18 + 29 + offset_y, cm_both, (self.settings_selected_item == 3), tick)
	print("bOTH", 30, 18 + 29 + offset_y, 14 - (num(cm_both) * 11))
	draw_ui_checkbox(48, 18 + 29 + offset_y, cm_city, (self.settings_selected_item == 4), tick)
	print("cITY", 56, 18 + 29 + offset_y, 14 - (num(cm_city) * 11))
	draw_ui_checkbox(75, 18 + 29 + offset_y, cm_mountain, (self.settings_selected_item == 5), tick)
	print("mOUNT.", 83, 18 + 29 + offset_y, 14 - (num(cm_mountain) * 11))

	print_shadow("sOUND cONFIG", 23, 18 + 42 + offset_y, 6, 2)
	draw_ui_checkbox(22, 18 + 50 + offset_y, s_music, (self.settings_selected_item == 6), tick)
	print("mUSIC", 30, 18 + 50 + offset_y, 14 - (num(s_music) * 11))
	draw_ui_checkbox(55, 18 + 50 + offset_y, s_sfx, (self.settings_selected_item == 7), tick)
	print("sfx", 63, 18 + 50 + offset_y, 14 - (num(s_sfx) * 11))
	
	draw_ui_square(21, 77 + offset_y, 75, 10, 8, 2 + 10 * num(self.settings_selected_item == 8 and (tick % 30 < 15 or self.settings_loading)), 2, 9)
	if not self.settings_erase_warning then
		print_shadow("cLEAR sAVEgAME /!\\", 27, 18 + 65 + offset_y, 2, 10)
	else
		print_shadow("aRE YOU SURE ? /!\\", 27, 18 + 65 + offset_y, 2, 10)
	end

	draw_ui_square(21, 95 + offset_y, 28, 10, 13, 2 + 10 * num(self.settings_selected_item == 9 and (tick % 30 < 15 or self.settings_loading)), 2, 6)
	print_shadow("rETURN", 27, 18 + 83 + offset_y, 2, 7)

	if _.input:mouse_is_resting() < 40 then
		if between(_.input:mouse_left(), 1, 10) then
			spr(13, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
		else
			spr(11, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
		end
	end

	if between(abs(tick), 0, 35) then
		map(82, 1, 35, 10 - (tick * 1.5), 7, 2)
		map(82, 3, 35, 27 - (tick * 1.5), 7, 2)
	end
	
	if self.settings_loading and self.settings_selected_item == 8 then
		if between(self.settings_loading, 50, 58) then
			local fade_1_colors = { [0] = 0, 1, 0, 0, 0, 0, 0, 6, 0, 0, 13, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_1_colors[i], 1)
			end
		elseif between(self.settings_loading, 59, 66) then
			local fade_2_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 1, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_2_colors[i], 1)
			end
		elseif between(self.settings_loading, 67, 100) then
			local fade_3_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_3_colors[i], 1)
			end
		end
	end
end

function draw_ui_square(x, y, w, h, c_background, c_border, c_shadow, c_highlight)
	c_background = c_background or 15
	c_border = c_border or 2
	c_shadow = c_shadow or 14
	c_highlight = c_highlight or 7

	pal(15, c_background)
	pal(2, c_border)
	pal(14, c_shadow)
	pal(7, c_highlight)
	
	rectfill(x + 2, y + 2, x + w + 5, y + h + 5, 15)
	
	line(x+8, y+1, x+w, y+1, 2)
	line(x+1, y+8, x+1, y+h, 2)
	line(x+8, y+h+6, x+w, y+h+6, 2)
	line(x+w+6, y+8, x+w+6, y+h, 2)

	line(x+8, y+2, x+w, y+2, 7)
	line(x+8, y+h+5, x+w, y+h+5, 14)

	spr(172, x, y, 1, 1, false)
	spr(172, x + w, y, 1, 1, true)
	spr(173, x, y + h, 1, 1, false)
	spr(173, x + w, y + h, 1, 1, true)
	
	pal()
end

function draw_ui_checkbox(x, y, checked, highlighted, tick)
	local color_offset = 0

	if not checked or false then
		if highlighted and abs(tick) % 30 < 15 then
			color_offset = -1
		end
	
		rect(x, y, x + 4, y + 4, 13 + color_offset)
		rectfill(x + 1, y + 1, x + 3, y + 3, 6)
	else
		if highlighted and abs(tick) % 30 < 15 then
			color_offset = 10
		end

		rect(x, y, x + 4, y + 4, 2 + color_offset)
		rectfill(x + 1, y + 1, x + 3, y + 3, 11)
	end
end

--------------------------------
-- player
--------------------------------

player = physics_object:extend()

function player:new(x, y, w, h)
	self.super:new()

	self.x = x
	self.y = y
	self.w = w
	self.h = h
	self.half_w = w / 2
	self.half_h = h / 2

	self.vx = 0
	self.vy = 0
	self.vy_max = 3
	self.gravity = 0.15
	self.jump = 2.5
	self.jump_counter = 0
	self.max_jump_height = 15
	
	self.state = fsm()
	self.state:add("static", function(tick) self:state_static(tick) end)
	self.state:add("fall", function(tick) self:state_fall(tick) end)
	self.state:add("jump", function(tick) self:state_jump(tick) end)
	self.state:add("dead", function(tick) self:state_dead(tick) end)
	self.state:init("static")

	self.animation = animation()
	self.animation:add("idle_flap", { 1, 3, 5, 7 }, 10, true)
	self.animation:add("flap", { 1, 3, 5, 7, 1 }, 3, false)
	self.animation:add("dead", { 9 }, 120, false)
	self.animation:play("idle_flap")
	
	self.tut_animation = animation()
	self.tut_animation:add("idle", { 11, 13 }, 30, true)
	self.tut_animation:play("idle")
end

function player:update()
	self.state:update()
	self.animation:update()
	self.tut_animation:update()

	if self.vy > self.vy_max then
		self.vy = self.vy_max
	end
	
	self.x += self.vx
	self.y += self.vy
end

function player:draw()
	local sprite_offset = 0
	
	if _.world.night then
		sprite_offset = 32
	end

	spr(self.animation:current() + sprite_offset, self:left() - 4, self:top() - 2, 2, 2)
	
	if self.state:is("static") then
		if _.world.night then
			pal(1, 2)
			spr(self.tut_animation:current(), self.x + 30, self.y + 0, 2, 2)
			print_outline("tap OR press z/x", self.x + 4, self.y + 20, 1, 7)
			pal()
		else
			spr(self.tut_animation:current(), self.x + 30, self.y + 0, 2, 2)
			print_outline("tap OR press z/x", self.x + 4, self.y + 20, 1, 7)
		end
	end
	
	if self.state:is("dead") then
		if abs(self.state.state_timer) < 10 then
			local flash_color = { [0] = 1, 6, 15, 6, 15, 6, 7, 7, 15, 10, 7, 15, 6, 15, 6, 7 }

			for i = 0, 15 do
				pal(i, flash_color[i], 1)
			end
			
			camera(rnd(8) - 4, 0)
		elseif abs(self.state.state_timer) >= 10 then
			pal()
			camera()
			
			local offset_y = 0

			if between(abs(self.state.state_timer), 10, 52) then
				offset_y = (128 + 80) - (self.state.state_timer * 4)
			end
			
			if abs(self.state.state_timer) == 53 and _.score.current == _.score.highscore and _.score.current > 0 then
				sfx_play(27)
			end
			
			if self.gameover_loading then
				offset_y = (self.gameover_loading * 4)
			end
			
			draw_ui_square(39, 20 + offset_y, 42, 7)
			print_outline("game over !", 43, 24 + offset_y, 2, 7)
			
			draw_ui_square(13, 30 + offset_y, 94, 50)

			print_shadow("score", 24, 41 + offset_y, 7, 8)
			rectfill(65, 40 + offset_y, 85, 46 + offset_y, 7)
			print(lpad(_.score.current, 5, " "), 66, 41 + offset_y, 2)
			
			print_shadow("highscore", 24, 51 + offset_y, 7, 8)
			rectfill(65, 50 + offset_y, 85, 56 + offset_y, 7)
			print(lpad(_.score.highscore, 5, " "), 66, 51 + offset_y, 2)
			
			if _.score.current == _.score.highscore and _.score.current > 0 then
				print_shadow("NEW!", 89, 51 + offset_y, 7, 11)
			end
			
			draw_ui_square(17, 65 + offset_y, 41, 10, 3, 2 + 10 * num(self.gameover_selected_item == 0 and (self.state.state_timer % 30 < 15 or self.gameover_loading)), 2, 11)
			print_shadow("pLAY aGAIN", 22, 71 + offset_y, 2, 7)

			draw_ui_square(67, 65 + offset_y, 36, 10, 13, 2 + 10 * num(self.gameover_selected_item == 1 and (self.state.state_timer % 30 < 15 or self.gameover_loading)), 2, 6)
			print_shadow("mAIN mENU", 72, 71 + offset_y, 2, 7)
			
			if _.input:mouse_is_resting() < 40 then
				if between(_.input:mouse_left(), 1, 10) then
					spr(13, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
				else
					spr(11, _.input:mouse_x(), _.input:mouse_y(), 2, 2)
				end
			end
		end
	end
	
	if self.gameover_loading then
		if between(self.gameover_loading, 20, 30) then
			local fade_1_colors = { [0] = 0, 1, 0, 0, 0, 0, 0, 6, 0, 0, 13, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_1_colors[i], 1)
			end
		elseif between(self.gameover_loading, 30, 40) then
			local fade_2_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 1, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_2_colors[i], 1)
			end
		elseif between(self.gameover_loading, 40, 50) then
			local fade_3_colors = { [0] = 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 }

			for i = 0, 15 do
				pal(i, fade_3_colors[i], 1)
			end
		end
	end

	--rect(self:left(), self:top(), self:right(), self:bottom(), 8)
end

function player:state_static(tick)
	self.vx = 0
	self.vy = 0
	
	if player.check_input() then
		self.vy = -self.jump
		self.animation:play("flap")
		self.state:switch("jump")
		sfx_play(22)
		_.game_started = true
	end
end

function player:state_fall(tick)
	self.vy += self.gravity
	
	if player.check_input() and self.y >= self.max_jump_height then
		self.vy = -self.jump
		self.animation:play("flap")
		self.state:switch("jump")
		sfx_play(22)
	end
	
	if self:check_collision() then
		self.state:switch("dead")
	end
end

function player:state_jump(tick)
	if tick == 0 then
		self.jump_counter = 0
	else
		self.jump_counter += 1
	end

	self.vy += self.gravity

	if self.vy >= 0 then
		self.state:switch("fall")
	end
	
	if self.jump_counter > 5 and player.check_input() and self.y >= self.max_jump_height then
		self.vy = -self.jump
		self.jump_counter = 0
		self.animation:play("flap")
		self.state:switch("jump")
		sfx_play(22)
	end
	
	if self:check_collision() then
		self.state:switch("dead")
	end
end

function player:state_dead(tick)
	if tick == 0 then
		music_stop()
		sfx_play(23)
		self.animation:play("dead")
		_.score:save()
		_.game_started = false
		self.gameover_selected_item = 0
		self.gameover_loading = false
	end
	
	local previous_selected_item = self.gameover_selected_item

	self.vx = 0
	self.vy = 0
	
	if self.y < 100 then
		if self.y + 2.4 >= 100 and tick > 10 then
			sfx_play(24)
		end
	
		self.y += 2.4
	end

	if abs(tick) > 52 and not self.gameover_loading then
		if _.input:mouse_is_resting() == 0 then
			if between(_.input:mouse_x(), 13, 58) and between(_.input:mouse_y(), 62, 77) then
				self.gameover_selected_item = 0
			elseif between(_.input:mouse_x(), 63, 103) and between(_.input:mouse_y(), 62, 77) then
				self.gameover_selected_item = 1
			end
		end

		if _.input:pad_left() == 1 then
			self.gameover_selected_item -= 1
		elseif _.input:pad_right() == 1 then
			self.gameover_selected_item += 1
		end

		self.gameover_selected_item = clamp(self.gameover_selected_item, 0, 1)

		if _.input:mouse_left() == 1 then
			if between(_.input:mouse_x(), 13, 58) and between(_.input:mouse_y(), 62, 77) then
				self.gameover_loading = 0
				sfx_play(26)
			elseif between(_.input:mouse_x(), 63, 103) and between(_.input:mouse_y(), 62, 77) then
				self.gameover_loading = 0
				sfx_play(26)
			end
		elseif _.input:pad_x() == 1 or _.input:pad_z() == 1 then
			self.gameover_loading = 0
			sfx_play(26)
		end
	end
	
	if previous_selected_item != self.gameover_selected_item then
		sfx_play(25)
	end

	if self.gameover_loading then
		self.gameover_loading += 1

		if self.gameover_loading > 50 then
			if self.gameover_selected_item == 0 then
				_.state.game_reset()
			elseif self.gameover_selected_item == 1 then
				_.state:switch("title")
			end
		end
	end
end

function player:check_collision()
	if self.y >= 96 then
		return true
	end

	for c in all(_.obstacles) do
		if c.is_bottom then
			if overlaps(self.x, self.y, self.w, self.h, c.x, (127 - (128 - c.y) + 20 + 64), c.w, 128) then
				return true
			end
		else
			if overlaps(self.x, self.y, self.w, self.h, c.x, (c.y - 20 - 64), c.w, 128) then
				return true
			end
		end
	end
	
	return false
end

function player.check_input()
	return _.input:mouse_left() == 1 or _.input:pad_x() == 1 or _.input:pad_z() == 1
end

--------------------------------
-- obstacle
--------------------------------

obstacle = physics_object:extend()

function obstacle:new(is_bottom, height)
	self.super:new()

	self.x = 150
	self.y = height
	self.w = 23
	self.h = 128
	self.half_w = self.w / 2
	self.half_h = self.h / 2

	self.vx = -0.8
	self.is_bottom = is_bottom
	self.scored = false
	self.destruction_border = -32
end

function obstacle:update()
	if _.game_started then
		self.x += self.vx
	end
	
	if self.x + 10 < _.player.x and self.is_bottom and not self.scored then
		_.score:add_points(1)
		sfx_play(28)
		self.scored = true
	end

	if self.x < self.destruction_border then
		del(_.obstacles, self)
	end
end

function obstacle:draw()
	local map_tile_offset = 0
	local sprite_offset = 0

	if _.world.night then
		map_tile_offset = 3
		sprite_offset = 4
	end

	if self.is_bottom then
		map(90 + map_tile_offset, 0, self:left(), 127 - (128 - self.y) + 20, 3, 16)
		spr(128 + sprite_offset, self:left() - 4, 127 - (128 - self.y) + 13, 4, 2)
	else
		map(90 + map_tile_offset, 0, self:left(), self.y - 20 - 128, 3, 16)
		spr(160 + sprite_offset, self:left() - 4, self.y - 28, 4, 2)
	end

	--if self.is_bottom then
	--	rect(self:left(), 127 - (128 - self.y) + 20, self:right(), 127, 8)
	--else
	--	rect(self:left(), 0, self:right(), self.y - 20, 8)
	--end
end

function obstacle.instantiate()
	local height = rnd(70 - 32) + 32

	add(_.obstacles, obstacle(true, height))
	add(_.obstacles, obstacle(false, height))
end

--------------------------------
-- world
--------------------------------

world = object:extend()

function world:new()
	self.cloud_height = 60
	self.city_height = 53
	self.mountain_height = 70
	self.woods_height = 90
	self.terrain_height = 104

	self:generate()
	self:reset()
end

function world:reset()
	self.parallax_1 = 0
	self.parallax_2 = 0
	self.parallax_3 = 0
	self.parallax_4 = 0
end

function world:generate()
	if _.settings.day == 1 and _.settings.night == 1 then
		if rnd(100) > 50 then
			self.night = true
		else
			self.night = false
		end
	else
		self.night = (_.settings.night == 1)
	end
	
	if _.settings.city == 1 and _.settings.mountain == 1 then
		if rnd(100) > 50 then
			self.city = true
		else
			self.city = false
		end
	else
		self.city = (_.settings.city == 1)
	end
end

function world:update()
	if not _.player.state:is("dead") then
		self.parallax_1 += 0.8
		self.parallax_2 += 0.2
		self.parallax_3 += 0.03
		self.parallax_4 += 0.01
	end
end

function world:draw()
	if not self.night then
		rectfill(0, self.cloud_height, 128, 0, 12) -- cielo
		rectfill(0, 128, 128, self.cloud_height, 7) -- nubes
		map(96, 8, -(flr(self.parallax_4) % 128), self.cloud_height, 32, 1) -- borde nubes
		
		if self.city then
			map(96, 15, -(flr(self.parallax_3) % 128), self.city_height, 32, 6) -- ciudad
		else
			pal(9, 6)
			map(96, 0, -(flr(self.parallax_3) % 128), self.mountain_height, 32, 4) -- montaña
			pal()
		end

		map(96, 13, -(flr(self.parallax_2) % 128), self.woods_height, 32, 2) -- bosque
	end

	if self.night then
		rectfill(0, self.cloud_height, 128, 0, 1) -- cielo
		rectfill(0, 128, 128, self.cloud_height, 6) -- nubes
		pal(12, 1) pal(6, 2) pal(7, 6)
		map(96, 8, -(flr(self.parallax_4) % 128), self.cloud_height, 32, 1) -- borde nubes
		pal()
		map(96, 9, -(flr(self.parallax_4) % 128), 0, 32, 4) -- estrellas
		
		if self.city then
			pal(6, 13) pal(7, 10)
			map(96, 15, -(flr(self.parallax_3) % 128), self.city_height, 32, 6) -- ciudad
			pal()
		else
			pal(5, 1) pal(4, 2) pal(9, 7)
			map(96, 0, -(flr(self.parallax_3) % 128), self.mountain_height, 32, 4) -- montaña
			pal()
		end

		pal(3, 2) pal(2, 1) pal(11, 3)
		map(96, 13, -(flr(self.parallax_2) % 128), self.woods_height, 32, 2) -- bosque
		pal()
	end
end

function world:draw_terrain()
	if not self.night then
		map(96, 5, -(flr(self.parallax_1) % 66), self.terrain_height, 32, 3) -- terreno
		map(96, 4, -(flr(self.parallax_1) % 128), self.terrain_height, 32, 1) -- borde terreno
	end
	
	if self.night then
		pal(15, 4) pal(7, 2)
		map(96, 5, -(flr(self.parallax_1) % 66), self.terrain_height, 32, 3) -- terreno
		pal()
		pal(15, 13) pal(11, 4) pal(3, 2)
		map(96, 4, -(flr(self.parallax_1) % 128), self.terrain_height, 32, 1) -- borde terreno
		pal()
	end
end

--------------------------------
-- score
--------------------------------

score = object:extend()

function score:new()
	self.current = 0
	self.highscore = dget(0)
end

function score:add_points(points)
	self.current += points
	
	if self.current > self.highscore then
		self.highscore = self.current
	end
end

function score:save()
	dset(0, self.highscore)
end

function score:draw()
	if _.player.state:is("dead") then
		return
	end

	local x_pos = 47
	local y_pos = 5
	local u = self.current % 10
	local d = ((self.current % 100) - u) / 10
	local c = ((self.current % 1000) - d - u) / 100
	local spr_index =
	{
		[0] = 136,
		[1] = 137,
		[2] = 138,
		[3] = 139,
		[4] = 140,
		[5] = 141,
		[6] = 142,
		[7] = 143,
		[8] = 168,
		[9] = 169,
		["x"] = 170,
		["score_icon"] = 171,
	}
	
	if self.current > 99 then
		spr(spr_index[c], x_pos, y_pos, 1, 2)
	end
	
	if self.current > 9 then
		spr(spr_index[d], x_pos + 8, y_pos, 1, 2)
	end

	spr(spr_index[u], x_pos + 16, y_pos, 1, 2)

	--print_outline("highscore: " .. self.highscore, 67, 116, 1, 7)
end

function score:reset()
	dset(0, 0)
end

--------------------------------
-- settings
--------------------------------

settings = object:extend()

function settings:new()
	if dget(32) == 0 then
		dset(33, 1)
		dset(34, 1)
		dset(35, 1)
		dset(36, 1)
		dset(37, 1)
		dset(38, 1)
		
		dset(32, 1)
	end

	self:reload()
end

function settings:reload()
	self.day = dget(33)
	self.night = dget(34)
	self.city = dget(35)
	self.mountain = dget(36)
	self.sfx = dget(37)
	self.music = dget(38)
end

function settings:set_day(enabled)
	dset(33, enabled)
	self:reload()
end

function settings:set_night(enabled)
	dset(34, enabled)
	self:reload()
end

function settings:set_city(enabled)
	dset(35, enabled)
	self:reload()
end

function settings:set_mountain(enabled)
	dset(36, enabled)
	self:reload()
end

function settings:set_sfx(enabled)
	dset(37, enabled)
	self:reload()
end

function settings:set_music(enabled)
	dset(38, enabled)
	self:reload()
end

function settings:reset()
	dset(32, 0)
end

__gfx__
00070000000000000000000000000000000001010000000000000101000000000000010100000000000000000000000000000000001000000100000000199910
07070700000011101100010100000000000010100000000000001010000000000000101000000000000000000000000000000000017100001710000000199910
00777000000177717710101000000000001111100000000000111110000000000011111000000001010100000000000000000000001710017100000000199910
77777770000177717711111000111111111111110000111111771771001111111177177100000010101000000000000000000000000101101000000000199911
00777000000177711177177101777771a171171100017771a171171101777771a171171100001111111100000000011000000000011017711110000000199999
0707070000017771a17117110177777111711711001777711171171101777771117117110011a11aa11a100000001771000000001771177117710000001a9999
0007000000117771117117110117771a1171171101177771117117110117771a1171171101aaa11aa111a100000017710000000001101771111000000012aaaa
00000000011a111a11711711111111aa111111111117777111771771111111aa11771771011a1111aa11a1100000177111000000000017767610000000012222
00000000111a11aa11771771011a11aa1111a110011177111111a110011a11aa1111a11011111111aa1111110000177676100000000176767671000000000000
00111111011a11aa1111a110001a111aa11aaa10001a111aa11aaa10001a111aa11aaa1011111111a17771100001767676710000000176767671000000000000
01999999001a111aa11aaa100001a11aa11a11000001a11aa11a11000001a11aa11a110017171711177777100001767676710000000176767671000000000000
019999990001a11aa11a11000000111111110000000011111111000000001111111100001171711a177777100001767676710000000017777710000000000000
01999aaa000011111111000000000101010000000000010101000000000001010100000017171711111111000000177777100000000001777710000000000000
01999222000001010100000000001010100000000000101010000000000010101000000001111100000000000000017777100000000001666610000000000000
01999111000010101000000000000000000000000000000000000000000000000000000001010000000000000000016666100000000000111100000000000000
01999991000000000000000000000000000000000000000000000000000000000000000010100000000000000000001111000000000000000000000000000000
01999991000000000000000000000000000002020000000000000202000000000000020200000000000000000000000000000000000000000000000000000000
01999aa1000022202200020200000000000020200000000000002020000000000000202000000000000000000000111111111111111111111111111111111111
01999221000277727720202000000000002212200000000000221220000000000022122000000002020200000001199999911999999911999999911999119991
01999100000277717712122000222222221111120000222222771772002222222277177200000020202000000001999999991999999991999999991999119991
01999100000277711177177202777771a171171200027771a171171202777771a171171200002212121200000001999aa9991999aa9991999aa9991999119991
0199910000027771a17117120277777111711712002777711171171202777771117117120022a11aa11a20000001999229991999229991999229991999119991
01aaa10000217771117117120217771a1171171202177771117117120217771a1171171202aaa11aa111a2000001999119991999119991999119991999119991
01222100021a111a11711712211111aa111111122117777111771772211111aa11771772021a1111aa11a1200001999999991999999991999999991999999991
00000000211a11aa11771772021a11aa1111a120021177111111a120021a11aa1111a12021111111aa11111200019999999919999999a19999999a1999999991
11111110021a11aa1111a120002a111aa11aaa20002a111aa11aaa20002a111aa11aaa2021111111a17771200001999aa9991999aaaa21999aaaa211aaaa9991
99199910002a111aa11aaa200002a11aa11a22000002a11aa11a22000002a11aa11a220027171711177777200001999229991999222211999222210122229991
991999100002a11aa11a22000000212121220000000021212122000000002121212200002171711a177777201111999119991999100001999100000111119991
aa199910000021212122000000000202020000000000020202000000000002020200000027171722222222009991999119991999100001999100001199999991
221999100000020202000000000020202000000000002020200000000000202020000000022122000000000099919991199919991000019991000019999999a1
0019991000002020200000000000000000000000000000000000000000000000000000000202000000000000aaa1aaa11aaa1aaa100001aaa1000012aaaaaa21
00199910000000000000000000000000000000000000000000000000000000000000000020200000000000002221222112221222100001222100000122222210
cccccccccccccccccccccccccccc66666666cccccccccccc6666666cccccccccccccccc66666666ccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccc66677777777666ccccccc66777777766ccccccccccc66677777777666cccccccccc66666666cccccccccccccccccccccccccccc
666cccccccccccccccccccc667777777777777766cccc6777777777776cccccccc667777777777777766ccccc66677777777666cccccccccccccccccc6666666
777666ccccccc66666cccc67777777777777777776cc677777777777776cccccc67777777777777777776cc667777777777777766ccccccccccccc6667777777
77777766ccc667777766c677777777777777777777667777777777777776cccc677777777777777777777667777777777777777776cccccccccc667777777777
777777776c677777777767777777777777777777777777777777777777776cc67777777777777777777777777777777777777777776c666cccc6777777777777
77777777767777777777777777777777777777777777777777777777777776677777777777777777777777777777777777777777777677766c67777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777677777777777777
cccccccc777777771111111111111111fff777fff777fff777fff7771fbfbbbb3b333333333232212fbfbbbb3b33333333323212111111111111111111111111
cccccccc77777777fffffffffffffff1ff777fff777fff777fff777f1fbfbbbb3b333333333232212fbfbbbb3b33333333323212111111111111111111111111
cccccccc77777777bbbbbbbbbbbbbb31f777fff777fff777fff777ff1fbfbbbb3b333333333232212fbfbbbb3b33333333323212116111111111111111611111
cccccccc777777773333333333333331777fff777fff777fff777fff1fbfbbbb3b333333333232212fbfbbbb3b33333333323212161611111111111111111111
cccccccc77777777111111111111111177fff777fff777fff777fff71fbfbbbb3b333333333232212fbfbbbb3b33333333323212116111111111111111111111
cccccccc7777777733333333333333337fff777fff777fff777fff771fbfbbbb3b333333333232212fbfbbbb3b33333333323212111111111111161111111111
cccccccc777777770000000000000000fff777fff777fff777fff7771fbfbbbb3b333333333232212fbfbbbb3b33333333323212111111111111111111111111
cccccccc777777770000000000000000ff777fff777fff777fff777f1fbfbbbb3b333333333232212fbfbbbb3b33333333323212111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222000000000000
00000000000000002b3b3320000000000000000000000000000000000000002222200000000000000000000002222200000000000000002b3333200000000000
0000000000000002b3b3333200002222200000022220000000000000000002b3b332000000000222200000002b33332000000000000002b3b333320000022222
200000000000002b3b3333332002b3b33200002b3b3200000022222000002b3b3333200000002b3332000002b3b333320000022220002b3b33333320002b3b33
3200002222000023b3333333202b3b33332002b3b333200002b333320002b3b3333332000002b3b33320002b3b33333320002b33320023b33333332002b3b333
332002b333222222233333322222b3333322223b333322222b3333332222223333333222222b3b3333322222333333322222b3b3332222333333222222333333
32222b33332b3b333233332b3b33233332b333233332233323333332b3333323333332b3b3323333332b33332333332b3333233332b333233332b3b333233333
2b33323332b3b333332332b3b33332332b3b3332332b3b333233332b3b33333233332b3b3333233332b3b333323332b3b33332332b3b3332332b3b3333323333
b3b33323323333333323323333333233233333323323b33332333323333333323332b3b333333233323333333233323333333233233333323323333333323332
3b333323333333333333333333333333333333333333333333333333333333333332333333333233333333333333333333333333333333333333333333333332
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
00000000000000000000000000000000000000000000000000000000000000002222222022222200222222202222222022222220222222202222222022222200
00000000000000000000000000000000000000000000000000000000000000002777771227777120277777122777771227717712277777122777771227777120
00000000000000000000000000000000000000000000000000000000000000002771771222777120277777122777771227717712277777122771111227777120
00000000000000000000000000000000000000000000000000000000000000002771771202777120211177122111771227717712277111122777771221177112
00000000000000000000000000000000000000000000000000000000000000002771771202777120277777122777771227777712277777122771771227777712
00000000000000000000000000000000000000000000000000000000000000002771771202777120277111122111771222227712211177122771771222277112
00011111111111111111111111111000000222222222222222222222222220002771771222777112277777122777771200027712277777122771771200277120
001bffffffffffbfbbbbbbbbbbb32100002bffffffffffbfbbbbbbbbbbb312002777771227777712277777122777771200027712277777122777771200277120
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002111111221111112211111122111111200021112211111122111111200211120
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000222222202222222022222200222222000002220022222200222222000022200
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000000000000000000000000000000000000000000000000000000000000000000
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000000000000000000000000000000000000000000000000000000000000000000
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000000000000000000000000000000000000000000000000000000000000000000
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000000000000000000000000000000000000000000000000000000000000000000
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212000000000000000000000000000000000000000000000000000000000000000000
00011111111111111111111111111000000211111111111111111111111120000000000000000000000000000000000000000000000000000000000000000000
0001111111111111111111111111100000021111111111111111111111112000222222202222222022222220111111110000000002ffffff0000000000000000
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002777771227777712277177121fff33210002222202ffffff0000000000000001
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002771771227717712227771121fb333210027777702ffffff0000000000000017
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002771771227717712021711201fb33321027fffff02ffffff0000000000000177
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002777771227717712227771121fb3332102ffffff02efffff0000000000000176
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002771771227777712277177121fb3332102ffffff002eeeee0000000000010167
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002771771221117712211111121bb3332102ffffff000222220000000000010016
001ffbbbbbb3b3333333333332322100002ffbbbbbb3b33333333333323212002777771227777712022222201bb3332102ffffff000000000000000000001001
001bffffffffffbfbbbbbbbbbbb32100002bffffffffffbfbbbbbbbbbbb312002111111221111112000000001bb333210000000002ffffff0000000000100100
00011111111111111111111111111000000222222222222222222222222220000222222002222220000000001bb332210000022202ffffff0000000000010010
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111110002277702efffff0000000000001000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000277fff002fffff0000000000000001
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002fffff002eefff0000000000000001
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000027fffff00022eee0000000000000001
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002ffffff000002220000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002ffffff000000000000000000000000
00000000000000000000044400000000000000001111111166666666000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000444550000000000000001111111166666666000000000000000000999999000000000000000011000111000000000000000000000000
000000000000000000044445550000000000000011111111666666660000000000000000997776669900000000000000a1001777000000000000000000000000
000000000000000004444445555500000000000011111111666666660000000000000009777776666699000000000000a1017776000000000000000044445000
00000000000000004444444555555000000000001111111166666666000000000000099777777766666690000000000091177767000000000000044444455550
50000000000000044444444555555500000000001111111166666666000000000000977777777766666669900000000021777676000000000044444444555555
55000000000000444444444455555550000000001111111166666666000000000099777777777766666666695000000011776767000000004444444445555555
555500000000044444444444555555550000000011111111666666660000000009777777777777666666666555500000a1767676000000444444444445555555
555550000000444444444444555555555500000000000000000000000000000997774777777746665666665555555000000000000000444444444444a1676711
55555500000444444444444455555555555000000000000000000000000009977744477477744565556665555555555000000000000444444444444591761110
5555555500444444444444444555555555550000000000000000000000004444444477447744555555565555555555550000000044444444444444452111aa11
55555555544444444444444445555555555550000000000000000000004444444444744474455555555555555555555555000004444444444444444511111aa1
555555555444444444444444455555555555550000000000000000004444444444444444445555555555555555555555555504444444444444444445a1aa111a
555555555544444444444444555555555555555000000000000000444444444444444444445555555555555555555555555544444444444444444445a1aaaa11
55555555555444444444444455555555555555550000000000004444444444444444444445555555555555555555555555544444444444444444444591111111
55555555555544444444444455555555555555555550000000444444444444444444444455555555555555555555555555444444444444444444445521000000
55555555555554444444444566666666000000005555500444444444aaaaaaa144444445000000000000000055555555544444441aaaaaaa4444445500000000
55555555555555444444445567776666000000005555555444444444aa99aaa144444445111111111111111155555555444444441aaa99994444445510000000
55555555555555444444445566666666000000005555555444444444aa22aaa1444444551aaaaaaa11aaaaaa55555554444444441aaa22224444455571000000
55555555555555544444445567766666000000005555555554444444aa11aaa144444555aaaaaaaa1aaaaaaa55555544444444441aaa11114444455577100000
55555555555555554444455566666666000000005555555555444444aaaaaaa144445555aaa999991aaa999955555444444444441aaaaaaa4444555567100000
55555555555555555444455567666666000006005555555555554444aaaaaa9144445555aaa222221aaa2222555544444444444419aaaaaa4444555576101000
555555555555555555444555666666660000060055555555555555449999992144455555aaa111111aaa11115554444444444444129999994445555561001000
555555555555555555544555666666660006060055555555555555542222221044455555aaaaaaaa1aaaaaaa5544444444444444112222224455555510010000
0000000000000000555545550000000000000000660000001176761a5444444444555555aaaaaaaa555555555444444444444444444444444555555500100100
1110001111111110555555550000000000000000660000000111671a5544444445555555aaa99999555555554444444444444444444444445555555501001000
7771001aaaaaaa115555555500000000000000006600000011aa111a5555444445555555aaa22222555555544444444444444444444444455555555500010000
6777101aaaaaaaa1555555550000000000000000660000001aa1111a5555554455555555aaa11111555555444444444444444444444445555555555510000000
7677711aaa99aaa155555555000000000006060066000000a111aa1a5555555555555555aaaaaaaa555554444444444444444444444455555555555510000000
6767771aaa22aaa15555555500000000000066006600000011aaaa1a55555555555555559aaaaaaa555555444444444544444444444555555555555510000000
7676771aaa11aaa15555555500066666000666006600000011111119555555555555555529999999555555554444445555544444445555555555555500000000
6767671aaaaaaaa15555555500006000000006006600000000000012555555555555555512222222555555555555555555555555555555555555555500000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc1111111111111ccccc111111111111111111111111111111111111ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19999999919991cccc1199999911999999911999999911999119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19999999919991cccc1999999991999999991999999991999119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999aaaaa19991cccc1999aa9991999aa9991999aa9991999119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19992222219991cccc1999229991999229991999229991999119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999111cc19991cccc1999119991999119991999119991999119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999991cc19991cccc1999999991999999991999999991999999991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999991cc19991cccc19999999919999999a19999999a1999999991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999aa1cc19991cccc1999aa9991999aaaa21999aaaa211aaaa9991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1999221cc19991cccc199922999199922221199922221c122229991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19991cccc19991111119991199919991cccc19991ccccc111119991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19991cccc19999999919991199919991cccc19991cccc1199999991ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc19991cccc1a999999919991199919991cccc19991cccc19999999a1ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc1aaa1cccc12aaaaaaa1aaa11aaa1aaa1cccc1aaa1cccc12aaaaaa21ccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc12221ccccc1222222212221122212221cccc12221ccccc12222221cccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccc1111ccc111111111c111111111111111111ccc1111cccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccc177771cc1aaaaaaa111aaaaaaa11aaaaaaa1cc177771ccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccc17767771c1aaaaaaaa1aaaaaaaa1aaaaaaaa1c17776771cccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccc1767677711aaa99aaa1aaa999991aaa999991177767671cccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc1c1676767771aaa22aaa1aaa222221aaa222221777676761c1cccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc1cc167676771aaa11aaa1aaa111111aaa11111177676761cc1cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccc1cc16767671aaaaaaaa1aaaaaaaa1aaaaaaaa17676761cc1ccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc1cc1cc1176761aaaaaaaa1aaaaaaaa1aaaaaaaa1676711cc1cc1ccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc1cc1cc111671aaa99aaa1aaa999991aaa99999176111cc1cc1cccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccc1ccc11aa111aaa22aaa1aaa222221aaa22222111aa11ccc1ccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccc11aa1111aaa11aaa1aaa111111aaa111111111aa11cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccc1a111aa1aaaaaaaa1aaaaaaaa1aaaaaaaa1aa111a1cccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccc111aaaa1aaaaaaa919aaaaaaa19aaaaaaa1aaaa111cccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccc1111111999999921299999991299999991111111ccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccc122222221c122222221122222221ccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc6c6ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc66ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccc666ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccc66666666cccc6ccccccc6666666cccccccccccccccc66666666ccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccc66677777776666666666c66777777766ccccccccccc66677777777666cccccccccc66666666cccccccccccccccccccccccccccccc
6cccccccccccccccccccc66777777777767776666666777777777776cccccccc667777777777777766ccccc66677777777666cccccccccccccccccc666666666
7666ccccccc66666cccc6777777777777666666666677777777777776cccccc67777777777777777776cc667777777777777766ccccccccccccc666777777777
777766ccc667777766c677777777777776776666666777777777777776cccc677777777777777777777667777777777777777776cccccccccc66777777777777
7777776c677777777767777777777777766666666667777777777777776cc67777777777777777777777676777777777777777776c666cccc677777777777777
777777767777777777777777777777777676666666677777777777777776677777777777777777777777766777777777777777777677766c6777776777777777
77777777777777777777777777777777766666666667777777777777777777777777777777777777777766677777777777777777777777767777776777777777
77777777777777777777777777777777766666666667777777777777777777777777777777777777777777677777777777777777777777777777676777777777
77777777777777777777777777777777766666666667777777777777777777777777777777777777766666666777777777777777777777777666666666677777
77777777777777777777777777777777766666666667777777777777777777777777777777777777767776666777777777777777777777777677766666677777
77777777777777777777777777777777766666666667777777777777777777777777777777777777766666666777777777777777777777777666666666677777
77777777777777777777771777777177766666666667777777777777777777777777777777777777767766666777777777777777777777777677666666677777
77777777777777777777717177771717766666666667777777777777777777777777777777777777766666666777777777777777777777777666666666677777
77777767777777777777771717717177766666666667777777777777777777777777776777777777767666666777776777777777777777777676666666677777
77777767777777777777777171171666666666666667777777777777777777777777776777777777766666666777776777777777777766666666666666677777
77776767777777777777711717711117766611111111111117777111111117771111111111111111111116661111171111111777777776777666666666677777
76666666666777777777177117711771666617771777177717771177177717771777177717771177117716661777111717171777766666666666666666677777
76777666666777777777711717711116666611711717171717771717171717771717171717111711171116661117117117171777767776666666666666677777
76666666666777777777777717767616666661711777177717771717177117771777177117711777177716661171117111711777766666666666666666677777
76776666666777777777777176767671666661711717171117771717171717771711171717111117111716661711117117171777767766666666666666677777
76666666666777777777777176767671666661711717171777771771171717771716171717771771177116661777171117171777766666666666666666677777
76766666666777777777777176767671666661111111111777771111111117771116111111111111111166661111111611111777767666666666666666677777
76666666666777777777777717777716666666666667777777777767777777777666666666677777766666666666666666677777766666666666666666677777
76666666666777777777777771777716666666666667777777776767777777777666666666677777766666666666666666677777766666666666666666677777
66666666666666666667777771666616666666666667777776666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666667776666667777776111166666666666667777776777666666666666666666666777666666666666666666666666666666666666666666666777666
66666666666666666667777776666666666666666667777776666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666667766666667777776666666666666666667777776776666666666666666666666776666666666666666666666666666666666666666666666776666
66666666666666666667777776666666666666666667777776666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666667666666667777776666666666666666667777776766666666666666666666666766666666666666666666666666666666666666666666666766666
66666666666666666667777776666666666666666667777776666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666667777776666666666666666667777776666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666222226666666666666666666666666666622222666666666666666666666666
66666666666666662222266666666666666666666662222266666666666666662b333326666666666666666666666666662b3b33266666666666666666666666
6666666666666662b3b332666666666222266666662b33332666666666666662b3b3333266666222226666666666666662b3b333326666222226666662222666
666622222666662b3b3333266666662b3332666662b3b333326666622226662b3b33333326662b3b33266666666666662b3b3333332662b3b33266662b3b3266
6662b333326662b3b3333332666662b3b33326662b3b33333326662b33326623b33333332662b3b3333266662222666623b3333333262b3b33332662b3b33326
222b3333332222223333333222222b3b3333322222333333322222b3b3332222333333222222333333332662b333222222233333322222b3333322223b333322
3323333332b3333323333332b3b3323333332b33332333332b3333233332b333233332b3b33323333332222b33332b3b333233332b3b33233332b33323333223
333233332b3b33333233332b3b3333233332b3b333323332b3b33332332b3b3332332b3b33333233332b33323332b3b333332332b3b33332332b3b3332332b3b
3332333323333333323332b3b333333233323333333233323333333233233333323323333333323332b3b33323323333333323323333333233233333323323b3
33333333333333333333323333333332333333333333333333333333333333333333333333333333323b33332333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
ffff1fffffffffffffff1fffffffffffffff1fffffffffffffff1fffffffffffffff1fffffffffffffff1fffffffffffffff1fffffffffffffff1fffffffffff
bbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbbbbb31bbbbbbbbbbb
33331333333333333333133333333333333313333333333333331333333333333333133333333333333313333333333333331333333333333333133333333333
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
ff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff
f777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff7
777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff77
77fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777
7fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777f
fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777ff
ff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff
f777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff7
777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff77
77fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777
7fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777f
fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777ff
ff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff
f777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff7
777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff77
77fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777
7fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777f
fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777fff777ff

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc0c1c2c300000000c8c9cacb00cdcecfc0c1c2c300000000c8c9cacb00cdcecf
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010302b2c2d2e2f005758595a5b5cd0d1d2d3d4d5d6d7d8d9dadbdcdddee0d0d1d2d3d4d5d6d7d8d9dadbdcdddee0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200f3b3c3d3e3f005758595a5b5ce0e1e2e0e0e5e6d2e8e0e0ebecd2eee0e0e1e2e0e0e5e6d2e8e0e0ebecd2eee0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aff0f1e9eaccef005758595a5b5ce0e0f2e0e0e0e0f7f8e0fafbfcfdfee0e0e0f2e0e0e0e0f7f8e0fafbfcfdfee0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bff6e7f9eddfff005758595a5b5c5253525352535253525352535253525352535253525352535253525352535253
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c5455565455565455565455565455565455565455565455565455565455565455
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c5556545556545556545556545556545556545556545556545556545556545556
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c5654555654555654555654555654555654555654555654555654555654555654
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c404142434445464748494a4b4c4d4e4f404142434445464748494a4b4c4d4e4f
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc55fc5c5c5c5c55f5dc55ec5c5c5c55ec55fc5c5c5c5c55f5dc55ec5c5c5c55e
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc5c55dc55f5ec5c5c5c5c5c5c55fc5c5c5c55dc55f5ec5c5c5c5c5c5c55fc5c5
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c5f5ec5c5c55dc55ec5c55fc5c55dc5c55f5ec5c5c55dc55ec5c55fc5c55dc5c5
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc5c5c5c55fc5c5c5c5c55dc5c5c55ec5c5c5c5c55fc5c5c5c5c55dc5c5c55ec5
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c606162636465666768696a6b6c6d6e6f606162636465666768696a6b6c6d6e6f
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c707172737475767778797a7b7c7d7e7f707172737475767778797a7b7c7d7e7f
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c0000000000f4000000000000000000000000000000f400000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c0000000000e3f500000000f4000000e40000000000e3f500000000f4000000e4
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c00e40000f3c6f50000e400e3e400f3e3f5e40000f3c6f50000e400e3e400f3e3
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5c00e3f500e3c6f5e400e3f5c6e3f5e3c6f5e3f500e3c6f5e400e3f5c6e3f5e3c6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5ce3c6e3f5c6c6f5e3c6c6e3c6c6c6c6c6e3c6e3f5c6c6f5e3c6c6e3c6c6c6c6c6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005758595a5b5cc6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0112000003744030250a7040a005137441302508744080251b7110a704037440302524615080240a7440a02508744087250a7040c0241674416025167251652527515140240c7440c025220152e015220150a525
011200000c033247151f5152271524615227151b5051b5151f5201f5201f5221f510225212252022522225150c0331b7151b5151b715246151b5151b5051b515275202752027522275151f5211f5201f5221f515
011200000c0330802508744080250872508044187151b7151b7010f0251174411025246150f0240c7440c0250c0330802508744080250872508044247152b715275020f0251174411025246150f0240c7440c025
011200002452024520245122451524615187151b7151f71527520275202751227515246151f7151b7151f715295202b5212b5122b5152461524715277152e715275002e715275022e715246152b7152771524715
011200002352023520235122351524615177151b7151f715275202752027512275152461523715277152e7152b5202c5212c5202c5202c5202c5222c5222c5222b5202b5202b5222b515225151f5151b51516515
011200000c0330802508744080250872508044177151b7151b7010f0251174411025246150f0240b7440b0250c0330802508744080250872524715277152e715080242e715080242e715246150f0240c7440c025
010e000005145185111c725050250c12524515185150c04511045185151d515110250c0451d5151d0250c0450a0451a015190150a02505145190151a015050450c0451d0151c0150012502145187150414518715
010e000021745115152072521735186152072521735186052d7142b7142971426025240351151521035115151d0451c0051c0251d035186151c0251d035115151151530715247151871524716187160c70724717
010e000002145185111c72502125091452451518515090250e045185151d5150e025090451d5151d025090450a0451a015190150a02505045190151a015050450c0451d0151c0150012502145187150414518715
010e000029045000002802529035186152802529035000001a51515515115150e51518615000002603500000240450000023025240351861523025240350000015515185151c51521515186150c615280162d016
010e000002145185112072521025090452451518515090450e04521515265150e025090451d5151d01504045090451d01520015210250414520015210250404509045280152d0150702505145187150414518715
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000060100a0101102014020120301c0401a0501b050100501b050180501b05016050230500d05017050130501c0501a050280502e050310002800028000240001e00020000210001b000180000000000000
000300001f0501f0501f0502705027050270502700027000270002700027000270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000163003630056200762008620096200b6200f62012620176201c6102161026610296102c6003060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000123500d350073500435001340013200130001400014000140001400014000140001400014000140000000000000000000000000000000000000000000000000000000000000000000000000000000000
000700001f350273501f300273002a200322003420035200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000243201d3001e3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800002f2402d2002d2002f2402d2002d2002f2402d200002002f24030300003000050000000005000050000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000223201d3001f3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001f350000001f300273002a200322003420035200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000018350000001f300273002a200322003420035200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c620126400d6300962007610056100360001600016000960009600096000960009600096000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600000c650116500a6500465009650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000700000134001330014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000223301d3001f3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000022330000001f300273002a200322003420035200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000007550095500a5500b5500e55012550165501b55021550275502d550315502a50037500395000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000d0000260502c0502c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00424344
00 00424344
00 00014344
00 00014344
01 00014344
00 00014344
00 02034344
02 04054344
01 06074344
00 06074344
00 08074344
00 08074344
00 0a094344
02 08094344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

