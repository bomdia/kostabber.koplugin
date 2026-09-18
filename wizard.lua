local sources = require("sources")
local opds = require("opds")

local wizard = {}

local function ui_dialog_add_sources(callback)
    local ok_input, InputDialog = pcall(require, "ui/widget/inputdialog")
    if not ok_input or not InputDialog then
        return false
    end

    local name, url
    local dialog
    dialog = InputDialog:new({
        title = "KoStabber: nuova sorgente OPDS",
        input = "",
        description = "Inserisci una sorgente per riga: Nome|URL",
        buttons = {
            {
                {
                    text = "Salva",
                    callback = function()
                        local raw = dialog:getInputText() or ""
                        local list = {}
                        for line in raw:gmatch("[^\r\n]+") do
                            name, url = line:match("^%s*(.-)%s*|%s*(.-)%s*$")
                            if name and url and name ~= "" and url ~= "" then
                                list[#list + 1] = { name = name, url = url }
                            end
                        end
                        callback(list)
                    end,
                },
            },
        },
    })

    local ok_mgr, UIManager = pcall(require, "ui/uimanager")
    if ok_mgr and UIManager and UIManager.show then
        UIManager:show(dialog)
    end
    return true
end

local function apply_sources(new_sources, should_test_connection)
    local valid = {}
    for _, src in ipairs(new_sources or {}) do
        if src.name and src.url and src.name ~= "" and src.url ~= "" then
            if should_test_connection then
                local ok = sources.test_connection(src.url)
                if ok then
                    valid[#valid + 1] = src
                end
            else
                valid[#valid + 1] = src
            end
        end
    end
    sources.save(valid)
    return valid
end

function wizard.run_first_time(on_finished)
    local done = false
    local function finish()
        if done then
            return
        end
        done = true
        opds.initial_index_all()
        if on_finished then
            on_finished()
        end
    end

    local shown = ui_dialog_add_sources(function(list)
        apply_sources(list, false)
        finish()
    end)

    if not shown then
        finish()
    end
end

function wizard.configure_sources(list, test_connection)
    local valid = apply_sources(list, test_connection)
    local indexed = opds.initial_index_all()
    return valid, indexed
end

return wizard
