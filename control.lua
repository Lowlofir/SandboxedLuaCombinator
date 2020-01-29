require "blueprint_custom_data.blueprint_custom_data"
local migrations = require 'script.migrations'
local semver = require 'script.semver'
utils = require 'script.utils'
gui_manager = require 'script.gui'


sandbox_env_std = {
  ipairs = ipairs,
  next = next,
  pairs = pairs,
  pcall = pcall,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  assert = assert,
  error = error,
  select = select ,
  table_size = table_size,

  serpent = { block = serpent.block },
  string = { byte = string.byte, char = string.char, find = string.find,
      format = string.format, gmatch = string.gmatch, gsub = string.gsub,
      len = string.len, lower = string.lower, match = string.match,
      rep = string.rep, reverse = string.reverse, sub = string.sub,
      upper = string.upper },
  table = { concat = table.concat, insert = table.insert, remove = table.remove,
      sort = table.sort, pack = table.pack, unpack = table.unpack, },
  math = { abs = math.abs, acos = math.acos, asin = math.asin,
      atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos,
      cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor,
      fmod = math.fmod, frexp = math.frexp, huge = math.huge,
      ldexp = math.ldexp, log = math.log, max = math.max,
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


settings_cache = {}

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
		assert( self[player_id][sett_name_adapt] ~= nil )
		self[player_id][sett_name_adapt] = pl.mod_settings[ext_sett_name].value
	end
end

local function on_runtime_mod_setting_changed( ev )
	-- game.print(ev.player_index..': '..ev.setting)
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
		log('SandboxedLuaCombinator: new_ver == old_ver!?')
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

local function reenable_recipes()
	for _, force in pairs(game.forces) do
		if force.technologies['lua-combinator-sb'].researched then
			force.recipes['lua-combinator-sb'].enabled = true
			force.recipes['lua-combinator-sb-sep'].enabled = true
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
	reenable_recipes()
end)


script.on_load( function ()
	for k,v in pairs(global.combinators) do
		combinators_local.register(k)
	end
	for k,v in pairs(global.guis) do
		setmetatable(v, {__index=comb_gui_class})
	end
end)

local function on_destroyed(ev)
	local entity = ev.entity or ev.ghost
	-- game.print(entity.name..' : '..entity.type)
	if entity.name == 'lua-combinator-sb-sep' then
		global.combinators[entity.unit_number].output_proxy.destroy()
	elseif entity.name == 'entity-ghost' and (entity.ghost_name == "lua-combinator-sb" or entity.ghost_name == "lua-combinator-sb-sep") then
		local spot= entity.surface.find_entities_filtered{name="entity-ghost", ghost_name="luacomsb_blueprint_data", area= {{entity.position.x-0.1,entity.position.y-0.1},{entity.position.x+0.1,entity.position.y+0.1}}}
		if #spot > 0 then
			spot[1].destroy()
		end
	end
end

script.on_event(defines.events.on_pre_player_mined_item, on_destroyed)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed)
script.on_event(defines.events.on_entity_died, on_destroyed)
script.on_event(defines.events.on_pre_ghost_deconstructed, on_destroyed)


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

	if not sandbox_env_std.game then
		sandbox_env_std.game = {
			item_prototypes = game.item_prototypes,
			recipe_prototypes = game.recipe_prototypes,
			-- print = game.print,
			tick = game.tick, -- just an initialization
		}
	end
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
		local blueprint_data = event.created_entity.surface.find_entities_filtered{position = event.created_entity.position, ghost_name = "luacomsb_blueprint_data"}
		if blueprint_data[1] then
			global.combinators[unit_id].code=read_from_combinator(blueprint_data[1])
			combinators_local[unit_id].func,global.combinators[unit_id].errors = load_combinator_code(unit_id)
			if not global.combinators[unit_id].errors then
				global.combinators[unit_id].errors = ""
			end
			local _, countred = string.gsub(global.combinators[unit_id].code, "rednet", "")
			local _, countgreen = string.gsub(global.combinators[unit_id].code, "greennet", "")
			global.combinators[unit_id].usered = (countred > 0)
			global.combinators[unit_id].usegreen = (countgreen > 0)
			blueprint_data[1].destroy()
		end
		global.combinators[unit_id].blueprint_data = event.created_entity.surface.create_entity{name = "luacomsb_blueprint_data", position = event.created_entity.position, force = event.created_entity.force}
		global.combinators[unit_id].blueprint_data.destructible = false
		global.combinators[unit_id].blueprint_data.minable = false
		write_to_combinator(global.combinators[unit_id].blueprint_data,global.combinators[unit_id].code)
	elseif event.created_entity.valid and event.created_entity.name == "lua-combinator-sb-sep" then
		local unit_id = event.created_entity.unit_number
		combinators_local.register(unit_id)

		local output_proxy = event.created_entity.surface.create_entity {
			name = 'lua-combinator-sb-proxy',
			position = event.created_entity.position,
			force = event.created_entity.force,
			create_build_effect_smoke = false
		}
		event.created_entity.connect_neighbour {
			wire = defines.wire_type.red,
			target_entity = output_proxy,
			source_circuit_id = defines.circuit_connector_id.combinator_output,
		}
		event.created_entity.connect_neighbour {
			wire = defines.wire_type.green,
			target_entity = output_proxy,
			source_circuit_id = defines.circuit_connector_id.combinator_output,
		}
	
		output_proxy.destructible = false
		global.combinators[unit_id] = {sep = true, output_proxy=output_proxy, formatting = true, entity = event.created_entity, code="", variables = {}, errors="", errors2="", output={}, next_tick=1, usegreen = false, usered = false}
	
	
		local blueprint_data = event.created_entity.surface.find_entities_filtered{position = event.created_entity.position, ghost_name = "luacomsb_blueprint_data"}
		if blueprint_data[1] then
			global.combinators[unit_id].code=read_from_combinator(blueprint_data[1])
			combinators_local[unit_id].func,global.combinators[unit_id].errors = load_combinator_code(unit_id)
			if not global.combinators[unit_id].errors then
				global.combinators[unit_id].errors = ""
			end
			local _, countred = string.gsub(global.combinators[unit_id].code, "rednet", "")
			local _, countgreen = string.gsub(global.combinators[unit_id].code, "greennet", "")
			global.combinators[unit_id].usered = (countred > 0)
			global.combinators[unit_id].usegreen = (countgreen > 0)
			blueprint_data[1].destroy()
		end
		global.combinators[unit_id].blueprint_data = event.created_entity.surface.create_entity{name = "luacomsb_blueprint_data", position = event.created_entity.position, force = event.created_entity.force}
		global.combinators[unit_id].blueprint_data.destructible = false
		global.combinators[unit_id].blueprint_data.minable = false
		write_to_combinator(global.combinators[unit_id].blueprint_data,global.combinators[unit_id].code)

	end
end


local function on_entity_settings_pasted(event)
	local name1 = "lua-combinator-sb"
	local name2 = "lua-combinator-sb-sep"
	if (event.source.name == name1 or event.source.name == name2) and (event.destination.name == name1 or event.destination.name == name2) then
		local dst_id = event.destination.unit_number
		local src_id = event.source.unit_number
		global.combinators[dst_id].code = global.combinators[src_id].code
		global.combinators[dst_id].variables = utils.deepcopy(global.combinators[src_id].variables)
		global.combinators[dst_id].errors2 = global.combinators[src_id].errors2
		global.combinators[dst_id].output = utils.deepcopy(global.combinators[src_id].output)
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

	if (sandbox_env_std.game) then
		sandbox_env_std.game.tick = event.tick
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
	local copiedoutput = utils.deepcopy(output)
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
			local target_out_comb
			if not tbl.sep then
				target_out_comb = tbl.entity
			else
				target_out_comb = tbl.output_proxy
			end

			combinators_local_cbs[target_out_comb] = combinators_local_cbs[target_out_comb] or target_out_comb.get_or_create_control_behavior()
			local control = combinators_local_cbs[target_out_comb]
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
	local is_sep = global.combinators[entity.unit_number].sep
	local ccid = is_sep and defines.circuit_connector_id.constant_combinator or defines.circuit_connector_id.combinator_input
	local cnw = combinators_local_cbs[entity].get_circuit_network(wire_type, ccid)
	if is_sep then output={} end
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





script.on_event(defines.events.on_gui_click, function (event)
	gui_manager:on_gui_click(event)
end)

script.on_event({defines.events.on_gui_closed},function(event)
if event.element and string.sub(event.element.name,1,13) == "luacomsb_gui_" then
	global.guis[tonumber(string.sub(event.element.name,14))]=nil
	event.element.destroy()
end
end)

script.on_event(defines.events.on_gui_opened, function(event)
	if not event.entity then return end
	local player = game.players[event.player_index]
	if player.opened ~= nil and (player.opened.name == "lua-combinator-sb" or player.opened.name == "lua-combinator-sb-sep") then
		local ent = player.opened
		local eid = ent.unit_number
		player.opened = nil
		if not global.guis[eid] then
			gui_manager:open(player,ent)
		else
			local who_opened_id = global.guis[eid].gui.player_index
			player.print(game.players[who_opened_id].name..' already opened this combinator', {1,1,0})
		end
	end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
	gui_manager:on_gui_text_changed(event)
end)
