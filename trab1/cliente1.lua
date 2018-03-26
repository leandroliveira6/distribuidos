-- Importa a biblioteca
local socket = require('socket')

local tempos = {}
for i=1, 20 do
    tempos[i] = socket.gettime()
    
    -- Conecta-se ao servidor na porta 1234 do IP local
    --print('Aguardando um servidor...')
    local servidor = socket.connect('*',1234)
    --print('Cliente conectado, enviando mensagens...')
    
    -- Envia mensagens ao servidor
    servidor:send("Solicitando uma string"..'\n')
    
    -- Determina um tempo máximo de espera
    servidor:settimeout(5)
    
    -- Aguarda a resposta do servidor
    local response, status = servidor:receive()
    if status ~= 'closed' and status ~= 'timeout' then
        --print("Resposta recebida: " .. response)
    end
    
    -- Fecha a conexão com o servidor
    --print("Fechando a conexão...")
    servidor:close()
    tempos[i] = socket.gettime() - tempos[i]
end

arquivo = io.open("cliente1_tempos", "w")
for i=1, #tempos do
    arquivo:write(tempos[i] .. '\n')
end
