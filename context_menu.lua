local storage = require("storage")
local opds = require("opds")

local context_menu = {}

function context_menu.actions_for_stub(stub_path)
    return {
        {
            id = "remove_local_asset",
            text = "Rimuovi asset locale",
            run = function()
                return storage.remove_local_asset(stub_path)
            end,
        },
        {
            id = "force_sync",
            text = "Forza sync metadati/progress",
            run = function()
                return opds.initial_index_all()
            end,
        },
        {
            id = "change_storage_strategy",
            text = "Cambia strategia storage",
            run = function(policy)
                storage.set_policy(policy)
                return true
            end,
        },
    }
end

return context_menu
