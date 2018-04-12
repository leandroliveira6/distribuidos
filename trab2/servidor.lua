local luarpc = require('luarpc')

local interface = {
	name = 'minhaInt',
	methods = {
		foo = {
			resulttype = "double",
			args = {
				{direction = "in", type = "double"},
				{direction = "in", type = "double"},
				{direction = "out", type = "string"}
			}
		},
        boo = {
        	resulttype = "void",
        	args = {{
        		direction = "inout", type = "double"}
        	}
        }
	}
}

myobj1 = {
	foo = function (a, b, s) return a+b, "alo alo" end,
	boo = function (n) print('n', n) return n end
}

ip, porta = luarpc.createServant(myobj1, interface)
print(ip, porta)
luarpc.waitIncoming()


