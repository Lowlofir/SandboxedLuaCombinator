local M = {}


local m1 = {
    version = '0.2.0',
    apply = function ()
        for id,tbl in pairs(global.combinators) do
            tbl.variables = { var = tbl.variables }
        end
    end
}
table.insert(M, m1)


local m2 = {
    version = '0.2.3',
    silent = true,
    apply = function ()
        for eid,gui in pairs(global.guis) do
            gui.destroy()
            global.guis[eid] = nil
        end
    end
}
table.insert(M, m2)

table.insert(M, {
    version = '0.3.4',
    apply = function ()
        for id,tbl in pairs(global.combinators) do
            tbl.outputs = { [1]=tbl.output }
            tbl.output = nil
        end
    end
})




return M