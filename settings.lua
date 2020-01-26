data:extend(
{ 	

	{
		type = "bool-setting",
		name = "luacomsb-indent-code", 
		setting_type = "runtime-per-user",
		default_value = true,
		order="a1",
		-- per_user = false,
	},
}   
)

data:extend({{
	type = "bool-setting",
	name = "luacomsb-colorize-code", 
	setting_type = "runtime-per-user",
	default_value = true,
	order="a1",
	-- per_user = false,
}})
