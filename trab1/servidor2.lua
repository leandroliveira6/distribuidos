-- Importa a biblioteca e libera a porta 1234 do IP local para conexões
local socket = require('socket')
local host = socket.bind('*',1234)

-- Aguarda conexões de clientes
print("Aguardando um cliente...")
local cliente = host:accept()
--print('Um cliente se conectou, recebendo mensagens...')

local tempos = {}
for i=1, 20 do
    tempos[i] = socket.gettime()
    
    -- Determina um tempo máximo de espera
    cliente:settimeout(5)
        
    -- Aguarda mensagens do cliente
    local request, status = cliente:receive()
    if status ~= 'closed' and status ~= 'timeout' then
        --print("Mensagem recebida: " .. request)
            
        -- Enviando a string solicitada
        --print("Respondendo a mensagem...")
        cliente:send(request .. '\n')            
    end
    
    tempos[i] = socket.gettime() - tempos[i]
end

-- Fecha a conexão com o cliente
print("Fechando a conexão...")
cliente:close()

arquivo = io.open("servidor2_tempos", "w")
for i=1, #tempos do
    arquivo:write(tempos[i] .. '\n')
end
