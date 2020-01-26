require 'blueprint_custom_data'

local sample_data = { sample_key = sample_value, {a=1, b = 'c'}, d = true}
write_to_combinator(combinator, sample_data)
local loaded_data = read_from_combinator(combinator)

-- now loaded_data contains the same data as is same as sample_data
