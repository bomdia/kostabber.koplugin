local util = require("util")
local paths = require("paths")

local cover_cache = {}

local function ext_from_url(url)
    local ext = url and url:match("%.([a-zA-Z0-9]+)(%?.*)?$")
    return ext and #ext <= 5 and ext or "jpg"
end

function cover_cache.path_for(url)
    if not url or url == "" then
        return nil
    end
    local filename = util.sha1_like(url) .. "." .. ext_from_url(url)
    return util.join(paths.cover_cache_dir, filename)
end

function cover_cache.ensure(url)
    local target = cover_cache.path_for(url)
    if not target then
        return nil
    end
    paths.ensure()
    if util.file_exists(target) then
        return target
    end

    local ok_http, http = pcall(require, "network/http")
    if ok_http and http and http.request then
        local ok, res = pcall(http.request, url, { method = "GET" })
        local status = ok and res and tonumber(res.status or res.code or 0) or 0
        if ok and res and res.body and status > 0 and status < 400 then
            local written = util.write_file(target, res.body)
            if written and util.file_exists(target) then
                return target
            end
        end
    end

    local ok_curl = util.command_success("curl -Lsf " .. util.shell_quote(url) .. " -o " .. util.shell_quote(target))
    if ok_curl and util.file_exists(target) then
        return target
    end
    return nil
end

return cover_cache
