package.path = '../?.lua;./?.lua;' .. package.path

local indexed = 0
local saved_sources
local allow_connection = true

package.loaded['sources'] = {
    add = function() end,
    save = function(list)
        saved_sources = list
        return true
    end,
    test_connection = function(_)
        return allow_connection
    end,
}

package.loaded['opds'] = {
    initial_index_all = function()
        indexed = indexed + 1
        return 0
    end,
}

package.loaded['ui/widget/inputdialog'] = nil
package.loaded['ui/uimanager'] = nil

local wizard = dofile('../wizard.lua')

local finished = false
wizard.run_first_time(function()
    finished = true
end)
assert(finished == true)
assert(indexed == 1)

local valid, total = wizard.configure_sources({ { name = 'A', url = 'https://x' } }, true)
assert(#valid == 1)
assert(saved_sources and #saved_sources == 1)
assert(total == 0)
assert(indexed == 2)

allow_connection = false
local filtered, total2 = wizard.configure_sources({ { name = 'B', url = 'https://y' } }, true)
assert(#filtered == 0)
assert(saved_sources and #saved_sources == 0)
assert(total2 == 0)
assert(indexed == 3)

print('wizard tests passed')
