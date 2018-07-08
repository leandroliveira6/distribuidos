local mqtt = require("mqtt_library")
local socket = require("socket")
local usuario = arg[2]
local topico_ataque = arg[3]
--local intervalo = arg[3]
local tempo_inicio = 0
local tempo_inicio_ataque = 0
local tempo_duracao_ataque = 0
local acabou = false
local cliente_mqtt = nil
local quantidade_mensagens = 0
local fator_rgb = 1



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
  if connect_feedback then
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
  if cliente_mqtt.connected then
    assinarTopicosMqtt({topico_ataque})
  end
end


function love.load()
  configurarClienteMqtt()
  tempo_inicio = socket.gettime()
end

function love.update(dt)
  if not acabou then
    if cliente_mqtt.connected and tempo_inicio_ataque > 0 then
      tempo_duracao_ataque = socket.gettime() - tempo_inicio_ataque
      cliente_mqtt:handler()
      cliente_mqtt:publish(topico_ataque, "teste de carga")
      --socket.sleep(intervalo)
    elseif not cliente_mqtt.connected and tempo_inicio_ataque > 0 then
      acabou = true
    elseif cliente_mqtt.connected then
      tempo_inicio_ataque = socket.gettime()
    end
  end
end

function love.draw()
  love.graphics.setColor(1*fator_rgb, 1*fator_rgb, 1*fator_rgb)
  love.graphics.print("Quantidade de mensagens: " .. quantidade_mensagens, 10, 10, 0, 3, 3)
  love.graphics.print("Tempo decorrido: " .. tostring(socket.gettime()-tempo_inicio), 10, 50, 0, 3, 3)
  if tempo_duracao_ataque > 0 then
    love.graphics.print("Tempo de ataque: " .. tempo_duracao_ataque, 10, 90, 0, 3, 3)
    love.graphics.print("Mensagens por segundo: " .. tostring(quantidade_mensagens/tempo_duracao_ataque), 10, 130, 0, 3, 3)
  end
  
end

function love.keyreleased(key)
  if cliente_mqtt.connected then
    cliente_mqtt:publish(topico_ataque, "teste")
  end
end