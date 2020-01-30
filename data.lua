
local trans = {
  filename = '__SandboxedLuaCombinator__/graphics/trans.png',
  width = 1,
  height = 1,
}
local con_point = {
  wire = {
    red = {0, 0},
    green = {0, 0},
  },
  shadow = {
    red = {0, 0},
    green = {0, 0},
  },
}
    

combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "lua-combinator-sb"
combinator.item_slot_count = 500
combinator.minable = {mining_time = 0.5, result = "lua-combinator-sb"}
combinator.additional_pastable_entities = {'lua-combinator-sb-sep'}
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
table.insert(blueprint_data.flags, "placeable-off-grid")
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


combinator2 = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])
combinator2.name = "lua-combinator-sb-sep"
combinator2.minable = {mining_time = 0.5, result = "lua-combinator-sb-sep"}
combinator2.additional_pastable_entities = {'lua-combinator-sb'}
combinator2.energy_source = { type = 'void' }
combinator2.energy_usage_per_tick = '1W'

local combinator2_item = table.deepcopy(data.raw['item']['arithmetic-combinator'])
combinator2_item.name = combinator2.name
combinator2_item.place_result = combinator2.name
combinator2_item.subgroup = 'circuit-network'
combinator2_item.order = 'c[combinators]-db[lua-combinator-sb-sep]'



combinator_output = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator_output.name = "lua-combinator-sb-output"
combinator_output.item_slot_count = 500
combinator_output.minable = {mining_time = 0.5, result = "lua-combinator-sb-output"}

combinator_output_item = table.deepcopy(data.raw["item"]["constant-combinator"])
combinator_output_item.name = combinator_output.name
combinator_output_item.place_result = combinator_output.name
combinator_output_item.subgroup = 'circuit-network'
combinator_output_item.order = 'c[combinators]-dc[lua-combinator-sb-output]'


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
    order = "c[combinators]-da[lua-combinator-sb]",
    place_result = "lua-combinator-sb",
    stack_size = 50
  },
  
  combinator2, combinator2_item,
  {
    type = 'constant-combinator',
    name = 'lua-combinator-sb-proxy',
    flags = {'placeable-off-grid'},
    collision_mask = {},
    item_slot_count = 500,
    circuit_wire_max_distance = 3,
    sprites = {
      north = trans,
      east = trans,
      south = trans,
      west = trans,
    },
    activity_led_sprites = trans,
    activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
    
    circuit_wire_connection_points = {con_point, con_point, con_point, con_point},
    draw_circuit_wires = false,
  },

  combinator_output, combinator_output_item
})

require 'prototypes.recipes'
require 'prototypes.sprites'
require 'prototypes.technology'
require 'prototypes.signals'