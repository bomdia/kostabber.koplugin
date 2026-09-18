local util = {}
local JSON_NULL = {}
local PARSE_ERROR = {}
util.json_null = JSON_NULL

local function path_sep()
    return package.config:sub(1, 1)
end

function util.join(...)
    local sep = path_sep()
    local parts = { ... }
    local out = {}
    for _, part in ipairs(parts) do
        if part and part ~= "" then
            out[#out + 1] = tostring(part):gsub(sep .. "+$", "")
        end
    end
    return table.concat(out, sep)
end

function util.file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

function util.read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    return data
end

function util.write_file(path, content)
    local f, err = io.open(path, "wb")
    if not f then
        return nil, err
    end
    f:write(content)
    f:close()
    return true
end

function util.shell_quote(s)
    s = tostring(s or "")
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

function util.mkdir_p(path)
    if not path or path == "" then
        return true
    end
    util.command_success("mkdir -p " .. util.shell_quote(path))
    return true
end

function util.now()
    return os.time()
end

function util.command_success(cmd)
    local a, b, c = os.execute(cmd)
    if type(a) == "number" then
        return a == 0, a, b, c
    end
    if type(a) == "boolean" then
        if b == "exit" then
            return a and c == 0, a, b, c
        end
        return a, a, b, c
    end
    return false, a, b, c
end

function util.sha1_like(input)
    local hash = 5381
    for i = 1, #input do
        hash = (hash * 33 + string.byte(input, i)) % 4294967296
    end
    return string.format("%08x", hash)
end

local function escape_lua_string(value)
    return string.format("%q", tostring(value))
end

local function is_array(tbl)
    local n = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        n = n + 1
    end
    return #tbl == n
end

local function serialize_value(value, depth)
    depth = depth or 0
    local indent = string.rep("    ", depth)
    local next_indent = string.rep("    ", depth + 1)
    local t = type(value)

    if t == "nil" then
        return "nil"
    elseif t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "nil"
        end
        return tostring(value)
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return escape_lua_string(value)
    elseif t == "table" then
        local parts = { "{" }
        if is_array(value) then
            for _, item in ipairs(value) do
                parts[#parts + 1] = "\n" .. next_indent .. serialize_value(item, depth + 1) .. ","
            end
        else
            local keys = {}
            for k, _ in pairs(value) do
                keys[#keys + 1] = k
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local key_repr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key_repr = k
                else
                    key_repr = "[" .. serialize_value(k, depth + 1) .. "]"
                end
                parts[#parts + 1] = "\n" .. next_indent .. key_repr .. " = " .. serialize_value(value[k], depth + 1) .. ","
            end
        end
        if #parts > 1 then
            parts[#parts + 1] = "\n" .. indent
        end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    end
    return "nil"
end

function util.save_lua_table(path, tbl)
    return util.write_file(path, "return " .. serialize_value(tbl) .. "\n")
end

function util.load_lua_table(path, fallback)
    if not util.file_exists(path) then
        return fallback
    end
    local content = util.read_file(path)
    if not content then
        return fallback
    end
    if #content > 1024 * 1024 then
        return fallback, "unsafe_file_size"
    end
    if not content:match("^%s*return%s*{") then
        return fallback, "unsafe_prefix"
    end
    local chunk
    local err
    if _VERSION == "Lua 5.1" then
        chunk, err = loadstring(content, "@" .. path)
        if chunk and setfenv then
            setfenv(chunk, {})
        else
            return fallback, "unsafe_runtime"
        end
    else
        chunk, err = load(content, "@" .. path, "t", {})
    end
    if not chunk then
        return fallback, err
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return fallback, result
    end
    return result
end

local function json_escape(s)
    return s:gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then
            return '\\"'
        elseif c == '\\' then
            return '\\\\'
        elseif c == '\b' then
            return '\\b'
        elseif c == '\f' then
            return '\\f'
        elseif c == '\n' then
            return '\\n'
        elseif c == '\r' then
            return '\\r'
        elseif c == '\t' then
            return '\\t'
        end
        return string.format('\\u%04x', c:byte())
    end)
end

function util.json_encode(value)
    if value == JSON_NULL then
        return "null"
    end
    local t = type(value)
    if t == "nil" then
        return "null"
    elseif t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        return tostring(value)
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return '"' .. json_escape(value) .. '"'
    elseif t == "table" then
        if is_array(value) then
            local parts = {}
            for _, v in ipairs(value) do
                parts[#parts + 1] = util.json_encode(v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = util.json_encode(tostring(k)) .. ":" .. util.json_encode(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

function util.json_decode(text)
    if not text or text == "" then
        return nil
    end
    local ok_dk, dkjson = pcall(require, "dkjson")
    if ok_dk and dkjson and dkjson.decode then
        return dkjson.decode(text)
    end

    local i = 1
    local len = #text

    local function skip_ws()
        while i <= len and text:sub(i, i):match("%s") do
            i = i + 1
        end
    end

    local parse_value

    local function parse_string()
        i = i + 1
        local out = {}
        while i <= len do
            local c = text:sub(i, i)
            if c == '"' then
                i = i + 1
                return table.concat(out)
            elseif c == "\\" then
                local esc = text:sub(i + 1, i + 1)
                local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if map[esc] then
                    out[#out + 1] = map[esc]
                    i = i + 2
                elseif esc == "u" then
                    local hex = text:sub(i + 2, i + 5)
                    if not hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
                        return PARSE_ERROR
                    end
                    local cp = tonumber(hex, 16)
                    local advance = 6
                    if cp >= 0xD800 and cp <= 0xDBFF and text:sub(i + 6, i + 7) == "\\u" then
                        local hex2 = text:sub(i + 8, i + 11)
                        if hex2:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
                            local cp2 = tonumber(hex2, 16)
                            if cp2 >= 0xDC00 and cp2 <= 0xDFFF then
                                cp = 0x10000 + ((cp - 0xD800) * 0x400) + (cp2 - 0xDC00)
                                advance = 12
                            end
                        end
                    end
                    if cp <= 0x7F then
                        out[#out + 1] = string.char(cp)
                    elseif cp <= 0x7FF then
                        local b1 = 0xC0 + math.floor(cp / 0x40)
                        local b2 = 0x80 + (cp % 0x40)
                        out[#out + 1] = string.char(b1, b2)
                    elseif cp <= 0xFFFF then
                        local b1 = 0xE0 + math.floor(cp / 0x1000)
                        local b2 = 0x80 + (math.floor(cp / 0x40) % 0x40)
                        local b3 = 0x80 + (cp % 0x40)
                        out[#out + 1] = string.char(b1, b2, b3)
                    else
                        local b1 = 0xF0 + math.floor(cp / 0x40000)
                        local b2 = 0x80 + (math.floor(cp / 0x1000) % 0x40)
                        local b3 = 0x80 + (math.floor(cp / 0x40) % 0x40)
                        local b4 = 0x80 + (cp % 0x40)
                        out[#out + 1] = string.char(b1, b2, b3, b4)
                    end
                    i = i + advance
                else
                    return PARSE_ERROR
                end
            else
                if c:byte() < 32 then
                    return PARSE_ERROR
                end
                out[#out + 1] = c
                i = i + 1
            end
        end
        return PARSE_ERROR
    end

    local function parse_number()
        local start_i = i
        local function current_char()
            return text:sub(i, i)
        end

        if current_char() == "-" then
            i = i + 1
        end

        local first = current_char()
        if first == "0" then
            i = i + 1
            if current_char():match("^%d$") then
                return PARSE_ERROR
            end
        elseif first:match("^[1-9]$") then
            i = i + 1
            while current_char():match("^%d$") do
                i = i + 1
            end
        else
            return PARSE_ERROR
        end

        if current_char() == "." then
            i = i + 1
            if not current_char():match("^%d$") then
                return PARSE_ERROR
            end
            while current_char():match("^%d$") do
                i = i + 1
            end
        end

        if current_char() == "e" or current_char() == "E" then
            i = i + 1
            if current_char() == "+" or current_char() == "-" then
                i = i + 1
            end
            if not current_char():match("^%d$") then
                return PARSE_ERROR
            end
            while current_char():match("^%d$") do
                i = i + 1
            end
        end

        local token = text:sub(start_i, i - 1)
        local n = tonumber(token)
        if n == nil then
            return PARSE_ERROR
        end
        return n
    end

    local function parse_array()
        i = i + 1
        skip_ws()
        local arr = {}
        if text:sub(i, i) == "]" then
            i = i + 1
            return arr
        end
        while i <= len do
            local v = parse_value()
            if v == PARSE_ERROR then
                return PARSE_ERROR
            end
            arr[#arr + 1] = v
            skip_ws()
            local c = text:sub(i, i)
            if c == "]" then
                i = i + 1
                return arr
            elseif c == "," then
                i = i + 1
            else
                return PARSE_ERROR
            end
            skip_ws()
        end
        return PARSE_ERROR
    end

    local function parse_object()
        i = i + 1
        skip_ws()
        local obj = {}
        if text:sub(i, i) == "}" then
            i = i + 1
            return obj
        end
        while i <= len do
            if text:sub(i, i) ~= '"' then
                return PARSE_ERROR
            end
            local key = parse_string()
            if key == PARSE_ERROR then
                return PARSE_ERROR
            end
            skip_ws()
            if text:sub(i, i) ~= ":" then
                return PARSE_ERROR
            end
            i = i + 1
            skip_ws()
            local parsed = parse_value()
            if parsed == PARSE_ERROR then
                return PARSE_ERROR
            end
            obj[key] = parsed
            skip_ws()
            local c = text:sub(i, i)
            if c == "}" then
                i = i + 1
                return obj
            elseif c == "," then
                i = i + 1
            else
                return PARSE_ERROR
            end
            skip_ws()
        end
        return PARSE_ERROR
    end

    function parse_value()
        skip_ws()
        local c = text:sub(i, i)
        if c == '"' then
            return parse_string()
        elseif c == "{" then
            return parse_object()
        elseif c == "[" then
            return parse_array()
        elseif c:match("[%d%-]") then
            return parse_number()
        elseif text:sub(i, i + 3) == "true" then
            i = i + 4
            return true
        elseif text:sub(i, i + 4) == "false" then
            i = i + 5
            return false
        elseif text:sub(i, i + 3) == "null" then
            i = i + 4
            return JSON_NULL
        end
        return PARSE_ERROR
    end

    local value = parse_value()
    if value == PARSE_ERROR then
        return nil
    end
    skip_ws()
    if i <= len then
        return nil
    end
    return value
end

return util
