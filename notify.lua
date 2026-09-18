local notify = {}

function notify.show(message)
    local ok, Notification = pcall(require, "ui/widget/notification")
    if not ok or not Notification then
        return false
    end
    local ok_mgr, UIManager = pcall(require, "ui/uimanager")
    if not ok_mgr or not UIManager or not UIManager.show then
        return false
    end

    local n = Notification:new({ text = message, timeout = 2 })
    UIManager:show(n)
    return true
end

return notify
