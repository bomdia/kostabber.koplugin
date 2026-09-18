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
paths.ensure()

-- init() first-run path
package.loaded['sources'] = {
    is_configured = function()
        return false
    end,
}

local wizard_called = false
package.loaded['wizard'] = {
    run_first_time = function(on_finished)
        wizard_called = true
        if on_finished then
            on_finished()
        end
    end,
}

local main_init = dofile('../main.lua')
main_init:init()
assert(wizard_called == true)
local state = util.load_lua_table(paths.state, {})
assert(state.first_run_completed == true)

-- clear mocks and test normal dispatch behavior
package.loaded['sources'] = nil
package.loaded['wizard'] = nil

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
