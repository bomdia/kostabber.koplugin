local util = require("util")
local paths = require("paths")
local stub = require("stub")
local sources = require("sources")
local cover_cache = require("cover_cache")
local notify = require("notify")

local opds = {}

local function xml_unescape(s)
    return (s or ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'")
end

local function resolve_url(base_url, href)
    if not href or href == "" then
        return href
    end
    if href:match("^https?://") then
        return href
    end
    if href:match("^//") then
        local scheme = (base_url and base_url:match("^(https?):")) or "http"
        return scheme .. ":" .. href
    end
    if not base_url or base_url == "" then
        return href
    end
    local function normalize_path(path)
        local stack = {}
        for seg in path:gmatch("[^/]+") do
            if seg == ".." then
                if #stack > 0 then
                    table.remove(stack)
                end
            elseif seg ~= "." and seg ~= "" then
                stack[#stack + 1] = seg
            end
        end
        return "/" .. table.concat(stack, "/")
    end
    local origin = base_url:match("^(https?://[^/]+)")
    if href:sub(1, 1) == "/" and origin then
        return origin .. normalize_path(href)
    end
    local base_dir = base_url:match("^(https?://.*/)")
    if not base_dir and origin then
        base_dir = origin .. "/"
    end
    local merged = (base_dir or "") .. href
    local prefix, path = merged:match("^(https?://[^/]+)(/.*)$")
    if prefix and path then
        return prefix .. normalize_path(path)
    end
    return merged
end

local function parse_entries(xml, source_url)
    local entries = {}
    for entry_xml in xml:gmatch("<entry[%s%S]-</entry>") do
        local id = entry_xml:match("<id>([%s%S]-)</id>")
        local title = entry_xml:match("<title[^>]*>([%s%S]-)</title>")
        local author = entry_xml:match("<author>[%s%S]-<name>([%s%S]-)</name>[%s%S]-</author>")
        local series = entry_xml:match('<category[^>]-label="series"[^>]-term="([^"]+)"')
            or entry_xml:match('<meta[^>]-name="calibre:series"[^>]-content="([^"]+)"')
        local series_index = tonumber(entry_xml:match('<meta[^>]-name="calibre:series_index"[^>]-content="([^"]+)"'))
        local download_url
        local cover_url

        for link in entry_xml:gmatch("<link%s+([^>]-)%s*/?>") do
            local attrs = {}
            for key, value in link:gmatch('([%w:_-]+)%s*=%s*"([^"]*)"') do
                attrs[key] = value
            end
            for key, value in link:gmatch("([%w:_-]+)%s*=%s*'([^']*)'") do
                if attrs[key] == nil then
                    attrs[key] = value
                end
            end
            local link_type = attrs.type or ""
            local href = attrs.href
            if href and link_type:find("acquisition", 1, true) and not download_url then
                download_url = href
            end
            if href and link_type:match("^image/") and not cover_url then
                cover_url = href
            end
        end

        if id and title and download_url then
            entries[#entries + 1] = {
                id = xml_unescape(id:gsub("^%s+", ""):gsub("%s+$", "")),
                title = xml_unescape(title:gsub("^%s+", ""):gsub("%s+$", "")),
                authors = author and { xml_unescape(author:gsub("^%s+", ""):gsub("%s+$", "")) } or {},
                series = series and xml_unescape(series) or nil,
                series_index = series_index,
                remote_download_url = resolve_url(source_url, xml_unescape(download_url)),
                cover_url = cover_url and resolve_url(source_url, xml_unescape(cover_url)) or nil,
            }
        end
    end
    return entries
end

local function list_stub_paths()
    local handle = io.popen("find " .. util.shell_quote(paths.stub_dir) .. " -maxdepth 1 -name '*.kocloud' 2>/dev/null")
    if not handle then
        return {}
    end
    local out = {}
    for line in handle:lines() do
        out[#out + 1] = line
    end
    handle:close()
    return out
end

local function find_existing_by_id(id)
    if not id then
        return nil, nil
    end
    for _, candidate in ipairs(list_stub_paths()) do
        local existing = stub.load(candidate)
        if existing and existing.id == id then
            return candidate, existing
        end
    end
    return nil, nil
end

local function fetch(url)
    paths.ensure()
    local ok_http, http = pcall(require, "network/http")
    if ok_http and http and http.request then
        local ok, res = pcall(http.request, url, { method = "GET" })
        local status = ok and res and tonumber(res.status or res.code or 0) or 0
        if ok and res and res.body and status > 0 and status < 400 then
            return res.body
        end
    end
    local tmp_path = util.join(paths.base, string.format("_opds_%s_%d.xml", util.sha1_like(url), util.now()))
    local ok_curl = util.command_success("curl -Lsf " .. util.shell_quote(url) .. " -o " .. util.shell_quote(tmp_path))
    if ok_curl then
        local body = util.read_file(tmp_path)
        os.remove(tmp_path)
        return body
    end
    return nil
end

function opds.index_source(source)
    notify.show("KoStabber: sync " .. (source.name or source.url or "source"))
    local xml = fetch(source.url)
    if not xml then
        notify.show("KoStabber: errore download feed")
        return 0, "fetch_failed"
    end

    local entries = parse_entries(xml, source.url)
    for _, entry in ipairs(entries) do
        local item = stub.new(entry)
        local path = util.join(paths.stub_dir, item.hash .. ".kocloud")
        local existing = stub.load(path)
        if not existing then
            local existing_path, found = find_existing_by_id(item.id)
            if found then
                existing = found
                path = existing_path
            end
        end
        if existing then
            item.hash = existing.hash or item.hash
            path = util.join(paths.stub_dir, item.hash .. ".kocloud")
            if not item.cover_url then
                item.cover_url = existing.cover_url
            end
            if existing.local_asset_path and util.file_exists(existing.local_asset_path) then
                item.local_asset_path = existing.local_asset_path
            else
                item.local_asset_path = nil
            end
            item.last_access_ts = existing.last_access_ts or item.last_access_ts
            item.read_progress = existing.read_progress or item.read_progress
        end
        stub.save(path, item)
        if item.cover_url then
            cover_cache.ensure(item.cover_url)
        end
    end
    notify.show(string.format("KoStabber: indicizzati %d titoli", #entries))
    return #entries
end

function opds.initial_index_all()
    paths.ensure()
    local total = 0
    for _, source in ipairs(sources.load()) do
        local count = opds.index_source(source)
        total = total + (count or 0)
    end
    return total
end

return opds
