local socket = require('socket') -- sempre o require
local servidor = socket.connect('localhost',1234)
if servidor then
    print('Conectado')
else 
    print('offline')
    os.exit()
end
print('Escreva algo')
local espera = false
repeat
    if not espera then
        servidor:send(io.read()..'\n')
    end
    espera = true
    servidor:settimeout(5)
    local mensagem, status = servidor:receive()
    if status == 'closed' then
       break
    end
    if mensagem then
        espera = false
        print(mensagem)
    end
until not servidor
