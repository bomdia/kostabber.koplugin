local util = require("util")

local stub = {}

function stub.new(entry)
    local hash_seed = (entry.id or "") .. "|" .. (entry.remote_download_url or "")
    local hash = entry.hash or util.sha1_like(hash_seed)
    return {
        format_version = 1,
        id = entry.id,
        title = entry.title or "",
        authors = entry.authors or {},
        series = entry.series,
        series_index = entry.series_index,
        cover_url = entry.cover_url,
        remote_download_url = entry.remote_download_url,
        hash = hash,
        local_asset_path = entry.local_asset_path,
        last_access_ts = entry.last_access_ts or 0,
        read_progress = entry.read_progress or { position = "", timestamp = 0 },
    }
end

function stub.save(path, obj)
    return util.save_json_table(path, obj)
end

function stub.load(path)
    return util.load_json_table(path, nil)
end

return stub
