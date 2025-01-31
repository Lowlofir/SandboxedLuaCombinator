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

local cbmap = {
	[defines.control_behavior.type.arithmetic_combinator] = defines.circuit_connector_id.combinator_input,
	[defines.control_behavior.type.constant_combinator] = defines.circuit_connector_id.constant_combinator,
	[defines.control_behavior.type.lamp] = defines.circuit_connector_id.lamp,
}

function combinators_local_cbs.get(entity)
	if combinators_local_cbs[entity] then
		return combinators_local_cbs[entity]
	end
	local cb = entity.get_or_create_control_behavior()
	local ccid = cbmap[cb.type]
	local tbl = { cb = cb, ccid = ccid }
	combinators_local_cbs[entity] = tbl
	return tbl
end


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
	if combinators_local[comb_eid].outputs_controller then
		combinators_local[comb_eid].outputs_controller:on_outputs_list_changed()
	end
	-- game.print(output_ent.unit_number..' assigned to '..comb_eid)
end

function outputs_registry.unassign(comb_eid, output_ent)
	local pos = find_in_list(global.combinators[comb_eid].additional_output_entities, output_ent)
	assert(pos)
	table.remove(global.combinators[comb_eid].additional_output_entities, pos)
	global.outputs[output_ent.unit_number] = nil
	if combinators_local[comb_eid].outputs_controller then
		combinators_local[comb_eid].outputs_controller:on_outputs_list_changed()
	end
	-- game.print(output_ent.unit_number..' unassigned from '..comb_eid)
end

function outputs_registry.get_assignation(output_ent_id)
	return global.outputs[output_ent_id]
end


local inputs_registry = {}

function inputs_registry.assign(comb_eid, input_ent)
	global.combinators[comb_eid].additional_input_entities = global.combinators[comb_eid].additional_input_entities or {}
	table.insert(global.combinators[comb_eid].additional_input_entities, input_ent)
	global.inputs[input_ent.unit_number] = comb_eid
	if combinators_local[comb_eid].inputs_controller then
		combinators_local[comb_eid].inputs_controller:on_inputs_list_changed()
	end
	-- game.print(input_ent.unit_number..' assigned to '..comb_eid)
end

function inputs_registry.unassign(comb_eid, input_ent)
	local pos = find_in_list(global.combinators[comb_eid].additional_input_entities, input_ent)
	assert(pos)
	table.remove(global.combinators[comb_eid].additional_input_entities, pos)
	global.inputs[input_ent.unit_number] = nil
	if combinators_local[comb_eid].inputs_controller then
		combinators_local[comb_eid].inputs_controller:on_inputs_list_changed()
	end
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



local outputs_controller_class = {}

function outputs_controller_class:make_output(outp_id)
	local single_output_meta = { __index=self.comb_tbl.outputs[outp_id] }  --
	self.comb_tbl.outputs[outp_id] = self.comb_tbl.outputs[outp_id] or {}
	single_output_meta.real_out_tbl = self.comb_tbl.outputs[outp_id]

	function single_output_meta.__newindex(output_tbl, k, v)
		local valid_v = v==nil or (type(v)=='number' and v >= -2147483648 and v <= 2147483647)
		if not valid_v then
			error('wrong output value', 2)
		end
		self.dirt_map[outp_id] = true
		single_output_meta.real_out_tbl[k] = v
	end

	local output = setmetatable({}, single_output_meta)
	return output
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

function outputs_controller_class:on_post_tick()
	local tbl = self.comb_tbl

	for output_id,_ in pairs(self.dirt_map) do
		local curr_out_tbl = tbl.outputs[output_id]
		local actual_output, new_errors2 = prepare_output(curr_out_tbl)
		tbl.errors2 = tbl.errors2..new_errors2

		local target_out
		if output_id == 1 then
			if not tbl.sep then
				target_out = tbl.entity
			else
				target_out = tbl.output_proxy
			end
		else
			target_out = tbl.additional_output_entities[output_id-1]
		end

		combinators_local_cbs.get(target_out).cb.parameters={parameters=actual_output}
		self.dirt_map[output_id] = nil
	end
end

function outputs_controller_class:get_outputs_table()
	if not self.outputs_table then
		local outputs_meta = {
			__index = function (outputs_tbl, output_index)
				if output_index==1 or (type(output_index)=='number' and self.comb_tbl.additional_output_entities[output_index-1]) then
					local outp = self:make_output(output_index)
					outputs_tbl[output_index] = outp
					return outp
				end
			end,
		}
		self.outputs_table = setmetatable({}, outputs_meta)
	end

	local ext_outputs_meta = {
		__index = self.outputs_table,
		__len = function (tbl)
			return #self.comb_tbl.additional_output_entities + 1
		end,
		__newindex = function (tbl, out_id, v) 
			-- game.print('!'..tostring(v)..'!')
			if not self.outputs_table[out_id] then
				error('no such output ('..tostring(out_id)..')', 2)
			end
			if type(v) ~= 'table' then
				error("only table can be assigned to output", 2)
			end

			for k,_ in pairs(self.comb_tbl.outputs[out_id]) do
				self.comb_tbl.outputs[out_id][k] = nil
			end
			for k,vv in pairs(v) do
				local valid_v = vv==nil or (type(vv)=='number' and vv >= -2147483648 and vv <= 2147483647)
				if not valid_v then
					error('wrong output value', 2)
				end		
				self.comb_tbl.outputs[out_id][k] = vv
			end
			self.dirt_map[out_id] = true
		end,
	}

	return setmetatable({}, ext_outputs_meta)
end

function outputs_controller_class:on_outputs_list_changed()
	for k,v in pairs(self.outputs_table) do
		self.outputs_table[k] = nil
	end
end


local outputs_controller_mt = {__index = outputs_controller_class}

local function make_outputs_controller(cid)
	local comb_tbl = global.combinators[cid]
	local controller = setmetatable({comb_tbl=comb_tbl, dirt_map={}}, outputs_controller_mt)
	return controller
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
		if k=='red' or k=='rednet' then
			local rn = get_red_network(single_input_meta.inp_entity, single_input_meta.looped_outp)
			rawset(input_tbl, k, rn)
			return rn
		elseif k=='green' or k=='greennet' then
			local gn = get_green_network(single_input_meta.inp_entity, single_input_meta.looped_outp)
			rawset(input_tbl, k, gn)
			return gn
		elseif k=='reset' then
			rawset(input_tbl, 'red', nil)
			rawset(input_tbl, 'rednet', nil)
			rawset(input_tbl, 'green', nil)
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
			if input_index==1 or self.comb_tbl.additional_input_entities[input_index-1] then
				local inp = self:make_input(input_index)
				-- game.print('self:make_input('..input_index..') for '..self.comb_tbl.entity.unit_number)
				rawset(inputs_tbl, input_index, inp)
				return inp
			end
		end,
		__newindex = function (tbl, k, v)
		end,
		__len = function (tbl)
			return #self.comb_tbl.additional_input_entities + 1
		end
	}
	self.inputs_table = setmetatable({}, inputs_meta)
	return self.inputs_table
end

function inputs_controller_class:on_tick()
	for k,v in pairs(self.inputs_table) do
		local _ = v.reset
	end
end

function inputs_controller_class:on_inputs_list_changed()
	for k,v in pairs(self.inputs_table) do
		self.inputs_table[k] = nil
	end
end

local inputs_controller_mt = {__index = inputs_controller_class}

local function make_inputs_controller(cid)
	local comb_tbl = global.combinators[cid]
	local controller = setmetatable({comb_tbl=comb_tbl}, inputs_controller_mt)
	return controller
end


local function make_custom_table_proxy(ct_game_key)
	local custom_table_proxy_mt = {
		__index = function (tbl, k)
			return game[ct_game_key][k]
		end
	}
	return setmetatable({}, custom_table_proxy_mt)
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
				tbl[k] = make_custom_table_proxy(k)
				return tbl[k]
			end
		end})
		sandbox_env_std.print = game.print
	end

	local tbl = global.combinators[cid]

	local inputs_controller = make_inputs_controller(cid)
	combinators_local[cid].inputs_controller = inputs_controller
	
	local outputs_controller = make_outputs_controller(cid)
	combinators_local[cid].outputs_controller = outputs_controller

	local ro_meta = {
		__index = sandbox_env_std,
	}

	local inptbl = inputs_controller:get_inputs_table()
	local outptbl = outputs_controller:get_outputs_table()

	local ro_env = setmetatable({ 
		inputs = inptbl,
		outputs = outptbl,
		output = outptbl[1],
		rednet = setmetatable({}, {__index = function (tbl, k)
			return inptbl[1].rednet[k]
		end}),
		greennet = setmetatable({}, {__index = function (tbl, k)
			return inptbl[1].greennet[k]
		end})

	}, ro_meta)

	local var_meta = {
		__index = ro_env,
		__newindex = function (tbl, k, v)
			if k=='output' then 
				ro_env.outputs[1] = v
			else
				rawset(tbl, k, v)
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

		global.combinators[unit_id] = {
			formatting = true, entity = new_ent, code="", variables = {}, errors="", errors2="", outputs={}, next_tick=1, 
			additional_output_entities={}, additional_input_entities={} 
		}
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
		if not global.combinators[dst_id].errors then
			global.combinators[dst_id].errors = ""
		end
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


	if sandbox_env_std.game then
		sandbox_env_std.game.tick = event.tick
	end


	for unit_nr, tbl in pairs(global.combinators) do
		if not tbl.entity or not tbl.entity.valid then
			game.print('not tbl.entity or not tbl.entity.valid')
			if tbl.blueprint_data and tbl.blueprint_data.valid then
				tbl.blueprint_data.destroy()
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


function combinator_tick(unit_nr, tick)
	tick = tick or game.tick
	local tbl = global.combinators[unit_nr]


	local combinator_local_dta = combinators_local[unit_nr]
	combinator_local_dta.inputs_controller:on_tick()

	local env_var = combinator_local_dta.env_var
	local func = combinator_local_dta.func
	-- assert(env_ro, 'no env')
	-- assert(func, 'no func')

	env_var.delay = 1
	env_var.var = env_var.var or {}

	do
		local _,error = pcall(func)
		tbl.errors=error or ""
	end

	local delay = tonumber(env_var.delay) or 1

	-- local legacy_output = rawget(env_var, 'output')
	-- if legacy_output then
	-- 	rawset(env_var, 'output', nil)
	-- 	combinator_local_dta.env_ro.outputs[1] = legacy_output
	-- end
	combinator_local_dta.outputs_controller:on_post_tick()
	if tbl.errors~="" or tbl.errors2 ~="" then
		for _, player in pairs(tbl.entity.last_user.force.connected_players) do
			player.add_custom_alert(tbl.entity,{type="virtual", name="luacomsb_error"},"LuaCombinator Error: "..tbl.errors..tbl.errors2,true)
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
	local cb_data = combinators_local_cbs.get(entity)
	local cnw = cb_data.cb.get_circuit_network(wire_type, cb_data.ccid)
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
