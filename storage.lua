local util = require("util")
local paths = require("paths")
local stub = require("stub")

local storage = {}

storage.policy = {
    none = "none",
    manual_unlimited = "manual_unlimited",
    fifo_cap = "fifo_cap",
    smart_inactivity = "smart_inactivity",
}

local DEFAULT_LEDGER = {
    policy = storage.policy.manual_unlimited,
    fifo_cap = 50,
    inactivity_days = 30,
    max_assets = 200,
    items = {},
}

local function load_ledger()
    paths.ensure()
    local raw = util.read_file(paths.storage_ledger)
    local ledger = raw and util.json_decode(raw) or nil
    if type(ledger) ~= "table" then
        ledger = {}
    end
    for k, v in pairs(DEFAULT_LEDGER) do
        if k ~= "items" and ledger[k] == nil then
            ledger[k] = v
        end
    end
    if type(ledger.items) ~= "table" then
        ledger.items = {}
    end
    return ledger
end

local function save_ledger(ledger)
    return util.write_file(paths.storage_ledger, util.json_encode(ledger))
end

function storage.get_policy()
    return load_ledger().policy
end

function storage.set_policy(policy_name)
    if policy_name ~= storage.policy.none
        and policy_name ~= storage.policy.manual_unlimited
        and policy_name ~= storage.policy.fifo_cap
        and policy_name ~= storage.policy.smart_inactivity then
        return nil, "invalid_policy"
    end
    local ledger = load_ledger()
    ledger.policy = policy_name
    save_ledger(ledger)
    return true
end

function storage.record_access(stub_hash)
    local ledger = load_ledger()
    ledger.items[stub_hash] = util.now()
    save_ledger(ledger)
end

local function remove_local_asset(stub_path, item)
    if item.local_asset_path and util.file_exists(item.local_asset_path) then
        os.remove(item.local_asset_path)
    end
    item.local_asset_path = nil
    stub.save(stub_path, item)
end

local function should_remove_smart(ledger, last_access)
    local inactive_seconds = (ledger.inactivity_days or 30) * 24 * 3600
    return (util.now() - (last_access or 0)) > inactive_seconds
end

function storage.evict_if_needed(stub_files)
    local ledger = load_ledger()
    local policy = ledger.policy
    if policy == storage.policy.manual_unlimited then
        return
    end

    local entries = {}
    for _, stub_path in ipairs(stub_files or {}) do
        local item = stub.load(stub_path)
        if item and item.hash and item.local_asset_path then
            entries[#entries + 1] = {
                path = stub_path,
                item = item,
                last_access = ledger.items[item.hash] or item.last_access_ts or 0,
            }
        end
    end

    if policy == storage.policy.none then
        for _, e in ipairs(entries) do
            remove_local_asset(e.path, e.item)
        end
        return
    end

    table.sort(entries, function(a, b)
        return a.last_access < b.last_access
    end)

    if policy == storage.policy.fifo_cap then
        local cap = tonumber(ledger.fifo_cap) or 50
        while #entries > cap do
            local evict = table.remove(entries, 1)
            remove_local_asset(evict.path, evict.item)
        end
        return
    end

    if policy == storage.policy.smart_inactivity then
        local max_assets = tonumber(ledger.max_assets) or 200
        local kept = {}
        for _, e in ipairs(entries) do
            if should_remove_smart(ledger, e.last_access) then
                remove_local_asset(e.path, e.item)
            else
                kept[#kept + 1] = e
            end
        end
        while #kept > max_assets do
            local evict = table.remove(kept, 1)
            remove_local_asset(evict.path, evict.item)
        end
    end
end

function storage.remove_local_asset(stub_path)
    local item = stub.load(stub_path)
    if not item then
        return nil, "stub_not_found"
    end
    remove_local_asset(stub_path, item)
    return true
end

return storage
