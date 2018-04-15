local luarpc = require('luarpc')
local interface = require('interface')
local proxy = luarpc.createProxy('*', 46625, interface)
print(proxy.boo(256))
