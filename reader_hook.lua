local util = require("util")
local paths = require("paths")
local stub = require("stub")
local storage = require("storage")
local notify = require("notify")

local reader_hook = {}

local function list_stub_files(dir, skip_path)
    local cmd
    if package.config:sub(1, 1) == "\\" then
        cmd = 'dir /b /a-d "' .. dir:gsub("/", "\\") .. '\\*.kocloud" 2> NUL'
    else
        cmd = "find " .. util.shell_quote(dir) .. " -maxdepth 1 -name '*.kocloud' 2>/dev/null"
    end
    local handle = io.popen(cmd)
    if not handle then
        return {}
    end
    local out = {}
    for line in handle:lines() do
        local path = line
        if package.config:sub(1, 1) == "\\" and not line:match("^[A-Za-z]:\\") then
            path = util.join(dir, line)
        end
        if path ~= skip_path then
            out[#out + 1] = path
        end
    end
    handle:close()
    return out
end

local function extension_from_item(item)
    local ext = item.remote_download_url and item.remote_download_url:match("%.([a-zA-Z0-9]+)(%?.*)?$")
    if ext and #ext <= 5 then
        return ext:lower()
    end
    return "epub"
end

local function download_asset(url, stub_hash)
    local target = util.join(paths.asset_dir, stub_hash .. "." .. extension_from_item({ remote_download_url = url }))
    local ok_http, http = pcall(require, "network/http")
    if ok_http and http and http.request then
        local ok, res = pcall(http.request, url, { method = "GET" })
        local status = ok and res and tonumber(res.status or res.code or 0) or 0
        if ok and res and res.body and status > 0 and status < 400 then
            util.write_file(target, res.body)
            return target
        end
    end

    local ok_curl = util.command_success("curl -Lsf " .. util.shell_quote(url) .. " -o " .. util.shell_quote(target))
    if ok_curl then
        return target
    end
    return nil
end

function reader_hook.resolve_local_path(stub_path)
    paths.ensure()
    local item = stub.load(stub_path)
    if not item then
        return nil, "invalid_stub"
    end

    if item.local_asset_path and util.file_exists(item.local_asset_path) then
        item.last_access_ts = util.now()
        stub.save(stub_path, item)
        storage.record_access(item.hash)
        return item.local_asset_path
    end

    if not item.remote_download_url then
        return nil, "missing_remote_download_url"
    end

    local local_path = download_asset(item.remote_download_url, item.hash)
    if not local_path then
        notify.show("KoStabber: download fallito")
        return nil, "download_failed"
    end

    item.local_asset_path = local_path
    item.last_access_ts = util.now()
    stub.save(stub_path, item)
    storage.record_access(item.hash)
    storage.evict_if_needed(list_stub_files(paths.stub_dir), stub_path)
    notify.show("KoStabber: asset pronto in cache")
    return local_path
end

function reader_hook.open_stub(stub_path, reader)
    local local_path, err = reader_hook.resolve_local_path(stub_path)
    if not local_path then
        return nil, err
    end

    if reader and reader.open then
        return reader:open(local_path)
    end
    return local_path
end

function reader_hook.sync_progress(stub_path, position)
    local item = stub.load(stub_path)
    if not item then
        return nil
    end
    item.read_progress = {
        position = position or "",
        timestamp = util.now(),
    }
    stub.save(stub_path, item)
    return true
end

return reader_hook
