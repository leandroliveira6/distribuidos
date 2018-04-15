local luarpc = require('luarpc')
local interface = require('interface')
local proxy = luarpc.createProxy('*', 42299, interface)
print(proxy.foo(2,56))
