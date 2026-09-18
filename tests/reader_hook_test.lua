package.path = '../?.lua;./?.lua;' .. package.path

local util = require('util')
local paths = require('paths')
paths.base = '/tmp/kostabber-reader-test'
paths.sources = paths.base .. '/sources.json'
paths.state = paths.base .. '/state.json'
paths.stub_dir = paths.base .. '/sync'
paths.cover_cache_dir = paths.base .. '/cache/covers'
paths.asset_dir = paths.base .. '/assets'
paths.storage_ledger = paths.base .. '/storage_ledger.json'
util.command_success("rm -rf " .. util.shell_quote(paths.base))
paths.ensure()

local stub = require('stub')
local notifications = {}
package.loaded['notify'] = {
    show = function(msg)
        notifications[#notifications + 1] = msg
        return true
    end,
}
local reader_hook = require('reader_hook')

-- cached asset reuse
local cached_asset = paths.asset_dir .. '/cached.epub'
util.write_file(cached_asset, 'cached')
local cached_stub = paths.stub_dir .. '/cached.kocloud'
stub.save(cached_stub, {
    format_version = 1,
    id = 'cached-id',
    title = 'Cached',
    authors = { 'A' },
    remote_download_url = 'https://example.invalid/book.epub',
    hash = 'cached-hash',
    local_asset_path = cached_asset,
    last_access_ts = 0,
    read_progress = { position = '', timestamp = 0 },
})

local resolved = reader_hook.resolve_local_path(cached_stub)
assert(resolved == cached_asset)

-- download success path via network/http
package.loaded['network/http'] = {
    request = function(_, _)
        return { status = 200, body = 'downloaded-data' }
    end,
}

local download_stub = paths.stub_dir .. '/download.kocloud'
stub.save(download_stub, {
    format_version = 1,
    id = 'download-id',
    title = 'Download',
    authors = { 'B' },
    remote_download_url = 'https://example.invalid/book.epub?x=1',
    hash = 'download-hash',
    local_asset_path = nil,
    last_access_ts = 0,
    read_progress = { position = '', timestamp = 0 },
})

local downloaded_path = reader_hook.resolve_local_path(download_stub)
assert(downloaded_path and downloaded_path:match('%.epub$'))
assert(util.file_exists(downloaded_path))
local updated_stub = stub.load(download_stub)
assert(updated_stub.local_asset_path == downloaded_path)
assert(type(updated_stub.last_access_ts) == 'number' and updated_stub.last_access_ts > 0)
local ledger = util.json_decode(util.read_file(paths.storage_ledger) or '{}')
assert(ledger and ledger.items and ledger.items['download-hash'])
assert(#notifications >= 1)
assert(notifications[#notifications]:match('asset pronto'))

-- download failure path propagates error
package.loaded['network/http'] = {
    request = function(_, _)
        return { status = 500, body = 'error-page' }
    end,
}

local old_command_success = util.command_success
util.command_success = function(_)
    return false
end

local failed_stub = paths.stub_dir .. '/failed.kocloud'
stub.save(failed_stub, {
    format_version = 1,
    id = 'fail-id',
    title = 'Fail',
    authors = { 'C' },
    remote_download_url = 'https://example.invalid/book.pdf',
    hash = 'failed-hash',
    local_asset_path = nil,
    last_access_ts = 0,
    read_progress = { position = '', timestamp = 0 },
})

local missing_path, err = reader_hook.resolve_local_path(failed_stub)
assert(missing_path == nil)
assert(err == 'download_failed')
assert(notifications[#notifications]:match('download fallito'))

util.command_success = old_command_success

print('reader_hook tests passed')
