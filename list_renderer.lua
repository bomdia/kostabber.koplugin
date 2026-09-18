local cover_cache = require("cover_cache")

local list_renderer = {}

local function format_main_title(item)
    if item.series and item.series_index then
        return string.format("[%s #%s] %s", item.series, tostring(item.series_index), item.title or "")
    end
    return item.title or ""
end

function list_renderer.render_item(stub_item)
    local authors = stub_item.authors or {}
    local subtitle = authors[1] or ""
    local badge = stub_item.local_asset_path and "cache" or "cloud"

    return {
        cover = stub_item.cover_url and cover_cache.path_for(stub_item.cover_url) or nil,
        cover_size = { width = 60, height = 90 },
        title = format_main_title(stub_item),
        subtitle = subtitle,
        subtitle_style = "small",
        badge = badge,
    }
end

return list_renderer
