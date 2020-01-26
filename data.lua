sp = 	{
				"automation-science-pack",
				"logistic-science-pack", 
				"chemical-science-pack", 
				"military-science-pack", 
				"production-science-pack",
				"utility-science-pack"
		}



combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "lua-combinator-sb"
combinator.item_slot_count = 500
combinator.minable = {mining_time = 0.5, result = "lua-combinator-sb"}
combinator.sprites = make_4way_animation_from_spritesheet({ layers =
      {
        {
          filename = "__SandboxedLuaCombinator__/graphics/lua-combinator.png",
          width = 58,
          height = 52,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
          hr_version =
          {
            scale = 0.5,
            filename = "__SandboxedLuaCombinator__/graphics/hr-lua-combinator.png",
            width = 114,
            height = 102,
            frame_count = 1,
            shift = util.by_pixel(0, 5)
          }
        },
        {
          filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
          width = 50,
          height = 34,
          frame_count = 1,
          shift = util.by_pixel(9, 6),
          draw_as_shadow = true,
          hr_version =
          {
            scale = 0.5,
            filename = "__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png",
            width = 98,
            height = 66,
            frame_count = 1,
            shift = util.by_pixel(8.5, 5.5),
            draw_as_shadow = true
          }
        }
      }
    })

blueprint_data = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
blueprint_data.name = "luacomsb_blueprint_data"
table.insert(blueprint_data.flags, "hide-alt-info")
blueprint_data.order = "xxxx"
blueprint_data.item_slot_count = 500
blueprint_data.selection_box={{-0.5,-0.5},{-0.25,-0.25}}
blueprint_data.selectable_in_game = false
blueprint_data.collision_mask = {"layer-11"}
blueprint_data.sprites = {
      north = {
        filename = "__SandboxedLuaCombinator__/graphics/transparent32.png",
        x = 0,
        y = 0,
        width = 32,
  	    height = 32,
        shift = {0.078125, 0.15625},
		
      },
      south = {
        filename = "__SandboxedLuaCombinator__/graphics/transparent32.png",
        x = 0,
        y = 0,
        width = 32,
        height = 32,
        shift = {0.078125, 0.15625},
		
      },
      east = {
        filename = "__SandboxedLuaCombinator__/graphics/transparent32.png",
        x = 0,
        y = 0,
        width = 32,
        height = 32,
        shift = {0.078125, 0.15625},
		
      },
      west = {
        filename = "__SandboxedLuaCombinator__/graphics/transparent32.png",
        x = 0,
        y = 0,
        width = 32,
        height = 32,
        shift = {0.078125, 0.15625},
		
      }
    }

blueprint_data_item = table.deepcopy(data.raw.item["constant-combinator"])
blueprint_data_item.name = "luacomsb_blueprint_data"
blueprint_data_item.icon = "__SandboxedLuaCombinator__/graphics/blueprint_data.png"
blueprint_data_item.icon_size = 64
blueprint_data_item.place_result = "luacomsb_blueprint_data"
if blueprint_data_item.flags then
	table.insert(blueprint_data_item.flags, "hidden")
else
	blueprint_data_item.flags = {"hidden"}
end


--[[
combinator2 = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])
combinator2.name = "lua-combinator-sb-sep"
combinator2.minable = {mining_time = 0.5, result = "lua-combinator-sb-sep"}
]]


data:extend({
  combinator,
  blueprint_data,
  blueprint_data_item,
  {
    type = "item",
    name = "lua-combinator-sb",
    icon_size = 64,
    icon = "__SandboxedLuaCombinator__/graphics/lua-combinator-icon.png",
    flags = {flag_quickbar},
    subgroup = "circuit-network",
    order = "c[combinators]-c[constant-combinator]",
    place_result = "lua-combinator-sb",
    stack_size = 50
  },
  
  -- combinator2,
  -- {
  --   type = "item",
  --   name = "lua-combinator-sb-sep",
  --   icon_size = 32,
  --   icon = "__base__/graphics/icons/arithmetic-combinator.png",
  --   flags = {flag_quickbar},
  --   subgroup = "circuit-network",
  --   order = "c[combinators]-c[arithmetic-combinator]",
  --   place_result = "lua-combinator-sb-sep",
  --   stack_size = 50
  -- },

  -- {		
  --   type = "recipe",
  --   name = "lua-combinator-sb-sep",
  --   icon_size = 64,
  --   enabled = "true",
  --   ingredients =
  --   {
  --     {"arithmetic-combinator", 1},
  --     {"advanced-circuit", 5}
  --   },
  --   result = "lua-combinator-sb-sep"
  -- },
	
	{
		type = "recipe",
		name = "lua-combinator-sb",
		icon_size = 64,
		enabled = "false",
		ingredients =
		{
			{"constant-combinator", 1},
			{"small-lamp", 1},
			{"advanced-circuit", 5}
		},
		result = "lua-combinator-sb"
	},
	
	{
    type = "technology",
    name = "lua-combinator-sb",
    icon_size = 144,
    icon = "__SandboxedLuaCombinator__/not-a-thumbnail.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "lua-combinator-sb"
      }
    },
    prerequisites = {"circuit-network", "advanced-electronics"},
    unit =
    {
      count = 100,
      ingredients =
      {
        {sp[1], 1},
        {sp[2], 1}
      },
      time = 15
    },
    order = "a-d-d-z",
  },
  {
    type = "virtual-signal",
    name = "luacomsb_error",
    special_signal = false,
    icon = "__SandboxedLuaCombinator__/graphics/error-icon.png",
    icon_size = 64,
    subgroup = "virtual-signal-special",
    order = "a[special]-[1everything]"
  },
  {
    type = "sprite",
    name = "luacomsb_bug",
    filename = "__SandboxedLuaCombinator__/graphics/bug.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32,
    flags = {"no-crop", "icon"},
    scale = 0.2
  },
  {
    type = "sprite",
    name = "luacomsb_forward",
    filename = "__SandboxedLuaCombinator__/graphics/forward.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32,
    flags = {"no-crop", "icon"},
    scale = 0.3
  },
{
    type = "sprite",
    name = "luacomsb_back",
    filename = "__SandboxedLuaCombinator__/graphics/back.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32,
    flags = {"no-crop", "icon"},
    scale = 0.3
  },
    {
    type = "sprite",
    name = "luacomsb_forward_enabled",
    filename = "__SandboxedLuaCombinator__/graphics/forward_enabled.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32,
    flags = {"no-crop", "icon"},
    scale = 0.3
  },
{
    type = "sprite",
    name = "luacomsb_back_enabled",
    filename = "__SandboxedLuaCombinator__/graphics/back_enabled.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32,
    flags = {"no-crop", "icon"},
    scale = 0.3
  },
  {
    type = "sprite",
    name = "luacomsb_close",
    filename = "__SandboxedLuaCombinator__/graphics/close.png",
    priority = "extra-high-no-scale",
    width = 20,
    height = 20,
    flags = {"no-crop", "icon"},
    scale = 1
  },
  {
    type = "sprite",
    name = "luacomsb_questionmark",
    filename = "__SandboxedLuaCombinator__/graphics/questionmark.png",
    priority = "extra-high-no-scale",
    width = 20,
    height = 20,
    flags = {"no-crop", "icon"},
    scale = 1
  },
})
