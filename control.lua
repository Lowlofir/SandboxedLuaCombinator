require "blueprint_custom_data.blueprint_custom_data"
local migrations = require 'script.migrations'
local semver = require 'script.semver'
utils = require 'script.utils'
gui_manager = require 'script.gui'


local sandbox_env_std = {
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

local combinators_local = {}
function combinators_local.register(id)
	combinators_local[id] = {}
end
function combinators_local.unregister(id)
	combinators_local[id] = nil
end

local combinators_local_cbs = {}


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
	global.outputs = {}
	global.inputs = {}
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
			force.recipes['lua-combinator-sb-output'].enabled = true
			force.recipes['lua-combinator-sb-input'].enabled = true
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
	if not global.outputs then
		global.outputs = {}
	end
	if not global.inputs then
		global.inputs = {}
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

local function find_in_list(l, val)
	local pos
	for k,v in pairs(l) do
		if v == val then
			pos = k
			break
		end
	end
	return pos
end

local outputs_registry = {}

function outputs_registry.assign(comb_eid, output_ent)
	global.combinators[comb_eid].additional_output_entities = global.combinators[comb_eid].additional_output_entities or {}
	table.insert(global.combinators[comb_eid].additional_output_entities, output_ent)
	global.outputs[output_ent.unit_number] = comb_eid
	game.print(output_ent.unit_number..' assigned to '..comb_eid)
end

function outputs_registry.unassign(comb_eid, output_ent)
	local pos = find_in_list(global.combinators[comb_eid].additional_output_entities, output_ent)
	assert(pos)
	table.remove(global.combinators[comb_eid].additional_output_entities, pos)
	global.outputs[output_ent.unit_number] = nil
	game.print(output_ent.unit_number..' unassigned from '..comb_eid)
end

function outputs_registry.get_assignation(output_ent_id)
	return global.outputs[output_ent_id]
end


local inputs_registry = {}

function inputs_registry.assign(comb_eid, input_ent)
	global.combinators[comb_eid].additional_input_entities = global.combinators[comb_eid].additional_input_entities or {}
	table.insert(global.combinators[comb_eid].additional_input_entities, input_ent)
	global.inputs[input_ent.unit_number] = comb_eid
	combinators_local[comb_eid].inputs_controller:on_inputs_list_changed()
	-- game.print(input_ent.unit_number..' assigned to '..comb_eid)
end

function inputs_registry.unassign(comb_eid, input_ent)
	local pos = find_in_list(global.combinators[comb_eid].additional_input_entities, input_ent)
	assert(pos)
	table.remove(global.combinators[comb_eid].additional_input_entities, pos)
	global.inputs[input_ent.unit_number] = nil
	combinators_local[comb_eid].inputs_controller:on_inputs_list_changed()
	-- game.print(input_ent.unit_number..' unassigned from '..comb_eid)
end

function inputs_registry.get_assignation(input_ent_id)
	return global.inputs[input_ent_id]
end



local function on_combinator_destroyed(unit_nr)
	local tbl = global.combinators[unit_nr]
	if tbl.output_proxy and tbl.output_proxy.valid then
		tbl.output_proxy.destroy()
	end
	if tbl.blueprint_data and tbl.blueprint_data.valid then
		tbl.blueprint_data.destroy()
	end
	if tbl.additional_output_entities then
		for k,v in pairs(tbl.additional_output_entities) do
			global.outputs[v.unit_number] = nil
			v.surface.create_entity{name="flying-text", position=v.position, text="Unassigned", color={r=1,g=1,b=0.2}}
		end
	end
	if tbl.additional_input_entities then
		for k,v in pairs(tbl.additional_input_entities) do
			global.inputs[v.unit_number] = nil
			v.surface.create_entity{name="flying-text", position=v.position, text="Unassigned", color={r=1,g=1,b=0.2}}
		end
	end

	global.combinators[unit_nr]=nil
	combinators_local.unregister(unit_nr)
end

local function on_destroyed(ev)
	local entity = ev.entity or ev.ghost
	local unit_nr = entity.unit_number
	-- game.print(entity.name..' : '..entity.type)
	if entity.name == 'lua-combinator-sb-sep' or entity.name == 'lua-combinator-sb' then
		on_combinator_destroyed(unit_nr)
	elseif entity.name == 'entity-ghost' and (entity.ghost_name == "lua-combinator-sb" or entity.ghost_name == "lua-combinator-sb-sep") then
		local spot= entity.surface.find_entities_filtered{name="entity-ghost", ghost_name="luacomsb_blueprint_data", area= {{entity.position.x-0.1,entity.position.y-0.1},{entity.position.x+0.1,entity.position.y+0.1}}}
		if #spot > 0 then
			spot[1].destroy()
		end
	elseif entity.name == 'lua-combinator-sb-output' then
		local asstion = outputs_registry.get_assignation(unit_nr)
		if asstion then
			outputs_registry.unassign(asstion, entity)
		end
	elseif entity.name == 'lua-combinator-sb-input' then
		local asstion = inputs_registry.get_assignation(unit_nr)
		if asstion then
			inputs_registry.unassign(asstion, entity)
		end
	end
end

script.on_event(defines.events.on_pre_player_mined_item, on_destroyed)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed)
script.on_event(defines.events.on_entity_died, on_destroyed)
script.on_event(defines.events.on_pre_ghost_deconstructed, on_destroyed)


function load_combinator_code(id)
	local env = setup_env(id)
	local code = global.combinators[id].code
	return load(code, code, 't', env)
end


local inputs_controller_class = {}

function inputs_controller_class:make_input(inp_id)
	local single_input_meta = {}
	if inp_id == 1 then
		single_input_meta.inp_entity = self.comb_tbl.entity
		single_input_meta.looped_outp = self.comb_tbl.sep and {} or self.comb_tbl.outputs[1]
	else
		single_input_meta.inp_entity = self.comb_tbl.additional_input_entities[inp_id-1]
		single_input_meta.looped_outp = {}
	end

	function single_input_meta.__index(input_tbl, k)
		if k=='rednet' then
			rawset(input_tbl, 'rednet', get_red_network(single_input_meta.inp_entity, single_input_meta.looped_outp))
			return input_tbl.rednet
		elseif k=='greennet' then
			rawset(input_tbl, 'greennet', get_green_network(single_input_meta.inp_entity, single_input_meta.looped_outp))
			return input_tbl.greennet
		elseif k=='reset' then
			rawset(input_tbl, 'rednet', nil)
			rawset(input_tbl, 'greennet', nil)
		end
	end
	function single_input_meta.__newindex(input_tbl, k, v)
	end

	local input = setmetatable({}, single_input_meta)
	return input
end

function inputs_controller_class:get_inputs_table()
	if self.inputs_table then 
		return self.inputs_table 
	end
	local inputs_meta = {
		__index = function (inputs_tbl, input_index)
			if type(input_index)=='number' and (input_index==1 or self.comb_tbl.additional_input_entities[input_index-1]) then
				inputs_tbl[input_index] = self:make_input(input_index)
				return inputs_tbl[input_index]
			end
		end
	}
	self.inputs_table = setmetatable({}, inputs_meta)
	return self.inputs_table
end

function inputs_controller_class:on_tick()
	if self.inputs_table then 
		for k,v in pairs(self.inputs_table) do
			local _ = v.reset
		end
	end
end

function inputs_controller_class:on_inputs_list_changed()
	self.inputs_table = nil
end

local inputs_controller_mt = {__index = inputs_controller_class}

local function make_inputs_controller(cid)
	local comb_tbl = global.combinators[cid]
	local controller = setmetatable({comb_tbl=comb_tbl}, inputs_controller_mt)
	return controller
end

function setup_env(cid)
	if not sandbox_env_std.game then
		sandbox_env_std.game = {
			-- item_prototypes = game.item_prototypes,
			-- recipe_prototypes = game.recipe_prototypes,
			tick = game.tick, -- just an initialization
		}
		setmetatable(sandbox_env_std.game, {__index=function (tbl, k)
			if k=='item_prototypes' or k=='recipe_prototypes' then 
				return game[k]
			end
		end})
		sandbox_env_std.print = game.print
	end


	local tbl = global.combinators[cid]

	local inputs_controller = make_inputs_controller(cid)
	combinators_local[cid].inputs_controller = inputs_controller
	
	local ro_meta = {
		__index = sandbox_env_std,
	}

	local ro_env = setmetatable({inputs = inputs_controller:get_inputs_table()}, ro_meta)

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
	local var_env = setmetatable(tbl.variables, var_meta)

	combinators_local[cid].env_ro = ro_env
	combinators_local[cid].env_var = var_env

	return var_env
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


local function make_output_proxy(comb_entity)
	local output_proxy = comb_entity.surface.create_entity {
		name = 'lua-combinator-sb-proxy',
		position = comb_entity.position,
		force = comb_entity.force,
		create_build_effect_smoke = false
	}
	comb_entity.connect_neighbour {
		wire = defines.wire_type.red,
		target_entity = output_proxy,
		source_circuit_id = defines.circuit_connector_id.combinator_output,
	}
	comb_entity.connect_neighbour {
		wire = defines.wire_type.green,
		target_entity = output_proxy,
		source_circuit_id = defines.circuit_connector_id.combinator_output,
	}
	output_proxy.destructible = false
	return output_proxy
end

local function on_built_entity(event)
	if not event.created_entity.valid then return end

	local new_ent = event.created_entity

	if new_ent.name == "lua-combinator-sb" or new_ent.name == "lua-combinator-sb-sep" then
		local unit_id = new_ent.unit_number
		combinators_local.register(unit_id)

		global.combinators[unit_id] = {formatting = true, entity = new_ent, code="", variables = {}, errors="", errors2="", outputs={}, next_tick=1, usegreen = false, usered = false}
		if new_ent.name == "lua-combinator-sb-sep" then
			local output_proxy = make_output_proxy(new_ent)
			global.combinators[unit_id].output_proxy = output_proxy
			global.combinators[unit_id].sep = true
		end

		local blueprint_data = new_ent.surface.find_entities_filtered{position = new_ent.position, ghost_name = "luacomsb_blueprint_data"}
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
		global.combinators[unit_id].blueprint_data = new_ent.surface.create_entity{name = "luacomsb_blueprint_data", position = new_ent.position, force = new_ent.force}
		global.combinators[unit_id].blueprint_data.destructible = false
		global.combinators[unit_id].blueprint_data.minable = false
		write_to_combinator(global.combinators[unit_id].blueprint_data,global.combinators[unit_id].code)

		local outputs = new_ent.surface.find_entities_filtered{position = new_ent.position, radius = 1.2, name = 'lua-combinator-sb-output'}
		for k,v in pairs(outputs) do
			if global.outputs[v.unit_number] then
				new_ent.surface.create_entity{name="flying-text", position=v.position, text="Already assigned", color={r=1,g=1,b=0.2}}
			else
				outputs_registry.assign(unit_id, v)
				new_ent.surface.create_entity{name="flying-text", position=v.position, text="Assigned", color={r=0.2,g=1,b=0.2}}
			end
		end

		local inputs = new_ent.surface.find_entities_filtered{position = new_ent.position, radius = 1.2, name = 'lua-combinator-sb-input'}
		for k,v in pairs(inputs) do
			if global.inputs[v.unit_number] then
				new_ent.surface.create_entity{name="flying-text", position=v.position, text="Already assigned", color={r=1,g=1,b=0.2}}
			else
				inputs_registry.assign(unit_id, v)
				new_ent.surface.create_entity{name="flying-text", position=v.position, text="Assigned", color={r=0.2,g=1,b=0.2}}
			end
		end


	elseif new_ent.name == "lua-combinator-sb-output" or new_ent.name == "lua-combinator-sb-input" then
		new_ent.operable = false
		local luacombs = new_ent.surface.find_entities_filtered{position = new_ent.position, radius = 1.2, name = {'lua-combinator-sb', 'lua-combinator-sb-sep'}}
		if #luacombs > 1 then
			new_ent.surface.create_entity{name="flying-text", position=new_ent.position, text="Ambiguous position", color={r=1,g=0.2,b=0.2}}
		elseif luacombs[1] and global.combinators[luacombs[1].unit_number] then
			local cid = luacombs[1].unit_number
			if new_ent.name == "lua-combinator-sb-output" then
				outputs_registry.assign(cid, new_ent)
			else
				inputs_registry.assign(cid, new_ent)
			end
			new_ent.surface.create_entity{name="flying-text", position=luacombs[1].position, text="Assigned", color={r=0.2,g=1,b=0.2}}
		end 
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

-- local prof
-- local prof_cnt

-- local function perf_start()
-- 	if prof_cnt%60<=0.1 and prof_cnt>0 then
-- 		prof.divide(prof_cnt)
-- 		game.print(prof)
-- 		prof.reset()
-- 		prof_cnt = 0
-- 	else
-- 		prof.restart()
-- 	end

-- end

-- local function perf_stop()
-- 	prof.stop()
-- 	prof_cnt = prof_cnt + 1
-- end

local type_count = {}
function find_lua_custom_table(t)
	for k,v in pairs(t) do
		type_count[type(v)] = type_count[type(v)] or 0
		type_count[type(v)] = type_count[type(v)] + 1
		if type(v) == 'table' then
			find_lua_custom_table(v)
		end
	end
end

local function on_tick(event)
	-- if not prof then 
	-- 	prof = game.create_profiler()
	-- 	prof_cnt = 0
	-- end
	-- if event.tick % 600 == 0 then

	-- 	log(serpent.block(global))
	-- 	find_lua_custom_table(global)
	-- 	log(serpent.block(type_count))
	-- end
	-- error('errooor')

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

			local red, green = get_networks(com983,global.combinators[unit_nr].outputs[1])
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
			game.print('not tbl.entity or not tbl.entity.valid')
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
					combinator_tick(unit_nr, event.tick)
				end
			end
		end
	end

end

local function prepare_output(o)
	local actual_output = {}
	local i=1
	local errors = ""
	for signal,value in pairs(o) do
		if global.signals[signal] then
			if type (value) == "number" then
				if value >= -2147483648 and value <= 2147483647 then
					if value ~= 0 then
						actual_output[i]={signal={type=global.signals[signal], name=signal},count=value,index=i}
						i=i+1
					end
				else
					errors =errors.."  +++output value must be between -2147483648 and 2147483647 ("..signal..")"
				end
			else
				errors = errors.."  +++output value must be a number ("..signal..")"
			end
		else
			errors = errors.."  +++invalid signal name in output ("..signal..")"
		end
	end
	return actual_output, errors
end

function combinator_tick(unit_nr, tick)
	tick = tick or game.tick
	local tbl = global.combinators[unit_nr]

	local outputs = tbl.outputs
	local copiedoutputs = utils.deepcopy(outputs)
	local rednet, greennet
	local looped_output = tbl.sep and outputs[1] or {}

	if tbl.usered then
		rednet = get_red_network(tbl.entity, looped_output)
	end
	if tbl.usegreen then
		greennet = get_green_network(tbl.entity, looped_output)
	end

	local env_ro = combinators_local[unit_nr].env_ro
	local func = combinators_local[unit_nr].func
	assert(env_ro, 'no env')
	assert(func, 'no func')

	combinators_local[unit_nr].inputs_controller:on_tick()
	env_ro.delay = 1
	env_ro.rednet = rednet
	env_ro.greennet = greennet
	env_ro.output = outputs[1]
	env_ro.outputs = outputs

	do
		local _,error = pcall(func)
		tbl.errors=error or ""
	end

	local delay = tonumber(env_ro.delay) or 1
	outputs = env_ro.outputs or {}

	if type(outputs) ~= "table" then
		tbl.errors = tbl.errors.."  +++outputs needs to be a table"
	else
		tbl.outputs = outputs
	end

	env_ro.var = env_ro.var or {}

	local outputs_cnt = #(tbl.additional_output_entities or {}) + 1
	for output_id = 1,outputs_cnt do
		if not tbl.outputs[output_id] then
			tbl.outputs[output_id] = {}
		elseif type(tbl.outputs[output_id]) ~= 'table' then
			tbl.errors = tbl.errors.."  +++output["..output_id.."] needs to be a table"
			tbl.outputs[output_id] = {}
		end
	end

	for output_id = 1,outputs_cnt do
		local curr_out_tbl = tbl.outputs[output_id]
		if compare_tables(copiedoutputs, curr_out_tbl) then
			local actual_output = {}
			local new_errors2 = ''
			actual_output, new_errors2 = prepare_output(curr_out_tbl)
			tbl.errors2 = tbl.errors2..new_errors2

			local target_out
			if output_id == 1 then
				if not tbl.sep then
					target_out = tbl.entity
				else
					target_out = tbl.output_proxy
				end
			else
				target_out = global.combinators[unit_nr].additional_output_entities[output_id-1]
			end

			combinators_local_cbs[target_out] = combinators_local_cbs[target_out] or target_out.get_or_create_control_behavior()
			combinators_local_cbs[target_out].parameters={parameters=actual_output}
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

local cbmap = {
	[defines.control_behavior.type.arithmetic_combinator] = defines.circuit_connector_id.combinator_input,
	[defines.control_behavior.type.constant_combinator] = defines.circuit_connector_id.constant_combinator,
	[defines.control_behavior.type.lamp] = defines.circuit_connector_id.lamp,
}

function get_col_network (entity, output, wire_type)
	combinators_local_cbs[entity] = combinators_local_cbs[entity] or entity.get_or_create_control_behavior()
	local control_behavior = combinators_local_cbs[entity]
	-- local is_sep = global.combinators[entity.unit_number].sep
	local ccid = cbmap[control_behavior.type]
	local cnw = control_behavior.get_circuit_network(wire_type, ccid)
	output = output or {}
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
