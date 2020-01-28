local lex = require 'script.lexer'

gui_manager = {}
comb_gui_class = {}

function gui_manager:on_gui_text_changed(ev)
	local eid = find_eid_for_gui_element(ev.element)
	if not eid then return end
	global.guis[eid]:on_gui_text_changed(eid, ev)
end

function gui_manager:on_gui_click(ev)
	local comb_id, elname, preset_i = find_eid_for_gui_element(ev.element)
	if not comb_id then return end
	-- log(serpent.block(global.guis[comb_id]))
	global.guis[comb_id]:on_gui_click(comb_id, elname, preset_i, ev)
end

function gui_manager:open(player, entity)
	local gui_data = self:create_gui(player, entity)
	setmetatable(gui_data, {__index=comb_gui_class})
	global.guis[entity.unit_number]=gui_data
	player.opened=gui_data.gui
end

function gui_manager:create_gui(player, entity)
	local indent_setting = settings_cache:get(player.index, 'indent_code' )
	local colorize_setting = settings_cache:get(player.index, 'colorize_code' )

	local entity_id = entity.unit_number
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
		elem.enabled = (indent_setting or colorize_setting)
		elem.state = global.combinators[entity_id].formatting and elem.enabled
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
		if global.combinators[entity_id].formatting and (indent_setting or colorize_setting) then
			elem.text=format_code(global.combinators[entity_id].code, colorize_setting, indent_setting)
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
	return this_gui_data
	-- global.guis[entity_id]=this_gui_data
	-- player.opened=gui
end


function comb_gui_class:on_gui_click(comb_id, elname, preset_i, event)

	local gui_t = global.guis[comb_id]
	local gui = gui_t.gui
	local indent_setting = settings_cache:get(gui.player_index, 'indent_code' )
	local colorize_setting = settings_cache:get(gui.player_index, 'colorize_code' )
	-- game.print('colorize_setting'..tostring(colorize_setting))

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
					code_textbox.text = format_code(global.presets[id], colorize_setting, indent_setting)
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
				code_tb.text = format_code(code_tb.text, colorize_setting, indent_setting)
				global.textboxes[gui_t.gui.name] = code_tb.text
			else
				code_tb.text = remove_colors(code_tb.text)
			end
			global.combinators[comb_id].formatting = event.element.state
		end
	elseif elname == 'bw_btn' then
		if event.button == defines.mouse_button_type.left and event.shift then
			self:history(gui, -50)
		elseif event.button == defines.mouse_button_type.right then
			self:history(gui, -5)
		else
			self:history(gui, -1)
		end
	elseif elname == 'fw_btn' then
		if event.button == defines.mouse_button_type.left and event.shift then
			self:history(gui, 50)
		elseif event.button == defines.mouse_button_type.right then
			self:history(gui, 5)
		else
			self:history(gui, 1)
		end
	end

end

function comb_gui_class:on_gui_text_changed(eid, ev)
	local indent_setting = settings_cache:get(ev.player_index, 'indent_code' )
	local colorize_setting = settings_cache:get(ev.player_index, 'colorize_code' )
	if ev.element.name ~= "luacomsb_code" then return end

	if not global.textboxes then
		global.textboxes = {}
	end
	local gui = global.guis[eid].gui
	if not gui.flow.luacomsb_formatting.state or(not indent_setting and not colorize_setting) then
		if not global.history[gui.name] then
			global.history[gui.name] = {ev.element.text}
			global.historystate[gui.name] = 1
		else
			insert_history(gui, ev.element.text)
		end
		global.textboxes[gui.name] = ev.element.text
		return
	end
	if not global.textboxes[gui.name] then
		global.textboxes[gui.name] = ev.element.text
		if not global.history[gui.name] then
			global.history[gui.name] = {ev.element.text}
			global.historystate[gui.name] = 1
		end
	else
		local current = remove_colors(ev.element.text)
		local cache = remove_colors(global.textboxes[gui.name])
		local cursor, upd_col, upd_flow = find_difference(current,cache)
		upd_col = upd_col and colorize_setting
		upd_flow = upd_flow and indent_setting
		if cursor then
			if upd_col or upd_flow then
				ev.element.text, cursor = format_code(current, colorize_setting, upd_flow, cursor)
				ev.element.select(cursor,cursor-1)
			end
		end
		if not global.history[gui.name] then
			global.history[gui.name] = {ev.element.text}
			global.historystate[gui.name] = 1
		else
			insert_history(gui, ev.element.text)
		end
		global.textboxes[gui.name] = ev.element.text
	end

end

function comb_gui_class:history (gui,interval)
	local indent_setting = settings_cache:get(gui.player_index, 'indent_code' )
	local colorize_setting = settings_cache:get(gui.player_index, 'colorize_code' )
	local gui_name = gui.name
	local eid = find_eid_for_gui_element(gui)
	local codebox = global.guis[eid].code_tb
	local i = math.min(#global.history[gui_name],math.max(1,global.historystate[gui_name]+interval))
	global.historystate[gui_name] = i
	if gui.flow.luacomsb_formatting.state then
		codebox.text = format_code(remove_colors(global.history[gui_name][i]), colorize_setting, indent_setting)
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



function find_difference (current, cache)
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
		local need_reflow = utils.toboolean(diff:find(' *\n+ *'))
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


function remove_colors(text)
	text = string.gsub(text,"%[color=%d+,%d+,%d+%]","")
	text = string.gsub(text,"%[img=luacomsb_bug%]","")
	text = string.gsub(text,"%[/color%]","")
	text = string.gsub(text,"%[font=default%-bold%]","")
	text = string.gsub(text,"%[/font%]","")
	return text
end

function format_code(text, colorize, upd_flow, tracked_pos)
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



return gui_manager