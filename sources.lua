local util = require("util")
local paths = require("paths")

local sources = {}

local function normalize_source(src)
    return {
        name = src.name,
        url = src.url,
    }
end

function sources.load()
    paths.ensure()
    return util.load_lua_table(paths.sources, {}) or {}
end

function sources.save(list)
    paths.ensure()
    local normalized = {}
    for _, src in ipairs(list or {}) do
        if src.name and src.url then
            normalized[#normalized + 1] = normalize_source(src)
        end
    end
    return util.save_lua_table(paths.sources, normalized)
end

function sources.add(name, url)
    local list = sources.load()
    list[#list + 1] = normalize_source({ name = name, url = url })
    return sources.save(list), list
end

function sources.is_configured()
    return #sources.load() > 0
end

function sources.test_connection(url)
    local ok_http, http = pcall(require, "network/http")
    if ok_http and http and http.request then
        local ok, res = pcall(http.request, url, { method = "GET" })
        if ok and res then
            local status = tonumber(res.status or res.code or 0) or 0
            return status >= 200 and status < 400, status
        end
    end
    local ok_curl, code = util.command_success("curl -Lsf -o /dev/null " .. util.shell_quote(url))
    return ok_curl, code
end

return sources
