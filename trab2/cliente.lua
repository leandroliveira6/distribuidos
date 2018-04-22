local luarpc = require('luarpc')
local interface = require('interface')
local proxy = luarpc.createProxy('*', 33929, interface)
print(proxy.foo(10, 6))
