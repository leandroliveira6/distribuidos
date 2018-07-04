local mqtt = require("mqtt_library")
local usuario = arg[1]
local cliente_mqtt = nil
local quantidade_mensagens = 0



--[[
  Funções responsaveis por configurar a conexão com o MQTT
]]
local criarClienteMqtt = function()
  local clienteCreateCallback = function(topic, message)
    quantidade_mensagens = quantidade_mensagens + 1
    print(quantidade_mensagens)
  end
  cliente_mqtt = mqtt.client.create("test.mosquitto.org", 1883, clienteCreateCallback)
end

local conectarClienteMqtt = function()
  local connect_feedback = cliente_mqtt:connect(usuario)
  if connect_feedback~=nil then
    print("ERRO! Houve problemas na conexão do cliente mqtt. Mensagem: " .. connect_feedback)
  else
    print("SUCESSO! " .. tostring(cliente_mqtt.connected))
  end
end

local assinarTopicosMqtt = function(tabela_topicos)
  cliente_mqtt:subscribe(tabela_topicos)
end

local configurarClienteMqtt = function()
  criarClienteMqtt()
  conectarClienteMqtt()
  assinarTopicosMqtt({"trab4_moviment"})
end

configurarClienteMqtt()

while true do
  if cliente_mqtt.connected then
    cliente_mqtt:publish("trab4_moviment", "teste")
  end
end