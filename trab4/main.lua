local mqtt = require("mqtt_library")
local cliente_mqtt = nil
local usuario = "lelele"
local personagem = nil
local random = nil
local outros_usuarios = {}
local tamanhox, tamanhoy = 20, 30
local disparos = {}
local disparos_danosos = {}
local quantidade_disparos = 0



--[[
  Funções responsaveis por configurar um personagem
]]
local criarPersonagem = function(corCustomizada)
  -- Atributos
  local posx, posy = nil, nil
  local cor = corCustomizada
  
  local iniciar = function()
    local width, height = love.graphics.getDimensions()
    posx, posy = math.random(width-tamanhox), math.random(height-tamanhoy)
    if not corCustomizada then
      cor = {0, 0.4, 1}
    end
  end
  iniciar()
  
  local validarMovimento = function(x, y)
    if x and y then
      local width, height = love.graphics.getDimensions()
      -- Verifica se o objeto sairá da tela
      if x < 0 or (x+tamanhox) > width or y < 0 or (y+tamanhoy) > height then
        return false
      end
      -- Verifica se o objeto estará em cima de alguem 
      for k, v in pairs(outros_usuarios) do
        if x+tamanhox > tonumber(v[1]) and x < tonumber(v[1])+tamanhox and y+tamanhoy > tonumber(v[2]) and y < tonumber(v[2])+tamanhoy then
          return false
        end
      end
      return true -- retorna verdadeiro se com o movimento o objeto não sai da tela e nem passa por cima de alguem 
    end
    return false -- retorna falso se x ou y forem nulos
  end
  
  return {
    update = function()
    end,
    draw = function()
      love.graphics.setColor(cor)
      love.graphics.rectangle("fill", posx, posy, tamanhox, tamanhoy)
    end,
    keypressed = function(key)
      local newx, newy = nil, nil
      if love.keyboard.isDown("w") then
        newx = posx
        newy = posy - 10
      elseif love.keyboard.isDown("s") then
        newx = posx
        newy = posy + 10
      elseif love.keyboard.isDown("d") then
        newx = posx + 10
        newy = posy
      elseif love.keyboard.isDown("a") then
        newx = posx - 10
        newy = posy
      end
      if validarMovimento(newx, newy) then
        posx, posy = newx, newy
        cliente_mqtt:publish("trab4_moviment", usuario .. ";" .. tostring(posx) .. ";" .. tostring(posy))
      end
    end,
    obterPosicao = function()
      return posx, posy
    end,
    verificarDano = function(x, y)
      if x+4 > posx and x-4 < posx+tamanhox and y+4 > posy and y-4 < posy+tamanhoy then
        return true
      end
      return false
    end
  }
end

local criarDisparo = function(id, x, y, mouseX, mouseY, vX, vY, corCustomizada, terceiros)
  local posx = x
  local posy = y
  local velocidadeX, velocidadeY = vX, vY
  local diametro = 8
  local ativo = true
  local deslocamento = 8;
  local identificador = id
  local cor = corCustomizada
  local de_terceiros = false
  
  local validarMovimento = function(x, y)
    local width, height = love.graphics.getDimensions()
    -- Verifica se o objeto sairá da tela
    if (x+diametro) < 0 or (x-diametro) > width or (y+diametro) < 0 or (y-tamanhoy) > height then
      return false
    end
    return true -- retorna verdadeiro se com o movimento o objeto não sai da tela ou não atinge ninguem
  end
    
  local iniciar = function()
    if mouseX and mouseY then
      local angulo = math.abs(math.atan((posy-mouseY)/(mouseX-posx)))
      if mouseX > posx then
        velocidadeX = deslocamento*math.cos(angulo)
      else
        velocidadeX = -deslocamento*math.cos(angulo)
      end
      if mouseY > posy then
        velocidadeY = deslocamento*math.sin(angulo)
      else
        velocidadeY = -deslocamento*math.sin(angulo)
      end
      cliente_mqtt:publish("trab4_actions", usuario .. ";" .. identificador .. ";" .. tostring(posx) .. ";" .. tostring(posy) .. ";" .. tostring(velocidadeX) .. ";" .. tostring(velocidadeY))
    end
    if not corCustomizada then
      cor = {0, 0.8, 1}
    end
    if not de_terceiros then
      de_terceiros = terceiros
    end
  end
  iniciar()
  
  return {
    update = function()
      local newx, newy = posx+velocidadeX, posy+velocidadeY
      if validarMovimento(newx, newy) then
        posx, posy = newx, newy
      else
        ativo = false
      end
    end,
    draw = function()
      love.graphics.setColor(cor)
      love.graphics.circle("fill", posx, posy, diametro, diametro)
    end,
    estaAtivo = function()
      return ativo
    end,
    desativar = function()
      ativo = false
    end,
    deTerceiros = function()
      return de_terceiros
    end,
    obterPosicao = function()
      return posx, posy
    end,
    obterIdentificador = function()
      return identificador
    end
  }
end



--[[
  Funções responsaveis por configurar a conexão com o MQTT
]]
local criarClienteMqtt = function()
  local clienteCreateCallback = function(topic, message)
    controle = not controle
    local infos = {}
    for info in string.gmatch(message,"([^;]+)") do
        table.insert(infos, info)
        print(info)
    end
    if infos[1] ~= usuario then
      if topic == "trab4_moviment" then
        outros_usuarios[infos[1]] = {infos[2], infos[3]}
      elseif topic == "trab4_actions" then
        disparo = criarDisparo(infos[2], infos[3], infos[4], nil, nil, infos[5], infos[6], {1, 0.8, 0}, true)
        table.insert(disparos, disparo)
      elseif topic == "trab4_finishedactions" then
        table.insert(disparos_danosos, infos[2])
      end
    end
  end
  cliente_mqtt = mqtt.client.create("test.mosquitto.org", 1883, clienteCreateCallback)
end

local conectarClienteMqtt = function()
  local connect_feedback = cliente_mqtt:connect(usuario)
  if connect_feedback~=nil then
    print("ERRO! Houve problemas na conexão do cliente mqtt. Mensagem: " .. connect_feedback)
  end
end

local assinarTopicosMqtt = function(tabela_topicos)
  cliente_mqtt:subscribe(tabela_topicos)
end

local configurarClienteMqtt = function()
  criarClienteMqtt()
  conectarClienteMqtt()
  assinarTopicosMqtt({"trab4_moviment", "trab4_actions", "trab4_finishedactions"})
end



function love.load()
  math.randomseed(os.time())
  love.keyboard.setKeyRepeat(true)
  configurarClienteMqtt()
  personagem = criarPersonagem()
end

function love.update(dt)
  personagem.update()
  cliente_mqtt:handler()
  for i = #disparos,1,-1 do
    local posx, posy, houve_dano, remover = nil, nil, nil, false
    disparos[i].update()
    if not disparos[i].estaAtivo() then
      remover = true
    end
    posx, posy = disparos[i].obterPosicao()
    if personagem.verificarDano(posx, posy) then
      cliente_mqtt:publish("trab4_finishedactions", usuario .. ";" .. disparos[i].obterIdentificador())
      remover = true
    end
    for j = #disparos_danosos,1,-1 do
      if disparos_danosos[j] == disparos[i].obterIdentificador() then
        table.remove(disparos_danosos, j)
        remover = true
      end
    end
    if remover then
      table.remove(disparos, i)
    end
  end
  
end

function love.draw()
  personagem.draw()
  love.graphics.setColor(1, 0.2, 0)
  for k, v in pairs(outros_usuarios) do
    love.graphics.print(k, v[1], v[2]-20)
    love.graphics.rectangle("fill", v[1], v[2], tamanhox, tamanhoy)
  end
  love.graphics.setColor(1, 0.8, 0)
  for _, v in pairs(disparos) do
    v.draw()
  end
end

function love.keypressed(key)
  personagem.keypressed(key)
end

function love.mousereleased(mouseX, mouseY)
  quantidade_disparos = quantidade_disparos + 1
  local posx, posy = personagem.obterPosicao()
  local disparo = criarDisparo(usuario .. tostring(quantidade_disparos), posx, posy, mouseX, mouseY)
  table.insert(disparos, disparo)
end
