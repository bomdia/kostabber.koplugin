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

allow_connection = false
local unchecked, total3 = wizard.configure_sources({ { name = 'C', url = 'https://z' } }, false)
assert(#unchecked == 1)
assert(saved_sources and #saved_sources == 1)
assert(total3 == 0)
assert(indexed == 4)

-- parse UI multiline input, keep only valid Nome|URL lines
local fake_input = "One|https://one\nbadline\nTwo|https://two\nNoUrl|\n|NoName"
package.loaded['ui/widget/inputdialog'] = {
    new = function(_, opts)
        local dialog = { buttons = opts.buttons }
        function dialog:getInputText()
            return fake_input
        end
        return dialog
    end,
}
package.loaded['ui/uimanager'] = {
    show = function(_, dialog)
        dialog.buttons[1][1].callback()
    end,
}
package.loaded['wizard'] = nil
local wizard_with_ui = dofile('../wizard.lua')
wizard_with_ui.run_first_time(function() end)
assert(saved_sources and #saved_sources == 2)
assert(saved_sources[1].name == 'One' and saved_sources[2].name == 'Two')
assert(indexed == 5)

print('wizard tests passed')
