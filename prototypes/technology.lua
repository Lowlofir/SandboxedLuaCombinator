sp = 	{
  "automation-science-pack",
  "logistic-science-pack", 
  "chemical-science-pack", 
  "military-science-pack", 
  "production-science-pack",
  "utility-science-pack"
}


data:extend({

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
          },
          {
            type = "unlock-recipe",
            recipe = "lua-combinator-sb-sep"
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
    

})