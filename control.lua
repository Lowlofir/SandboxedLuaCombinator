require "blueprint_custom_data.blueprint_custom_data"
local lex = require 'script.lexer'
local migrations = require 'script.migrations'
local semver = require 'script.semver'

local function toboolean(v)
	if v then 
		return true
	else
		return false
	end
end

sandbox_env_std = {
  ipairs = ipairs,
  next = next,
  pairs = pairs,
  pcall = pcall,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  serpent = { block = serpent.block },
  string = { byte = string.byte, char = string.char, find = string.find,
      format = string.format, gmatch = string.gmatch, gsub = string.gsub,
      len = string.len, lower = string.lower, match = string.match,
      rep = string.rep, reverse = string.reverse, sub = string.sub,
      upper = string.upper },
  table = { insert = table.insert, maxn = table.maxn, remove = table.remove,
      sort = table.sort, pack = table.pack, unpack = table.unpack, },
  math = { abs = math.abs, acos = math.acos, asin = math.asin,
      atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos,
      cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor,
      fmod = math.fmod, frexp = math.frexp, huge = math.huge,
      ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max,
      min = math.min, modf = math.modf, pi = math.pi, pow = math.pow,
      rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh,
      sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
}

combinators_local = {}
function combinators_local.register(id)
	combinators_local[id] = {}
end
function combinators_local.unregister(id)
	combinators_local[id] = nil
end

combinators_local_cbs = {}


local settings_cache = {}

function settings_cache:get(player_id, sett_name)
	if not self[player_id] then
		local pl = game.players[player_id]
		self[player_id] = { indent_code = pl.mod_settings['luacomsb-indent-code'].value,
							colorize_code = pl.mod_settings['luacomsb-colorize-code'].value
						}
	end
	return self[player_id][sett_name]
end

function settings_cache:update(player_id, ext_sett_name)
	local pl = game.players[player_id]
	if not self[player_id] then
		self[player_id] = { indent_code = pl.mod_settings['luacomsb-indent-code'].value,
							colorize_code = pl.mod_settings['luacomsb-colorize-code'].value}
	else
		local sett_name_adapt = ext_sett_name:gsub('luacomsb%-',''):gsub('%-','_')
		assert( self[player_id][sett_name_adapt] )
		self[player_id][sett_name_adapt] = pl.mod_settings[ext_sett_name].value
	end
end

local function on_runtime_mod_setting_changed( ev )
	game.print(ev.player_index..': '..ev.setting)
	settings_cache:update(ev.player_index, ev.setting)
end

script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)




script.on_init( function ()
	global.combinators = {}
	global.guis = {}
	global.signals = {}
	for name, _ in pairs(game.virtual_signal_prototypes) do
		global.signals[name]="virtual"
	end
	for name, _ in pairs(game.item_prototypes) do
		global.signals[name]="item"
	end
	for name, _ in pairs(game.fluid_prototypes) do
		global.signals[name]="fluid"
	end
	global.presets = {}
	global.history = {}
	global.historystate = {}
	global.textboxes = {}
end)

local function parse_version(version)
	if (not version) or (not version:match('^%d+%.%d+%.%d+$')) then return nil; end
	return semver(version)
end

local function migrate_if_required(changes)
	local mod_name = 'SandboxedLuaCombinator'
	if not changes[mod_name] then
		return  -- not required
	end
	new_ver_str = changes[mod_name].new_version
	old_ver_str = changes[mod_name].old_version

	new_ver = parse_version(new_ver_str)
	old_ver = parse_version(old_ver_str)

	if (not new_ver) or (not old_ver) then return end
	if new_ver == old_ver then
		game.print('SandboxedLuaCombinator: new_ver == old_ver')
		return
	end

	table.sort(migrations, function(m1, m2) return parse_version(m1.version) <= parse_version(m2.version) end)

	for _,m in ipairs(migrations) do
		m_ver = parse_version(m.version)
		assert(m_ver)
		-- game.print('SandboxedLuaCombinator: '..old_ver_str..' -> '..new_ver_str)
		log('SandboxedLuaCombinator: '..old_ver_str..' -> '..new_ver_str)
		-- game.print('SandboxedLuaCombinator: '..m_ver.major..':'..m_ver.minor..':'..m_ver.patch)
		-- game.print('SandboxedLuaCombinator: '..old_ver.major..':'..old_ver.minor..':'..old_ver.patch)
		-- game.print('SandboxedLuaCombinator: '..tostring(m_ver > old_ver))
		if m_ver > old_ver and m_ver <= new_ver then
			-- game.print('SandboxedLuaCombinator: '..tostring(m_ver > old_ver)..' checkpoint 2')
			if not m.silent then
				game.print('SandboxedLuaCombinator: applying migration '..m.version)
			end
			log('SandboxedLuaCombinator: applying migration '..m.version)
			m.apply()
		end
	end 

end

script.on_configuration_changed(function(changes)
	global.signals={}
	for name, _ in pairs(game.virtual_signal_prototypes) do
		global.signals[name]="virtual"
	end
	for name, _ in pairs(game.item_prototypes) do
		global.signals[name]="item"
	end
	for name, _ in pairs(game.fluid_prototypes) do
		global.signals[name]="fluid"
	end
	if not global.presets then
		global.presets = {}
		for i, gui in pairs(global.guis) do
			gui.destroy()
			global.guis[i] = nil
		end
	end
	if not global.history then
		global.history = {}
		global.historystate = {}
	end
	if not global.textboxes then
		global.textboxes = {}
	end

	-- game.print(serpent.block(changes))
	migrate_if_required(changes.mod_changes)
end)


script.on_load( function ()
	for k,v in pairs(global.combinators) do
		combinators_local.register(k)
	end
end)

script.on_event(defines.events.on_pre_ghost_deconstructed, function(event)
	if event.ghost and event.ghost.type == "entity-ghost" and event.ghost.ghost_name == "lua-combinator-sb" then
		local spot= event.ghost.surface.find_entities_filtered{name="entity-ghost", inner_name="luacomsb_blueprint_data", ghost_name="luacomsb_blueprint_data", area= {{event.ghost.position.x-0.1,event.ghost.position.y-0.1},{event.ghost.position.x+0.1,event.ghost.position.y+0.1}}}
		if #spot >0 then
			spot[1].destroy()
		end
	end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
	if event.entity  and event.entity.name == "entity-ghost" and event.entity.ghost_name == "lua-combinator-sb" then
		local spot= event.entity .surface.find_entities_filtered{name="entity-ghost", inner_name="luacomsb_blueprint_data", ghost_name="luacomsb_blueprint_data", area= {{event.entity.position.x-0.1,event.entity.position.y-0.1},{event.entity.position.x+0.1,event.entity.position.y+0.1}}}
		if #spot >0 then
			spot[1].destroy()
		end
	end
end)

function load_combinator_code(id)
	local env_ro, env_var = create_env(global.combinators[id].variables)
	combinators_local[id].env_ro = env_ro
	combinators_local[id].env_var = env_var
	local code = global.combinators[id].code
	return load(code, code, 't', env_var)
end

function create_env(v)
	assert(v and type(v)=='table')
	v.var = v.var or {}

	local ro_meta = {
		__index = sandbox_env_std,
	}
	local ro_env = setmetatable({}, ro_meta)
	ro_env.print = game.print

	local var_meta = {
		__index = ro_env,
		__newindex = function (table, key, value)
			if rawget(ro_env, key) then
				ro_env[key] = value
			else
				rawset(table, key, value)
			end
		end
	}
	local var_env = setmetatable(v, var_meta)
	return ro_env, var_env
end

function load_code(code,id)
	local test=remove_colors(code)
	local code = (test or "")
	global.combinators[id].code = code
	combinators_local[id].func, global.combinators[id].errors = load_combinator_code(id)
	-- combinators_local[id].func = global.combinators[id].func ------------------
	if not global.combinators[id].errors then
		global.combinators[id].errors = ""
	end
	global.combinators[id].errors2 = ""
	local _, countred = string.gsub(global.combinators[id].code, "rednet", "")
	local _, countgreen = string.gsub(global.combinators[id].code, "greennet", "")
	global.combinators[id].usered = (countred > 0)
	global.combinators[id].usegreen = (countgreen > 0)
	write_to_combinator(global.combinators[id].blueprint_data,global.combinators[id].code)
	if global.combinators[id].entity.valid then
		for _, player in pairs(game.players) do
			player.remove_alert{entity = global.combinators[id].entity}
		end
	end
end

local function on_built_entity(event)
	if event.created_entity.valid and event.created_entity.name == "lua-combinator-sb" then
		local unit_id = event.created_entity.unit_number
		combinators_local.register(unit_id)
		global.combinators[unit_id] = {formatting = true, entity = event.created_entity, code="", variables = {}, errors="", errors2="", output={}, next_tick=1, usegreen = false, usered = false}
		local blueprint_data983 = event.created_entity.surface.find_entities_filtered{position = event.created_entity.position, ghost_name = "luacomsb_blueprint_data"}
		if blueprint_data983[1] then
			global.combinators[unit_id].code=read_from_combinator(blueprint_data983[1])
			combinators_local[unit_id].func,global.combinators[unit_id].errors = load_combinator_code(unit_id)
			-- combinators_local[unit_id].func = global.combinators[unit_id].func
			if not global.combinators[unit_id].errors then
				global.combinators[unit_id].errors = ""
			end
			local _, countred = string.gsub(global.combinators[unit_id].code, "rednet", "")
			local _, countgreen = string.gsub(global.combinators[unit_id].code, "greennet", "")
			if countred > 0 then
				global.combinators[unit_id].usered = true
			else
				global.combinators[unit_id].usered = false
			end
			if countgreen > 0 then
				global.combinators[unit_id].usegreen = true
			else
				global.combinators[unit_id].usegreen = false
			end
			blueprint_data983[1].destroy()
		end
		global.combinators[unit_id].blueprint_data = event.created_entity.surface.create_entity{name = "luacomsb_blueprint_data", position = event.created_entity.position, force = event.created_entity.force}
		global.combinators[unit_id].blueprint_data.destructible = false
		global.combinators[unit_id].blueprint_data.minable = false
		write_to_combinator(global.combinators[unit_id].blueprint_data,global.combinators[unit_id].code)
	end
end


local function on_entity_settings_pasted(event)
	if event.source.name == "lua-combinator-sb" and event.destination.name == "lua-combinator-sb" then
		local dst_id = event.destination.unit_number
		local src_id = event.source.unit_number
		global.combinators[dst_id].code = global.combinators[src_id].code
		global.combinators[dst_id].variables = luacomsb_deepcopy(global.combinators[src_id].variables)
		global.combinators[dst_id].errors2 = global.combinators[src_id].errors2
		global.combinators[dst_id].output = luacomsb_deepcopy(global.combinators[src_id].output)
		global.combinators[dst_id].next_tick = global.combinators[src_id].next_tick
		if not 	   global.textboxes["luacomsb_gui_"..dst_id] then
			global.textboxes["luacomsb_gui_"..dst_id] = global.combinators[src_id].code
		end
		if not global.history["luacomsb_gui_"..dst_id] then
			global.history["luacomsb_gui_"..dst_id] = {global.combinators[src_id].code}
			global.historystate["luacomsb_gui_"..dst_id] = 1
		else
			insert_history ("luacomsb_gui_"..dst_id,global.combinators[src_id].code)
		end
		combinators_local[dst_id].func,global.combinators[dst_id].errors = load_combinator_code(dst_id)
		-- combinators_local[dst_id].func = global.combinators[dst_id].func
		if not global.combinators[dst_id].errors then
			global.combinators[dst_id].errors = ""
		end
		local _, countred = string.gsub(global.combinators[dst_id].code, "rednet", "")
		local _, countgreen = string.gsub(global.combinators[dst_id].code, "greennet", "")
		global.combinators[dst_id].usered = (countred > 0)
		global.combinators[dst_id].usegreen = (countgreen > 0)
		global.combinators[dst_id].formatting = global.combinators[src_id].formatting
		write_to_combinator(global.combinators[dst_id].blueprint_data,global.combinators[dst_id].code)
	end
end

local function on_tick(event)
	-- print = game.print
	-- printt = function (o)
	-- 	return game.print(serpent.block(o))
	-- end

	for unit_nr, gui_t in pairs(global.guis) do
		local gui = gui_t.gui
		if (not global.combinators[unit_nr]) or (not global.combinators[unit_nr].entity.valid) then
			gui.destroy()
			global.guis[unit_nr]=nil
			combinators_local.unregister(unit_nr)
		else
			if gui.main_table.flow then
				gui.main_table.flow.clear()
			end
			local com983 = global.combinators[unit_nr].entity

			local red, green = get_networks(com983,global.combinators[unit_nr].output)
			for sig,val in pairs(red) do
				local cap = gui.main_table.flow.add{type="label",name="red_"..sig,caption=sig.."= "..val}
				cap.style.font_color= {r=1,g=0.3,b=0.3}
			end
			for sig,val in pairs(green) do
				local cap = gui.main_table.flow.add{type="label",name="green_"..sig,caption=sig.."= "..val}
				cap.style.font_color= {r=0.3,g=1,b=0.3}
			end
			gui.main_table.left_table.under_text.errors.caption=(global.combinators[unit_nr].errors or "")..(global.combinators[unit_nr].errors2 or "")
		end
	end

	for unit_nr, tbl in pairs(global.combinators) do
		if not tbl.entity or not tbl.entity.valid then
			if global.combinators[unit_nr].blueprint_data and global.combinators[unit_nr].blueprint_data.valid then
				global.combinators[unit_nr].blueprint_data.destroy()
			end
			global.combinators[unit_nr]=nil
			combinators_local.unregister(unit_nr)
		else
			if event.tick % 600 == 0 and tbl.errors..tbl.errors2 ~= "" then
				for _, player in pairs(game.players) do
					player.add_custom_alert(tbl.entity,{type="virtual", name="luacomsb_error"},"LuaCombinator Error: "..tbl.errors..tbl.errors2,true)
				end
			end
			if event.tick >= tbl.next_tick and tbl.code ~= "" then
				if not combinators_local[unit_nr].func then
					combinators_local[unit_nr].func, global.combinators[unit_nr].errors = load_combinator_code(unit_nr)
					global.combinators[unit_nr].errors = global.combinators[unit_nr].errors or ""
				end
				if combinators_local[unit_nr].func then
					combinator_tick(unit_nr)
				end
			end
		end
	end

end

function combinator_tick(unit_nr)
	local tick = game.tick
	local tbl = global.combinators[unit_nr]

	local output = tbl.output
	local copiedoutput = luacomsb_deepcopy(output)
	local rednet, greennet
	if tbl.usered then
		rednet = get_red_network(tbl.entity,output)
	end
	if tbl.usegreen then
		greennet = get_green_network(tbl.entity,output)
	end

	local env_ro = combinators_local[unit_nr].env_ro
	local func = combinators_local[unit_nr].func
	assert(env_ro, 'no env')
	assert(func, 'no func')

	env_ro.delay = 1
	env_ro.rednet = rednet
	env_ro.greennet = greennet
	env_ro.output = output

	do
		local _,error = pcall(func)
		tbl.errors=error or ""
	end

	local delay = tonumber(env_ro.delay) or 1
	output = env_ro.output or {}

	if type(output) ~= "table" then
		tbl.errors = tbl.errors.."  +++output needs to be a table"
	else
		tbl.output = output
	end

	env_ro.var = env_ro.var or {}

	if compare_tables(copiedoutput, tbl.output) then
		local actual_output = {}
		local i=1
		tbl.errors2 = ""
		for signal,value in pairs(tbl.output) do
			if global.signals[signal] then
				if type (value) == "number" then
					if value >= -2147483648 and value <= 2147483647 then
						if value ~= 0 then
							actual_output[i]={signal={type=global.signals[signal], name=signal},count=value,index=i}
							i=i+1
						end
					else
						tbl.errors2 =tbl.errors2.."  +++output value must be between -2147483648 and 2147483647 ("..signal..")"
					end
				else
					tbl.errors2 = tbl.errors2.."  +++output value must be a number ("..signal..")"
				end
			else
				tbl.errors2 = tbl.errors2.."  +++invalid signal name in output ("..signal..")"
			end
		end
		if not tbl.entity or not tbl.entity.valid then
			global.combinators[unit_nr]=nil
			return
		else
			combinators_local_cbs[tbl.entity] = combinators_local_cbs[tbl.entity] or tbl.entity.get_or_create_control_behavior()
			local control = combinators_local_cbs[tbl.entity]
			-- local control = tbl.entity.get_or_create_control_behavior()
			control.parameters={parameters=actual_output}
		end
	end
	if tbl.errors..tbl.errors2 ~="" then
		for _, player in pairs(game.players) do
			if player.force == tbl.entity.last_user.force then
				player.add_custom_alert(tbl.entity,{type="virtual", name="luacomsb_error"},"LuaCombinator Error: "..tbl.errors..tbl.errors2,true)
			end
		end
	end
	tbl.next_tick = tick + delay

end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

script.on_event(defines.events.on_tick, on_tick)


function compare_tables (t1,t2)
	local i1 = table_size(t1)
	local i2 = 0
	for key, value in pairs(t2) do
		if t1[key] ~= t2[key] then
			return true
		end
		i2=i2+1
	end
	if i2 ~= i1 then
		return true
	end
	return false
end

function get_col_network (entity, output, wire_type)
	combinators_local_cbs[entity] = combinators_local_cbs[entity] or entity.get_control_behavior()
	local cnw = combinators_local_cbs[entity].get_circuit_network(wire_type)
	local ret_red = {}
	if cnw and cnw.signals then
		for _, tbl in pairs(cnw.signals) do
			local name = tbl.signal.name
			if tbl.count ~= 0 then
				ret_red[name] = tbl.count - (output[name] or 0)
			end
		end
	end
	return ret_red
end

function get_red_network (entity,output)
	return get_col_network(entity,output, defines.wire_type.red)
end

function get_green_network (entity,output)
	return get_col_network(entity,output, defines.wire_type.green)
end

function get_networks (entity,output)
	return get_red_network(entity,output), get_green_network(entity,output)
end






-- ##########################################################################################################





local function find_difference (current, cache)
	if current == cache then return nil end
	-- printt('-------------')
	-- printt(current)
	-- printt(cache)
	-- printt('+++')

	local pos = 1
	for i=1, math.min(#current, #cache) do
		local ch = current:sub(i,i)
		pos = i
		if ch ~= cache:sub(i,i) then
			break
		elseif pos == math.min(#current, #cache) then
			-- printt('eos')
			pos = i+1
		end
	end

	local undefined_cur
	local pos_cur = pos
	local pos_cch = pos
	local diff
	local trivial
	local diff_len = math.abs(#current - #cache)
	if #current > #cache then
		pos_cur = pos_cur + diff_len
		diff = current:sub(pos_cch, pos_cur-1)
		undefined_cur = (current:sub(pos_cur-2, pos_cur-2) == diff)
	elseif #current < #cache then
		-- printt('#current < #cache')
		pos_cch = pos_cch + diff_len
		diff = cache:sub(pos_cur, pos_cch-1)
		-- printt('pos_cur, pos_cch: '..pos_cur..', '..pos_cch)
		undefined_cur = (current:sub(pos_cur-1, pos_cur-1) == diff) or
						(current:sub(pos_cur, pos_cur) == diff)
	end
	trivial = (current:sub(pos_cur) == cache:sub(pos_cch))

	-- printt('diff: '..diff)
	if not trivial then
		log('not trivial')
		-- printt('not trivial')
		return pos_cur, true
	else
		local patt = ' +'
		local need_recolor = ( current:gsub(patt, ' ') ~=  cache:gsub(patt, ' '))
		local need_reflow = toboolean(diff:find(' *\n+ *'))
		if need_reflow then
			-- printt('need_reflow')
		end
		if undefined_cur then
			-- printt('pos_cur = nil')
			pos_cur = nil
		else
			-- printt('pos_cur: '..current:sub(pos_cur, pos_cur+6))
		end
		return pos_cur, need_recolor, need_reflow
	end
end


script.on_event(defines.events.on_gui_text_changed, function(event)
	local eid = find_eid_for_gui_element(event.element)
	if not eid then return end
	-- print('on_gui_text_changed')
	local indent_setting = settings_cache:get(event.player_index, 'indent_code' )
	local colorize_setting = settings_cache:get(event.player_index, 'colorize_code' )
	if event.element.name == "luacomsb_code" then
		if not global.textboxes then
			global.textboxes = {}
		end
		local gui = global.guis[eid].gui
		if not gui.flow.luacomsb_formatting.state or(not indent_setting and not colorize_setting) then
			if not global.history[gui.name] then
				global.history[gui.name] = {event.element.text}
				global.historystate[gui.name] = 1
			else
				insert_history(gui, event.element.text)
			end
			global.textboxes[gui.name] = event.element.text
			return
		end
		if not global.textboxes[gui.name] then
			global.textboxes[gui.name] = event.element.text
			if not global.history[gui.name] then
				global.history[gui.name] = {event.element.text}
				global.historystate[gui.name] = 1
			end
		else
			local current = remove_colors(event.element.text)
			local cache = remove_colors(global.textboxes[gui.name])
			local cursor, upd_col, upd_flow = find_difference(current,cache)
			if cursor then
				if upd_col or upd_flow then
					event.element.text, cursor = format_code(current, colorize_setting, upd_flow, cursor)
					event.element.select(cursor,cursor-1)
				end
			end
			if not global.history[gui.name] then
				global.history[gui.name] = {event.element.text}
				global.historystate[gui.name] = 1
			else
				insert_history(gui, event.element.text)
			end
			global.textboxes[gui.name] = event.element.text
		end
	end
end)

function remove_colors(text)
	text = string.gsub(text,"%[color=%d+,%d+,%d+%]","")
	text = string.gsub(text,"%[img=luacomsb_bug%]","")
	text = string.gsub(text,"%[/color%]","")
	text = string.gsub(text,"%[font=default%-bold%]","")
	text = string.gsub(text,"%[/font%]","")
	return text
end

function format_code(text, colorize, upd_flow, tracked_pos)
	colorize = colorize or true
	upd_flow = upd_flow or true

	local cursor = tracked_pos
	local tracking = true
	if not tracked_pos then tracking = false end

	-- printt('upd_flow: '..tostring(upd_flow))

	local result
	if upd_flow then
		local patt = '\n[ \t]+'
		if tracking then
			local t = 0
			local ii = 1
			while true do
				local a,b = text:find(patt, ii)
				if not a then break end
				ii=b+1
				if b > tracked_pos then
					if a >= tracked_pos then
						break
					else
						-- todo
						t = t + tracked_pos-(a+1)
						log('todo 15')

						-- print('todo 15')
					end
				end
				t = t + b-a
			end
			cursor = cursor - t
			-- print('t '..t)
		end
		result = text:gsub(patt, '\n')
		-- printt('tracked: '..result:sub(tracked_pos, tracked_pos+2))
	else
		result = text
	end

	local indent = 0
	local indentator = '  '
	if colorize or upd_flow then
		local lexed = lex(result)
		local blue = {"and","break","do","else","elseif","end","false","for","function","goto","if","in","local","nil","not","or","repeat","return","then","true","until","while"}
		local lightblue = {"assert","collectgarbage","dofile","error","getfenv","getmetatable","ipairs","load","loadfile","loadstring","module","next","pairs","pcall","print","rawequal","rawget","rawlen","rawset","require","select","setfenv","setmetatable","tonumber","tostring","type","unpack","xpcall","string","table","math","bit32","coroutine","io","os","debug","package"}
		local violet = {"byte","char","dump","find","format","gmatch","gsub","len","lower","match","rep","reverse","sub","upper","abs","acos","asin","atan","atan2","ceil","cos","cosh","deg","exp","floor","fmod","frexp","ldexp","log","log10","max","min","modf","pow","rad","random","randomseed","sin","sinh","sqrt","tan","tanh","arshift","band","bnot","bor","btest","bxor","extract","lrotate","lshift","replace","rrotate","rshift","shift","string.byte","string.char","string.dump","string.find","string.format","string.gmatch","string.gsub","string.len","string.lower","string.match","string.rep","string.reverse","string.sub","string.upper","table.concat","table.insert","table.maxn","table.pack","table.remove","table.sort","table.unpack","math.abs","math.acos","math.asin","math.atan","math.atan2","math.ceil","math.cos","math.cosh","math.deg","math.exp","math.floor","math.fmod","math.frexp","math.huge","math.ldexp","math.log","math.log10","math.max","math.min","math.modf","math.pi","math.pow","math.rad","math.random","math.randomseed","math.sin","math.sinh","math.sqrt","math.tan","math.tanh","bit32.arshift","bit32.band","bit32.bnot","bit32.bor","bit32.btest","bit32.bxor","bit32.extract","bit32.lrotate","bit32.lshift","bit32.replace","bit32.rrotate","bit32.rshift"}
		local pink = {"rednet","greennet","var","output","delay"}
		local ind_kw = {'do', 'function', 'then', '{'}
		local unind_kw = {'end', 'elseif', '}' }
		local function isin(t,v)
			for k,vv in pairs(t) do
				if v==vv then return true end
			end
			return false
		end
		local function rttag(colorstr, font)
			local fonttag = font and '[font='..font..']' or ''
			local colortag = colorstr and '[color='..colorstr..']' or ''
			local fontendtag = font and '[/font]' or ''
			local colorendtag = colorstr and '[/color]' or ''
			return fonttag..colortag, colorendtag..fontendtag
		end

		local reass_list = {}
		for _,tokline in pairs(lexed) do
			local line_t = { tags={} }
			local nonspace_tokens = 0
			local curr_indent = indent
			for _, token in pairs(tokline) do
				local color, font
				if token.type == 'keyword' then
					color, font = '0,0,255', 'default-bold'
				elseif isin(blue, token.data) then
					color, font = '0,0,255', 'default-bold'
				elseif isin(lightblue, token.data) then
					color, font = '0,128,192', 'default-bold'
				elseif isin(violet, token.data) then
					color, font = '128,0,255', 'default-bold'
				elseif isin(pink, token.data) then
					color, font = '255,0,255'
				elseif token.type == 'number' then
					color, font = '255,128,0'
				elseif token.type == 'string' then
					color, font = '80,80,80'
				elseif token.type == 'comment' then
					color, font = '0,128,0'
				else
					-- nil, nil
				end

				local pre, post = rttag(color, font)

				if pre ~= '' and colorize then
					table.insert(line_t, pre)
					line_t.tags[#line_t] = true
				end

				table.insert(line_t, token.data)

				if post ~= '' and colorize then
					table.insert(line_t, post)
					line_t.tags[#line_t] = true
				end

				if isin(ind_kw, token.data) then
					indent = indent + 1
				elseif isin(unind_kw, token.data) then
					indent = indent - 1
					if nonspace_tokens == 0 then curr_indent = indent end
				end

				if token.type ~= 'whitespace' then
					nonspace_tokens = nonspace_tokens + 1
				end
			end
			line_t.indent = curr_indent
			table.insert(reass_list, line_t)
		end

		if tracking then
			local textpos = 1
			for _, line_t in ipairs(reass_list) do
				if upd_flow then
					cursor = cursor + line_t.indent * #indentator
					textpos = textpos + line_t.indent * #indentator
				end

				for i, token_str in ipairs(line_t) do
					if line_t.tags[i] then
						cursor = cursor + #token_str
					else
						textpos = textpos + #token_str
						if textpos>tracked_pos then
							goto multibrake
						end
					end
				end
				textpos = textpos + 1
				if textpos>tracked_pos then
					goto multibrake
				end
			end
			::multibrake::
		end

		local tmpt = {}
		for _, line_t in ipairs(reass_list) do
			local line_str
			if upd_flow then
				line_str = indentator:rep(line_t.indent)..table.concat(line_t)
			else
				line_str = table.concat(line_t)
			end
			table.insert(tmpt, line_str)
		end
		result = table.concat(tmpt,'\n')
	end
	return result, cursor
end

function insert_history(gui, code)
	local gui_name = gui
	if type(gui) ~= "string" then
		gui_name=gui.name
	end
	local i = global.historystate[gui_name]
	if #global.history[gui_name] == global.historystate[gui_name] then
		i=i+1
		table.insert(global.history[gui_name], code)
		global.historystate[gui_name] = i
	else
		i=i+1
		global.history[gui_name][i] = code
		global.historystate[gui_name] = i
		for a=i+1, #global.history[gui_name] do
			global.history[gui_name][a] = nil
		end
	end
	if i > 500 then
		i=i-1
		table.remove(global.history[gui_name],1)
		global.historystate[gui_name] = i
	end
	if type(gui) ~= "string" then
		if global.history[gui_name][i-1] then
			gui.flow.luacomsb_back.sprite = "luacomsb_back_enabled"
			gui.flow.luacomsb_back.ignored_by_interaction = false
		else
			gui.flow.luacomsb_back.sprite = "luacomsb_back"
			gui.flow.luacomsb_back.ignored_by_interaction = true
		end
		if global.history[gui_name][i+1] then
			gui.flow.luacomsb_forward.sprite = "luacomsb_forward_enabled"
			gui.flow.luacomsb_forward.ignored_by_interaction = false
		else
			gui.flow.luacomsb_forward.sprite = "luacomsb_forward"
			gui.flow.luacomsb_forward.ignored_by_interaction = true
		end
	end
end

function history (gui,interval)
	local gui_name = gui.name
	local eid = find_eid_for_gui_element(gui)
	local codebox = global.guis[eid].code_tb
	local i = math.min(#global.history[gui_name],math.max(1,global.historystate[gui_name]+interval))
	global.historystate[gui_name] = i
	if gui.flow.luacomsb_formatting.state then
		codebox.text = format_code(remove_colors(global.history[gui_name][i]))
	else
		codebox.text = remove_colors(global.history[gui_name][i])
	end
	if global.history[gui_name][i-1] then
		gui.flow.luacomsb_back.sprite = "luacomsb_back_enabled"
		gui.flow.luacomsb_back.ignored_by_interaction = false
	else
		gui.flow.luacomsb_back.sprite = "luacomsb_back"
		gui.flow.luacomsb_back.ignored_by_interaction = true
	end
	if global.history[gui_name][i+1] then
		gui.flow.luacomsb_forward.sprite = "luacomsb_forward_enabled"
		gui.flow.luacomsb_forward.ignored_by_interaction = false
	else
		gui.flow.luacomsb_forward.sprite = "luacomsb_forward"
		gui.flow.luacomsb_forward.ignored_by_interaction = true
	end
	global.textboxes[gui_name] = codebox.text
end

script.on_event(defines.events.on_gui_opened, function(event)
	if not event.entity then return end
	local player = game.players[event.player_index]
	if player.opened ~= nil and player.opened.name == "lua-combinator-sb" then
		local ent = player.opened
		local eid = ent.unit_number
		player.opened = nil
		-- if player.gui.center["luacomsb_gui_"..ent.unit_number] then
		-- 	player.gui.center["luacomsb_gui_"..ent.unit_number].destroy()
		-- end
		if not global.guis[eid] then
			create_gui(player,ent)
		else
			local who_opened_id = global.guis[eid].gui.player_index
			player.print(game.players[who_opened_id].name..' already opened this combinator', {1,1,0})
		end
	end
end)


function find_eid_for_gui_element(v)
	for eid, e_g_els in pairs(global.guis) do
		if type(eid) ~= 'number' then goto continue end
		for elname, vv in pairs(e_g_els) do
			if elname == 'preset_btns' then
				for i, vvv in pairs(vv) do
					if v == vvv then
						return eid, 'preset_btn', i
					end
				end
			elseif vv == v then
				--printd('elname '..elname..'\neid '..eid)
				return eid, elname
			end
		end
		::continue::
	end
	log('not found')
	log(serpent.block(global.guis))
end

--[[
 gui
 x_btn
 fw_btn
 bw_btn
 formatting_cb
 code_tb
 ok_btn
 preset_btns
 ]]

function create_gui(player, entity)
	local entity_id = entity.unit_number
	--global.combinators[entity.unit_number].formatting = global.combinators[entity.unit_number].formatting or  false
	local this_gui_data = {}
	local gui = player.gui.center.add{type = "frame", name = "luacomsb_gui_"..entity_id, caption = "", direction = "vertical"}
	this_gui_data.gui = gui
		gui.caption = "rednet[], greennet[], var[], output[], delay"
		gui.style.top_padding 		= 1
		gui.style.right_padding 	= 4
		gui.style.bottom_padding 	= 4
		gui.style.left_padding 		= 4
		--gui.style.scaleable 		= false
	gui.add{type = "flow", name = "flow", direction = "horizontal"}
		gui.flow.style.width = 799
	local elem = gui.flow.add{type = "sprite-button", name = "luacomsb_x_"..entity_id, direction = "horizontal"}
	this_gui_data.x_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		--elem.style.disabled_font_color ={r=1,g=1,b=1}
		elem.sprite="luacomsb_close"
	elem = gui.flow.add{type = "sprite-button", name = "luacomsb_help", direction = "horizontal"}
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite="luacomsb_questionmark"
	elem=gui.flow.add{type = "flow", name = "flow1", direction = "horizontal"}
		elem.style.width=15
	elem = gui.flow.add{type="sprite-button", name = "luacomsb_back", state = true}
	this_gui_data.bw_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite="luacomsb_back"
		elem.hovered_sprite ="luacomsb_back"
		elem.clicked_sprite ="luacomsb_back"
	elem = gui.flow.add{type="sprite-button", name = "luacomsb_forward", state = true}
	this_gui_data.fw_btn = elem
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite="luacomsb_forward"
		elem.hovered_sprite ="luacomsb_forward"
		elem.clicked_sprite  ="luacomsb_forward"
	elem = gui.flow.add{type="checkbox", name = "luacomsb_formatting", state = true}
	this_gui_data.formatting_cb = elem
		elem.tooltip="Toggle code formatting"
		elem.style.height=18
		elem.style.width=18
		elem.state = global.combinators[entity_id].formatting
	elem=gui.flow.add{type = "flow", name = "flow2", direction = "horizontal"}
		--elem.style.width=95
		elem.style.horizontally_stretchable = true
	local preset_btns = {}
	for i=0,20 do
		elem = gui.flow.add{type = "button", name = "luacomsb_preset_"..i, direction = "horizontal",caption=i}
		preset_btns[i] = elem
			elem.style.height=20
			elem.style.width=27
			elem.style.top_padding=0
			elem.style.bottom_padding=0
			elem.style.left_padding=0
			elem.style.right_padding=0
		if not global.presets[i+1] then
			elem.style.font_color = {r=0.3,g=0.3,b=0.3}
			elem.style.hovered_font_color  = {r=0.3,g=0.3,b=0.3}
		else
			elem.tooltip = global.presets[i+1]
		end
	end
	this_gui_data.preset_btns = preset_btns
	elem = gui.add{type = "table", column_count=2, name = "main_table", direction = "vertical"}
		elem.style.vertical_align = "top"
	elem = gui.main_table.add{type = "flow", column_count=1, name = "left_table", direction = "vertical"}
		elem.style.vertical_align = "top"
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
	elem = gui.main_table.left_table.add{type = "scroll-pane",  name = "code_scroll", direction = "vertical"}
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
		elem.style.maximal_height = 700
	elem = gui.main_table.left_table.code_scroll.add{type = "table", column_count=1, name = "code_table", direction = "vertical"}
		--elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
	elem = gui.main_table.left_table.code_scroll.code_table.add{type = "text-box", name = "luacomsb_code", direction = "vertical"}
	this_gui_data.code_tb = elem
		elem.style.vertically_stretchable = true
		--elem.style.vertically_squashable = false
		elem.style.width = 800
		elem.style.minimal_height = 100
		if global.combinators[entity_id].formatting then
			elem.text=format_code(global.combinators[entity_id].code)
		else
			elem.text = global.combinators[entity_id].code
		end
		if global.combinators[entity_id].errors and global.combinators[entity_id].errors ~= "" then
			local test = string.gsub(global.combinators[entity_id].errors,".+:(%d+):.+", "%1")
			elem.text = insert_error_icon(elem.text,test)
		else
			elem.text = insert_error_icon(elem.text)
		end
		global.textboxes[gui.name] = elem.text
		if not global.history[gui.name] then
			global.history[gui.name] = {elem.text}
			global.historystate[gui.name] = 1
		end
	elem = gui.main_table.add{type="scroll-pane",name="flow",direction="vertical"}
		elem.style.maximal_height = 700
	gui.main_table.left_table.add{type = "table", column_count=2, name = "under_text", direction = "vertical"}
		gui.main_table.left_table.under_text.style.width=800
	gui.main_table.left_table.under_text.add{type = "label", name = "errors", direction = "horizontal"}
		gui.main_table.left_table.under_text.errors.style.width=760
	elem =gui.main_table.left_table.under_text.add{type = "button", name = "luacomsb_ok_"..entity_id, direction = "horizontal",caption="ok"}
	this_gui_data.ok_btn = elem
		elem.style.width=35
		elem.style.height=30
		elem.style.top_padding=0
		elem.style.left_padding=0
	local i = global.historystate[gui.name]
	if global.history[gui.name][i-1] then
		gui.flow.luacomsb_back.sprite = "luacomsb_back_enabled"
		gui.flow.luacomsb_back.ignored_by_interaction = false
	else
		gui.flow.luacomsb_back.sprite = "luacomsb_back"
		gui.flow.luacomsb_back.ignored_by_interaction = true
	end
	if global.history[gui.name][i+1] then
		gui.flow.luacomsb_forward.sprite = "luacomsb_forward_enabled"
		gui.flow.luacomsb_forward.ignored_by_interaction = false
	else
		gui.flow.luacomsb_forward.sprite = "luacomsb_forward"
		gui.flow.luacomsb_forward.ignored_by_interaction = true
	end
	global.guis[entity_id]=this_gui_data
	player.opened=gui
end

function helper_gui(pl)
	local player = game.players[pl]
	if not player.gui.center["luacomsb_helper_"..pl] then
		local gui = player.gui.center.add{type = "frame", name = "luacomsb_helper_"..pl, caption = "", direction = "vertical"}
		local elem = gui.add{type = "sprite-button", name = "luacomsb_helper_x", direction = "horizontal"}
		elem.style.height=20
		elem.style.width=20
		elem.style.top_padding=0
		elem.style.bottom_padding=0
		elem.style.left_padding=0
		elem.style.right_padding=0
		elem.sprite="luacomsb_close"
		gui.add{type = "label", name = "1", direction = "horizontal",caption = "Here are a few variables to get you started:"}
		gui.add{type = "label", name = "2", direction = "horizontal",caption = "combinator = the entity the script is running on"}
		gui.add{type = "label", name = "3", direction = "horizontal",caption = "rednet [] = signals in the red network (read only) (Signal-name -> Value)"}
		gui.add{type = "label", name = "4", direction = "horizontal",caption = "greennet [] = same for the green network"}
		gui.add{type = "label", name = "5", direction = "horizontal",caption = "output [] = a table with all the signals you are sending to the networks, they are permanent so to remove a signal you need to "}
		gui.add{type = "label", name = "6", direction = "horizontal",caption = "                    set its entry to nil, or flush all signals by entering output = {} (creates a fresh table) (Signal-name -> Value)"}
		gui.add{type = "label", name = "7", direction = "horizontal",caption = "var [] = a table to store all your variables between the ticks"}
		gui.add{type = "label", name = "8", direction = "horizontal",caption = "delay = the delay in ticks until the next update (to save some ups) (not persistent, needs to be set on each update)"}
		gui.add{type = "label", name = "9", direction = "horizontal",caption = " "}
		gui.add{type = "label", name = "10", direction = "horizontal",caption = "Presets:"}
		gui.add{type = "label", name = "11", direction = "horizontal",caption = "Save & Load with left-click"}
		gui.add{type = "label", name = "12", direction = "horizontal",caption = "Delete with right-click"}
	end
end

function insert_error_icon(text, errorline)
	text = string.gsub(text,"%[img=luacomsb_bug%]","")
	if errorline then
		errorline=tonumber(errorline)
		local _,linecount = text:gsub("([^\n]*)\n?","")
		local lines = linecount
		if string.sub(text,-1) == "\n" then
			lines=linecount+1
		end
		local i=0
		local result = ""
		for line in text:gmatch("([^\n]*)\n?") do
			i=i+1
			if i<lines then
				if i == errorline then
					line = "[img=luacomsb_bug]"..line
				end
				if i>1 then
					line = "\n"..line
				end
				result = result..line
			end
		end
		return result
	else
		return text
	end
end

script.on_event(defines.events.on_gui_click, function (event)
	local comb_id, elname, preset_i = find_eid_for_gui_element(event.element)
	if not comb_id then return end
	local gui_t = global.guis[comb_id]
	local gui = gui_t.gui

	if elname == 'ok_btn' then
		local code = gui_t.code_tb.text
		load_code(code, comb_id)
		if global.combinators[comb_id].errors and global.combinators[comb_id].errors ~= "" then
			local test = string.gsub(global.combinators[comb_id].errors,".+:(%d+):.+", "%1")
			gui_t.code_tb.text = insert_error_icon(code,test)
		else
			gui_t.code_tb.text = insert_error_icon(code)
			combinator_tick(comb_id)
		end
	elseif elname == 'x_btn' then
		gui.destroy()
		global.guis[comb_id]=nil
	elseif (event.element.name == "luacomsb_help") then
		helper_gui(event.player_index)
	elseif (event.element.name == "luacomsb_helper_x") then
		event.element.parent.destroy()
	elseif elname == 'preset_btn' then
		local subgui = event.element.parent
		assert( subgui.parent == gui )
		local id = preset_i+1
		if event.button == defines.mouse_button_type.left then
			local code_textbox = gui_t.code_tb
			if global.presets[id] then
				if subgui.luacomsb_formatting.state then
					code_textbox.text = format_code(global.presets[id])
				else
					code_textbox.text = global.presets[id]
				end
				global.textboxes[gui.name] = code_textbox.text
				if not global.history[gui.name] then
					global.history[gui.name] = {code_textbox.text}
					global.historystate[gui.name] = 1
				else
					insert_history(gui, code_textbox.text)
				end
			else
				global.presets[id] = remove_colors(code_textbox.text)
					event.element.style.font_color = {r=0,g=0,b=0}
					event.element.style.hovered_font_color  = {r=0,g=0,b=0}
				event.element.tooltip = global.presets[id]
			end
		elseif event.button == defines.mouse_button_type.right then
			global.presets[id] = nil
			event.element.style.font_color = {r=0.3,g=0.3,b=0.3}
			event.element.style.hovered_font_color  = {r=0.3,g=0.3,b=0.3}
			event.element.tooltip = ""
		end
	elseif elname == 'formatting_cb' then
		if event.button == defines.mouse_button_type.left then
			local code_tb = gui_t.code_tb
			if event.element.state == true then
				code_tb.text = format_code(code_tb.text)
				global.textboxes[gui_t.gui.name] = code_tb.text
			else
				code_tb.text = remove_colors(code_tb.text)
			end
			global.combinators[comb_id].formatting = event.element.state
		end
	elseif elname == 'bw_btn' then
		if event.button == defines.mouse_button_type.left and event.shift then
			history(gui, -50)
		elseif event.button == defines.mouse_button_type.right then
			history(gui, -5)
		else
			history(gui, -1)
		end
	elseif elname == 'fw_btn' then
		if event.button == defines.mouse_button_type.left and event.shift then
			history(gui, 50)
		elseif event.button == defines.mouse_button_type.right then
			history(gui, 5)
		else
			history(gui, 1)
		end
	end
end)

script.on_event({defines.events.on_gui_closed},function(event)
if event.element and string.sub(event.element.name,1,13) == "luacomsb_gui_" then
	global.guis[tonumber(string.sub(event.element.name,14))]=nil
	event.element.destroy()
end
end)

function luacomsb_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[luacomsb_deepcopy(orig_key)] = luacomsb_deepcopy(orig_value)
        end
        -- setmetatable(copy, luacomsb_deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end