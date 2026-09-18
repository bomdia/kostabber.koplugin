local util = require("util")
local paths = require("paths")
local sources = require("sources")
local wizard = require("wizard")
local opds = require("opds")

local KoStabber = {
    name = "KoStabber",
}

local function load_state()
    return util.load_json_table(paths.state, { first_run_completed = false }) or { first_run_completed = false }
end

local function save_state(state)
    return util.save_json_table(paths.state, state)
end

function KoStabber:init()
    paths.ensure()
    local state = load_state()
    local first_run = not state.first_run_completed or not sources.is_configured()

    if first_run then
        wizard.run_first_time(function()
            state.first_run_completed = true
            save_state(state)
        end)
    else
        opds.initial_index_all()
    end
end

function KoStabber:onOpenFile(path, reader)
    if not path or not path:match("%.kocloud$") then
        return nil
    end
    local reader_hook = require("reader_hook")
    return reader_hook.open_stub(path, reader)
end

function KoStabber:getContextMenuActions(path)
    if not path or not path:match("%.kocloud$") then
        return {}
    end
    local context_menu = require("context_menu")
    return context_menu.actions_for_stub(path)
end

function KoStabber:renderFileItem(path)
    if not path or not path:match("%.kocloud$") then
        return nil
    end
    local stub = require("stub")
    local list_renderer = require("list_renderer")
    local item = stub.load(path)
    if not item then
        return nil
    end
    return list_renderer.render_item(item)
end

return KoStabber
