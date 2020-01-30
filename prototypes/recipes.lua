data:extend({

    {		
        type = "recipe",
        name = "lua-combinator-sb-sep",
        -- icon_size = 64,
        enabled = "false",
        ingredients =
        {
          {"arithmetic-combinator", 1},
          {"advanced-circuit", 5}
        },
        result = "lua-combinator-sb-sep"
      },
      
      {
        type = "recipe",
        name = "lua-combinator-sb",
        -- icon_size = 64,
        enabled = "false",
        ingredients =
        {
          {"constant-combinator", 1},
          {"advanced-circuit", 5}
        },
        result = "lua-combinator-sb"
      },

      {
        type = "recipe",
        name = "lua-combinator-sb-output",
        -- icon_size = 64,
        enabled = "false",
        ingredients =
        {
          {"constant-combinator", 1},
          {"advanced-circuit", 3}
        },
        result = "lua-combinator-sb-output"
      },
      {
        type = "recipe",
        name = "lua-combinator-sb-input",
        -- icon_size = 64,
        enabled = "false",
        ingredients =
        {
          {"small-lamp", 1},
          {"advanced-circuit", 3}
        },
        result = "lua-combinator-sb-input"
      }


    
})