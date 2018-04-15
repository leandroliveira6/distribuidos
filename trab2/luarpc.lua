local socket = require('socket')
local servants = {}



--[[ Atributos de controle da aplicação ]]
local tempo_servants = 1
local tempo_de_espera = 5
local protocolo = '\\:-)\\'



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
                return nil, '__ERRORPC: Tipos dos valores incompativeis!'
            end
        end
    else
        return nil, '__ERRORPC: Numero de valores incompativeis!'
    end
    return true
end

--[[ Método responsavel por transformar dados em string
    - metodo: Nome do metodo ou qualquer outra string que se deseja passar como primeira parte da mensagem
    - parametros: Tabela contendo todos os dados de parametros ou resultados
    - return: Uma string pronta para ser enviada para algum lugar
]]
local empacotar = function(metodo, parametros)
    pacote = metodo .. protocolo
    for i=1,#parametros do
        pacote = pacote .. parametros[i] .. protocolo
    end
    return pacote..'\n'
end

--[[ Método responsavel por transformar string em dados string, tendo que ser convertido caso se queira executar ações
    - pacote: String contendo todos os dados
    - return: Uma tabela de strings
]]
local desempacotar = function(pacote)
    local desempacote = {}
    for str in string.gmatch(pacote, '([^'..protocolo..']+)') do
        if str ~= ':-)' and str ~= '\n' then
            table.insert(desempacote, str)
        end
    end
    return desempacote
end

--[[ Método responsavel por converter valores em seus respectivos tipos
    - valores: Valores a serem convertidos
    - tipos: Tipos para os valores serem convertidos
    - return: Uma tabela contendo os valores convertidos ou nil caso haja algum problema
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
    return nil
end 

--[[ Método responsavel por executar um metodo no servidor
    - raw_request: String contendo os dados decessarios para se executar um metodo
    - servant: Servant contendo todos os atributos necessarios para se executar um metodo
    - return: Uma tabela com os resultados convertidos ou nil caso haja algum problema
]]
local executar = function(raw_request, servant)
	local request = desempacotar(raw_request)
	local metodos = servant.interface.methods
	if request and metodos[request[1]] then
		local metodo = table.remove(request, 1)
		local tipos_parametros, tipos_resultados = obtem_tipos(metodos[metodo])
		local parametros = converter(request, tipos_parametros)
		local resultados = table.pack(servant.objeto[metodo](unpack(parametros)))
		return converter(resultados, tipos_resultados)
	end
	return nil
end



-- Funções publicas
local createServant = function(objeto, interface)
	servant = {
		objeto = objeto,
		interface = interface,
		servidor = socket.bind('*', 0)
	}
	table.insert(servants, servant)
	return servant.servidor:getsockname()
end

local waitIncoming = function()
	while true do
		for i=1, #servants do
			servants[i].servidor:settimeout(tempo_servants)
			local cliente = servants[i].servidor:accept()
			if cliente then
				cliente:settimeout(tempo_de_espera)
				local request = cliente:receive()
				if request then
					local resultados = executar(request, servants[i])
					local resultado, outros = resultados[1], table.pack(unpack(resultados,2))
					cliente:send(empacotar(resultado, outros)..'\n')
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
                    local request = empacotar(k, parametros)
                    local resultados = ''
                    servidor:send(request)
                    servidor:settimeout(tempo_de_espera)
                    local resultados = servidor:receive()
                    if resultados then
                        local desempacote = desempacotar(resultados)
                        resultados = converter(desempacote, tipos_resultados)
                    end
                    servidor:close()
                    return unpack(resultados)
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



--[[ Testes ]]
local testes = function()
    local imprime_tabela = function(tabela)
	    for k, v in pairs(tabela) do
		    print(k, v, type(v))
	    end
	    print()
    end
    local interface = {
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
                args = {
                    {direction = "inout", type = "double"}
                }
            }
        }
    }
    local obj = {
	    foo = function (a, b, s) return a+b, "alo alo" end,
	    boo = function (n) print('n', n) return n end
    }
    local parametros, resultados
    
    print('metodos privados')
    print('testes do metodo obtem_tipos')
    for k, v in pairs(interface.methods) do
        print(k)
        parametros, resultados = obtem_tipos(v)
        print('parametros')
        imprime_tabela(parametros)
        print('resultados')
        imprime_tabela(resultados)
    end
    
    print('testes do metodo validador')
    print('foo')
    parametros, resultados = obtem_tipos(interface.methods.foo)
    print('parametros', validador({2,4}, parametros), '(true esperado)')
    print('parametros', validador({5.4,2}, parametros), '(true esperado)')
    print('parametros', validador({2,4,3}, parametros), '(nil esperado)')
    print('parametros', validador({8.8}, parametros), '(nil esperado)')
    print('parametros', validador({6, 'asd'}, parametros), '(nil esperado)')
    print()
    
    print('boo')
    parametros, resultados = obtem_tipos(interface.methods.boo)
    print('parametros', validador({2}, parametros), '(true esperado)')
    print('parametros', validador({5.4}, parametros), '(true esperado)')
    print('parametros', validador({2,4}, parametros), '(nil esperado)')
    print('parametros', validador({'asd'}, parametros), '(nil esperado)')
    print()
    
    print('testes do metodo empacotar')
    local pacote = empacotar('foo', {12,54})
    print(pacote)
    print()
    
    print('testes do metodo desempacotar')
    local desempacote = desempacotar(pacote)
    imprime_tabela(desempacote)
    
    print('testes do metodo converter')
    imprime_tabela(converter(desempacote, {'string', 'number', 'number'}))
    
    print('metodos publicos')
    local ip, porta = createServant(obj, interface)
    
    print('testes do metodo executar')
    resultados = executar(pacote, servants[1])
    imprime_tabela(resultados)
    
    print('testes do metodo createProxy')
    local proxy = createProxy(ip, porta, interface)
    imprime_tabela(proxy)
end
--testes()



return {createServant = createServant, waitIncoming = waitIncoming, createProxy = createProxy}
