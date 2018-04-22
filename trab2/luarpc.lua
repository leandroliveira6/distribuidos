local socket = require('socket')
local servants = {}
local binds = {}



--[[ Atributos de controle da aplicação ]]
local tempo_servants = 1
local tempo_de_espera = 5
local quebra_linha = '\\:-)\\'



-- Métodos privados
--[[ Método responsavel por traduzir os tipos de interface para os tipos de lua
    - tipo: O tipo da interface
    - return: O respectivo tipo em lua
]]
local traduz_tipo = function(tipo)
    traducao = 'nil'
    if tipo == 'double' then
		traducao = 'number'
	elseif tipo == 'char' or tipo == 'string' then
		traducao = 'string'
	end
	return traducao
end

--[[ Método responsavel por organizar os tipos de um metodo em tipos de resultados e tipos de parametros
    - metodo: Metodo da interface, contendo apenas seus dados
    - return: Uma tabela de tipos de parametros e outra de tipos de resultados
]]
local obtem_tipos = function(metodo)
    resultados = {}
    parametros = {}
    
    -- adiciona o tipo do resultado principal na tabela, sendo nil o tipo de resultado de void
    table.insert(resultados, traduz_tipo(metodo.resulttype))
    
    -- itera por todos os args e adiciona seus tipos nas respectivas tabelas
    for i=1, #metodo.args do
        if metodo.args[i].direction == 'in' then
            table.insert(parametros, traduz_tipo(metodo.args[i].type))
        elseif metodo.args[i].direction == 'out' then
            table.insert(resultados, traduz_tipo(metodo.args[i].type))
        else -- inout
            tipo = traduz_tipo(metodo.args[i].type)
            table.insert(parametros, tipo)
            table.insert(resultados, tipo)
        end
    end
    
    return parametros, resultados
end

--[[ Método responsavel por verificar se os tipos passados equivalem aos tipos da interface
    - valores: Tabela contendo todos os valores passados
    - tipos: Tabela contendo todos os tipos
    - return: true caso todos os valores estiverem certos ou uma string de erro caso contrario
]]
local validador = function(valores, tipos)
    if #valores == #tipos then
        for i=1,#valores do
            if type(valores[i]) ~= tipos[i] then
                return nil, '__ERRORPC: Tipos dos valores incompativeis!\n'
            end
        end
    else
        return nil, '__ERRORPC: Numero de valores incompativeis!\n'
    end
    return true
end

--[[ Método responsavel por transformar dados em uma lista de strings
    - metodo: Nome do metodo ou qualquer outra string que se deseja passar como primeira parte da mensagem
    - parametros: Tabela contendo todos os dados de parametros ou resultados
    - return: Uma lista de strings pronta para ser enviada para algum lugar
]]
local empacotar = function(metodo, parametros)
    pacote = {' \n'}
    table.insert(pacote, metodo .. '\n')
    for i=1,#parametros do
        table.insert(pacote, parametros[i] .. '\n')
    end
    return pacote
end

--[[ Método responsavel por transformar uma lista de strings em dados
    - conexao: Conexao para recebimento dos parametros ou resultados
    - itens: Lista contendo os tipos de entrada ou saida, usado para determinar a quantidade de iterações com o 'outro lado'
    - return: Uma lista com os parametros ou resultados
]]
local desempacotar = function(conexao, itens)
    local desempacote = {}
    if conexao and itens then
        for i=1,#itens do
            local item = conexao:receive()
            table.insert(desempacote, item)
        end
    end
    return desempacote
end

--[[ Metodo responsavel unicamente por concatenar os resultados convertidos separados por \n
     desempacote: Tabela contendo todos os resultados
     return: String dos valores separados por \n
]]
local obtem_saida = function(desempacote)
    return table.concat(desempacote, '\n')
end

--[[ Método responsavel por converter valores em seus respectivos tipos
    - valores: Valores a serem convertidos
    - tipos: Tipos para os valores serem convertidos
    - return: Uma tabela contendo os valores convertidos ou uma mensagem de erro
]]
local converter = function(valores, tipos)
    if tipos[1] == 'nil' and #valores+1 == #tipos then
        table.insert(valores, 1, 'nil')
    end
    if #valores == #tipos then
        local new_valores = {}
        for i=1,#tipos do
            if tipos[i] == 'number' then
                table.insert(new_valores, tonumber(valores[i]))
            elseif tipos[i] == 'nil' then
                table.insert(new_valores, 'nil')
            else
                table.insert(new_valores, valores[i])
            end
        end
        return new_valores
    end
    return '__ERRORPC: Problemas na conversão, tipos incompativeis!\n'
end 

--[[ Método responsavel por executar um metodo no servidor
    - metodo: Método que se deseja executar uma ação
    - request: Lista de strings contendo os dados decessarios para se executar o metodo
    - servant: Servant contendo todos os atributos necessarios para se executar o metodo
    - return: Uma tabela com os resultados convertidos ou uma mensagem de erro
]]
local executar = function(metodo, request, servant)
	local tipos = servant.tipos[metodo]
	if request and tipos then
		local parametros = converter(request, tipos['in'])
		local resultados = table.pack(servant.objeto[metodo](unpack(parametros)))
		return converter(resultados, tipos['out'])
	end
	return '__ERRORPC: Metodo inexistente!\n'
end

-- Funções publicas
local createServant = function(objeto, interface)
    local servidor = socket.bind('*', 0)
    local tipos = {}
    for k, v in pairs(interface.methods) do
        local tipos_parametros, tipos_resultados = obtem_tipos(v)
        tipos[k] = {}
        tipos[k]['in'] = tipos_parametros
        tipos[k]['out'] = tipos_resultados
    end
	servants[servidor] = {
		objeto = objeto,
		interface = interface,
		tipos = tipos
	}
	table.insert(binds, servidor)
	return servidor:getsockname()
end

local waitIncoming = function()
	while true do
		local conexoes = socket.select(binds, nil, tempo_servants)
		for _, conexao in ipairs(conexoes) do
		    if servants[conexao] then
			    local cliente = conexao:accept()
			    local request = cliente:receive()
			    if request then
			        local metodo = cliente:receive()
			        local desempacote = desempacotar(cliente, servants[conexao].tipos[metodo]['in'])
				    local resultados = executar(metodo, desempacote, servants[conexao])
				    if type(resultados) ~= 'string' then
				        local resultado, outros = resultados[1], table.pack(unpack(resultados,2))
				        local pacote = empacotar(resultado, outros)
				        for i=1,#pacote do
				            cliente:send(pacote[i])
				        end
				    else
				        cliente:send(resultados)
				    end
			    end
			    cliente:close()
	        end
		end					
	end
end

local createProxy = function(ip, porta, interface)
    local ip = ip
    local porta = porta
    local proxy = {}
    for k,v in pairs(interface.methods) do
        local tipos_parametros, tipos_resultados = obtem_tipos(v)
        proxy[k] = function(...)
            local parametros = {...}
            local valido, erro = validador(parametros, tipos_parametros)
            if valido then
                local servidor = socket.connect(ip,porta)
                if servidor then
                    local pacote = empacotar(k, parametros)
                    local resultados = ''
                    local response = ''
                    for i=1,#pacote do
					    servidor:send(pacote[i])
					end
                    servidor:settimeout(tempo_de_espera)
                    response = servidor:receive()
				    if response then
				        local desempacote = desempacotar(servidor, tipos_resultados)
				        resultados = converter(desempacote, tipos_resultados)
				        resultados = obtem_saida(resultados)
				    end
                    servidor:close()
                    return resultados
                else
                    return '__ERRORPC: Servidor offline!'
                end
            else
                return erro
            end
        end
    end
    return proxy
end

return {createServant = createServant, waitIncoming = waitIncoming, createProxy = createProxy}
