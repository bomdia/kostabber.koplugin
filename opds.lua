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

local function parse_entries(xml)
    local entries = {}
    for entry_xml in xml:gmatch("<entry.-</entry>") do
        local id = entry_xml:match("<id>(.-)</id>")
        local title = entry_xml:match("<title[^>]*>(.-)</title>")
        local author = entry_xml:match("<author>.-<name>(.-)</name>.-</author>")
        local series = entry_xml:match('<category[^>]-label="series"[^>]-term="([^"]+)"')
            or entry_xml:match('<meta[^>]-name="calibre:series"[^>]-content="([^"]+)"')
        local series_index = tonumber(entry_xml:match('<meta[^>]-name="calibre:series_index"[^>]-content="([^"]+)"'))
        local download_url = entry_xml:match('<link[^>]-type="[^"]*acquisition[^"]*"[^>]-href="([^"]+)"')
        local cover_url = entry_xml:match('<link[^>]-type="image/[^\"]+"[^>]-href="([^"]+)"')

        if id and title and download_url then
            entries[#entries + 1] = {
                id = xml_unescape(id),
                title = xml_unescape(title),
                authors = author and { xml_unescape(author) } or {},
                series = series and xml_unescape(series) or nil,
                series_index = series_index,
                remote_download_url = xml_unescape(download_url),
                cover_url = cover_url and xml_unescape(cover_url) or nil,
            }
        end
    end
    return entries
end

local function fetch(url)
    local ok_http, http = pcall(require, "network/http")
    if ok_http and http and http.request then
        local ok, res = pcall(http.request, url, { method = "GET" })
        if ok and res and res.body then
            return res.body
        end
    end
    local tmp_path = util.join(paths.base, "_opds.xml")
    local ok_curl = os.execute("curl -Lsf " .. util.shell_quote(url) .. " -o " .. util.shell_quote(tmp_path))
    if ok_curl == true or ok_curl == 0 then
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

    local entries = parse_entries(xml)
    for _, entry in ipairs(entries) do
        local item = stub.new(entry)
        local path = util.join(paths.stub_dir, item.hash .. ".kocloud")
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
