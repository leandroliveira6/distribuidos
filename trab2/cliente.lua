local luarpc = require('luarpc')
local interface = require('interface')
local proxy = luarpc.createProxy('*', 38471, interface)
print(proxy.foo(2,8))
