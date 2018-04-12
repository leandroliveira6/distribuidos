local socket = require('socket')
local servants = {}

-- Funções privadas
local imprime_tabela = function(tabela)
	for k, v in pairs(tabela) do
		print(k, v)
	end
end

local desempacotaRequest = function(request)
	local tmp = {}
	for item in string.gmatch(request, '([^,]+)') do
		table.insert(tmp, item)
	end
	return tmp
end

local adiciona_tabela = function(entradas, saidas, tipo, valor)
	if tipo == 'double' then
		tipo = 'number'
		if entradas then
			valor = tonumber(valor) 
		end
	elseif tipo == 'char' then
		tipo = 'string'
	end -- valor se torna nil caso não consiga converter
	
	if entradas then table.insert(entradas, valor) end
	if saidas and tipo ~= 'void' then table.insert(saidas, tipo) end
end

local criaResponse = function(saidas, ...)
	retornos = {...}
	response = ''
	--print('debug')
	--imprime_tabela(retornos)
	--imprime_tabela(saidas)
	--print('fimdebug')
	if #saidas == #retornos then
		for i=1,#saidas do
			if saidas[i] == type(retornos[i]) then
				response=response..tostring(retornos[i])..', '
			else
				return response..'___ERRORPC: Uma das saídas não corresponde ao tipo especificado pela interface!\n'
			end
		end
		return response..'\n'
	end
	return '___ERRORPC: Quantidade de saídas não corresponde com a interface!\n'
end

local executaRequest = function(raw_request, servant)
	local request = desempacotaRequest(raw_request)
	local metodos = servant.interface.methods
	if metodos[request[1]] then
		local metodo = table.remove(request, 1)
		local argumentos = metodos[metodo].args
		local entradas = {}
		local saidas = {}
		local j = 0
		adiciona_tabela(nil, saidas, metodos[metodo].resulttype, nil)
		for i=1,#argumentos do
			if argumentos[i].direction == 'in' then
				j=j+1 -- verificar o tamanho da request
				adiciona_tabela(entradas, nil, argumentos[i].type, request[j])
			elseif argumentos[i].direction == 'out' then
				adiciona_tabela(nil, saidas, argumentos[i].type, nil)
			else
				j=j+1 -- verificar o tamanho da request
				adiciona_tabela(entradas, saidas, argumentos[i].type, request[j])
			end
		end
		return criaResponse(saidas, servant.objeto[metodo](unpack(entradas)))
	end	
end

-- Funções publicas
local createServant = function(objeto, interface)
	servant = {
		objeto = objeto,
		interface = interface,
		servidor = socket.bind('*', 1234)
	}
	table.insert(servants, servant)
	return servant.servidor:getsockname()
end

local waitIncoming = function()
	while true do
		for i=1, #servants do
			servants[i].servidor:settimeout(1)
			local cliente = servants[i].servidor:accept()
			if cliente then
				cliente:settimeout(1)
				local request = cliente:receive()
				if request then
					local response = executaRequest(request, servants[i])
					cliente:send(response)
				end
				cliente:close()
			end					
		end
	end
end
	
return {createServant = createServant, waitIncoming = waitIncoming}
