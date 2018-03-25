local socket = require('socket') -- sempre o require
local host = socket.bind('*',1234)
print('Aguardando uma conexao!')
local user = host:accept()
print('Alguem se conectou! aguardando dados')
while true do
    local mensagem, status = user:receive()
    if status == 'closed' then
       break
    end
    print(mensagem)
    user:send(io.read()..'\n')
end
