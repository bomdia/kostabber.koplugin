local util = require("util")

local paths = {}

local plugin_home = os.getenv("KOSTABBER_HOME") or util.join(os.getenv("HOME") or ".", ".config", "koreader", "kostabber")

paths.base = plugin_home
paths.sources = util.join(plugin_home, "sources.lua")
paths.state = util.join(plugin_home, "state.lua")
paths.stub_dir = util.join(plugin_home, "sync")
paths.cover_cache_dir = util.join(plugin_home, "cache", "covers")
paths.asset_dir = util.join(plugin_home, "assets")
paths.storage_ledger = util.join(plugin_home, "storage_ledger.json")

function paths.ensure()
    util.mkdir_p(paths.base)
    util.mkdir_p(paths.stub_dir)
    util.mkdir_p(paths.cover_cache_dir)
    util.mkdir_p(paths.asset_dir)
end

return paths
