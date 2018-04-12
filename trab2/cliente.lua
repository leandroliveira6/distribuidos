-- Importa a biblioteca
local socket = require('socket')

local servidor = socket.connect('*',1234)
servidor:send('foo, 3, 2, 1'..'\n')
servidor:settimeout(5)    
local response, status = servidor:receive()
servidor:close()
print(response, status)

servidor = socket.connect('*',1234)
servidor:send('boo, 654'..'\n')
servidor:settimeout(5)    
local response, status = servidor:receive()
servidor:close()
print(response, status)
