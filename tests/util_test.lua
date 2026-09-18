package.path = '../?.lua;./?.lua;' .. package.path

local util = require('util')
local base = '/tmp/kostabber-util-test'
util.command_success('rm -rf ' .. util.shell_quote(base))
util.mkdir_p(base)

local bad = base .. '/bad.json'
util.write_file(bad, '{bad json')
local fallback = { ok = true }
local loaded_bad = util.load_json_table(bad, fallback)
assert(loaded_bad == fallback)

local scalar = base .. '/scalar.json'
util.write_file(scalar, '42')
local loaded_scalar = util.load_json_table(scalar, fallback)
assert(loaded_scalar == fallback)

local obj = base .. '/obj.json'
util.write_file(obj, '{"a":1}')
local loaded_obj = util.load_json_table(obj, fallback)
assert(type(loaded_obj) == 'table' and loaded_obj.a == 1)

print('util tests passed')
