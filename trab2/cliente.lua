local luarpc = require('luarpc')
local interface = require('interface')
local proxy = luarpc.createProxy('*', 41003, interface)
print(proxy.foo(2,3))
