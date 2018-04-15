local luarpc = require('luarpc')
local interface = require('interface')

myobj1 = {
	foo = function (a, b, s) return a+b, "alo alo" end,
	boo = function (n) return n end
}

myobj2 = { 
    foo = function (a, b, s) return a-b, "tchau" end,
    boo = function (n) return 1 end
}

ip, porta = luarpc.createServant(myobj1, interface)
print(ip, porta)
ip, porta = luarpc.createServant(myobj2, interface)
print(ip, porta)
luarpc.waitIncoming()


