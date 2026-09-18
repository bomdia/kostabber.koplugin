package.path = '../?.lua;./?.lua;' .. package.path

local util = require('util')
local paths = require('paths')
paths.base = '/tmp/kostabber-main-test'
paths.sources = paths.base .. '/sources.lua'
paths.state = paths.base .. '/state.lua'
paths.stub_dir = paths.base .. '/sync'
paths.cover_cache_dir = paths.base .. '/cache/covers'
paths.asset_dir = paths.base .. '/assets'
paths.storage_ledger = paths.base .. '/storage_ledger.json'
util.command_success("rm -rf " .. util.shell_quote(paths.base))
paths.ensure()

-- init() first-run path
package.loaded['sources'] = {
    is_configured = function()
        return false
    end,
}

local wizard_called = false
local deferred_finish
package.loaded['wizard'] = {
    run_first_time = function(on_finished)
        wizard_called = true
        deferred_finish = on_finished
    end,
}

local main_init = dofile('../main.lua')
main_init:init()
assert(wizard_called == true)
local before_state = util.load_lua_table(paths.state, {})
assert(before_state.first_run_completed ~= true)
assert(type(deferred_finish) == 'function')
deferred_finish()
local state = util.load_lua_table(paths.state, {})
assert(state.first_run_completed == true)

-- init() real wizard fallback path without UI
paths.base = '/tmp/kostabber-main-test-fallback'
paths.sources = paths.base .. '/sources.lua'
paths.state = paths.base .. '/state.lua'
paths.stub_dir = paths.base .. '/sync'
paths.cover_cache_dir = paths.base .. '/cache/covers'
paths.asset_dir = paths.base .. '/assets'
paths.storage_ledger = paths.base .. '/storage_ledger.json'
util.command_success("rm -rf " .. util.shell_quote(paths.base))
paths.ensure()

local indexed = 0
package.loaded['sources'] = {
    is_configured = function()
        return false
    end,
}
package.loaded['opds'] = {
    initial_index_all = function()
        indexed = indexed + 1
        return 0
    end,
}
package.loaded['wizard'] = nil
package.loaded['ui/widget/inputdialog'] = nil
package.loaded['ui/uimanager'] = nil
local main_real_wizard = dofile('../main.lua')
main_real_wizard:init()
local fallback_state = util.load_lua_table(paths.state, {})
assert(fallback_state.first_run_completed == true)
assert(indexed == 1)

-- clear mocks and test normal dispatch behavior
package.loaded['sources'] = nil
package.loaded['wizard'] = nil
package.loaded['opds'] = nil

local stub = require('stub')
local stub_path = paths.stub_dir .. '/abc123.kocloud'
stub.save(stub_path, {
    format_version = 1,
    id = 'id-1',
    title = 'My Book',
    authors = { 'Author' },
    remote_download_url = 'https://example.invalid/book.epub',
    hash = 'abc123',
    local_asset_path = '/tmp/local.epub',
    last_access_ts = 0,
    read_progress = { position = '', timestamp = 0 },
})

package.loaded['reader_hook'] = {
    open_stub = function(path, _)
        return 'opened:' .. path
    end,
}

local main = dofile('../main.lua')
assert(main.onOpenFile(main, '/tmp/not_stub.txt') == nil)
assert(main.onOpenFile(main, stub_path) == 'opened:' .. stub_path)

local non_stub_actions = main.getContextMenuActions(main, '/tmp/not_stub.txt')
assert(type(non_stub_actions) == 'table' and #non_stub_actions == 0)

local stub_actions = main.getContextMenuActions(main, stub_path)
assert(type(stub_actions) == 'table' and #stub_actions >= 3)
assert(stub_actions[1].id == 'remove_local_asset')

local item = main.renderFileItem(main, stub_path)
assert(item and item.title == 'My Book')
assert(item.subtitle == 'Author')

print('main.lua tests passed')
