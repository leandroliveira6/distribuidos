local mqtt = require("mqtt_library")
local cliente_mqtt = nil -- Contem o objeto mqtt
local usuario = arg[2] -- Nome de usuario deve ser passado por parametro na execução do projeto
local personagem = nil -- Tabela que contem a nave do usuario
local outros_usuarios = {} -- A posicao dos demais usuarios conectados ao mqtt e chaveados pelo nome
local outros_usuarios_situacao = {} -- A situação da vida dos usuarios conectados, tambem chaveado pelos nomes. São iniciados com true, mudado para false ao receber uma mensagem no topico trab4_finishedactions informando que o mesmo foi morto
local tamanhox, tamanhoy = 20, 30 -- Tamanho do retangulo dos personagens
local disparos = {} -- Lista de todos os disparos ativos, tais disparos são desativados ao sair da tela ou atingir algum usuario
local disparos_danosos = {} -- Lista de todos os disparos que atingiram alguem. Usada para remoção do disparo da lista de disparos
local quantidade_disparos = 0 -- Utilizado como parte do id do disparo, para fins de reconhecimento e remoção caso o mesmo atinja alguem
local dano_por_disparo = 10 -- Como o proprio nome sugere, é o dano que o personagem leva por cada disparo que o atingiu
local pontos = 0 -- Para cada disparo que tenha acertado alguem, um ponto é dado
local fator_rgb = 1 -- Fator multiplicativo para os parametros rgb do setColor, pois dependendo da versão o padrão [0..255] não é empregado, mas sim [0..1]



--[[
  Função responsavel por configurar um personagem e retorna uma tabela com todas as funções necessarias
]]  
local criarPersonagem = function(corCustomizada)
  -- Atributos
  local posx, posy = nil, nil
  local cor = corCustomizada
  local vida = 20
  
  -- Função para publicar no mqtt a posição do personagem
  local publicarPosicao = function()
    cliente_mqtt:publish("trab4_moviment", usuario .. ";" .. tostring(posx) .. ";" .. tostring(posy))
  end
  
  -- Função que inicializa as variaveis locais do personagem, como a posição (randomica) e cor, publicando no mqtt no final
  local iniciar = function()
    local width, height = love.graphics.getDimensions()
    posx, posy = math.random(width-tamanhox), math.random(height-tamanhoy)
    if not corCustomizada then
      cor = {0, 1*fator_rgb, 1*fator_rgb}
    end
    publicarPosicao()
  end
  iniciar()
  
  -- Verifica se a proxima coordenada, passada nos parametros x e y, é valida, ou seja, está dentro da tela e não está em cima de alguem 
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
    draw = function()
      love.graphics.setColor(cor)
      love.graphics.rectangle("fill", posx, posy, tamanhox, tamanhoy)
    end,
    keypressed = function(key)
      local newx, newy = nil, nil
      if vida <= 0 then
        return
      end
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
      if validarMovimento(newx, newy) then -- Se o movimento for valido, é publicado no mqtt a nova coordenada para atualização nas outras instancias
        posx, posy = newx, newy
        publicarPosicao()
      end
    end,
    obterPosicao = function()
      return posx, posy
    end,
    verificarDano = function(disparo) -- Na iteração do update por todos os disparos para atualização das coordenadas, é verificado para cada um se o mesmo atingiu o personagem corrente, retornando true e publicando no mqtt caso tenha atingido
      local x, y = disparo.obterPosicao()
      if vida <= 0 then
        return false
      elseif x+4 > posx and x-4 < posx+tamanhox and y+4 > posy and y-4 < posy+tamanhoy then
        vida = vida - dano_por_disparo
        if vida <= 0 then
          cor = {0, 0.4*fator_rgb, 0.4*fator_rgb}
          -- Publicação que faz com que a exibição das instancias mortas mude
          cliente_mqtt:publish("trab4_finishedactions", usuario .. ";" .. disparo.obterIdentificador() .. ";" .. disparo.obterCriador() .. ";" .. "morto")
        end
        -- Publicação para uso de quem efetuou o disparo que atingiu a instancia, para que o mesmo contabilize os pontos
        cliente_mqtt:publish("trab4_finishedactions", usuario .. ";" .. disparo.obterIdentificador() .. ";" .. disparo.obterCriador() .. ";" .. "vivo")
        return true
      end
      return false
    end,
    verificarSituacao = function() -- Retorna verdadeiro se o personagem ainda vive
      if vida <= 0 then
        return false
      end
      return true
    end,
    publicarPosicao = publicarPosicao
  }
end

local criarDisparo = function(id, x, y, mouseX, mouseY, vX, vY, corCustomizada, terceiros, atirador)
  local posx = x
  local posy = y
  local velocidadeX, velocidadeY = vX, vY
  local diametro = 8
  local ativo = true
  local deslocamento = 8;
  local identificador = id
  local cor = corCustomizada
  local de_terceiros = false -- Disparos que não são da instancia corrente são tratados iguais
  local criador = atirador -- Para se atingir o personagem corrente o mesmo poder informar a quem atingiu
  local bloqueado = true
  
  local validarMovimento = function(x, y)
    local width, height = love.graphics.getDimensions()
    -- Verifica se o objeto sairá da tela
    if (x+diametro*2) < 0 or (x-diametro*2) > width or (y+diametro*2) < 0 or (y-diametro*2) > height then
      return false
    end
    return true -- retorna verdadeiro se com o movimento o objeto não sai da tela
  end
    
  local iniciar = function() -- Se houver mouseX e mouseY, significa que o disparo é local, criando assim uma instancia de disparo propria, sendo esta ignorada ao verificar colisões no personagem corrente. É publicado os dados de todos os disparos proprios, para que as demais instancias do jogo possa replica-lo
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
      cor = {0, 0.8*fator_rgb, 1*fator_rgb}
    end
    if terceiros then
      de_terceiros = terceiros
      bloqueado = false
    end
  end
  iniciar()
  
  return {
    update = function() -- Movimenta o disparo segundo as componentes da velocidade
      if not bloqueado then
        local newx, newy = posx+velocidadeX, posy+velocidadeY
        if validarMovimento(newx, newy) then
          posx, posy = newx, newy
        else
          ativoa = false
        end
      end
    end,
    draw = function()
      love.graphics.setColor(cor)
      love.graphics.circle("fill", posx, posy, diametro, diametro)
      if bloqueado then
        love.graphics.line(posx, posy, posx+velocidadeX*4, posy+velocidadeY*4)
      end
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
    end,
    obterCriador = function()
      return criador
    end,
    desbloquear = function()
      bloqueado = false
    end
  }
end



--[[
  Funções responsaveis por configurar a conexão com o MQTT
]]
local criarClienteMqtt = function()
  local clienteCreateCallback = function(topic, message)
    local infos = {}
    for info in string.gmatch(message,"([^;]+)") do
        table.insert(infos, info)
    end
    if infos[1] ~= usuario then
      if topic == "trab4_moviment" and infos[2] and infos[3] then -- Topico que lista todas as posições das instancias do jogo. Ao receber mensagens nesse topico, é criada/atualizada a posição do personagem que se movimentou. Cada personagem possui sua propria chave na lista de outros usuarios e na situação dos outros usuarios, facilitando assim o acesso e manutenção da mesma 
        print("Nova mensagem de movimento")
        if not outros_usuarios[infos[1]] then
          personagem.publicarPosicao()
        end
        outros_usuarios[infos[1]] = {infos[2], infos[3]}
        outros_usuarios_situacao[infos[1]] = true -- true para vivo
        
      elseif topic == "trab4_actions" then -- Lista todos os disparos efetuados. Para fins de otimização, visto que não há necessidade de publicar toda a tragetoria do disparo já que ela é constante, as mensagens para esse topico só são enviadas uma vez, na criação do disparo. Todas as demais aplicações replica esse disparo localmente, o diferenciando dos proprios disparos, para que os mesmos computem localmente as movimentações
        disparo = criarDisparo(infos[2], infos[3], infos[4], nil, nil, infos[5], infos[6], {1*fator_rgb, 0.8*fator_rgb, 0}, true, infos[1])
        table.insert(disparos, disparo)
        
      elseif topic == "trab4_finishedactions" then -- Lista todos os disparos que atingiram alguem. Para fins de pontuação, remoção do disparo da tela ou informar que algum dos jogadores foi morto
        table.insert(disparos_danosos, infos[2])
        if infos[3] == usuario then
          pontos = pontos + 1
        end
        if infos[4] == "morto" then
          outros_usuarios_situacao[infos[1]] = false -- false para morto
        end
      end
    elseif topic == "trab4_actions" then
      for i = #disparos,1,-1 do -- Itera sobre todos os disparos a fim de desbloquear o disparo efetuado
        if disparos[i].obterIdentificador() == infos[2] then
          disparos[i].desbloquear()
          break
        end
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
  math.randomseed(os.time()) -- Necessario para que a randomização dos valores seja mais variada
  love.keyboard.setKeyRepeat(true)
  configurarClienteMqtt()
  personagem = criarPersonagem()
end

function love.update(dt)
  cliente_mqtt:handler()
  for i = #disparos,1,-1 do -- Itera sobre todos os disparos, verificando para cada um se o mesmo atingiu alguem ou saiu da tela, tendo assim que ser removido
    local remover = false
    disparos[i].update()
    if not disparos[i].estaAtivo() then
      remover = true
    end
    if disparos[i].deTerceiros() and personagem.verificarDano(disparos[i]) then
      remover = true
    end
    for j = #disparos_danosos,1,-1 do
      if disparos_danosos[j] == disparos[i].obterIdentificador() then
        table.remove(disparos_danosos, j)
        remover = true
        break
      end
    end
    if remover then
      table.remove(disparos, i)
    end
  end
end

function love.draw()
  personagem.draw()
  for k, v in pairs(outros_usuarios) do
    if outros_usuarios_situacao[k] then -- Pinta de uma cor clara personagens vivos e de cor escura personagens mortos
      love.graphics.setColor(1*fator_rgb, 1*fator_rgb, 0)
    else
      love.graphics.setColor(0.4*fator_rgb, 0.4*fator_rgb, 0)
    end
    love.graphics.print(k, v[1], v[2]-20)
    love.graphics.rectangle("fill", v[1], v[2], tamanhox, tamanhoy)
  end
  for _, v in pairs(disparos) do
    v.draw()
  end
  love.graphics.setColor(1*fator_rgb, 1*fator_rgb, 1*fator_rgb)
  love.graphics.print("Pontos: " .. pontos, 10, 10)
end

function love.keypressed(key)
  personagem.keypressed(key)
end

function love.mousereleased(mouseX, mouseY)
  if personagem.verificarSituacao() then -- Se o personagem tiver vivo, cria uma instancia pro disparo e insere ela na lista de disparos para manutenção e exibição
    quantidade_disparos = quantidade_disparos + 1
    local posx, posy = personagem.obterPosicao()
    local disparo = criarDisparo(usuario .. tostring(quantidade_disparos), posx+tamanhox/2, posy, mouseX, mouseY)
    table.insert(disparos, disparo)
  end
end
