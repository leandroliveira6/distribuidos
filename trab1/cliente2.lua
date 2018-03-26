-- Importa a biblioteca e conecta-se ao servidor na porta 1234 do IP local
local socket = require('socket')

local tempos = {}
local servidor = socket.connect('*',1234)
--print("Conectou-se ao servidor...")
for i=1, 20 do
    tempos[i] = socket.gettime()
        
    -- Envia mensagens ao servidor
    servidor:send("Solicitando uma string"..'\n')
    
    -- Determina um tempo máximo de espera
    servidor:settimeout(5)
    
    -- Aguarda a resposta do servidor
    local response, status = servidor:receive()
    if status ~= 'closed' and status ~= 'timeout' then
        --print("Resposta recebida: " .. response)
    end

    tempos[i] = socket.gettime() - tempos[i]
end

-- Fecha a conexão com o servidor
print("Fechando a conexão...")
servidor:close()

arquivo = io.open("cliente2_tempos", "w")
for i=1, #tempos do
    arquivo:write(tempos[i] .. '\n')
end
