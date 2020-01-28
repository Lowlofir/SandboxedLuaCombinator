
local M = {}

function M.toboolean(v)
	if v then 
		return true
	else
		return false
	end
end

function M.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
        end
        -- setmetatable(copy, luacomsb_deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


return M