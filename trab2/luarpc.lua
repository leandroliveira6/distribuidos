local socket = require('socket')
local servants = {}

local tempo_servants = 1
local tempo_de_espera = 5

--[[ Métodos privados ]]
local traduz_tipo = function(tipo)
    traducao = 'nil'
    if tipo == 'double' then
		traducao = 'number'
	elseif tipo == 'char' or tipo == 'string' then
		traducao = 'string'
	end
	return traducao
end

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

local empacotar = function(metodo, parametros)
    pacote = metodo .. '\\:-)\\'
    for i=1,#parametros do
        pacote = pacote .. parametros[i] .. '\\:-)\\'
    end
    return pacote..'\n'
end

local desempacotar = function(pacote)
    local desempacote = {}
    for str in string.gmatch(pacote, '([^\\:-)\\]+)') do
        if str ~= ':-)' and str ~= '\n' then
            table.insert(desempacote, str)
        end
    end
    return desempacote
end

local converter = function(valores, tipos)
    if #valores == #tipos then
        for i=1,#valores do
            if tipos[i] == 'number' then
                valores[i] = tonumber(valores[i])
            elseif tipos[i] == 'nil' then
                valores[i] = nil
            end
        end
        return valores
    end
    return nil
end

local executar = function(raw_request, servant)
	local request = desempacotar(raw_request)
	local metodos = servant.interface.methods
	if request and metodos[request[1]] then
		local metodo = table.remove(request, 1)
		local tipos_parametros, tipos_resultados = obtem_tipos(metodos[metodo])
		local parametros = converter(request, tipos_parametros)
		return table.pack(servant.objeto[metodo](unpack(parametros)))
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
					local resultado, outros = resultados[1], table.pack(table.unpack(resultados,2))
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
                    servidor:send(request)
                    servidor:settimeout(tempo_de_espera)
                    local resultados = servidor:receive()
                    if resultados then
                        resultados = desempacotar(resultados)
                    end
                    servidor:close()
                    resultados = converter(resultados, tipos_resultados)
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
